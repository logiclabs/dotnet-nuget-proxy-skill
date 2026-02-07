---
name: nuget-proxy-debug
description: Diagnose NuGet proxy configuration and identify issues
---

# NuGet Proxy Debug Command

Comprehensive diagnostic tool for NuGet proxy configuration issues.

## What This Does

1. **Checks environment variables**: Examines HTTP_PROXY, HTTPS_PROXY, _NUGET_UPSTREAM_PROXY, and authentication settings
2. **Checks credential provider**: Verifies the C# plugin is compiled and installed
3. **Tests proxy status**: Determines if the proxy daemon is running on port 8888
4. **Tests connectivity**: Verifies connection to NuGet sources through the proxy
5. **Reviews logs**: Examines proxy logs for errors
6. **Generates report**: Provides detailed diagnostic report with recommendations

## Usage

```
/nuget-proxy-debug
```

## Output Includes

- Credential provider installation status (DLL in ~/.nuget/plugins/netcore/)
- Proxy daemon status (running/stopped, PID)
- Environment variable values (HTTPS_PROXY, _NUGET_UPSTREAM_PROXY)
- Network connectivity test results
- Error messages from /tmp/nuget-proxy.log
- Recommendations for fixes

## Common Issues Detected

- Credential provider not compiled/installed
- Proxy daemon not running on port 8888
- Missing or incorrect HTTPS_PROXY / _NUGET_UPSTREAM_PROXY variables
- Proxy authentication failures (upstream 401)
- Port conflicts

## Follow-Up Actions

After diagnosis, you'll receive specific recommendations such as:
- Run `source install-credential-provider.sh` to set up the solution
- Run `dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --start` to start the proxy
- Run `/nuget-proxy-verify` to test the configuration
