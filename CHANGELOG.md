# Changelog

All notable changes to the .NET NuGet Proxy Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Fast-path startup**: When SDK, plugin, and proxy are already configured, the
  SessionStart hook skips all setup and persists env in under a second.
- **Quiet output by default**: Startup scripts suppress apt/dpkg/dotnet noise.
  Set `NUGET_PROXY_VERBOSE=true` for detailed output during setup.
- **Scoped proxy**: `dotnet()` shell function routes only dotnet traffic through the
  local proxy. Global `HTTPS_PROXY` / `HTTP_PROXY` are no longer overwritten, so other
  tools (curl, apt, pip) continue to use the upstream proxy unchanged.
- **SessionStart hook config** updated to match the documented Claude Code web pattern
  (`"matcher": "startup"`, direct script path, `CLAUDE_CODE_REMOTE` check inside script).

### Fixed
- Resource leaks in proxy server (TcpClient/NetworkStream now use `using` statements)
- Case-insensitive `Proxy-Authorization` header check (per HTTP RFC 7230)
- HTTP status code parsing (exact match on status code field, not substring search)
- Header injection scoped to headers only (previously could match body content)
- Missing `Flush()` after critical protocol writes
- `install-credential-provider.sh` uses `return 1` instead of `exit 1` (safe when sourced)
- Glob patterns use `grep --include` instead of `**/*.ext` (globstar not enabled by default)
- Release workflow path updated from deleted `plugins/` directory to root `skills/`
- Stale references to Python proxy and slash commands removed from CONTRIBUTING.md

## [1.0.0] - 2026-02-06

### Added
- **C# NuGet Credential Provider** — self-contained .NET plugin
  - Compiles to a .NET DLL in `~/.nuget/plugins/netcore/` for NuGet auto-discovery
  - Embeds HTTP/HTTPS proxy server with JWT auth injection
  - Manages proxy lifecycle as a background daemon (start/stop/health check)
  - Implements NuGet cross-platform plugin protocol v2
  - No wrapper scripts or NuGet.Config changes needed after install
- **install-credential-provider.sh** — one-command setup: compiles, installs, configures
- **SessionStart hook** (`hooks/session-start.sh`) — automatic .NET SDK install and proxy setup
- **Pre-restore hook** (`hooks/pre-dotnet-restore.sh`) — validates proxy before dotnet restore
- **WHY-PROXY-BRIDGE-NEEDED.md** — technical analysis of .NET SocketsHttpHandler proxy auth gap
- **nuget-proxy-troubleshooting** skill with comprehensive troubleshooting guide
- Plugin structure with `.claude-plugin/plugin.json` and `marketplace.json`
- `verify-plugin.sh` for plugin structure validation

### Planned Features
- Support for custom proxy ports
- Support for private NuGet feeds

---

[Unreleased]: https://github.com/logiclabs/dotnet-nuget-proxy-skill/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/logiclabs/dotnet-nuget-proxy-skill/releases/tag/v1.0.0
