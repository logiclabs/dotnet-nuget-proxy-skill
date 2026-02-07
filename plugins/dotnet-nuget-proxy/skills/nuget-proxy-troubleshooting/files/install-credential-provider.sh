#!/bin/bash
# Install the NuGet Proxy Credential Provider
#
# This script:
#   1. Installs the credential provider plugin
#   2. Saves the original upstream proxy URL
#   3. Points HTTPS_PROXY to the local proxy (localhost:8888)
#   4. Sets NUGET_PLUGIN_PATHS so NuGet discovers the plugin
#   5. Starts the proxy daemon
#
# After installation, `dotnet restore` works without wrapper scripts
# or NuGet.Config changes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="nuget-plugin-proxy-auth"
PLUGIN_SOURCE="$SCRIPT_DIR/$PLUGIN_NAME"
LOCAL_PROXY="http://127.0.0.1:8888"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $1"; }
error() { echo -e "${RED}[ERR]${NC} $1"; }

# --- Verify prerequisites ---
if [ ! -f "$PLUGIN_SOURCE" ]; then
    error "Plugin not found at: $PLUGIN_SOURCE"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    error "Python 3 is required but not found"
    exit 1
fi

echo "Installing NuGet Proxy Credential Provider"
echo "==========================================="
echo ""

# --- Capture the original upstream proxy BEFORE we overwrite HTTPS_PROXY ---
UPSTREAM_PROXY="${_NUGET_UPSTREAM_PROXY:-${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}}"

if [ -z "$UPSTREAM_PROXY" ]; then
    error "No proxy URL found in environment (HTTPS_PROXY / HTTP_PROXY)"
    error "This plugin requires an authenticated upstream proxy"
    exit 1
fi

# Strip localhost references (don't save our own local proxy as upstream)
if echo "$UPSTREAM_PROXY" | grep -qE "127\.0\.0\.1|localhost"; then
    if [ -n "$_NUGET_UPSTREAM_PROXY" ]; then
        UPSTREAM_PROXY="$_NUGET_UPSTREAM_PROXY"
    else
        error "HTTPS_PROXY points to localhost but no upstream proxy saved"
        error "Set _NUGET_UPSTREAM_PROXY to the authenticated proxy URL"
        exit 1
    fi
fi

# --- Install the plugin ---
PLUGIN_DIR="$HOME/.nuget/plugins/netcore/$PLUGIN_NAME"
mkdir -p "$PLUGIN_DIR"
cp "$PLUGIN_SOURCE" "$PLUGIN_DIR/$PLUGIN_NAME"
chmod +x "$PLUGIN_DIR/$PLUGIN_NAME"
info "Plugin installed to: $PLUGIN_DIR"

# Also install to PATH for NuGet 6.13+ discovery
LOCAL_BIN="$HOME/.local/bin"
if [ -d "$LOCAL_BIN" ]; then
    cp "$PLUGIN_SOURCE" "$LOCAL_BIN/$PLUGIN_NAME"
    chmod +x "$LOCAL_BIN/$PLUGIN_NAME"
fi

# --- Configure environment for current session ---
export _NUGET_UPSTREAM_PROXY="$UPSTREAM_PROXY"
export NUGET_PLUGIN_PATHS="$PLUGIN_DIR/$PLUGIN_NAME"
export HTTPS_PROXY="$LOCAL_PROXY"
export HTTP_PROXY="$LOCAL_PROXY"
export https_proxy="$LOCAL_PROXY"
export http_proxy="$LOCAL_PROXY"

info "Saved upstream proxy to _NUGET_UPSTREAM_PROXY"
info "Set NUGET_PLUGIN_PATHS=$PLUGIN_DIR/$PLUGIN_NAME"
info "Set HTTPS_PROXY=$LOCAL_PROXY"

# --- Start the proxy daemon ---
echo ""
"$PLUGIN_DIR/$PLUGIN_NAME" --start 2>/dev/null
if [ $? -eq 0 ]; then
    info "Proxy daemon started"
else
    warn "Proxy may already be running or failed to start"
fi

# --- Write shell profile snippet ---
PROFILE_SNIPPET="
# NuGet Proxy Credential Provider
export _NUGET_UPSTREAM_PROXY=\"\${_NUGET_UPSTREAM_PROXY:-\$HTTPS_PROXY}\"
export NUGET_PLUGIN_PATHS=\"$PLUGIN_DIR/$PLUGIN_NAME\"
export HTTPS_PROXY=\"$LOCAL_PROXY\"
export HTTP_PROXY=\"$LOCAL_PROXY\"
export https_proxy=\"$LOCAL_PROXY\"
export http_proxy=\"$LOCAL_PROXY\"
"

echo ""
echo "==========================================="
echo ""
info "Installation complete!"
echo ""
echo "  For this session, the environment is already configured."
echo "  Just run: dotnet restore"
echo ""
echo "  To persist across sessions, add to your shell profile:"
echo ""
echo "    cat >> ~/.bashrc << 'NUGETEOF'"
echo "$PROFILE_SNIPPET"
echo "NUGETEOF"
echo ""
echo "  Or source this script at the start of each session:"
echo "    source $SCRIPT_DIR/install-credential-provider.sh"
echo ""

# --- Verify ---
echo "Verification:"
"$PLUGIN_DIR/$PLUGIN_NAME" --status 2>/dev/null
