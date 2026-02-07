#!/bin/bash
# Install the NuGet Proxy Credential Provider
#
# This script:
#   1. Compiles the C# credential provider plugin (first time only)
#   2. Installs it to ~/.nuget/plugins/netcore/ for NuGet auto-discovery
#   3. Saves the original upstream proxy URL
#   4. Points HTTPS_PROXY to the local proxy (localhost:8888)
#   5. Starts the proxy daemon
#
# After installation, `dotnet restore` works without wrapper scripts
# or NuGet.Config changes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="nuget-plugin-proxy-auth"
PLUGIN_SRC_DIR="$SCRIPT_DIR/${PLUGIN_NAME}-src"
LOCAL_PROXY="http://127.0.0.1:8888"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $1"; }
error() { echo -e "${RED}[ERR]${NC} $1"; }

# --- Verify prerequisites ---
if [ ! -d "$PLUGIN_SRC_DIR" ]; then
    error "Plugin source not found at: $PLUGIN_SRC_DIR"
    exit 1
fi

if ! command -v dotnet &> /dev/null; then
    error ".NET SDK is required but not found"
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

# --- Clean up any old installations ---
OLD_PLUGIN_DIR="$HOME/.nuget/plugins/$PLUGIN_NAME"
if [ -d "$OLD_PLUGIN_DIR" ] && [ ! -d "$OLD_PLUGIN_DIR/$PLUGIN_NAME" ]; then
    rm -rf "$OLD_PLUGIN_DIR"
    warn "Removed old plugin installation"
fi

# --- Compile the plugin (if needed) ---
# Install to netcore dir - NuGet auto-discovers and launches via `dotnet <dll>`
PLUGIN_DIR="$HOME/.nuget/plugins/netcore/$PLUGIN_NAME"
PLUGIN_DLL="$PLUGIN_DIR/$PLUGIN_NAME.dll"

if [ ! -f "$PLUGIN_DLL" ] || [ "$PLUGIN_SRC_DIR/Program.cs" -nt "$PLUGIN_DLL" ]; then
    echo "Compiling credential provider..."
    # Build using the upstream proxy (not localhost) so NuGet can fetch SDK deps
    _NUGET_UPSTREAM_PROXY="$UPSTREAM_PROXY" \
    HTTPS_PROXY="$UPSTREAM_PROXY" HTTP_PROXY="$UPSTREAM_PROXY" \
    https_proxy="$UPSTREAM_PROXY" http_proxy="$UPSTREAM_PROXY" \
    dotnet publish "$PLUGIN_SRC_DIR" \
        -c Release \
        -o "$PLUGIN_DIR" \
        --nologo \
        -v quiet 2>&1
    if [ $? -ne 0 ]; then
        error "Failed to compile credential provider"
        exit 1
    fi
    info "Compiled plugin to: $PLUGIN_DIR"
else
    info "Plugin already compiled (up to date)"
fi

# --- Configure environment for current session ---
export _NUGET_UPSTREAM_PROXY="$UPSTREAM_PROXY"
export HTTPS_PROXY="$LOCAL_PROXY"
export HTTP_PROXY="$LOCAL_PROXY"
export https_proxy="$LOCAL_PROXY"
export http_proxy="$LOCAL_PROXY"

info "Saved upstream proxy to _NUGET_UPSTREAM_PROXY"
info "Set HTTPS_PROXY=$LOCAL_PROXY"

# --- Start the proxy daemon ---
echo ""
dotnet "$PLUGIN_DLL" --start 2>/dev/null
if [ $? -eq 0 ]; then
    info "Proxy daemon started"
else
    warn "Proxy may already be running or failed to start"
fi

# --- Write shell profile snippet ---
PROFILE_SNIPPET="
# NuGet Proxy Credential Provider
export _NUGET_UPSTREAM_PROXY=\"\${_NUGET_UPSTREAM_PROXY:-\$HTTPS_PROXY}\"
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
dotnet "$PLUGIN_DLL" --status 2>/dev/null
