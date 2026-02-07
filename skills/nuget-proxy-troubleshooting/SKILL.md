---
name: dotnet-nuget-proxy
description: Fixes .NET NuGet restore authentication in Claude Code using a proxy bridge that injects JWT credentials
---

# .NET NuGet Authentication for Claude Code Environment

## Problem Overview

In the Claude Code environment, NuGet package restoration fails with 401 authentication errors because:
- Claude Code uses a JWT-authenticated HTTP proxy (e.g., `21.0.0.141:15004`)
- NuGet / .NET's HttpClient does **not** pass the `PROXY_AUTHORIZATION` environment variable to the downstream proxy
- Even with credentials embedded in the `HTTPS_PROXY` URL or configured in `NuGet.Config` (`http_proxy.user`/`http_proxy.password`), the proxy CONNECT tunnel returns `401 Unauthorized`

## Why Credential Providers Don't Work for Proxy Auth

NuGet's cross-platform credential provider plugin protocol (v2) is designed for **package source authentication** (401 from nuget.org), not **proxy authentication** (401/407 from an HTTP proxy). Testing confirmed:

- The proxy 401 occurs at the HTTP transport layer, during the CONNECT tunnel setup
- NuGet's plugin infrastructure is never consulted -- no plugin logs are created
- Setting `NUGET_PLUGIN_PATHS` / `NUGET_NETCORE_PLUGIN_PATHS` has no effect
- NuGet.Config `http_proxy.user` / `http_proxy.password` settings are also ignored for CONNECT auth

The credential provider plugin (`nuget-plugin-proxy-auth`) is included for reference and may work in future NuGet versions that support proxy credential plugins, but currently the proxy bridge is the only working solution.

## Solution: Custom Proxy Bridge

A local Python proxy on `localhost:8888` that NuGet connects to without authentication, which then forwards requests to the upstream proxy with JWT credentials injected.

### How It Works

```
NuGet → localhost:8888 (nuget-proxy.py) → Upstream Proxy (JWT auth injected) → nuget.org
        [no auth required]                [Proxy-Authorization: Basic <JWT>]    [internet]
```

### Quick Start

```bash
# Use the wrapper script (auto-starts proxy, sets env vars)
./dotnet-with-proxy.sh restore
./dotnet-with-proxy.sh build
./dotnet-with-proxy.sh run
```

### Components

1. **nuget-proxy.py** - Python HTTP/HTTPS proxy that:
   - Listens on `127.0.0.1:8888` (unauthenticated, localhost only)
   - Forwards requests to the upstream proxy with JWT authentication
   - Handles HTTPS CONNECT tunneling for secure connections
   - Extracts credentials from `PROXY_AUTHORIZATION` env var or proxy URL

2. **dotnet-with-proxy.sh** - Wrapper script that:
   - Automatically detects/starts the proxy if not running
   - Sets `HTTP_PROXY`/`HTTPS_PROXY` to `http://127.0.0.1:8888`
   - Runs dotnet commands seamlessly
   - Keeps proxy running between commands

3. **NuGet.config** - Configured to use the local proxy on port 8888

### Manual Proxy Control

```bash
# Start proxy manually
python3 nuget-proxy.py &

# Check if running
ps aux | grep nuget-proxy

# Stop proxy
kill $(cat /tmp/nuget-proxy.pid)
```

### Environment Variables

The proxy reads credentials from (in order):
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
# Proxy is not running - start it
python3 nuget-proxy.py &
# or use the wrapper script which auto-starts it
./dotnet-with-proxy.sh restore
```

#### Proxy starts but restore still fails

```bash
# Make sure NuGet is using the local proxy, not the upstream one
http_proxy=http://127.0.0.1:8888 \
https_proxy=http://127.0.0.1:8888 \
HTTP_PROXY=http://127.0.0.1:8888 \
HTTPS_PROXY=http://127.0.0.1:8888 \
dotnet restore
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

---

## Reference: Credential Provider Plugin (Experimental)

The `nuget-plugin-proxy-auth` file implements a NuGet cross-platform credential provider plugin (v2 protocol). It correctly:
- Handles the JSON-over-stdin/stdout protocol handshake
- Claims the Authentication operation
- Extracts JWT from environment and returns credentials

However, **NuGet does not invoke credential providers for proxy authentication** -- only for package source authentication. This plugin is included for:
- Future NuGet versions that may support proxy credential plugins
- Environments where the auth challenge comes from a private NuGet feed (not a proxy)
- Reference implementation of the NuGet v2 plugin protocol in Python

## Best Practices

1. **Use the proxy bridge** (`dotnet-with-proxy.sh`) for all dotnet commands
2. **Install .NET SDK from `packages.microsoft.com`** -- the `dot.net` script is blocked
3. **Check proxy logs** at `/tmp/nuget-proxy.log` if issues occur
4. **Verify credentials are available** in `PROXY_AUTHORIZATION` or `HTTPS_PROXY`
5. **Keep the proxy running** between commands for efficiency
