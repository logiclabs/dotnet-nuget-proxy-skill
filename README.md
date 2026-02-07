# .NET NuGet Proxy Plugin for Claude Code

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/logiclabs/dotnet-nuget-proxy-skill/releases)

A Claude Code plugin that fixes .NET NuGet proxy authentication issues in containerized and proxy-authenticated environments.

## Problem Solved

In containerized Claude Code environments with JWT-authenticated proxies, NuGet package restoration fails with 401 authentication errors. This happens because .NET's `SocketsHttpHandler` does not send `Proxy-Authorization` on the initial HTTPS CONNECT request ([dotnet/runtime #66244](https://github.com/dotnet/runtime/issues/66244)).

This plugin provides a **C# NuGet credential provider** that embeds a local proxy bridge, handling authentication transparently. After setup, `dotnet restore` works without wrapper scripts or NuGet.Config changes.

## How It Works

```
NuGet -> localhost:8888 (credential provider proxy) -> Upstream Proxy (JWT injected) -> nuget.org
         [no auth required]                            [Proxy-Authorization header]     [internet]
```

The C# credential provider:
- Compiles to a .NET DLL in `~/.nuget/plugins/netcore/` for auto-discovery by NuGet
- Embeds an HTTP/HTTPS proxy that injects JWT auth into upstream proxy requests
- Manages the proxy lifecycle as a background daemon
- Implements the NuGet cross-platform plugin protocol v2

## Installation

### Claude Code (Desktop CLI)

```
/plugin marketplace add logiclabs/dotnet-nuget-proxy-skill
/plugin install dotnet-nuget-proxy@dotnet-nuget-proxy
```

### Claude Code on the Web

1. Open Claude Code in your browser
2. Run `/plugin marketplace add logiclabs/dotnet-nuget-proxy-skill`
3. Run `/plugin install dotnet-nuget-proxy@dotnet-nuget-proxy`

### Manual Installation

```bash
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill ~/.claude/plugins/dotnet-nuget-proxy
```

## Quick Start

### 1. Set Up the Credential Provider

```bash
source install-credential-provider.sh
```

This compiles the C# plugin, installs it, starts the proxy daemon, and configures environment variables.

### 2. Use dotnet Normally

```bash
dotnet restore
dotnet build
dotnet run
```

No wrapper scripts needed.

### 3. Slash Commands

| Command | Description |
|---------|-------------|
| `/nuget-proxy-debug` | Run diagnostics on proxy configuration |
| `/nuget-proxy-fix` | Set up the proxy solution |
| `/nuget-proxy-verify` | Test and validate the configuration |

You can also ask Claude naturally:
- "I'm getting 401 errors when running dotnet restore"
- "Help me fix NuGet proxy authentication"
- "Set up NuGet to work with the proxy"

## Architecture

### Components

1. **nuget-plugin-proxy-auth-src/** - C# source for the credential provider:
   - `Program.cs` - Self-contained proxy server + NuGet plugin protocol + daemon management
   - `nuget-plugin-proxy-auth.csproj` - .NET 8.0 project file
   - Compiled on first install via `dotnet publish`

2. **install-credential-provider.sh** - Install script that:
   - Compiles the C# plugin (if needed)
   - Captures original upstream proxy URL as `_NUGET_UPSTREAM_PROXY`
   - Points `HTTPS_PROXY` to `http://127.0.0.1:8888`
   - Starts the proxy daemon
   - No NuGet.Config changes needed

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `_NUGET_UPSTREAM_PROXY` | Original upstream proxy URL (set by install script) |
| `HTTPS_PROXY` | Points to localhost:8888 after install |
| `PROXY_AUTHORIZATION` | JWT or Basic auth token (read by Claude Code) |

## Proxy Management

```bash
# Check status
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --status

# Start proxy
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start

# Stop proxy
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --stop
```

## Troubleshooting

### "401 Unauthorized" during dotnet restore
```bash
# Run diagnostics
/nuget-proxy-debug

# Or re-run the install script
source install-credential-provider.sh
```

### "Connection refused on port 8888"
```bash
# Start the proxy daemon
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start
```

### Plugin not found by NuGet
```bash
# Verify the DLL exists
ls ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll

# Recompile if needed
source install-credential-provider.sh
```

### Check proxy logs
```bash
cat /tmp/nuget-proxy.log
```

## Installing the .NET SDK

The default `dot.net` install script redirects to `builds.dotnet.microsoft.com`, which is blocked by the proxy allowlist. Instead use `packages.microsoft.com`:

```bash
curl -sSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
apt-get update && apt-get install -y dotnet-sdk-8.0
```

## Requirements

- **.NET SDK 8.0+** (for compiling the credential provider)
- **Claude Code** environment with proxy authentication

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT - see [LICENSE](LICENSE).

## Documentation

- [Skill Documentation](plugins/dotnet-nuget-proxy/skills/nuget-proxy-troubleshooting/SKILL.md)
- [Proxy README](plugins/dotnet-nuget-proxy/skills/nuget-proxy-troubleshooting/files/NUGET-PROXY-README.md)
- [Why a Proxy Bridge is Needed](plugins/dotnet-nuget-proxy/skills/nuget-proxy-troubleshooting/files/WHY-PROXY-BRIDGE-NEEDED.md)
- [Changelog](CHANGELOG.md)
