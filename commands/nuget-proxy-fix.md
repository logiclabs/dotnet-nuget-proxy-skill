---
name: nuget-proxy-fix
description: Fix .NET NuGet proxy authentication issues by setting up the custom proxy solution
---

# NuGet Proxy Fix Command

This command helps you set up the complete NuGet proxy solution for environments with JWT-authenticated proxies (like Claude Code containerized environments).

## What This Does

1. **Diagnoses the problem**: Checks if you're experiencing NuGet 401 authentication errors
2. **Creates proxy files**: Sets up the custom Python proxy bridge (nuget-proxy.py)
3. **Creates wrapper script**: Sets up the auto-starting dotnet wrapper (dotnet-with-proxy.sh)
4. **Configures NuGet**: Creates NuGet.config pointing to local proxy
5. **Tests the solution**: Verifies everything works with a test restore

## When to Use

Use this command when you encounter:
- `401 Unauthorized` errors during `dotnet restore`
- NuGet proxy authentication failures
- Package restore failures in proxy environments
- Claude Code containerized environment NuGet issues

## Usage

Simply type:
```
/nuget-proxy-fix
```

The command will guide you through the setup process and verify everything works correctly.

## What Gets Created

- **nuget-proxy.py**: Python HTTP/HTTPS proxy that bridges NuGet to authenticated proxies
- **dotnet-with-proxy.sh**: Wrapper script that auto-starts proxy and runs dotnet commands
- **setup-dotnet-alias.sh**: Helper to create convenient aliases
- **NuGet.config**: NuGet configuration pointing to local proxy on port 8888
- **NUGET-PROXY-README.md**: Complete documentation

## After Setup

Use the wrapper script for all dotnet commands:
```bash
./dotnet-with-proxy.sh restore
./dotnet-with-proxy.sh build
./dotnet-with-proxy.sh run
```

Or create an alias for convenience:
```bash
source setup-dotnet-alias.sh
dotnet restore  # Now uses the proxy automatically
```
