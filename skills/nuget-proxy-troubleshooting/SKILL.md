---
name: dotnet-nuget-proxy
description: Explains how to fix .NET NuGet restore issues in Claude Code environment using the custom proxy solution
---

# .NET NuGet Proxy Solution for Claude Code Environment

## Problem Overview

In the Claude Code environment, NuGet package restoration fails with authentication errors because:
- Claude Code uses a JWT-authenticated HTTP proxy at `21.0.0.179:15004`
- NuGet doesn't support the authentication method required by this proxy
- This results in 401 errors when trying to restore packages from nuget.org

## Solution: Custom Proxy Bridge

This project includes a custom proxy solution that bridges NuGet to the authenticated Claude Code proxy.

### Components

1. **nuget-proxy.py** - Python HTTP/HTTPS proxy that:
   - Listens on localhost:8888 (unauthenticated)
   - Forwards requests to Claude Code proxy with JWT authentication
   - Handles HTTPS CONNECT tunneling for secure connections

2. **dotnet-with-proxy.sh** - Wrapper script that:
   - Automatically detects/starts the proxy if needed
   - Sets HTTP_PROXY/HTTPS_PROXY environment variables
   - Runs dotnet commands seamlessly

3. **NuGet.config** - Configured to use the local proxy on port 8888

4. **NUGET-PROXY-README.md** - Detailed documentation

## Quick Start

### For New Sessions

When starting a new Claude Code session:

1. **Check if proxy files exist:**
   ```bash
   ls -la nuget-proxy.py dotnet-with-proxy.sh NuGet.config
   ```

2. **If files exist, use the wrapper script:**
   ```bash
   # Restore packages
   ./dotnet-with-proxy.sh restore

   # Build project
   ./dotnet-with-proxy.sh build

   # Run project
   ./dotnet-with-proxy.sh run
   ```

3. **The wrapper automatically:**
   - Detects if proxy is running
   - Starts proxy if needed
   - Keeps proxy running between commands
   - Sets proper environment variables

### Manual Proxy Control

**Start proxy manually:**
```bash
python3 nuget-proxy.py
```

**Check if running:**
```bash
ps aux | grep nuget-proxy
# or
cat /tmp/nuget-proxy.pid && ps -p $(cat /tmp/nuget-proxy.pid)
```

**Stop proxy:**
```bash
kill $(cat /tmp/nuget-proxy.pid)
```

## How It Works

### Authentication Flow

```
NuGet → localhost:8888 (nuget-proxy.py) → 21.0.0.179:15004 (Claude Code proxy) → nuget.org
        [no auth required]                 [JWT auth added]                     [internet]
```

### Environment Variables

The proxy solution relies on these environment variables (automatically set by Claude Code):
- `HTTP_PROXY` - Used by the Python proxy to connect upstream
- `HTTPS_PROXY` - Same as HTTP_PROXY
- `PROXY_AUTHORIZATION` - JWT token for authentication

### NuGet Configuration

The `NuGet.config` file configures NuGet to use the local proxy:
```xml
<configuration>
  <config>
    <add key="http_proxy" value="http://127.0.0.1:8888" />
    <add key="https_proxy" value="http://127.0.0.1:8888" />
  </config>
</configuration>
```

## Troubleshooting

### Issue: "Connection refused" on port 8888

**Cause:** Proxy is not running

**Solution:**
```bash
python3 nuget-proxy.py &
# or use wrapper script which auto-starts it
./dotnet-with-proxy.sh restore
```

### Issue: "Address already in use"

**Cause:** Proxy is already running or port is taken

**Solution:**
```bash
# Check what's using port 8888
lsof -i :8888
# or
ps aux | grep nuget-proxy

# If it's the proxy, use it as-is
# If it's something else, kill it:
kill $(lsof -t -i:8888)
```

### Issue: 401 Unauthorized from upstream proxy

**Cause:** Claude Code proxy environment variables missing or expired

**Solution:**
```bash
# Check if auth is available
echo $PROXY_AUTHORIZATION

# If empty, the session may need to be restarted
# Try running a simple command first to trigger auth refresh
curl -I https://api.nuget.org/v3/index.json
```

### Issue: Proxy starts but restore still fails

**Cause:** NuGet not using proxy configuration

**Solution:**
```bash
# Verify NuGet.config exists
cat NuGet.config

# Force restore with explicit config
dotnet restore --configfile NuGet.config

# Or use the wrapper script
./dotnet-with-proxy.sh restore
```

### Issue: SSL/TLS certificate errors

**Cause:** Python proxy not properly handling HTTPS CONNECT

**Solution:**
```bash
# Check proxy logs
# The proxy should show CONNECT requests

# Restart proxy
kill $(cat /tmp/nuget-proxy.pid)
python3 nuget-proxy.py &

# Wait a moment, then retry
./dotnet-with-proxy.sh restore
```

## Creating Proxy Files (If Missing)

If the proxy files don't exist in a new session, you'll need to recreate them. Here's a quick reference:

### Create nuget-proxy.py

See the NUGET-PROXY-README.md file or the existing nuget-proxy.py for the complete implementation.

Key requirements:
- Python 3 with http.server and socket modules
- Handles both HTTP requests and HTTPS CONNECT tunneling
- Extracts auth from environment variables
- Listens on 127.0.0.1:8888

### Create dotnet-with-proxy.sh

```bash
#!/bin/bash
PROXY_PORT=8888
PROXY_PID_FILE="/tmp/nuget-proxy.pid"

is_proxy_running() {
    # Check by PID file
    if [ -f "$PROXY_PID_FILE" ]; then
        local pid=$(cat "$PROXY_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            if ps -p "$pid" -o cmd= | grep -q "nuget-proxy.py"; then
                return 0
            fi
        fi
    fi

    # Fallback: Check if process exists
    if ps aux | grep "[n]uget-proxy.py" > /dev/null 2>&1; then
        local pid=$(ps aux | grep "[n]uget-proxy.py" | awk '{print $2}' | head -1)
        if [ -n "$pid" ]; then
            echo $pid > "$PROXY_PID_FILE"
            return 0
        fi
    fi
    return 1
}

if is_proxy_running; then
    echo "✓ NuGet proxy already running"
else
    echo "Starting NuGet proxy on port $PROXY_PORT..."
    python3 nuget-proxy.py > /tmp/nuget-proxy.log 2>&1 &
    echo $! > "$PROXY_PID_FILE"
    sleep 2
    if is_proxy_running; then
        echo "✓ NuGet proxy started (PID: $(cat $PROXY_PID_FILE))"
    else
        echo "✗ Failed to start proxy"
        exit 1
    fi
fi

echo "Running: dotnet $@"
http_proxy=http://127.0.0.1:$PROXY_PORT \
https_proxy=http://127.0.0.1:$PROXY_PORT \
HTTP_PROXY=http://127.0.0.1:$PROXY_PORT \
HTTPS_PROXY=http://127.0.0.1:$PROXY_PORT \
dotnet "$@"

DOTNET_EXIT_CODE=$?
if [ $DOTNET_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "Keeping proxy running for future commands..."
    echo "To stop: kill \$(cat $PROXY_PID_FILE)"
fi

exit $DOTNET_EXIT_CODE
```

Make it executable:
```bash
chmod +x dotnet-with-proxy.sh
```

### Create NuGet.config

```bash
cat > NuGet.config << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <config>
    <add key="http_proxy" value="http://127.0.0.1:8888" />
    <add key="https_proxy" value="http://127.0.0.1:8888" />
  </config>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
</configuration>
EOF
```

## Best Practices

1. **Always use the wrapper script** for dotnet commands to ensure proxy is running
2. **Keep the proxy running** between commands for efficiency (it auto-starts as needed)
3. **Check proxy logs** at `/tmp/nuget-proxy.log` if issues occur
4. **Don't manually set proxy environment variables** - let the wrapper script handle it
5. **Commit proxy files** to the repository so they're available in all sessions

## Alternative: Direct dotnet Commands

If you prefer not to use the wrapper, set environment variables manually:

```bash
# Start proxy first
python3 nuget-proxy.py &

# Set env vars and run dotnet
export HTTP_PROXY=http://127.0.0.1:8888
export HTTPS_PROXY=http://127.0.0.1:8888
export http_proxy=http://127.0.0.1:8888
export https_proxy=http://127.0.0.1:8888

dotnet restore
dotnet build
dotnet run
```

## Summary

The NuGet proxy solution is a **temporary workaround** for the Claude Code environment until the underlying proxy authentication issue is resolved. The wrapper script makes it seamless to use - just prefix your dotnet commands with `./dotnet-with-proxy.sh` and everything works automatically.

For more details, see `NUGET-PROXY-README.md` in the repository root.
