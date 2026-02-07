---
name: nuget-proxy-fix
description: Fix .NET NuGet proxy authentication issues using a C# credential provider with embedded proxy bridge
---

# NuGet Proxy Fix Command

This command fixes NuGet authentication in environments with JWT-authenticated proxies (like Claude Code) where NuGet doesn't pass proxy credentials during HTTPS CONNECT tunnel setup.

## What This Does

1. **Diagnoses the problem**: Checks environment variables and proxy configuration
2. **Compiles and installs the credential provider**: Builds the C# NuGet plugin from source
3. **Starts the proxy daemon**: Launches the local proxy bridge on localhost:8888
4. **Tests the solution**: Verifies everything works with a test restore

## Recommended: C# Credential Provider

The credential provider is a self-contained C# NuGet plugin that:
- Compiles to a .NET DLL installed in `~/.nuget/plugins/netcore/` for auto-discovery
- Embeds an HTTP/HTTPS proxy that injects JWT auth into upstream proxy requests
- Manages the proxy lifecycle as a background daemon
- Implements the NuGet cross-platform plugin protocol v2

### Setup

```bash
# Install (compiles plugin, starts proxy, sets env vars)
source install-credential-provider.sh

# Then just use dotnet normally - no wrapper scripts needed
dotnet restore
dotnet build
```

### What Gets Created

- **nuget-plugin-proxy-auth-src/** - C# source (Program.cs + .csproj)
- **install-credential-provider.sh** - Installation and setup script
- **~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/** - Compiled plugin (auto-discovered by NuGet)

## Fallback: Python Proxy Bridge

If the .NET SDK is not yet available to compile the C# plugin:

```bash
python3 nuget-proxy.py &
HTTPS_PROXY=http://127.0.0.1:8888 dotnet restore
```

### Legacy Files (still functional)

- **nuget-proxy.py** - Standalone Python proxy implementation
- **dotnet-with-proxy.sh** - Wrapper script that auto-starts Python proxy

## When to Use

Use this command when you encounter:
- `401 Unauthorized` errors during `dotnet restore`
- `407 Proxy Authentication Required` errors
- NuGet proxy authentication failures in containerized environments
