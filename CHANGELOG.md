# Changelog

All notable changes to the .NET NuGet Proxy Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-06

### Added

#### Core Functionality
- Initial release of .NET NuGet Proxy Plugin
- Custom Python proxy bridge (nuget-proxy.py) for JWT authentication
- Auto-starting wrapper script (dotnet-with-proxy.sh) for seamless dotnet commands
- NuGet.config automatic configuration
- Cross-platform support (Windows, macOS, Linux)

#### Skills
- **nuget-proxy-troubleshooting**: Comprehensive skill with 8KB of troubleshooting knowledge
  - Problem diagnosis and solution architecture
  - Quick start guide for new sessions
  - Troubleshooting for 7+ common issues
  - File recreation instructions
  - Best practices and alternative approaches

#### Slash Commands
- `/nuget-proxy-debug` - Comprehensive diagnostics for proxy configuration
- `/nuget-proxy-fix` - One-command setup of complete proxy solution
- `/nuget-proxy-verify` - Validation testing with real NuGet operations

#### Hooks
- **pre-dotnet-restore.sh**: Pre-execution hook that checks proxy configuration
  - Warns when HTTP_PROXY/HTTPS_PROXY not set
  - Alerts when proxy process not running
  - Checks for NuGet.config file
  - Provides actionable tips for fixes

#### Supporting Files
- **nuget-proxy.py** (6.8KB): Python proxy implementation
  - HTTP/HTTPS CONNECT tunneling
  - JWT authentication handling
  - Logging and error handling
- **dotnet-with-proxy.sh** (2.6KB): Wrapper script with auto-start
- **setup-dotnet-alias.sh** (633B): Alias creation helper
- **NuGet.config** (345B): Pre-configured for local proxy
- **NUGET-PROXY-README.md** (3.6KB): Detailed proxy documentation

#### Documentation
- Comprehensive README.md with installation and usage
- Quick start guide
- Troubleshooting section
- Architecture diagrams
- Pro tips and best practices

#### Features
- Automatic backup creation before modifications
- Timestamped backup files
- Real-time proxy status detection
- Environment variable validation
- Network connectivity testing
- Detailed error reporting
- AI-powered assistance through Claude Code

### Technical Details

#### Plugin Structure
- Proper plugin architecture with `.claude-plugin/plugin.json`
- Skills organized in `skills/` directory
- Commands in `commands/` directory
- Hooks in `hooks/` directory
- Clean separation of concerns

#### Requirements
- Python 3.x for proxy bridge
- .NET SDK (any version)
- Claude Code environment

#### Performance
- Proxy starts in < 2 seconds
- Minimal overhead on package operations
- Efficient process detection
- Cached proxy keeps running between commands

### Security
- Proxy authentication via environment variables
- No credential storage in files
- Secure JWT token handling
- Localhost-only proxy binding (127.0.0.1)

### Known Limitations
- Proxy runs on fixed port 8888 (configurable in future versions)
- Requires Python 3.x to be installed
- Designed specifically for JWT-authenticated proxy environments

---

## [Unreleased]

### Planned Features
- Support for custom proxy ports
- Configuration file for proxy settings
- Enhanced logging with rotation
- Integration with dotnet global tools
- Support for private NuGet feeds
- Windows service installation option
- macOS launchd integration
- Linux systemd service file
- Multi-proxy support for complex networks

### Potential Improvements
- Performance metrics dashboard
- Automatic proxy health checks
- Self-healing capabilities
- Better error recovery
- Integration with CI/CD pipelines

---

## Release Notes

### 1.0.0 - Initial Release

This is the first production-ready release of the .NET NuGet Proxy Plugin. It provides a complete solution for .NET developers working in proxy-authenticated environments, particularly Claude Code containerized environments.

The plugin has been tested with:
- .NET 8.0 and .NET 10.0
- NuGet protocol version 3
- Ubuntu 24.04 LTS
- Claude Code web environment

**Installation**: See [README.md](README.md) for installation instructions.

**Feedback**: Please report issues on [GitHub Issues](https://github.com/logiclabs/dotnet-nuget-proxy-skill/issues).

---

[1.0.0]: https://github.com/logiclabs/dotnet-nuget-proxy-skill/releases/tag/v1.0.0
[Unreleased]: https://github.com/logiclabs/dotnet-nuget-proxy-skill/compare/v1.0.0...HEAD
