---
name: dotnet-nuget-proxy
description: Fixes .NET NuGet restore authentication in Claude Code using a credential provider or proxy bridge
---

# .NET NuGet Authentication for Claude Code Environment

## Problem Overview

In the Claude Code environment, NuGet package restoration fails with 401 authentication errors because:
- Claude Code uses a JWT-authenticated HTTP proxy
- NuGet doesn't pass the `PROXY_AUTHORIZATION` environment variable to the downstream proxy
- This results in 401/407 errors when trying to restore packages from nuget.org

## Solution A: Custom Credential Provider (Recommended)

A NuGet cross-platform credential provider plugin that reads the JWT from `PROXY_AUTHORIZATION` and supplies it to NuGet's authentication pipeline. This eliminates the need for an intermediate proxy process.

### How It Works

```
NuGet ──── auth challenge (401/407) ───→ Credential Provider
  │                                            │
  │        ← Username + Password (from JWT) ───┘
  │
  └──── authenticated request ───→ Proxy ───→ nuget.org
```

The credential provider:
1. Is discovered by NuGet via the plugin protocol
2. Implements NuGet's cross-platform plugin protocol v2 (JSON over stdin/stdout)
3. Reads JWT credentials from `PROXY_AUTHORIZATION` environment variable
4. Returns them when NuGet encounters an authentication challenge
5. Supports Basic auth and Bearer token formats

### Quick Start

```bash
# Install the credential provider
./install-credential-provider.sh

# Set the plugin path for current session
export NUGET_PLUGIN_PATHS="$HOME/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth"

# Use dotnet normally - no wrapper script needed
dotnet restore
dotnet build
```

### Components

1. **nuget-plugin-proxy-auth** - Python credential provider that:
   - Implements NuGet cross-platform plugin protocol v2
   - Extracts JWT from `PROXY_AUTHORIZATION` environment variable
   - Falls back to credentials embedded in proxy URL
   - Returns credentials via the standard plugin protocol

2. **install-credential-provider.sh** - Installation script that:
   - Copies plugin to `~/.nuget/plugins/netcore/`
   - Sets `NUGET_PLUGIN_PATHS` for current session
   - Optionally installs to `~/.local/bin/` for PATH discovery
   - Verifies installation

### Environment Variables

The credential provider reads from (in order):
- `PROXY_AUTHORIZATION` - JWT or Basic auth token for the proxy
- `HTTPS_PROXY` / `https_proxy` - Proxy URL (credentials may be embedded)
- `HTTP_PROXY` / `http_proxy` - Proxy URL (credentials may be embedded)

### Credential Formats Supported

| Format | Example | Handling |
|--------|---------|----------|
| Basic token | `Basic dXNlcjpwYXNz` | Decoded to username:password |
| Bearer token | `Bearer eyJhbGc...` | Passed as-is as password |
| Raw token | `eyJhbGciOi...` | Used as password with placeholder username |
| URL credentials | `http://user:pass@proxy:port` | Extracted from URL |

### Verification

```bash
# Check if plugin is discoverable
nuget-plugin-proxy-auth

# Should show:
#   NuGetProxyCredentialProvider - NuGet Cross-Platform Credential Provider
#   Proxy:       configured
#   Credentials: available
```

### Troubleshooting

#### Credential provider not found by NuGet

```bash
# Verify NUGET_PLUGIN_PATHS is set
echo $NUGET_PLUGIN_PATHS

# Or check plugin directory
ls ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/

# Re-install if missing
./install-credential-provider.sh
```

#### Credentials not available

```bash
# Check environment
echo $PROXY_AUTHORIZATION

# If empty, the Claude Code session environment may not be loaded
# Verify proxy URL has credentials
echo $HTTPS_PROXY
```

#### NuGet ignores the credential provider

```bash
# Enable verbose NuGet logging to see plugin discovery
dotnet restore -v detailed 2>&1 | grep -i plugin

# Force NuGet to clear plugin cache
dotnet nuget locals plugins-cache --clear
```

---

## Solution B: Custom Proxy Bridge (Fallback)

If the credential provider doesn't work (e.g., NuGet version doesn't support cross-platform plugins for proxy auth), fall back to the proxy bridge approach.

### How It Works

```
NuGet → localhost:8888 (nuget-proxy.py) → Upstream Proxy (JWT auth added) → nuget.org
        [no auth required]                [JWT auth injected]                [internet]
```

### Quick Start

```bash
# Use the wrapper script
./dotnet-with-proxy.sh restore
./dotnet-with-proxy.sh build
```

### Components

1. **nuget-proxy.py** - Python HTTP/HTTPS proxy that:
   - Listens on localhost:8888 (unauthenticated)
   - Forwards requests to upstream proxy with JWT authentication
   - Handles HTTPS CONNECT tunneling

2. **dotnet-with-proxy.sh** - Wrapper script that:
   - Automatically detects/starts the proxy
   - Sets HTTP_PROXY/HTTPS_PROXY environment variables
   - Runs dotnet commands seamlessly

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

---

## Architecture Comparison

| Aspect | Credential Provider | Proxy Bridge |
|--------|-------------------|--------------|
| Background process | None | Python proxy on port 8888 |
| NuGet config changes | NUGET_PLUGIN_PATHS env var | http_proxy in NuGet.config |
| Wrapper script needed | No | Yes (dotnet-with-proxy.sh) |
| Protocol | NuGet plugin v2 (JSON/stdio) | HTTP/HTTPS proxy |
| Port usage | None | localhost:8888 |
| NuGet version required | 4.8+ (cross-platform plugins) | Any |
| Complexity | Lower (single executable) | Higher (proxy + wrapper + config) |

## Best Practices

1. **Try the credential provider first** - it's simpler and requires no background process
2. **Fall back to the proxy bridge** if the credential provider doesn't work with your NuGet version
3. **Check proxy logs** at `/tmp/nuget-proxy.log` if using the proxy bridge
4. **Verify `PROXY_AUTHORIZATION`** is set in your environment before either approach
