---
name: dotnet-nuget-proxy
description: Complete guide for using .NET and NuGet in the Claude Code web environment, including SDK installation and proxy authentication setup
---

# .NET in the Claude Code Web Environment

This skill provides everything needed to get .NET working in a Claude Code web session, including SDK installation and NuGet proxy authentication.

## When to Use This Skill

Use this skill whenever the user wants to:
- Install the .NET SDK in a Claude Code web session
- Run `dotnet restore`, `dotnet build`, `dotnet run`, or `dotnet new`
- Fix 401/407 proxy authentication errors from NuGet
- Create a new .NET project in the web environment
- Troubleshoot any .NET or NuGet connectivity issues

## Automatic Setup via SessionStart Hook

For projects that use .NET regularly, a SessionStart hook can automatically install the SDK and configure the proxy when a Claude Code web session starts. This means `dotnet restore` just works from the first command.

To set this up in a project, add to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/plugins/dotnet-nuget-proxy-skill/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

The path above assumes the plugin was cloned to `.claude/plugins/dotnet-nuget-proxy-skill/`. Adjust if installed elsewhere. Ensure the hook script is executable (`chmod +x`).

The hook checks `CLAUDE_CODE_REMOTE` internally and:
- Only runs in Claude Code web sessions (exits immediately on desktop)
- Installs .NET SDK from `packages.microsoft.com` if not present
- Compiles and installs the credential provider
- Starts the proxy daemon
- Persists the `dotnet()` shell function and `_NUGET_UPSTREAM_PROXY` via `$CLAUDE_ENV_FILE`

---

## Manual Decision Flow

Follow these steps in order when the user wants to use .NET (if no SessionStart hook is configured):

### Step 1: Detect required .NET version from the project

**IMPORTANT**: Before installing any .NET SDK, check the project's `.csproj` or `.sln` files to determine the required version:

```bash
# Find the TargetFramework in project files
grep -rh --include='*.csproj' '<TargetFramework>' . 2>/dev/null
```

- `net8.0` → install `dotnet-sdk-8.0`
- `net9.0` → install `dotnet-sdk-9.0`
- `net10.0` → install `dotnet-sdk-10.0`

If no project files exist yet (creating a new project), ask the user which .NET version to use or default to the latest LTS.

### Step 2: Check if the correct .NET SDK is installed

```bash
dotnet --list-sdks
```

If the required version is not installed, go to **Installing the .NET SDK** below.
If installed, proceed to Step 3.

### Step 3: Check if NuGet proxy is set up

```bash
# Is the credential provider installed?
ls ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll

# Is the proxy daemon running?
curl -s -o /dev/null -w "%{http_code}" --proxy http://127.0.0.1:8888 http://example.com 2>/dev/null
```

If the credential provider is NOT installed, go to **Setting Up NuGet Proxy Authentication** below.
If installed but proxy not running, start it:
```bash
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start
```

### Step 4: Use .NET normally

```bash
dotnet restore
dotnet build
dotnet run
```

---

## Installing the .NET SDK

**CRITICAL**: Do NOT use `https://dot.net/v1/dotnet-install.sh` or any installer from `dot.net`. It redirects to `builds.dotnet.microsoft.com` which is **blocked** by the proxy allowlist and will return `403 host_not_allowed`.

Install from `packages.microsoft.com` instead (this domain IS allowed).

**IMPORTANT**: Match the SDK version to the project's `<TargetFramework>`. Check `.csproj` files first (see Step 1 above).

```bash
# Download the Microsoft package repository configuration
curl -sSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
  -o /tmp/packages-microsoft-prod.deb

# Install the repository configuration
dpkg -i /tmp/packages-microsoft-prod.deb

# Update apt and install .NET SDK (replace X with the version from project files)
apt-get update --allow-insecure-repositories
apt-get install -y --allow-unauthenticated dotnet-sdk-X.0
```

Common packages: `dotnet-sdk-8.0`, `dotnet-sdk-9.0`, `dotnet-sdk-10.0`

Notes:
- `curl` automatically uses the `HTTPS_PROXY` environment variable (already set in Claude Code web)
- `apt-get` also respects `http_proxy`/`https_proxy` env vars
- The `--allow-insecure-repositories` and `--allow-unauthenticated` flags are needed because GPG key verification may fail through the proxy

### Verify installation

```bash
dotnet --version
dotnet --list-sdks
```

---

## Setting Up NuGet Proxy Authentication

### The Problem

In the Claude Code web environment, NuGet package restoration fails with **401 Unauthorized** because:
- The environment uses a JWT-authenticated HTTP proxy
- .NET's `SocketsHttpHandler` does NOT send `Proxy-Authorization` on the initial HTTPS CONNECT request
- This is a known .NET runtime limitation ([dotnet/runtime #66244](https://github.com/dotnet/runtime/issues/66244))
- NuGet's credential provider protocol handles package source auth, not proxy auth

### The Solution

A C# NuGet credential provider that runs a local proxy bridge:

```
NuGet → localhost:8888 (local proxy) → Upstream Proxy (JWT injected) → nuget.org
        [no auth required]            [Proxy-Authorization header]     [internet]
```

### Setup

The install script compiles the C# plugin, installs it, and starts the proxy:

```bash
source <plugin-files-dir>/install-credential-provider.sh
```

Where `<plugin-files-dir>` is the directory containing `install-credential-provider.sh`. If the plugin is installed, the file is at:
`skills/nuget-proxy-troubleshooting/files/install-credential-provider.sh`

This script:
1. Captures the original upstream proxy URL from `$HTTPS_PROXY`
2. Compiles the C# plugin via `dotnet publish` (offline — uses local SDK packs, no network needed)
3. Installs to `~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/` for auto-discovery
4. Creates a `dotnet()` shell function that routes only dotnet traffic through `localhost:8888`
5. Starts the proxy daemon
6. Global `HTTPS_PROXY` is NOT modified — other tools (curl, apt, pip) are unaffected
7. No NuGet.Config changes needed

**IMPORTANT**: Use `source` (not `bash` or `./`) so the shell function applies to the current shell.

After setup, just use `dotnet restore` / `dotnet build` / `dotnet run` normally.

### Manual Proxy Control

```bash
PLUGIN_DLL=~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll

# Check status
dotnet $PLUGIN_DLL --status

# Start proxy
dotnet $PLUGIN_DLL --start

# Stop proxy
dotnet $PLUGIN_DLL --stop
```

### Environment Variables

After installation, these are set:

| Variable | Value | Purpose |
|----------|-------|---------|
| `_NUGET_UPSTREAM_PROXY` | Original proxy URL | Preserved upstream proxy with credentials |
| `dotnet()` | shell function | Routes dotnet traffic through `localhost:8888` |

Global `HTTPS_PROXY` / `HTTP_PROXY` remain **unchanged** — only `dotnet` commands use the local proxy.

The proxy reads credentials from (in order):
1. `_NUGET_UPSTREAM_PROXY` - Original upstream proxy URL (set by install script)
2. `PROXY_AUTHORIZATION` - JWT or Basic auth token
3. Original `HTTPS_PROXY` / `HTTP_PROXY` values

---

## Troubleshooting

### "401 Unauthorized" during dotnet restore

```bash
# 1. Check if proxy is running
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --status

# 2. Check if upstream proxy credentials are available
echo $_NUGET_UPSTREAM_PROXY | head -c 50

# 3. If not set, re-run the install script
source <plugin-files-dir>/install-credential-provider.sh
```

### "Connection refused" on port 8888

The proxy daemon is not running:
```bash
dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start
```

### Plugin not found by NuGet

```bash
# Verify the DLL exists
ls ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll

# If missing, recompile via the install script
source <plugin-files-dir>/install-credential-provider.sh
```

### "403 host_not_allowed" when installing .NET SDK

You tried to use `dot.net/v1/dotnet-install.sh` which redirects to a blocked domain. Use `packages.microsoft.com` instead (see **Installing the .NET SDK** above).

### Check proxy logs

```bash
cat /tmp/nuget-proxy.log
```

---

## What NOT to Do

1. **Do NOT use `dotnet-install.sh`** from `dot.net` - it redirects to `builds.dotnet.microsoft.com` which is blocked
2. **Do NOT set `Proxy-Authorization` and expect NuGet to use it** - .NET's HTTP stack ignores this env var
3. **Do NOT try `http_proxy.user` / `http_proxy.password` in NuGet.Config** - .NET's `SocketsHttpHandler` won't send proxy credentials on the initial CONNECT
4. **Do NOT use `dotnet tool install`** for proxy setup before the proxy is working - it needs NuGet which is the thing that's broken
5. **Do NOT run `install-credential-provider.sh` without `source`** - env vars won't apply to the current shell

## Architecture Details

### C# Credential Provider

The credential provider is a single-file C# program (`Program.cs`) that serves three roles:

1. **NuGet Plugin** (launched with `-Plugin` arg by NuGet): Implements the NuGet cross-platform plugin protocol v2 over stdin/stdout JSON messages. Ensures the proxy daemon is running, then responds to NuGet handshake/auth requests.

2. **Proxy Server** (launched with `--_run-proxy` arg): TCP listener on `127.0.0.1:8888` that handles HTTP CONNECT tunneling. Reads the upstream proxy URL from `_NUGET_UPSTREAM_PROXY`, opens a CONNECT tunnel to the upstream proxy with `Proxy-Authorization` header injected, then relays traffic bidirectionally.

3. **Daemon Manager** (launched with `--start`/`--stop`/`--status` args): Spawns the proxy server as a background process, writes PID file to `/tmp/nuget-proxy.pid`, verifies port 8888 is listening.

### Why This Approach

See `WHY-PROXY-BRIDGE-NEEDED.md` for the full technical analysis. In summary:
- `SocketsHttpHandler.PreAuthenticateProxy` was never implemented in any .NET version
- NuGet's credential provider protocol only handles package source auth (HTTP 401 from nuget.org), not proxy auth (HTTP 401/407 from proxy)
- The local proxy bridge is the only reliable workaround until .NET adds `PreAuthenticateProxy` support
