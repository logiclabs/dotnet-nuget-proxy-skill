#!/bin/bash
# Install the NuGet Proxy Credential Provider
#
# This script installs the credential provider so NuGet can authenticate
# with the proxy using JWT credentials from the PROXY_AUTHORIZATION
# environment variable.
#
# Installation methods (in order of preference):
#   1. NUGET_PLUGIN_PATHS env var (most reliable, works with all NuGet versions)
#   2. ~/.nuget/plugins/ directory (standard plugin location)
#   3. PATH-based discovery (requires NuGet 6.13+)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="nuget-plugin-proxy-auth"
PLUGIN_SOURCE="$SCRIPT_DIR/$PLUGIN_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Verify the plugin source exists
if [ ! -f "$PLUGIN_SOURCE" ]; then
    error "Plugin not found at: $PLUGIN_SOURCE"
    exit 1
fi

# Verify Python 3 is available
if ! command -v python3 &> /dev/null; then
    error "Python 3 is required but not found"
    exit 1
fi

info "Installing NuGet Proxy Credential Provider..."
echo ""

# --- Method 1: Install to ~/.nuget/plugins/netcore/ ---
PLUGIN_DIR="$HOME/.nuget/plugins/netcore/$PLUGIN_NAME"

info "Installing to: $PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
cp "$PLUGIN_SOURCE" "$PLUGIN_DIR/$PLUGIN_NAME"
chmod +x "$PLUGIN_DIR/$PLUGIN_NAME"

# --- Method 2: Set NUGET_PLUGIN_PATHS for current session ---
export NUGET_PLUGIN_PATHS="$PLUGIN_DIR/$PLUGIN_NAME"
info "Set NUGET_PLUGIN_PATHS=$NUGET_PLUGIN_PATHS"

# --- Method 3: Also install to a PATH-discoverable location ---
LOCAL_BIN="$HOME/.local/bin"
if [ -d "$LOCAL_BIN" ]; then
    cp "$PLUGIN_SOURCE" "$LOCAL_BIN/$PLUGIN_NAME"
    chmod +x "$LOCAL_BIN/$PLUGIN_NAME"
    info "Also installed to: $LOCAL_BIN/$PLUGIN_NAME (PATH discovery)"
fi

echo ""
info "Installation complete!"
echo ""

# --- Verify installation ---
info "Verifying installation..."
echo ""

# Check plugin runs
if "$PLUGIN_DIR/$PLUGIN_NAME" 2>/dev/null | head -1 | grep -q "Credential Provider"; then
    info "Plugin executable: OK"
else
    warn "Plugin may not be executable. Check Python 3 availability."
fi

# Check environment
if [ -n "$PROXY_AUTHORIZATION" ]; then
    info "PROXY_AUTHORIZATION: set"
else
    warn "PROXY_AUTHORIZATION: not set (credentials won't be available)"
fi

PROXY_URL="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}"
if [ -n "$PROXY_URL" ]; then
    info "Proxy URL: configured"
else
    warn "Proxy URL: not set"
fi

echo ""
echo "--- Setup Instructions ---"
echo ""
echo "For the current shell session, run:"
echo "  export NUGET_PLUGIN_PATHS=\"$PLUGIN_DIR/$PLUGIN_NAME\""
echo ""
echo "To make permanent, add to your shell profile (~/.bashrc or ~/.zshrc):"
echo "  echo 'export NUGET_PLUGIN_PATHS=\"$PLUGIN_DIR/$PLUGIN_NAME\"' >> ~/.bashrc"
echo ""
echo "Then run dotnet restore as normal (no proxy wrapper needed):"
echo "  dotnet restore"
echo ""
