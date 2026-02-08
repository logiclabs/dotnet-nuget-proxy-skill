---
name: install-dotnet-web
description: Install the .NET NuGet proxy plugin into the current project and configure the SessionStart hook for automatic .NET setup in Claude Code web sessions.
user-invocable: true
---

# Install .NET Web Support for Claude Code

This skill installs the .NET NuGet proxy plugin into the current project so that future Claude Code web sessions automatically have the .NET SDK and NuGet proxy authentication ready.

## What Gets Installed

1. **Plugin files** at `.claude/plugins/dotnet-nuget-proxy-skill/` — the credential provider source, hooks, and install scripts
2. **SessionStart hook** in `.claude/settings.json` — triggers automatic setup when a web session starts

## Installation Steps

Follow these steps exactly:

### Step 1: Download the plugin

Download the latest release from GitHub and extract it into the project's `.claude/plugins/` directory.

```bash
REPO="logiclabs/dotnet-nuget-proxy-skill"
PLUGIN_DEST=".claude/plugins/dotnet-nuget-proxy-skill"

# Get the latest release tag
TAG=$(curl -sSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null || true)

# Download tarball (latest release or main branch)
TMPDIR=$(mktemp -d)
if [ -n "$TAG" ]; then
  curl -sSL "https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz" -o "$TMPDIR/plugin.tar.gz"
else
  curl -sSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" -o "$TMPDIR/plugin.tar.gz"
fi

# Extract
mkdir -p "$PLUGIN_DEST"
tar -xzf "$TMPDIR/plugin.tar.gz" -C "$TMPDIR"
EXTRACTED=$(find "$TMPDIR" -maxdepth 1 -type d -name "dotnet-nuget-proxy-skill-*" | head -1)
cp -a "$EXTRACTED/." "$PLUGIN_DEST/"
rm -rf "$TMPDIR"

# Make hooks executable
chmod +x "$PLUGIN_DEST/hooks/"*.sh
```

### Step 2: Configure the SessionStart hook

Read the existing `.claude/settings.json` (if it exists) and merge in the SessionStart hook. Do NOT overwrite existing settings — merge carefully.

The hook entry to add to `hooks.SessionStart`:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/plugins/dotnet-nuget-proxy-skill/hooks/session-start.sh"
    }
  ]
}
```

Use the following Python snippet to merge safely:

```bash
python3 -c "
import json, os
f = '.claude/settings.json'
s = json.load(open(f)) if os.path.exists(f) else {}
s.setdefault('hooks', {}).setdefault('SessionStart', [])
cmd = '\"\\$CLAUDE_PROJECT_DIR\"/.claude/plugins/dotnet-nuget-proxy-skill/hooks/session-start.sh'
exists = any(h.get('command') == cmd for e in s['hooks']['SessionStart'] for h in e.get('hooks', []))
if not exists:
    s['hooks']['SessionStart'].append({'hooks': [{'type': 'command', 'command': cmd}]})
    open(f, 'w').write(json.dumps(s, indent=2) + '\n')
    print('SessionStart hook added to .claude/settings.json')
else:
    print('SessionStart hook already configured')
"
```

### Step 3: Confirm success

After installation, tell the user:

- The plugin is installed at `.claude/plugins/dotnet-nuget-proxy-skill/`
- The SessionStart hook is configured in `.claude/settings.json`
- They should **commit both** to their repo: `git add .claude/plugins/dotnet-nuget-proxy-skill .claude/settings.json`
- Future Claude Code web sessions will automatically install the .NET SDK, compile the credential provider, and start the proxy
- The hook only runs in web sessions — it exits immediately on desktop (checks `CLAUDE_CODE_REMOTE` internally)
- If they want to test it now, they can run: `source .claude/plugins/dotnet-nuget-proxy-skill/hooks/session-start.sh`

## Important Notes

- The SessionStart hook installs the .NET SDK from `packages.microsoft.com` (NOT from `dot.net` which is blocked by the proxy)
- The credential provider compiles offline using local SDK packs — no NuGet packages needed
- Only `dotnet` commands are routed through the local proxy; other tools (curl, apt, pip) are unaffected
- The proxy daemon runs on `localhost:8888` and injects JWT auth into upstream CONNECT requests
