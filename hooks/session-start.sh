#!/bin/bash
set -euo pipefail

# SessionStart hook for .NET NuGet proxy authentication in Claude Code web
#
# This hook automatically:
#   1. Installs the .NET SDK (from packages.microsoft.com, not the blocked dot.net)
#   2. Compiles and installs the NuGet proxy credential provider
#   3. Starts the proxy daemon on localhost:8888
#   4. Persists environment variables for the session
#
# Only runs in Claude Code web sessions (skips on desktop/local).
#
# Set NUGET_PROXY_VERBOSE=true for detailed output during setup.

# Only run in remote (web) sessions
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Resolve the plugin directory (where this script lives)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$HOOK_DIR/.." && pwd)"
FILES_DIR="$PLUGIN_DIR/skills/nuget-proxy-troubleshooting/files"

VERBOSE="${NUGET_PROXY_VERBOSE:-false}"

# Logging helpers — only print detail lines when verbose
log()     { echo "$1"; }
verbose() { [ "$VERBOSE" = "true" ] && echo "$1" || true; }

# --- Step 1: Detect required .NET SDK version from project files ---
DOTNET_VERSION=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  # 1. Check global.json first (canonical way to pin .NET SDK version)
  if [ -f "$CLAUDE_PROJECT_DIR/global.json" ]; then
    DOTNET_VERSION=$(grep -oP '"version"\s*:\s*"\K[0-9]+' "$CLAUDE_PROJECT_DIR/global.json" 2>/dev/null | head -1 || true)
    if [ -n "$DOTNET_VERSION" ]; then
      verbose "Detected .NET $DOTNET_VERSION from global.json."
    fi
  fi

  # 2. Fall back to <TargetFramework> in .csproj files
  #    Exclude the plugin's own .csproj (its TFM is overridden at compile time)
  if [ -z "$DOTNET_VERSION" ]; then
    TFM=$(grep -rh --include='*.csproj' --exclude-dir='nuget-plugin-proxy-auth-src' \
      '<TargetFramework>' "$CLAUDE_PROJECT_DIR" 2>/dev/null \
      | head -1 | grep -oP 'net\K[0-9]+' || true)
    if [ -n "$TFM" ]; then
      DOTNET_VERSION="$TFM"
      verbose "Detected .NET $DOTNET_VERSION from project files."
    fi
  fi
fi

# If no .NET project found, skip SDK installation entirely.
if [ -z "$DOTNET_VERSION" ]; then
  verbose "No .NET project files found. Skipping SDK installation."
  exit 0
fi

# --- Fast-path: skip everything if already fully configured ---
PLUGIN_NAME="nuget-plugin-proxy-auth"
PLUGIN_DLL="$HOME/.nuget/plugins/netcore/$PLUGIN_NAME/$PLUGIN_NAME.dll"
PLUGIN_SRC="$FILES_DIR/${PLUGIN_NAME}-src/Program.cs"

is_sdk_installed() {
  command -v dotnet &>/dev/null || return 1
  local installed
  installed=$(dotnet --list-sdks 2>/dev/null | grep -oP '^\K[0-9]+' | head -1 || true)
  [ "$installed" = "$DOTNET_VERSION" ]
}

is_plugin_current() {
  [ -f "$PLUGIN_DLL" ] && [ -f "$PLUGIN_SRC" ] && [ ! "$PLUGIN_SRC" -nt "$PLUGIN_DLL" ]
}

is_proxy_running() {
  curl -s --connect-timeout 1 "http://127.0.0.1:8888" &>/dev/null || \
    ss -tlnp 2>/dev/null | grep -q ':8888 ' 2>/dev/null || \
    netstat -tlnp 2>/dev/null | grep -q ':8888 ' 2>/dev/null
}

if is_sdk_installed && is_plugin_current && is_proxy_running; then
  verbose ".NET SDK, plugin, and proxy already configured — fast-path."

  # Still need to persist the dotnet() function and env for this session
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    UPSTREAM_PROXY="${_NUGET_UPSTREAM_PROXY:-${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}}"
    # Strip localhost proxy (use saved upstream)
    if echo "$UPSTREAM_PROXY" | grep -qE "127\.0\.0\.1|localhost"; then
      UPSTREAM_PROXY="${_NUGET_UPSTREAM_PROXY:-$UPSTREAM_PROXY}"
    fi
    echo "export _NUGET_UPSTREAM_PROXY=\"${UPSTREAM_PROXY}\"" >> "$CLAUDE_ENV_FILE"
    cat >> "$CLAUDE_ENV_FILE" << 'DOTNET_FUNC'
dotnet() {
    HTTPS_PROXY="http://127.0.0.1:8888" \
    HTTP_PROXY="http://127.0.0.1:8888" \
    https_proxy="http://127.0.0.1:8888" \
    http_proxy="http://127.0.0.1:8888" \
    _NUGET_UPSTREAM_PROXY="${_NUGET_UPSTREAM_PROXY}" \
    command dotnet "$@"
}
export -f dotnet
DOTNET_FUNC
  fi
  log ".NET NuGet proxy ready."
  exit 0
fi

log "Setting up .NET NuGet proxy authentication..."

# --- Step 2: Install .NET SDK if not present or wrong version ---
install_sdk() {
  log "Installing .NET SDK $DOTNET_VERSION..."
  if [ "$VERBOSE" = "true" ]; then
    curl -sSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
      -o /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    apt-get update --allow-insecure-repositories
    apt-get install -y --allow-unauthenticated dotnet-sdk-$DOTNET_VERSION.0
  else
    curl -sSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
      -o /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb >/dev/null 2>&1
    apt-get update --allow-insecure-repositories >/dev/null 2>&1
    apt-get install -y --allow-unauthenticated dotnet-sdk-$DOTNET_VERSION.0 >/dev/null 2>&1
  fi
  log ".NET SDK installed: $(dotnet --version)"
}

if ! command -v dotnet &>/dev/null; then
  install_sdk
else
  INSTALLED=$(dotnet --list-sdks 2>/dev/null | grep -oP '^\K[0-9]+' | head -1 || true)
  if [ -n "$INSTALLED" ] && [ "$INSTALLED" != "$DOTNET_VERSION" ]; then
    verbose "Installed .NET SDK is $INSTALLED but project requires $DOTNET_VERSION."
    install_sdk
  else
    verbose ".NET SDK already installed: $(dotnet --version)"
  fi
fi

# --- Step 3: Set up the credential provider and proxy ---
if [ -f "$FILES_DIR/install-credential-provider.sh" ]; then
  # Pass quiet mode to the install script
  NUGET_PROXY_VERBOSE="$VERBOSE" source "$FILES_DIR/install-credential-provider.sh"
else
  echo "WARNING: install-credential-provider.sh not found at $FILES_DIR"
  exit 0
fi

# --- Step 4: Persist the upstream proxy and dotnet function for the session ---
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export _NUGET_UPSTREAM_PROXY=\"${_NUGET_UPSTREAM_PROXY:-}\"" >> "$CLAUDE_ENV_FILE"
  cat >> "$CLAUDE_ENV_FILE" << 'DOTNET_FUNC'
dotnet() {
    HTTPS_PROXY="http://127.0.0.1:8888" \
    HTTP_PROXY="http://127.0.0.1:8888" \
    https_proxy="http://127.0.0.1:8888" \
    http_proxy="http://127.0.0.1:8888" \
    _NUGET_UPSTREAM_PROXY="${_NUGET_UPSTREAM_PROXY}" \
    command dotnet "$@"
}
export -f dotnet
DOTNET_FUNC
  verbose "Environment persisted for session."
fi

log ".NET NuGet proxy setup complete."
