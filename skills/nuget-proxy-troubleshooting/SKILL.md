---
name: dotnet-nuget-proxy
description: Fixes .NET NuGet restore authentication in Claude Code using a credential provider that manages a local proxy bridge
---

# .NET NuGet Authentication for Claude Code Environment

## Problem Overview

In the Claude Code environment, NuGet package restoration fails with 401 authentication errors because:
- Claude Code uses a JWT-authenticated HTTP proxy (e.g., `21.0.0.141:15004`)
- NuGet / .NET's HttpClient does **not** pass the `PROXY_AUTHORIZATION` environment variable to the downstream proxy
- Even with credentials embedded in the `HTTPS_PROXY` URL or configured in `NuGet.Config` (`http_proxy.user`/`http_proxy.password`), the proxy CONNECT tunnel returns `401 Unauthorized`

## Why a Proxy Bridge is Needed

NuGet's cross-platform credential provider plugin protocol (v2) is designed for **package source authentication** (401 from nuget.org), not **proxy authentication** (401/407 from an HTTP proxy). The proxy 401 occurs at the HTTP transport layer, during the CONNECT tunnel setup, before NuGet's plugin infrastructure is consulted.

The solution is a local proxy bridge on `localhost:8888` that NuGet connects to without authentication, which then forwards requests to the upstream proxy with JWT credentials injected.

## Solution: C# Credential Provider + Proxy Bridge

A self-contained C# NuGet credential provider plugin that:
1. Compiles to a .NET DLL installed in `~/.nuget/plugins/netcore/` for auto-discovery
2. Embeds an HTTP/HTTPS proxy server that injects JWT auth into upstream requests
3. Manages the proxy lifecycle (start/stop/health check as daemon)
4. Implements the NuGet cross-platform plugin protocol v2

### How It Works

```
NuGet → localhost:8888 (proxy daemon) → Upstream Proxy (JWT auth injected) → nuget.org
        [no auth required]              [Proxy-Authorization: Basic <JWT>]    [internet]
```

NuGet auto-discovers the plugin in `~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/` and launches it via `dotnet nuget-plugin-proxy-auth.dll -Plugin`. The plugin ensures the proxy daemon is running, then handles the NuGet protocol.

### Quick Start

```bash
# Install (compiles C# plugin, starts proxy, sets env vars)
source install-credential-provider.sh

# Then just use dotnet normally
dotnet restore
dotnet build
dotnet run
```

### Components

1. **nuget-plugin-proxy-auth-src/** - C# source for the credential provider:
   - `Program.cs` - Single-file implementation of proxy + NuGet plugin protocol
   - `nuget-plugin-proxy-auth.csproj` - Project file targeting net8.0
   - Compiled on first install via `dotnet publish`

2. **install-credential-provider.sh** - Install script that:
   - Compiles the C# plugin (if needed)
   - Captures original upstream proxy URL as `_NUGET_UPSTREAM_PROXY`
   - Sets `HTTPS_PROXY` to `http://127.0.0.1:8888`
   - Starts the proxy daemon
   - No NuGet.Config changes needed

### Manual Proxy Control

```bash
# Start proxy manually
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start

# Check status
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --status

# Stop proxy
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --stop
```

### Environment Variables

The proxy reads credentials from (in order):
- `_NUGET_UPSTREAM_PROXY` - Original upstream proxy URL (set by install script)
- `PROXY_AUTHORIZATION` - JWT or Basic auth token
- `HTTPS_PROXY` / `https_proxy` - Proxy URL (credentials may be embedded)
- `HTTP_PROXY` / `http_proxy` - Proxy URL (credentials may be embedded)

### Troubleshooting

#### 401 Unauthorized from upstream proxy

```bash
# Check if auth is available
echo $PROXY_AUTHORIZATION
echo $HTTPS_PROXY | head -c 50

# If empty, the session may need to be restarted
```

#### "Connection refused" on port 8888

```bash
# Proxy is not running - start it via the plugin
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start
```

#### Plugin not found by NuGet

```bash
# Verify the DLL exists
ls ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll

# If missing, recompile
source install-credential-provider.sh
```

---

## Installing the .NET SDK

The default `dot.net` install script redirects to `builds.dotnet.microsoft.com`, which is **blocked** by the proxy allowlist. Instead, install the SDK via `packages.microsoft.com` (which is allowed):

```bash
# Download and install the Microsoft package feed
curl -x "http://<proxy-host:port>" -U "<user:pass>" --proxy-basic -sSL \
  https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
  -o /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb

# Configure apt proxy, then install
apt-get update --allow-insecure-repositories
apt-get install -y --allow-unauthenticated dotnet-sdk-8.0
```

Do **NOT** use `https://dot.net/v1/dotnet-install.sh` -- it redirects to `builds.dotnet.microsoft.com` which returns `403 host_not_allowed`.

## Best Practices

1. **Use the credential provider** (`source install-credential-provider.sh`) for seamless NuGet auth
2. **Install .NET SDK from `packages.microsoft.com`** -- the `dot.net` script is blocked
3. **Check proxy logs** at `/tmp/nuget-proxy.log` if issues occur
4. **Verify credentials are available** in `PROXY_AUTHORIZATION` or `HTTPS_PROXY`
5. **Keep the proxy running** between commands for efficiency
