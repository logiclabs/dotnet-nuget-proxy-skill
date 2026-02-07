using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace NuGetProxyAuth;

/// <summary>
/// NuGet Proxy Credential Provider - Self-contained proxy + NuGet plugin.
///
/// Solves the problem where NuGet doesn't pass PROXY_AUTHORIZATION to the
/// downstream proxy, causing 401 errors during package restore.
///
/// This single executable:
///   1. Embeds an HTTP/HTTPS proxy that injects JWT auth into upstream requests
///   2. Manages the proxy lifecycle (start/stop/health check as daemon)
///   3. Implements the NuGet cross-platform plugin protocol v2
///   4. When NuGet invokes this plugin, it ensures the proxy is running first
/// </summary>
class Program
{
    const int LocalProxyPort = 8888;
    const string LocalProxyHost = "127.0.0.1";
    static readonly string LocalProxyUrl = $"http://{LocalProxyHost}:{LocalProxyPort}";
    static readonly string PidFile = Path.Combine(Path.GetTempPath(), "nuget-proxy.pid");
    static readonly string LogFile = Path.Combine(Path.GetTempPath(), "nuget-proxy.log");

    static int Main(string[] args)
    {
        var argSet = new HashSet<string>(args, StringComparer.OrdinalIgnoreCase);

        if (argSet.Contains("-Plugin"))
            return RunPlugin();
        if (argSet.Contains("--_run-proxy"))
            return RunProxyServer();
        if (argSet.Contains("--start"))
            return StartDaemon() ? 0 : 1;
        if (argSet.Contains("--stop"))
            return StopDaemon() ? 0 : 1;

        PrintStatus();
        return 0;
    }

    // =========================================================================
    // Environment / Credential Helpers
    // =========================================================================

    static string? GetUpstreamProxyUrl()
    {
        // The install script saves the original upstream proxy here
        var upstream = Environment.GetEnvironmentVariable("_NUGET_UPSTREAM_PROXY")?.Trim();
        if (!string.IsNullOrEmpty(upstream))
            return upstream;

        // Fall back: check standard env vars, skip if they point to our local proxy
        foreach (var name in new[] { "HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy" })
        {
            var url = Environment.GetEnvironmentVariable(name)?.Trim();
            if (!string.IsNullOrEmpty(url) &&
                !url.Contains("127.0.0.1") &&
                !url.Contains("localhost"))
                return url;
        }

        return null;
    }

    static (string? host, int port, string? authHeader) ParseUpstreamProxy()
    {
        var url = GetUpstreamProxyUrl();
        if (url == null) return (null, 0, null);

        try
        {
            var uri = new Uri(url);
            string? auth = null;
            if (!string.IsNullOrEmpty(uri.UserInfo))
            {
                var decoded = Uri.UnescapeDataString(uri.UserInfo);
                auth = "Basic " + Convert.ToBase64String(Encoding.UTF8.GetBytes(decoded));
            }
            return (uri.Host, uri.Port, auth);
        }
        catch
        {
            return (null, 0, null);
        }
    }

    // =========================================================================
    // Proxy Server
    // =========================================================================

    static int RunProxyServer()
    {
        var (upstreamHost, upstreamPort, upstreamAuth) = ParseUpstreamProxy();
        if (upstreamHost == null)
        {
            Log("ERROR: No upstream proxy URL found in environment");
            return 1;
        }

        var listener = new TcpListener(IPAddress.Parse(LocalProxyHost), LocalProxyPort);
        try
        {
            listener.Start();
        }
        catch (SocketException ex)
        {
            Log($"ERROR: Cannot bind to {LocalProxyUrl}: {ex.Message}");
            return 1;
        }

        Log($"NuGet proxy running on {LocalProxyUrl}");
        Console.WriteLine($"NuGet proxy running on {LocalProxyUrl}");

        while (true)
        {
            try
            {
                var client = listener.AcceptTcpClient();
                ThreadPool.QueueUserWorkItem(_ =>
                    HandleClient(client, upstreamHost, upstreamPort, upstreamAuth));
            }
            catch (Exception ex)
            {
                Log($"Accept error: {ex.Message}");
            }
        }
    }

    static void HandleClient(TcpClient client, string upstreamHost, int upstreamPort, string? upstreamAuth)
    {
        try
        {
            client.ReceiveTimeout = 60000;
            client.SendTimeout = 60000;
            using var clientStream = client.GetStream();

            // Read the first request line + headers
            var requestBytes = ReadHttpHeaders(clientStream);
            if (requestBytes == null) return;

            var requestText = Encoding.ASCII.GetString(requestBytes);
            var firstLine = requestText.Split('\n')[0].Trim('\r');
            var parts = firstLine.Split(' ');
            if (parts.Length < 3) return;

            var method = parts[0].ToUpper();

            if (method == "CONNECT")
                HandleConnect(clientStream, parts[1], upstreamHost, upstreamPort, upstreamAuth);
            else
                HandleHttpRequest(clientStream, requestBytes, upstreamHost, upstreamPort, upstreamAuth);
        }
        catch (Exception ex)
        {
            Log($"Client error: {ex.Message}");
        }
        finally
        {
            try { client.Close(); } catch { }
        }
    }

    static void HandleConnect(NetworkStream clientStream, string target,
        string upstreamHost, int upstreamPort, string? upstreamAuth)
    {
        Log($"CONNECT {target}");

        using var upstream = new TcpClient();
        upstream.Connect(upstreamHost, upstreamPort);
        using var upstreamStream = upstream.GetStream();

        // Send CONNECT to upstream proxy with auth
        var connectReq = new StringBuilder();
        connectReq.Append($"CONNECT {target} HTTP/1.1\r\n");
        connectReq.Append($"Host: {target}\r\n");
        if (upstreamAuth != null)
            connectReq.Append($"Proxy-Authorization: {upstreamAuth}\r\n");
        connectReq.Append("\r\n");

        var connectBytes = Encoding.ASCII.GetBytes(connectReq.ToString());
        upstreamStream.Write(connectBytes, 0, connectBytes.Length);
        upstreamStream.Flush();

        // Read upstream response
        var responseBytes = ReadHttpHeaders(upstreamStream);
        if (responseBytes == null) return;

        var responseText = Encoding.ASCII.GetString(responseBytes);
        var statusLine = responseText.Split('\n')[0].Trim('\r');

        // Parse status code: "HTTP/1.1 200 ..."
        var statusParts = statusLine.Split(' ');
        var statusCode = statusParts.Length >= 2 ? statusParts[1] : "";

        if (statusCode == "200")
        {
            // Tell client the tunnel is established
            var ok = Encoding.ASCII.GetBytes("HTTP/1.1 200 Connection Established\r\nProxy-Agent: NuGet-Proxy\r\n\r\n");
            clientStream.Write(ok, 0, ok.Length);
            clientStream.Flush();

            // Relay data bidirectionally
            Relay(clientStream, upstreamStream);
        }
        else
        {
            // Forward the error to client
            var errMsg = $"HTTP/1.1 502 Bad Gateway\r\n\r\nUpstream proxy refused CONNECT: {statusLine}\r\n";
            var errBytes = Encoding.ASCII.GetBytes(errMsg);
            clientStream.Write(errBytes, 0, errBytes.Length);
            clientStream.Flush();
        }
    }

    static void HandleHttpRequest(NetworkStream clientStream, byte[] requestBytes,
        string upstreamHost, int upstreamPort, string? upstreamAuth)
    {
        var requestText = Encoding.ASCII.GetString(requestBytes);
        var firstLine = requestText.Split('\n')[0].Trim('\r');
        Log(firstLine);

        // Inject Proxy-Authorization header if not present (search headers only, not body)
        if (upstreamAuth != null)
        {
            var headerEnd = requestText.IndexOf("\r\n\r\n", StringComparison.Ordinal);
            if (headerEnd >= 0)
            {
                var headersOnly = requestText.Substring(0, headerEnd);
                if (headersOnly.IndexOf("Proxy-Authorization:", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    var modified = headersOnly +
                                   $"\r\nProxy-Authorization: {upstreamAuth}" +
                                   requestText.Substring(headerEnd);
                    requestBytes = Encoding.ASCII.GetBytes(modified);
                }
            }
        }

        // Forward to upstream proxy
        try
        {
            using var upstream = new TcpClient();
            upstream.Connect(upstreamHost, upstreamPort);
            using var upstreamStream = upstream.GetStream();

            upstreamStream.Write(requestBytes, 0, requestBytes.Length);
            upstreamStream.Flush();

            // Read and forward response
            var buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = upstreamStream.Read(buffer, 0, buffer.Length)) > 0)
            {
                clientStream.Write(buffer, 0, bytesRead);
            }
            clientStream.Flush();
        }
        catch (Exception ex)
        {
            var errMsg = $"HTTP/1.1 502 Bad Gateway\r\n\r\nProxy Error: {ex.Message}\r\n";
            var errBytes = Encoding.ASCII.GetBytes(errMsg);
            clientStream.Write(errBytes, 0, errBytes.Length);
            clientStream.Flush();
        }
    }

    static void Relay(NetworkStream a, NetworkStream b)
    {
        var cts = new CancellationTokenSource();
        var t1 = Task.Run(() => CopyStream(a, b, cts));
        var t2 = Task.Run(() => CopyStream(b, a, cts));
        Task.WaitAny(t1, t2);
        cts.Cancel();
        try { Task.WaitAll(t1, t2); } catch { }
    }

    static void CopyStream(NetworkStream source, NetworkStream dest, CancellationTokenSource cts)
    {
        try
        {
            var buffer = new byte[8192];
            while (!cts.IsCancellationRequested)
            {
                var read = source.Read(buffer, 0, buffer.Length);
                if (read <= 0) break;
                dest.Write(buffer, 0, read);
            }
        }
        catch { }
    }

    static byte[]? ReadHttpHeaders(NetworkStream stream)
    {
        var buffer = new List<byte>(4096);
        var timeout = 30000;
        var sw = Stopwatch.StartNew();

        while (sw.ElapsedMilliseconds < timeout)
        {
            if (stream.DataAvailable)
            {
                var b = stream.ReadByte();
                if (b < 0) break;
                buffer.Add((byte)b);

                // Check for end of headers
                var len = buffer.Count;
                if (len >= 4 &&
                    buffer[len - 4] == '\r' && buffer[len - 3] == '\n' &&
                    buffer[len - 2] == '\r' && buffer[len - 1] == '\n')
                {
                    return buffer.ToArray();
                }
            }
            else
            {
                Thread.Sleep(1);
            }
        }

        return buffer.Count > 0 ? buffer.ToArray() : null;
    }

    // =========================================================================
    // Daemon Lifecycle
    // =========================================================================

    static bool IsProxyRunning()
    {
        // Check PID file
        if (File.Exists(PidFile))
        {
            try
            {
                var pidStr = File.ReadAllText(PidFile).Trim();
                if (int.TryParse(pidStr, out var pid))
                {
                    var proc = Process.GetProcessById(pid);
                    if (!proc.HasExited) return true;
                }
            }
            catch { }
        }

        // Fall back: check if port is listening
        try
        {
            using var sock = new TcpClient();
            sock.Connect(LocalProxyHost, LocalProxyPort);
            return true;
        }
        catch
        {
            return false;
        }
    }

    static bool StartDaemon()
    {
        if (IsProxyRunning())
        {
            Log("Proxy already running");
            Console.WriteLine($"Proxy already running on {LocalProxyUrl}");
            return true;
        }

        var upstream = GetUpstreamProxyUrl();
        if (upstream == null)
        {
            Log("ERROR: No upstream proxy URL found in environment");
            Console.Error.WriteLine("ERROR: No upstream proxy URL found. Set _NUGET_UPSTREAM_PROXY or HTTPS_PROXY.");
            return false;
        }

        Log($"Starting proxy daemon on {LocalProxyUrl}");

        // Spawn self with --_run-proxy flag
        var exePath = Environment.ProcessPath ?? Process.GetCurrentProcess().MainModule?.FileName;
        if (exePath == null)
        {
            Console.Error.WriteLine("ERROR: Cannot determine executable path");
            return false;
        }

        // Determine how to launch: if we're a .dll, use dotnet; if .exe or native, run directly
        string fileName;
        string arguments;
        if (exePath.EndsWith(".dll", StringComparison.OrdinalIgnoreCase) ||
            exePath.Contains("dotnet"))
        {
            // Find the DLL path - it might be the entry assembly
            var dllPath = System.Reflection.Assembly.GetExecutingAssembly().Location;
            if (string.IsNullOrEmpty(dllPath))
                dllPath = exePath;
            fileName = "dotnet";
            arguments = $"\"{dllPath}\" --_run-proxy";
        }
        else
        {
            fileName = exePath;
            arguments = "--_run-proxy";
        }

        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };

        // Pass upstream proxy to child
        psi.Environment["_NUGET_UPSTREAM_PROXY"] = upstream;
        // Copy other relevant env vars
        foreach (var name in new[] { "PROXY_AUTHORIZATION", "HTTPS_PROXY", "HTTP_PROXY", "https_proxy", "http_proxy" })
        {
            var val = Environment.GetEnvironmentVariable(name);
            if (val != null)
                psi.Environment[name] = val;
        }

        var proc = Process.Start(psi);
        if (proc == null)
        {
            Console.Error.WriteLine("ERROR: Failed to start proxy process");
            return false;
        }

        // Redirect stdout/stderr to log file in background
        _ = Task.Run(async () =>
        {
            try
            {
                using var logStream = File.Open(LogFile, FileMode.Append, FileAccess.Write, FileShare.Read);
                using var writer = new StreamWriter(logStream) { AutoFlush = true };
                var stdout = proc.StandardOutput.ReadToEndAsync();
                var stderr = proc.StandardError.ReadToEndAsync();
                var results = await Task.WhenAll(stdout, stderr);
                foreach (var r in results)
                    if (!string.IsNullOrEmpty(r)) await writer.WriteAsync(r);
            }
            catch { }
        });

        proc.StandardInput.Close();

        File.WriteAllText(PidFile, proc.Id.ToString());

        // Wait for proxy to be ready
        for (int i = 0; i < 20; i++)
        {
            Thread.Sleep(250);
            if (IsProxyRunning())
            {
                Log($"Proxy started (PID {proc.Id})");
                Console.WriteLine($"Proxy running on {LocalProxyUrl} (PID {proc.Id})");
                return true;
            }
        }

        Console.Error.WriteLine("ERROR: Proxy failed to start within 5 seconds");
        return false;
    }

    static bool StopDaemon()
    {
        if (File.Exists(PidFile))
        {
            try
            {
                var pidStr = File.ReadAllText(PidFile).Trim();
                if (int.TryParse(pidStr, out var pid))
                {
                    var proc = Process.GetProcessById(pid);
                    proc.Kill();
                    File.Delete(PidFile);
                    Console.WriteLine($"Proxy stopped (PID {pid})");
                    return true;
                }
            }
            catch (ArgumentException)
            {
                // Process not found
                File.Delete(PidFile);
            }
            catch { }
        }
        Console.WriteLine("Proxy is not running");
        return false;
    }

    // =========================================================================
    // NuGet Plugin Protocol v2
    // =========================================================================

    static int RunPlugin()
    {
        Log("Plugin starting");

        // Ensure the proxy is running before NuGet makes any requests
        if (!IsProxyRunning())
        {
            Log("Proxy not running, starting daemon...");
            if (!StartDaemon())
                Log("WARNING: Failed to start proxy daemon");
        }
        else
        {
            Log("Proxy already running");
        }

        Log("Handling NuGet plugin protocol");

        try
        {
            string? line;
            while ((line = Console.ReadLine()) != null)
            {
                line = line.Trim();
                if (string.IsNullOrEmpty(line)) continue;

                PluginMessage? message;
                try
                {
                    message = JsonSerializer.Deserialize<PluginMessage>(line);
                }
                catch
                {
                    continue;
                }

                if (message == null || message.Type != "Request") continue;

                var response = HandlePluginMessage(message);
                var json = JsonSerializer.Serialize(response);
                Console.WriteLine(json);
                Console.Out.Flush();
            }
        }
        catch (Exception ex) when (ex is IOException || ex is ObjectDisposedException)
        {
            // Pipe closed
        }

        Log("Plugin exiting (proxy daemon stays running)");
        return 0;
    }

    static PluginMessage HandlePluginMessage(PluginMessage request)
    {
        var method = request.Method ?? "";
        var rid = request.RequestId ?? Guid.NewGuid().ToString();

        return method switch
        {
            "Handshake" => MakeResponse(rid, "Handshake", new Dictionary<string, object>
            {
                ["ResponseCode"] = "Success",
                ["ProtocolVersion"] = "2.0.0",
            }),
            "Initialize" => MakeResponse(rid, "Initialize", new Dictionary<string, object>
            {
                ["ResponseCode"] = "Success",
            }),
            "GetOperationClaims" => MakeResponse(rid, "GetOperationClaims", new Dictionary<string, object>
            {
                ["ResponseCode"] = "Success",
                ["Claims"] = new[] { 2 }, // Authentication
            }),
            "GetAuthenticationCredentials" => HandleGetCredentials(rid),
            "SetCredentials" => MakeResponse(rid, "SetCredentials", new Dictionary<string, object>
            {
                ["ResponseCode"] = "Success",
            }),
            _ => MakeResponse(rid, method, new Dictionary<string, object>
            {
                ["ResponseCode"] = "NotFound",
            }),
        };
    }

    static PluginMessage HandleGetCredentials(string requestId)
    {
        // Get credentials from env
        var proxyAuth = Environment.GetEnvironmentVariable("PROXY_AUTHORIZATION")?.Trim();
        string? username = null, password = null;

        if (!string.IsNullOrEmpty(proxyAuth))
        {
            username = "proxy-auth";
            password = proxyAuth;
        }
        else
        {
            // Try extracting from upstream proxy URL
            var upstream = GetUpstreamProxyUrl();
            if (upstream != null)
            {
                try
                {
                    var uri = new Uri(upstream);
                    if (!string.IsNullOrEmpty(uri.UserInfo))
                    {
                        var parts = Uri.UnescapeDataString(uri.UserInfo).Split(':', 2);
                        username = parts[0];
                        password = parts.Length > 1 ? parts[1] : "";
                    }
                }
                catch { }
            }
        }

        if (username != null && password != null)
        {
            return MakeResponse(requestId, "GetAuthenticationCredentials", new Dictionary<string, object>
            {
                ["ResponseCode"] = "Success",
                ["Username"] = username,
                ["Password"] = password,
                ["AuthTypes"] = new[] { "Basic" },
                ["Message"] = "",
            });
        }

        return MakeResponse(requestId, "GetAuthenticationCredentials", new Dictionary<string, object>
        {
            ["ResponseCode"] = "NotFound",
            ["Username"] = "",
            ["Password"] = "",
            ["AuthTypes"] = Array.Empty<string>(),
            ["Message"] = "No proxy credentials found in environment",
        });
    }

    static PluginMessage MakeResponse(string requestId, string method, Dictionary<string, object> payload)
    {
        return new PluginMessage
        {
            RequestId = requestId,
            Type = "Response",
            Method = method,
            Payload = payload,
        };
    }

    // =========================================================================
    // Status Display
    // =========================================================================

    static void PrintStatus()
    {
        Console.WriteLine("NuGetProxyCredentialProvider");
        Console.WriteLine("===========================");
        Console.WriteLine();

        var running = IsProxyRunning();
        Console.WriteLine($"  Local proxy:    {LocalProxyUrl}  [{(running ? "RUNNING" : "STOPPED")}]");

        if (File.Exists(PidFile))
        {
            try { Console.WriteLine($"  Proxy PID:      {File.ReadAllText(PidFile).Trim()}"); }
            catch { }
        }

        var upstream = GetUpstreamProxyUrl();
        if (upstream != null)
        {
            try
            {
                var uri = new Uri(upstream);
                Console.WriteLine($"  Upstream proxy: {uri.Scheme}://{uri.Host}:{uri.Port}");
            }
            catch { Console.WriteLine($"  Upstream proxy: {upstream}"); }
        }
        else
        {
            Console.WriteLine("  Upstream proxy: (not detected)");
        }

        Console.WriteLine($"  Plugin paths:   {Environment.GetEnvironmentVariable("NUGET_PLUGIN_PATHS") ?? "(not set)"}");
        Console.WriteLine();
        Console.WriteLine("Commands:");
        Console.WriteLine("  --start    Start proxy daemon");
        Console.WriteLine("  --stop     Stop proxy daemon");
        Console.WriteLine("  --status   Show this status");
        Console.WriteLine("  -Plugin    NuGet plugin mode (auto)");
    }

    // =========================================================================
    // Logging
    // =========================================================================

    static void Log(string message)
    {
        Console.Error.WriteLine($"[NuGetProxyAuth] {message}");
        Console.Error.Flush();
    }
}

// =========================================================================
// NuGet Plugin Protocol Message
// =========================================================================

class PluginMessage
{
    [JsonPropertyName("RequestId")]
    public string? RequestId { get; set; }

    [JsonPropertyName("Type")]
    public string? Type { get; set; }

    [JsonPropertyName("Method")]
    public string? Method { get; set; }

    [JsonPropertyName("Payload")]
    public Dictionary<string, object>? Payload { get; set; }
}
