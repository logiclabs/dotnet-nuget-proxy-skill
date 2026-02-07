# Why a Local Proxy Bridge is Needed for NuGet

## The Problem

NuGet package restore fails with 401 errors when behind an authenticated HTTP proxy
(e.g., Claude Code's JWT-authenticated proxy). NuGet and .NET do not properly pass
proxy credentials during HTTPS CONNECT tunnel setup.

## Root Cause Analysis

The problem spans **two layers**:

### Layer 1: .NET Runtime (`SocketsHttpHandler`)

.NET's `HttpClient` / `SocketsHttpHandler` does NOT send `Proxy-Authorization` on
the initial `CONNECT` request. Instead, it sends an unauthenticated CONNECT, waits
for a 407 response, then retries with credentials. Many proxies (including Claude
Code's JWT proxy) reject immediately on the first 401 without giving the client a
chance to retry.

**Key GitHub issues (as of Feb 2026):**

- [dotnet/runtime #66244](https://github.com/dotnet/runtime/issues/66244)
  "Extra round trip due to 407 proxy authentication when using proxy with basic auth"
  Status: **Open**, milestone "Future". No fix merged.

- [dotnet/runtime #114066](https://github.com/dotnet/runtime/issues/114066)
  "Proxy CONNECT fails (407) on Linux; no Proxy-Authorization header sent"
  Status: **Closed without fix** (inactivity, May 2025). Network traces confirmed
  no Proxy-Authorization on CONNECT. Works on Windows but not Linux.

- [dotnet/runtime #100515](https://github.com/dotnet/runtime/issues/100515)
  "HttpClient without initial proxy auth limits capability"
  Status: **Closed**, milestoned .NET 9.0.0. Despite being closed as "completed",
  the actual fix (PR #101053) only addressed **stale credential caching** for
  server auth (`PreAuthenticate`), NOT proxy CONNECT pre-authentication.
  **`PreAuthenticateProxy` was never implemented** - the property does not exist
  on `SocketsHttpHandler` in any .NET version (verified against main branch).
  The only proxy-related properties are: `UseProxy`, `Proxy`, `DefaultProxyCredentials`.

### Layer 2: NuGet Client

NuGet delegates all HTTP transport to .NET's `HttpClient`. It has no mechanism to:
- Read a `PROXY_AUTHORIZATION` environment variable
- Inject custom headers on CONNECT requests
- Invoke credential provider plugins for proxy 407 responses (only for source 401s)

NuGet **does** read `http_proxy.user`/`http_proxy.password` from NuGet.Config and
creates a `WebProxy` with `NetworkCredential`, but the actual header injection is
handled by .NET's `SocketsHttpHandler` (Layer 1), which fails as described above.

The NuGet team labels proxy auth issues as `Resolution:BlockedByExternal`:
- [NuGet/Home #6978](https://github.com/NuGet/Home/issues/6978) - "dotnet restore
  with HTTP_PROXY broken again" - Closed as blocked by runtime.

## What Would Need to Change (for the proxy bridge to become unnecessary)

### Option A: .NET Runtime Adds Proxy Pre-Authentication

`SocketsHttpHandler` would need a `PreAuthenticateProxy` property (or similar)
that sends `Proxy-Authorization` on the INITIAL CONNECT request without requiring
a 407 round-trip.

**Status (Feb 2026): NOT IMPLEMENTED.** Despite issue #100515 being closed as
"completed" for .NET 9, the actual fix (PR #101053) only addressed stale credential
caching for server auth. `PreAuthenticateProxy` does not exist on `SocketsHttpHandler`
in any .NET version including the current main branch. The proxy-related properties
remain limited to `UseProxy`, `Proxy`, and `DefaultProxyCredentials`.

Issue [dotnet/runtime #66244](https://github.com/dotnet/runtime/issues/66244)
(the actual pre-auth request) remains **Open** with milestone "Future".

### Option B: NuGet Reads `PROXY_AUTHORIZATION` Environment Variable

NuGet would need to:
1. Check for `PROXY_AUTHORIZATION` env var
2. Create a custom `HttpMessageHandler` that injects `Proxy-Authorization` header
   on CONNECT requests
3. This would bypass the `SocketsHttpHandler` limitation

**Likelihood: Very low.** No issue or feature request exists for this. The NuGet
team considers proxy auth to be a runtime responsibility.

### Option C: NuGet Invokes Credential Providers for Proxy 407

NuGet's plugin protocol v2 would need to:
1. Catch 407 Proxy Authentication Required responses
2. Invoke credential provider plugins (currently only invoked for 401 from sources)
3. Retry the request with proxy credentials from the plugin

**Likelihood: Low.** The NuGet team has not expressed interest in this approach.

### Option D: NuGet Properly Passes `WebProxy.Credentials` to CONNECT

This is essentially Option A but could be done at the NuGet level by implementing
a custom `HttpMessageHandler` that pre-authenticates with the proxy, rather than
waiting for the runtime to fix `SocketsHttpHandler`.

**Likelihood: Low.** NuGet prefers to use stock `HttpClient` behavior.

## Current Workaround: Local Proxy Bridge

A local proxy on `localhost:8888` (no auth required) that forwards requests to the
upstream proxy with JWT credentials injected into the CONNECT request headers.

```
NuGet → localhost:8888 (no auth) → Upstream Proxy (JWT injected) → nuget.org
```

Implemented as a C# NuGet credential provider plugin that:
- Compiles to a .NET DLL in `~/.nuget/plugins/netcore/` for auto-discovery
- Embeds the proxy server
- Manages proxy lifecycle as a daemon
- Handles the NuGet plugin protocol v2

## Monitoring

Periodically check these issues for resolution:
- [ ] [dotnet/runtime #66244](https://github.com/dotnet/runtime/issues/66244) - Pre-auth for proxy (the key issue, still Open/Future)
- [ ] [dotnet/runtime #114066](https://github.com/dotnet/runtime/issues/114066) - Linux CONNECT failure (closed without fix)

Note: [dotnet/runtime #100515](https://github.com/dotnet/runtime/issues/100515)
was misleadingly closed as "completed" for .NET 9 but the fix (PR #101053) only
addressed server credential caching, not proxy pre-authentication.
