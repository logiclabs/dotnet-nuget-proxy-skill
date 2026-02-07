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

# Only run in remote (web) sessions
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Resolve the plugin directory (where this script lives)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$HOOK_DIR/.." && pwd)"
FILES_DIR="$PLUGIN_DIR/skills/nuget-proxy-troubleshooting/files"

echo "Setting up .NET NuGet proxy authentication..."

# --- Step 1: Detect required .NET SDK version from project files ---
DOTNET_VERSION=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  # Look for TargetFramework in .csproj files to determine required SDK version
  TFM=$(grep -rh --include='*.csproj' '<TargetFramework>' "$CLAUDE_PROJECT_DIR" 2>/dev/null \
    | head -1 | grep -oP 'net\K[0-9]+' || true)
  if [ -n "$TFM" ]; then
    DOTNET_VERSION="$TFM"
    echo "Detected .NET $DOTNET_VERSION from project files."
  fi
fi

# If no .NET project found, skip SDK installation entirely.
# Claude will use the SKILL.md decision flow to ask the user which version to install.
if [ -z "$DOTNET_VERSION" ]; then
  echo "No .NET project files found. Skipping SDK installation."
  echo "When you need .NET, ask Claude to set it up — it will install the right version."
  exit 0
fi

# --- Step 2: Install .NET SDK if not present or wrong version ---
install_sdk() {
  echo "Installing .NET SDK $DOTNET_VERSION from packages.microsoft.com..."
  curl -sSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
    -o /tmp/packages-microsoft-prod.deb
  dpkg -i /tmp/packages-microsoft-prod.deb 2>/dev/null
  apt-get update --allow-insecure-repositories 2>/dev/null
  apt-get install -y --allow-unauthenticated dotnet-sdk-$DOTNET_VERSION.0 2>/dev/null
  echo ".NET SDK installed: $(dotnet --version)"
}

if ! command -v dotnet &>/dev/null; then
  install_sdk
else
  # Check if the installed SDK matches the required version
  INSTALLED=$(dotnet --list-sdks 2>/dev/null | grep -oP '^\K[0-9]+' | head -1 || true)
  if [ -n "$INSTALLED" ] && [ "$INSTALLED" != "$DOTNET_VERSION" ]; then
    echo "Installed .NET SDK is $INSTALLED but project requires $DOTNET_VERSION."
    install_sdk
  else
    echo ".NET SDK already installed: $(dotnet --version)"
  fi
fi

# --- Step 3: Set up the credential provider and proxy ---
if [ -f "$FILES_DIR/install-credential-provider.sh" ]; then
  source "$FILES_DIR/install-credential-provider.sh"
else
  echo "WARNING: install-credential-provider.sh not found at $FILES_DIR"
  echo "NuGet proxy authentication will not be configured."
  exit 0
fi

# --- Step 4: Persist the upstream proxy and dotnet function for the session ---
# Only _NUGET_UPSTREAM_PROXY needs persisting — global HTTPS_PROXY stays unchanged.
# The dotnet() shell function (created by install-credential-provider.sh) scopes
# the local proxy to dotnet commands only, so other tools are unaffected.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export _NUGET_UPSTREAM_PROXY=\"${_NUGET_UPSTREAM_PROXY:-}\"" >> "$CLAUDE_ENV_FILE"
  # Re-export the dotnet shell function so it survives across subshells
  LOCAL_PROXY="http://127.0.0.1:8888"
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
  echo "Environment persisted for session."
fi

echo ".NET NuGet proxy setup complete."
