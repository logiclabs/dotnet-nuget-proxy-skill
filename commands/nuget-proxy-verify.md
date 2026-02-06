---
name: nuget-proxy-verify
description: Verify NuGet proxy configuration is working correctly
---

# NuGet Proxy Verify Command

Tests and validates that the NuGet proxy solution is working correctly.

## What This Does

1. **Checks proxy status**: Verifies the proxy is running on port 8888
2. **Tests environment**: Validates HTTP_PROXY and HTTPS_PROXY variables
3. **Verifies NuGet.config**: Confirms configuration is correct
4. **Tests package restore**: Attempts to restore packages from NuGet.org
5. **Checks authentication**: Validates proxy authentication is working
6. **Measures performance**: Records response times and connection metrics

## Usage

```
/nuget-proxy-verify
```

## Test Sequence

1. **Proxy Process Check**: Confirms nuget-proxy.py is running
2. **Port Availability**: Verifies port 8888 is accessible
3. **Environment Variables**: Checks proxy variables are set
4. **NuGet Configuration**: Validates NuGet.config syntax and proxy settings
5. **Network Connectivity**: Tests connection to nuget.org through proxy
6. **Package Search**: Attempts to search for a known package
7. **Package Restore**: Runs a test restore operation

## Success Criteria

✅ Proxy running on port 8888
✅ Environment variables configured
✅ NuGet.config exists and valid
✅ Can connect to NuGet.org through proxy
✅ Package search succeeds
✅ Package restore succeeds

## If Tests Fail

The command will provide specific error messages and recommendations:
- If proxy not running: Start with `python3 nuget-proxy.py &`
- If config missing: Run `/nuget-proxy-fix` to create it
- If authentication fails: Check PROXY_AUTHORIZATION environment variable
- If port conflict: Check what's using port 8888 with `lsof -i :8888`

## Performance Metrics

Reports include:
- Proxy response time
- Package download speed
- Connection establishment time
- Overall restore duration
