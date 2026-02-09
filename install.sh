#!/bin/bash
set -euo pipefail

# install.sh - Install the .NET NuGet proxy plugin into a project
#
# Downloads the latest release from GitHub, extracts it into the project's
# .claude/plugins/ directory, and configures the SessionStart hook in
# .claude/settings.json.
#
# Usage:
#   ./install.sh [TARGET_PROJECT_DIR]
#
# If no target is specified, installs into the current directory.
#
# Examples:
#   # Install into the current project
#   curl -sSL https://raw.githubusercontent.com/logiclabs/dotnet-nuget-proxy-skill/main/install.sh | bash
#
#   # Install into a specific project
#   ./install.sh /path/to/my-dotnet-project

REPO="logiclabs/dotnet-nuget-proxy-skill"
PLUGIN_NAME="dotnet-nuget-proxy-skill"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERR]${NC} $1"; }
log()   { echo "$1"; }

# --- Determine target project directory ---
TARGET_DIR="${1:-.}"
if [ ! -d "$TARGET_DIR" ]; then
    error "Target directory does not exist: $TARGET_DIR"
    exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

PLUGIN_DEST="$TARGET_DIR/.claude/plugins/$PLUGIN_NAME"
SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"
HOOK_COMMAND="bash \"\$CLAUDE_PROJECT_DIR\"/.claude/plugins/$PLUGIN_NAME/hooks/session-start.sh"

log ""
log ".NET NuGet Proxy Plugin Installer"
log "================================="
log ""
log "Target project: $TARGET_DIR"
log "Plugin destination: $PLUGIN_DEST"
log ""

# --- Check prerequisites ---
if ! command -v curl &>/dev/null; then
    error "curl is required but not found"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    error "python3 is required for JSON manipulation but not found"
    exit 1
fi

# --- Download latest release ---
log "Fetching latest release info..."

# Get the latest release tag via GitHub API
RELEASE_INFO=$(curl -sSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null || true)

if [ -n "$RELEASE_INFO" ]; then
    TAG=$(echo "$RELEASE_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null || true)
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if [ -n "${TAG:-}" ]; then
    log "Downloading release $TAG..."
    TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"
else
    warn "No release found, downloading from main branch..."
    TARBALL_URL="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
    TAG="main"
fi

if ! curl -sSL "$TARBALL_URL" -o "$TMPDIR/plugin.tar.gz"; then
    error "Failed to download plugin archive from $TARBALL_URL"
    exit 1
fi

info "Downloaded plugin archive"

# --- Extract to plugin destination ---
log "Installing plugin files..."

# Remove existing installation if present
if [ -d "$PLUGIN_DEST" ]; then
    warn "Removing existing installation at $PLUGIN_DEST"
    rm -rf "$PLUGIN_DEST"
fi

mkdir -p "$PLUGIN_DEST"

# Extract tarball — GitHub tarballs contain a top-level directory we need to strip
tar -xzf "$TMPDIR/plugin.tar.gz" -C "$TMPDIR"
EXTRACTED_DIR=$(find "$TMPDIR" -maxdepth 1 -type d -name "${PLUGIN_NAME}-*" | head -1)

if [ -z "$EXTRACTED_DIR" ]; then
    error "Failed to find extracted plugin directory"
    exit 1
fi

# Copy plugin files (exclude git artifacts and build outputs)
rsync -a \
    --exclude='.git' \
    --exclude='.git/' \
    --exclude='bin/' \
    --exclude='obj/' \
    --exclude='.gitignore' \
    "$EXTRACTED_DIR/" "$PLUGIN_DEST/" 2>/dev/null \
|| cp -a "$EXTRACTED_DIR/." "$PLUGIN_DEST/"

# Make hook scripts executable
find "$PLUGIN_DEST/hooks" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
chmod +x "$PLUGIN_DEST/install.sh" 2>/dev/null || true

info "Plugin files installed to $PLUGIN_DEST"

# --- Configure SessionStart hook in .claude/settings.json ---
log "Configuring SessionStart hook..."

mkdir -p "$TARGET_DIR/.claude"

# Use Python to safely merge the hook into settings.json
python3 << 'PYEOF' - "$SETTINGS_FILE" "$HOOK_COMMAND"
import json
import sys
import os

settings_file = sys.argv[1]
hook_command = sys.argv[2]

# Load existing settings or start fresh
settings = {}
if os.path.exists(settings_file):
    try:
        with open(settings_file, 'r') as f:
            settings = json.load(f)
    except (json.JSONDecodeError, IOError):
        # Backup corrupted file
        backup = settings_file + '.bak'
        if os.path.exists(settings_file):
            os.rename(settings_file, backup)
            print(f"Backed up existing settings to {backup}")
        settings = {}

# Build the hook entry we want
new_hook_entry = {
    "hooks": [
        {
            "type": "command",
            "command": hook_command
        }
    ]
}

# Ensure hooks.SessionStart exists
if "hooks" not in settings:
    settings["hooks"] = {}
if "SessionStart" not in settings["hooks"]:
    settings["hooks"]["SessionStart"] = []

# Check if the hook is already configured (avoid duplicates)
already_installed = False
for entry in settings["hooks"]["SessionStart"]:
    for hook in entry.get("hooks", []):
        if hook.get("command", "") == hook_command:
            already_installed = True
            break
    if already_installed:
        break

if already_installed:
    print("SessionStart hook already configured — skipping")
else:
    settings["hooks"]["SessionStart"].append(new_hook_entry)
    print("SessionStart hook added")

# Write settings
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
PYEOF

info "Settings updated at $SETTINGS_FILE"

# --- Summary ---
log ""
log "Installation complete!"
log ""
log "What was installed:"
log "  - Plugin files: .claude/plugins/$PLUGIN_NAME/"
log "  - SessionStart hook: .claude/settings.json"
log ""
log "Next steps:"
log "  1. Commit the .claude/ directory to your repo:"
log "     git add .claude/plugins/$PLUGIN_NAME .claude/settings.json"
log "     git commit -m 'Add .NET NuGet proxy plugin for Claude Code web'"
log ""
log "  2. The SessionStart hook will automatically run in Claude Code web"
log "     sessions. It installs the .NET SDK, compiles the credential"
log "     provider, and starts the proxy — making dotnet restore work"
log "     behind authenticated proxies."
log ""
log "  3. On desktop/local Claude Code, the hook exits immediately"
log "     (checks CLAUDE_CODE_REMOTE internally)."
log ""
