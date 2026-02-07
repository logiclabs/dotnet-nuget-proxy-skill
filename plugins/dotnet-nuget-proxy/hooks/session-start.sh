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

# --- Step 1: Install .NET SDK if not present ---
if ! command -v dotnet &>/dev/null; then
  echo "Installing .NET SDK from packages.microsoft.com..."
  curl -sSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
    -o /tmp/packages-microsoft-prod.deb
  dpkg -i /tmp/packages-microsoft-prod.deb
  apt-get update --allow-insecure-repositories 2>/dev/null
  apt-get install -y --allow-unauthenticated dotnet-sdk-8.0 2>/dev/null
  echo ".NET SDK installed: $(dotnet --version)"
else
  echo ".NET SDK already installed: $(dotnet --version)"
fi

# --- Step 2: Set up the credential provider and proxy ---
if [ -f "$FILES_DIR/install-credential-provider.sh" ]; then
  source "$FILES_DIR/install-credential-provider.sh"
else
  echo "WARNING: install-credential-provider.sh not found at $FILES_DIR"
  echo "NuGet proxy authentication will not be configured."
  exit 0
fi

# --- Step 3: Persist env vars for the session ---
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export _NUGET_UPSTREAM_PROXY=\"${_NUGET_UPSTREAM_PROXY:-}\"" >> "$CLAUDE_ENV_FILE"
  echo "export HTTPS_PROXY=\"${HTTPS_PROXY:-}\"" >> "$CLAUDE_ENV_FILE"
  echo "export HTTP_PROXY=\"${HTTP_PROXY:-}\"" >> "$CLAUDE_ENV_FILE"
  echo "export https_proxy=\"${https_proxy:-}\"" >> "$CLAUDE_ENV_FILE"
  echo "export http_proxy=\"${http_proxy:-}\"" >> "$CLAUDE_ENV_FILE"
  echo "Environment variables persisted for session."
fi

echo ".NET NuGet proxy setup complete."
