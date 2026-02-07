---
name: nuget-proxy-verify
description: Verify NuGet proxy configuration is working correctly
---

# NuGet Proxy Verify Command

Tests and validates that the NuGet proxy solution is working correctly.

## What This Does

1. **Checks credential provider**: Verifies the C# plugin DLL exists in ~/.nuget/plugins/netcore/
2. **Checks proxy status**: Verifies the proxy daemon is running on port 8888
3. **Tests environment**: Validates HTTPS_PROXY and _NUGET_UPSTREAM_PROXY variables
4. **Tests package restore**: Attempts to restore packages from NuGet.org
5. **Checks authentication**: Validates proxy authentication is working end-to-end

## Usage

```
/nuget-proxy-verify
```

## Test Sequence

1. **Credential Provider Check**: Confirms nuget-plugin-proxy-auth.dll is installed
2. **Proxy Daemon Check**: Verifies port 8888 is accessible
3. **Environment Variables**: Checks HTTPS_PROXY points to localhost:8888
4. **Network Connectivity**: Tests connection to nuget.org through proxy
5. **Package Restore**: Runs a test restore operation

## Success Criteria

- Credential provider DLL exists in ~/.nuget/plugins/netcore/
- Proxy daemon running on port 8888
- HTTPS_PROXY set to http://127.0.0.1:8888
- Can connect to NuGet.org through proxy
- Package restore succeeds

## If Tests Fail

The command will provide specific error messages and recommendations:
- If plugin not installed: Run `source install-credential-provider.sh`
- If proxy not running: Run `dotnet <plugin-dll> --start`
- If authentication fails: Check _NUGET_UPSTREAM_PROXY and PROXY_AUTHORIZATION
- If port conflict: Check what's using port 8888 with `lsof -i :8888`
