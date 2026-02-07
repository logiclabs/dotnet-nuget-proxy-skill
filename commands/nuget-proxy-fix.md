---
name: nuget-proxy-fix
description: Fix .NET NuGet proxy authentication issues using a credential provider or proxy bridge
---

# NuGet Proxy Fix Command

This command fixes NuGet authentication in environments with JWT-authenticated proxies (like Claude Code) where NuGet doesn't pass the `PROXY_AUTHORIZATION` environment variable to the downstream proxy.

## What This Does

1. **Diagnoses the problem**: Checks environment variables and proxy configuration
2. **Installs credential provider** (preferred): Sets up the NuGet cross-platform credential provider plugin that supplies JWT proxy credentials from the environment
3. **Falls back to proxy bridge** (if needed): Sets up the Python proxy bridge as an alternative
4. **Tests the solution**: Verifies everything works with a test restore

## Approach A: Credential Provider (Recommended)

The credential provider plugs directly into NuGet's authentication pipeline:
- No background proxy process needed
- No wrapper script needed
- Uses NuGet's native cross-platform plugin protocol v2
- Reads JWT from `PROXY_AUTHORIZATION` environment variable

### Setup

```bash
# Install the credential provider
./install-credential-provider.sh

# Set plugin path
export NUGET_PLUGIN_PATHS="$HOME/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth"

# Use dotnet normally
dotnet restore
dotnet build
```

## Approach B: Proxy Bridge (Fallback)

If the credential provider doesn't work with the NuGet version in use:

```bash
./dotnet-with-proxy.sh restore
./dotnet-with-proxy.sh build
```

## When to Use

Use this command when you encounter:
- `401 Unauthorized` errors during `dotnet restore`
- `407 Proxy Authentication Required` errors
- NuGet proxy authentication failures
- Package restore failures in proxy environments
- Claude Code containerized environment NuGet issues

## What Gets Created

### Credential Provider
- **nuget-plugin-proxy-auth**: NuGet cross-platform credential provider plugin (Python)
- **install-credential-provider.sh**: Installation and setup script

### Proxy Bridge (Fallback)
- **nuget-proxy.py**: Python HTTP/HTTPS proxy bridge
- **dotnet-with-proxy.sh**: Wrapper script that auto-starts proxy
- **NuGet.config**: NuGet configuration pointing to local proxy
