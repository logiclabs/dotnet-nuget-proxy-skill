# NuGet Proxy for Claude Code Environment

This directory contains a proxy solution that enables `dotnet restore` and `dotnet build` to work in the Claude Code environment by handling proxy authentication automatically.

## Quick Start (Recommended)

```bash
# Install the C# credential provider (compiles plugin, starts proxy, sets env vars)
source install-credential-provider.sh

# Then use dotnet normally - no wrapper scripts needed
dotnet restore
dotnet build
dotnet test
```

The install script:
- Compiles a C# NuGet credential provider plugin from `nuget-plugin-proxy-auth-src/`
- Installs it to `~/.nuget/plugins/netcore/` where NuGet auto-discovers it
- Saves the original upstream proxy URL to `_NUGET_UPSTREAM_PROXY`
- Creates a `dotnet()` shell function that routes only dotnet traffic through `localhost:8888`
- Starts the proxy daemon
- Global `HTTPS_PROXY` stays unchanged — other tools (curl, apt, pip) are unaffected

## How It Works

```
NuGet -> localhost:8888 (proxy daemon) -> Upstream Proxy (JWT injected) -> nuget.org
         [no auth required]               [Proxy-Authorization header]     [internet]
```

The C# credential provider plugin:
1. **Embeds a proxy server** that listens on `localhost:8888` without authentication
2. **Injects JWT credentials** into upstream proxy CONNECT requests
3. **Manages the proxy lifecycle** as a background daemon (start/stop/health check)
4. **Implements the NuGet plugin protocol v2** so NuGet discovers it automatically

## Files

- **`nuget-plugin-proxy-auth-src/`** - C# source for the credential provider
  - `Program.cs` - Single-file implementation (~725 lines)
  - `nuget-plugin-proxy-auth.csproj` - .NET 8.0 project file
- **`install-credential-provider.sh`** - Install script (compile, install, configure)
- **`WHY-PROXY-BRIDGE-NEEDED.md`** - Technical analysis of why this approach is needed

## Managing the Proxy

```bash
# Check status
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --status

# Start proxy manually
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start

# Stop proxy
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --stop
```

## Troubleshooting

### Credential provider not found
```bash
# Recompile and install
source install-credential-provider.sh
```

### Proxy not running
```bash
# Start it via the compiled plugin
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start
```

### Still getting 401 errors
```bash
# Check the upstream proxy is correctly saved
echo $_NUGET_UPSTREAM_PROXY
echo $PROXY_AUTHORIZATION

# Check proxy logs
cat /tmp/nuget-proxy.log
```

## Why This is Needed

NuGet's `HttpClient` / .NET's `SocketsHttpHandler` does not send `Proxy-Authorization` on the initial HTTPS CONNECT request. The proxy rejects the unauthenticated CONNECT with 401. This is a .NET runtime limitation ([dotnet/runtime #66244](https://github.com/dotnet/runtime/issues/66244)) with no fix in any current .NET version.

See `WHY-PROXY-BRIDGE-NEEDED.md` for the full technical analysis.
