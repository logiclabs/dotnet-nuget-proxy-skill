# NuGet Proxy for Claude Code Environment

This directory contains a proxy solution that enables `dotnet restore` and `dotnet build` to work in the Claude Code environment by handling proxy authentication automatically.

## Quick Start

### Option 1: Use the Wrapper Script (Recommended)

Simply use the wrapper script instead of `dotnet`:

```bash
./dotnet-with-proxy.sh restore
./dotnet-with-proxy.sh build
./dotnet-with-proxy.sh test
```

The script will automatically:
- Start the proxy if it's not running
- Keep it running for future commands
- Set the correct environment variables

### Option 2: Create an Alias

Source the alias setup script for convenient use:

```bash
source ./setup-dotnet-alias.sh
```

Now use `dotnet` commands normally:
```bash
dotnet restore
dotnet build
dotnet test
```

**To make the alias permanent**, add this line to your `~/.bashrc`:
```bash
alias dotnet='/home/user/testbed/dotnet-with-proxy.sh'
```

### Option 3: Manual Proxy + Environment Variables

Start the proxy manually:
```bash
python3 nuget-proxy.py &
```

Then run dotnet with environment variables:
```bash
http_proxy=http://127.0.0.1:8888 \
https_proxy=http://127.0.0.1:8888 \
HTTP_PROXY=http://127.0.0.1:8888 \
HTTPS_PROXY=http://127.0.0.1:8888 \
dotnet build
```

## How It Works

The solution consists of two key files:

### 1. `nuget-proxy.py`
A Python HTTP/HTTPS proxy that:
- Listens on `localhost:8888`
- Accepts connections from NuGet without authentication
- Forwards requests to the Claude Code authenticated proxy
- Handles HTTPS CONNECT tunneling for secure connections

### 2. `NuGet.config`
Configures NuGet to use the local proxy (this is optional with the wrapper script)

## Files

- **`nuget-proxy.py`** - The proxy server implementation
- **`dotnet-with-proxy.sh`** - Wrapper script that auto-starts proxy and runs dotnet
- **`setup-dotnet-alias.sh`** - Creates a convenient alias for the current session
- **`NuGet.config`** - NuGet configuration file
- **`NUGET-PROXY-README.md`** - This file

## Managing the Proxy

### Check if proxy is running:
```bash
ps aux | grep nuget-proxy
```

### View proxy logs:
```bash
tail -f /tmp/nuget-proxy.log
```

### Stop the proxy:
```bash
kill $(cat /tmp/nuget-proxy.pid)
```

### Manually start proxy in foreground (for debugging):
```bash
python3 nuget-proxy.py
```

## Troubleshooting

### Build fails with proxy errors
1. Check if proxy is running: `ps aux | grep nuget-proxy`
2. Check logs: `cat /tmp/nuget-proxy.log`
3. Restart proxy: `pkill -f nuget-proxy.py && python3 nuget-proxy.py &`

### Proxy won't start
- Check if port 8888 is already in use: `lsof -i :8888`
- Check proxy environment variables are set: `env | grep proxy`

### NuGet can't find packages
- Ensure the proxy is running
- Verify network connectivity through the proxy
- Check that `api.nuget.org` is in the allowed hosts

## Why This is Needed

The Claude Code environment requires all external network access to go through an authenticated proxy. However, NuGet doesn't handle this proxy authentication properly, resulting in 401 errors when trying to restore packages.

This solution creates a local proxy that:
1. Accepts unauthenticated connections from NuGet
2. Adds the required authentication tokens
3. Forwards requests to the Claude Code proxy

This allows `dotnet` commands to work seamlessly in the Claude Code environment.

## Performance

The proxy adds minimal overhead:
- Local connection to 127.0.0.1 (microseconds)
- Single hop through the authenticated proxy
- Persistent connections maintained for efficiency

Typical package restore times are comparable to direct connections.
