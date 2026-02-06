#!/bin/bash
# Wrapper script for dotnet commands that automatically uses the NuGet proxy
# Usage: ./dotnet-with-proxy.sh build
#        ./dotnet-with-proxy.sh restore
#        ./dotnet-with-proxy.sh test

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_SCRIPT="$SCRIPT_DIR/nuget-proxy.py"
PROXY_PORT=8888
PROXY_PID_FILE="/tmp/nuget-proxy.pid"

# Function to check if proxy is running
is_proxy_running() {
    # First check by PID file
    if [ -f "$PROXY_PID_FILE" ]; then
        local pid=$(cat "$PROXY_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            # Check if it's actually our proxy
            if ps -p "$pid" -o cmd= | grep -q "nuget-proxy.py"; then
                return 0
            fi
        fi
    fi

    # Fallback: Check if port is in use (proxy might be running without PID file)
    if ps aux | grep "[n]uget-proxy.py" > /dev/null 2>&1; then
        # Found proxy process, create PID file
        local pid=$(ps aux | grep "[n]uget-proxy.py" | awk '{print $2}' | head -1)
        if [ -n "$pid" ]; then
            echo $pid > "$PROXY_PID_FILE"
            return 0
        fi
    fi

    return 1
}

# Function to start proxy
start_proxy() {
    echo "Starting NuGet proxy on port $PROXY_PORT..."
    python3 "$PROXY_SCRIPT" > /tmp/nuget-proxy.log 2>&1 &
    local pid=$!
    echo $pid > "$PROXY_PID_FILE"
    sleep 2

    if is_proxy_running; then
        echo "✓ NuGet proxy started (PID: $pid)"
    else
        echo "✗ Failed to start proxy. Check /tmp/nuget-proxy.log for errors"
        exit 1
    fi
}

# Function to stop proxy
stop_proxy() {
    if [ -f "$PROXY_PID_FILE" ]; then
        local pid=$(cat "$PROXY_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Stopping NuGet proxy (PID: $pid)..."
            kill "$pid"
            rm -f "$PROXY_PID_FILE"
        fi
    fi
}

# Trap to ensure cleanup on script exit if we started the proxy
PROXY_STARTED_HERE=false

cleanup() {
    if [ "$PROXY_STARTED_HERE" = true ]; then
        echo ""
        echo "Keeping proxy running for future commands..."
        echo "To stop: kill \$(cat $PROXY_PID_FILE)"
    fi
}

trap cleanup EXIT

# Check if proxy is already running
if ! is_proxy_running; then
    start_proxy
    PROXY_STARTED_HERE=true
else
    echo "✓ NuGet proxy already running"
fi

# Run dotnet command with proxy environment variables
echo "Running: dotnet $@"
echo ""

http_proxy=http://127.0.0.1:$PROXY_PORT \
https_proxy=http://127.0.0.1:$PROXY_PORT \
HTTP_PROXY=http://127.0.0.1:$PROXY_PORT \
HTTPS_PROXY=http://127.0.0.1:$PROXY_PORT \
dotnet "$@"
