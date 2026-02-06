---
name: nuget-proxy-debug
description: Diagnose NuGet proxy configuration and identify issues
---

# NuGet Proxy Debug Command

Comprehensive diagnostic tool for NuGet proxy configuration issues.

## What This Does

1. **Checks environment variables**: Examines HTTP_PROXY, HTTPS_PROXY, and authentication settings
2. **Analyzes NuGet.config**: Reviews NuGet configuration files for proxy settings
3. **Tests connectivity**: Verifies connection to NuGet sources and proxy servers
4. **Checks proxy status**: Determines if the custom proxy bridge is running
5. **Reviews logs**: Examines proxy logs for errors or issues
6. **Generates report**: Provides detailed diagnostic report with recommendations

## Usage

```
/nuget-proxy-debug
```

## Output Includes

- Current proxy configuration status
- Environment variable values
- NuGet.config file locations and contents
- Proxy process status (running/stopped)
- Network connectivity test results
- Error messages from logs
- Recommendations for fixes

## Common Issues Detected

- Missing HTTP_PROXY/HTTPS_PROXY variables
- Proxy not running on port 8888
- NuGet.config misconfiguration
- Proxy authentication failures
- Port conflicts
- SSL/TLS certificate errors

## Follow-Up Actions

After diagnosis, you'll receive specific recommendations such as:
- Run `/nuget-proxy-fix` to set up the proxy solution
- Run `/nuget-proxy-verify` to test the configuration
- Restart the proxy with `python3 nuget-proxy.py &`
- Update NuGet.config with correct settings
