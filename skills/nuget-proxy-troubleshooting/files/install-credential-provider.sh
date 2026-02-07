#!/bin/bash
# Install the NuGet Proxy Credential Provider
#
# This script:
#   1. Compiles the C# credential provider plugin (first time only)
#   2. Installs it to ~/.nuget/plugins/netcore/ for NuGet auto-discovery
#   3. Saves the original upstream proxy URL to _NUGET_UPSTREAM_PROXY
#   4. Creates a dotnet() shell function that routes only dotnet traffic
#      through the local proxy — global HTTPS_PROXY is NOT modified
#   5. Starts the proxy daemon
#
# After installation, `dotnet restore` works without wrapper scripts
# or NuGet.Config changes. Other tools (curl, apt, pip) continue to
# use the original upstream proxy unaffected.
#
# IMPORTANT: Use `source` (not `bash` or `./`) so the shell function
# and env vars apply to the current shell.
#
# Set NUGET_PROXY_VERBOSE=true for detailed output.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="nuget-plugin-proxy-auth"
PLUGIN_SRC_DIR="$SCRIPT_DIR/${PLUGIN_NAME}-src"
LOCAL_PROXY="http://127.0.0.1:8888"

VERBOSE="${NUGET_PROXY_VERBOSE:-false}"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()    { [ "$VERBOSE" = "true" ] && echo -e "${GREEN}[OK]${NC} $1" || true; }
error()   { echo -e "${RED}[ERR]${NC} $1"; }
log()     { echo "$1"; }
verbose() { [ "$VERBOSE" = "true" ] && echo "$1" || true; }

# --- Verify prerequisites ---
if [ ! -d "$PLUGIN_SRC_DIR" ]; then
    error "Plugin source not found at: $PLUGIN_SRC_DIR"
    return 1 2>/dev/null || exit 1
fi

if ! command -v dotnet &> /dev/null; then
    error ".NET SDK is required but not found"
    return 1 2>/dev/null || exit 1
fi

verbose "Installing NuGet Proxy Credential Provider"

# --- Capture the original upstream proxy ---
UPSTREAM_PROXY="${_NUGET_UPSTREAM_PROXY:-${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}}"

if [ -z "$UPSTREAM_PROXY" ]; then
    error "No proxy URL found in environment (HTTPS_PROXY / HTTP_PROXY)"
    error "This plugin requires an authenticated upstream proxy"
    return 1 2>/dev/null || exit 1
fi

# Strip localhost references (don't save our own local proxy as upstream)
if echo "$UPSTREAM_PROXY" | grep -qE "127\.0\.0\.1|localhost"; then
    if [ -n "$_NUGET_UPSTREAM_PROXY" ]; then
        UPSTREAM_PROXY="$_NUGET_UPSTREAM_PROXY"
    else
        error "HTTPS_PROXY points to localhost but no upstream proxy saved"
        error "Set _NUGET_UPSTREAM_PROXY to the authenticated proxy URL"
        return 1 2>/dev/null || exit 1
    fi
fi

# --- Clean up any old installations ---
OLD_PLUGIN_DIR="$HOME/.nuget/plugins/$PLUGIN_NAME"
if [ -d "$OLD_PLUGIN_DIR" ] && [ ! -d "$OLD_PLUGIN_DIR/$PLUGIN_NAME" ]; then
    rm -rf "$OLD_PLUGIN_DIR"
    verbose "Removed old plugin installation"
fi

# --- Compile the plugin (if needed) ---
# Install to netcore dir - NuGet auto-discovers and launches via `dotnet <dll>`
PLUGIN_DIR="$HOME/.nuget/plugins/netcore/$PLUGIN_NAME"
PLUGIN_DLL="$PLUGIN_DIR/$PLUGIN_NAME.dll"

if [ ! -f "$PLUGIN_DLL" ] || [ "$PLUGIN_SRC_DIR/Program.cs" -nt "$PLUGIN_DLL" ]; then
    log "Compiling credential provider..."

    # Detect the installed SDK major version so we compile against matching
    # framework packs. The .csproj defaults to net8.0 but the installed SDK
    # might be 9, 10, etc. — and only its own packs are available locally.
    SDK_MAJOR=$(dotnet --version 2>/dev/null | grep -oP '^\K[0-9]+' || echo "8")
    TFM_OVERRIDE="net${SDK_MAJOR}.0"

    # The project has zero NuGet package dependencies, but dotnet still needs
    # to resolve framework references (Microsoft.NETCore.App.Ref). We restore
    # from the local SDK packs directory only — no network access needed.
    DOTNET_PACKS="$(dotnet --info 2>/dev/null | grep -m1 'Base Path' | sed 's/.*: *//' | sed 's|/sdk/.*|/packs/|')"
    if [ -z "$DOTNET_PACKS" ] || [ ! -d "$DOTNET_PACKS" ]; then
        for p in /usr/lib/dotnet/packs /usr/share/dotnet/packs; do
            if [ -d "$p" ]; then DOTNET_PACKS="$p"; break; fi
        done
    fi
    if [ -n "$DOTNET_PACKS" ] && [ -d "$DOTNET_PACKS" ]; then
        dotnet restore "$PLUGIN_SRC_DIR" \
            -p:TargetFramework="$TFM_OVERRIDE" \
            --source "$DOTNET_PACKS" \
            --verbosity quiet 2>/dev/null || true
    fi
    if ! dotnet publish "$PLUGIN_SRC_DIR" \
        -c Release \
        -o "$PLUGIN_DIR" \
        -p:TargetFramework="$TFM_OVERRIDE" \
        --no-restore \
        --nologo \
        -v quiet 2>&1; then
        error "Failed to compile credential provider"
        return 1 2>/dev/null || exit 1
    fi
    info "Compiled plugin to: $PLUGIN_DIR"
else
    info "Plugin already compiled (up to date)"
fi

# --- Configure environment for current session ---
# Save the upstream proxy so the C# plugin can find it
export _NUGET_UPSTREAM_PROXY="$UPSTREAM_PROXY"

info "Saved upstream proxy to _NUGET_UPSTREAM_PROXY"

# Create a shell function that sets proxy vars ONLY for dotnet commands.
# This avoids overwriting the global HTTPS_PROXY that other tools rely on.
dotnet() {
    HTTPS_PROXY="$LOCAL_PROXY" \
    HTTP_PROXY="$LOCAL_PROXY" \
    https_proxy="$LOCAL_PROXY" \
    http_proxy="$LOCAL_PROXY" \
    _NUGET_UPSTREAM_PROXY="${_NUGET_UPSTREAM_PROXY}" \
    command dotnet "$@"
}
export -f dotnet

info "Created dotnet() shell function (proxy scoped to dotnet only)"

# --- Start the proxy daemon ---
# Use 'command dotnet' to bypass our shell function (daemon needs the real upstream proxy)
_NUGET_UPSTREAM_PROXY="$UPSTREAM_PROXY" command dotnet "$PLUGIN_DLL" --start 2>/dev/null
if [ $? -eq 0 ]; then
    info "Proxy daemon started"
else
    verbose "Proxy may already be running or failed to start"
fi

# --- Verification (verbose only) ---
if [ "$VERBOSE" = "true" ]; then
    echo ""
    echo "Verification:"
    _NUGET_UPSTREAM_PROXY="$UPSTREAM_PROXY" command dotnet "$PLUGIN_DLL" --status 2>/dev/null
fi
