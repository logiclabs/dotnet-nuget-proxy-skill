# .NET NuGet Proxy Plugin for Claude Code

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/logiclabs/dotnet-nuget-proxy-skill/releases)

A Claude Code plugin that enables .NET development in Claude Code web sessions by fixing NuGet proxy authentication and providing .NET SDK installation guidance.

## Problem Solved

In Claude Code web environments with JWT-authenticated proxies:
1. **NuGet fails with 401 errors** because .NET's `SocketsHttpHandler` does not send `Proxy-Authorization` on the HTTPS CONNECT request ([dotnet/runtime #66244](https://github.com/dotnet/runtime/issues/66244))
2. **The standard .NET SDK installer is blocked** because `dot.net` redirects to `builds.dotnet.microsoft.com` which isn't in the proxy allowlist

This plugin solves both problems.

## How It Works

```
NuGet → localhost:8888 (credential provider proxy) → Upstream Proxy (JWT injected) → nuget.org
        [no auth required]                           [Proxy-Authorization header]     [internet]
```

A C# NuGet credential provider:
- Compiles to a .NET DLL in `~/.nuget/plugins/netcore/` for auto-discovery by NuGet
- Embeds an HTTP/HTTPS proxy that injects JWT auth into upstream proxy requests
- Manages the proxy lifecycle as a background daemon
- Implements the NuGet cross-platform plugin protocol v2

## Installation

### Claude Code (Desktop or Web) - NOT CURRENTLY WORKING

```
/plugin marketplace add logiclabs/dotnet-nuget-proxy-skill
/plugin install dotnet-nuget-proxy@dotnet-nuget-proxy
```

### Manual Installation

```bash
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill ~/.claude/plugins/dotnet-nuget-proxy
```

## Automatic Setup (SessionStart Hook)

For .NET projects, add a SessionStart hook so the SDK and proxy are ready automatically when a Claude Code web session starts.

### Slash Command (Recommended)

If you already have the plugin installed, run this in a Claude Code session inside your project:

```
/install-dotnet-web
```

Claude will download the plugin files into `.claude/plugins/dotnet-nuget-proxy-skill/`, configure the SessionStart hook in `.claude/settings.json`, and tell you what to commit.

### One-Line Install

Run this from your project directory:

```bash
curl -sSL https://raw.githubusercontent.com/logiclabs/dotnet-nuget-proxy-skill/main/install.sh | bash
```

Or install into a specific project:

```bash
curl -sSL https://raw.githubusercontent.com/logiclabs/dotnet-nuget-proxy-skill/main/install.sh | bash -s /path/to/project
```

This downloads the latest release, extracts the plugin into `.claude/plugins/dotnet-nuget-proxy-skill/`, and configures the SessionStart hook in `.claude/settings.json`. Commit the `.claude/` directory to your repo.

### Manual Setup

<details>
<summary>Manual steps (if you prefer not to use the install script)</summary>

**1. Download and extract the plugin into your project:**

```bash
mkdir -p .claude/plugins
curl -sSL https://github.com/logiclabs/dotnet-nuget-proxy-skill/archive/refs/tags/v1.0.0.tar.gz \
  | tar -xz -C .claude/plugins/ --strip-components=1 --one-top-level=dotnet-nuget-proxy-skill
```

**2. Register the hook in `.claude/settings.json`:**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/plugins/dotnet-nuget-proxy-skill/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

**3. Make the hook executable and commit both to your repo:**

```bash
chmod +x .claude/plugins/dotnet-nuget-proxy-skill/hooks/session-start.sh
```

</details>

All future Claude Code web sessions will have .NET ready automatically.

The hook only runs in web sessions (checks `CLAUDE_CODE_REMOTE` internally and exits on desktop). It installs the .NET SDK, compiles the credential provider, starts the proxy, and persists env vars for the session.

---

## Manual Setup for a New Session

### 1. Install .NET SDK (if not already installed)

**Do NOT use `dot.net/v1/dotnet-install.sh`** — it redirects to a blocked domain. Use `packages.microsoft.com`:

```bash
curl -sSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
  -o /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
apt-get update --allow-insecure-repositories
apt-get install -y --allow-unauthenticated dotnet-sdk-8.0
```

`curl` and `apt-get` automatically use the `HTTPS_PROXY` environment variable already set in Claude Code web.

### 2. Set Up the Credential Provider

```bash
source skills/nuget-proxy-troubleshooting/files/install-credential-provider.sh
```

This compiles the C# plugin, installs it, starts the proxy daemon, and creates a `dotnet()` shell function that routes only dotnet traffic through the local proxy. **Must use `source`** so the shell function applies to the current shell. Global `HTTPS_PROXY` is NOT modified.

### 3. Use .NET Normally

```bash
dotnet restore
dotnet build
dotnet run
```

No wrapper scripts or NuGet.Config changes needed.

### Ask Claude for Help

Once the plugin is installed, just describe your problem:
- "I'm getting 401 errors when running dotnet restore"
- "Help me set up .NET in this session"
- "Install .NET and create a new web API project"

Claude will use the plugin's skill to guide you through the correct steps.

## Architecture

### Components

1. **nuget-plugin-proxy-auth-src/** — C# source for the credential provider:
   - `Program.cs` — Self-contained proxy server + NuGet plugin protocol + daemon management
   - `nuget-plugin-proxy-auth.csproj` — .NET 8.0 project file
   - Compiled on first install via `dotnet publish`

2. **install-credential-provider.sh** — Install script that:
   - Compiles the C# plugin (if needed)
   - Captures original upstream proxy URL as `_NUGET_UPSTREAM_PROXY`
   - Creates a `dotnet()` shell function routing dotnet traffic through `localhost:8888`
   - Starts the proxy daemon
   - Global `HTTPS_PROXY` stays unchanged (other tools unaffected)

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `_NUGET_UPSTREAM_PROXY` | Original upstream proxy URL (set by install script) |
| `dotnet()` | Shell function that sets `HTTPS_PROXY=localhost:8888` only for dotnet |
| `PROXY_AUTHORIZATION` | JWT or Basic auth token (set by Claude Code) |

## Proxy Management

```bash
PLUGIN_DLL=~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll

# Check status
dotnet $PLUGIN_DLL --status

# Start proxy
dotnet $PLUGIN_DLL --start

# Stop proxy
dotnet $PLUGIN_DLL --stop
```

## Troubleshooting

### "401 Unauthorized" during dotnet restore

```bash
# Check proxy status
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --status

# Re-run the install script if needed
source skills/nuget-proxy-troubleshooting/files/install-credential-provider.sh
```

### "Connection refused on port 8888"

```bash
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start
```

### "403 host_not_allowed" when installing .NET SDK

You used `dot.net/v1/dotnet-install.sh`. Use `packages.microsoft.com` instead (see Quick Start above).

### Plugin not found by NuGet

```bash
# Verify the DLL exists
ls ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll

# Recompile if needed
source skills/nuget-proxy-troubleshooting/files/install-credential-provider.sh
```

### Check proxy logs

```bash
cat /tmp/nuget-proxy.log
```

## Requirements

- **Claude Code** environment with proxy authentication
- **.NET SDK 8.0+** (installed via `packages.microsoft.com` — see Quick Start)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](LICENSE).

## Documentation

- [Skill Documentation](skills/nuget-proxy-troubleshooting/SKILL.md)
- [Proxy README](skills/nuget-proxy-troubleshooting/files/NUGET-PROXY-README.md)
- [Why a Proxy Bridge is Needed](skills/nuget-proxy-troubleshooting/files/WHY-PROXY-BRIDGE-NEEDED.md)
- [Changelog](CHANGELOG.md)
