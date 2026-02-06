# .NET NuGet Proxy Plugin for Claude Code

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/logiclabs/dotnet-nuget-proxy-skill/releases)

A comprehensive Claude Code plugin that diagnoses and fixes .NET NuGet proxy authentication issues in containerized and proxy-authenticated environments.

## 🎯 Problem Solved

In containerized Claude Code environments with JWT-authenticated proxies, NuGet package restoration fails with 401 authentication errors because NuGet doesn't support the required authentication method. This plugin provides:

- **Custom Python proxy bridge** that handles authentication transparently
- **Auto-starting wrapper scripts** for seamless dotnet command execution
- **Comprehensive diagnostics** to identify proxy configuration issues
- **Automated setup** with backup and validation
- **Complete troubleshooting guide** built into AI assistance

## ✨ Features

- 🔍 **Automatic Diagnostics**: Analyzes environment variables, NuGet.config, and network connectivity
- 🔧 **One-Command Fix**: Sets up complete proxy solution with all necessary files
- ✅ **Verification Testing**: Validates configuration with real NuGet operations
- 💾 **Backup Management**: Creates timestamped backups before modifications
- 🌍 **Cross-Platform**: Supports Windows, macOS, and Linux
- 🤖 **AI-Powered Help**: Claude understands and troubleshoots proxy issues automatically
- ⚡ **Auto-Starting Proxy**: Wrapper script manages proxy lifecycle automatically

## 📦 Installation

### Claude Code (Desktop CLI)

Add the marketplace and install the plugin:

```
/plugin marketplace add logiclabs/dotnet-nuget-proxy-skill
/plugin install dotnet-nuget-proxy@dotnet-nuget-proxy
```

### Claude Code on the Web

1. Open Claude Code in your browser
2. Run `/plugin marketplace add logiclabs/dotnet-nuget-proxy-skill`
3. Run `/plugin install dotnet-nuget-proxy@dotnet-nuget-proxy`

The plugin will be available immediately in your session. It persists across sessions once installed.

### Manual Installation

```bash
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill ~/.claude/plugins/dotnet-nuget-proxy
```

Then restart Claude Code to load the plugin.

## 🚀 Quick Start

### 1. Diagnose Current Setup

```
/nuget-proxy-debug
```

Claude will analyze your environment and identify any proxy configuration issues.

### 2. Auto-Fix Configuration

```
/nuget-proxy-fix
```

This automatically:
- Creates the custom Python proxy bridge (nuget-proxy.py)
- Sets up auto-starting wrapper script (dotnet-with-proxy.sh)
- Configures NuGet.config to use local proxy
- Creates helper scripts and documentation
- Backs up existing configurations

### 3. Verify Everything Works

```
/nuget-proxy-verify
```

Tests the proxy configuration with real NuGet operations and confirms everything is working.

## 📚 Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/nuget-proxy-debug` | Run comprehensive diagnostics on proxy configuration |
| `/nuget-proxy-fix` | Automatically set up the proxy solution |
| `/nuget-proxy-verify` | Test and validate proxy configuration |

### Natural Language

You can also just ask Claude naturally:

- "I'm getting 401 errors when running dotnet restore"
- "Help me fix NuGet proxy authentication"
- "Set up NuGet to work with the proxy"
- "Why is my package restore failing?"

Claude will automatically use the plugin skills to help troubleshoot and fix issues.

### Using the Wrapper Script

After running `/nuget-proxy-fix`, use the wrapper script for all dotnet commands:

```bash
# The wrapper auto-starts the proxy if needed
./dotnet-with-proxy.sh restore
./dotnet-with-proxy.sh build
./dotnet-with-proxy.sh run
./dotnet-with-proxy.sh test

# Or create an alias
source setup-dotnet-alias.sh
dotnet restore  # Now uses proxy automatically
```

## 🏗️ How It Works

### Architecture

```
NuGet CLI → localhost:8888 → Custom Python Proxy → Authenticated Proxy → nuget.org
            (no auth)         (adds JWT auth)       (Claude Code)      (internet)
```

### Components Created

1. **nuget-proxy.py**: Python HTTP/HTTPS proxy that:
   - Listens on localhost:8888 (unauthenticated)
   - Forwards to Claude Code proxy with JWT authentication
   - Handles HTTPS CONNECT tunneling

2. **dotnet-with-proxy.sh**: Wrapper script that:
   - Detects if proxy is running
   - Auto-starts proxy if needed
   - Sets HTTP_PROXY/HTTPS_PROXY environment variables
   - Runs dotnet commands seamlessly

3. **NuGet.config**: Configuration file pointing to localhost:8888

4. **NUGET-PROXY-README.md**: Complete documentation and troubleshooting guide

## 🛠️ Plugin Skills

The plugin includes the following skills that Claude uses automatically:

### `/dotnet-nuget-proxy:nuget-proxy-troubleshooting`

Comprehensive skill that provides:
- Problem diagnosis and understanding
- Solution architecture documentation
- Quick start instructions
- Troubleshooting for common issues
- File recreation steps
- Best practices

## 🔧 Configuration

### Environment Variables

The solution uses these environment variables (automatically set by Claude Code):
- `HTTP_PROXY` - Used by Python proxy to connect upstream
- `HTTPS_PROXY` - Same as HTTP_PROXY
- `PROXY_AUTHORIZATION` - JWT token for authentication

### NuGet.config Locations

The plugin works with standard NuGet.config locations:
- **User-level**: `%APPDATA%\NuGet\NuGet.config` (Windows) or `~/.nuget/NuGet/NuGet.config` (Unix)
- **Project-level**: `./NuGet.config`
- **Solution-level**: `./NuGet.config` (at solution root)

## 🐛 Troubleshooting

### Common Issues

#### "Connection refused on port 8888"

**Solution**: Start the proxy
```bash
python3 nuget-proxy.py &
# or use wrapper script
./dotnet-with-proxy.sh restore
```

#### "Address already in use"

**Solution**: Check what's using port 8888
```bash
ps aux | grep nuget-proxy
# If it's the proxy, you're good!
```

#### Still getting 401 errors

**Solution**: Run diagnostics
```
/nuget-proxy-debug
```

This will identify the specific issue and provide targeted recommendations.

### Getting Help

1. **With Claude**: Simply describe the issue naturally
2. **Slash Commands**: Use `/nuget-proxy-debug` for detailed diagnostics
3. **GitHub Issues**: [Report issues here](https://github.com/logiclabs/dotnet-nuget-proxy-skill/issues)

## 📋 Requirements

- **Python 3.x** (for proxy bridge)
- **.NET SDK** (any version)
- **Claude Code** environment with proxy authentication

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes in Claude Code
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for the Claude Code community
- Addresses proxy authentication challenges in containerized environments
- Inspired by real-world .NET development challenges

## 📖 Documentation

- [Quick Start Guide](plugins/dotnet-nuget-proxy/skills/nuget-proxy-troubleshooting/SKILL.md)
- [Detailed Proxy Documentation](plugins/dotnet-nuget-proxy/skills/nuget-proxy-troubleshooting/files/NUGET-PROXY-README.md)
- [Changelog](CHANGELOG.md)

## 🔗 Links

- [GitHub Repository](https://github.com/logiclabs/dotnet-nuget-proxy-skill)
- [Issue Tracker](https://github.com/logiclabs/dotnet-nuget-proxy-skill/issues)
- [Claude Code Documentation](https://code.claude.com/docs)

## 💡 Pro Tips

1. **Keep proxy running** - The wrapper script handles this automatically
2. **Use wrapper script** - Always prefer `./dotnet-with-proxy.sh` over direct dotnet commands
3. **Check logs** - When issues occur, check `/tmp/nuget-proxy.log` first
4. **Commit proxy files** - Add them to your repository so teammates benefit too
5. **Run verify after setup** - Always run `/nuget-proxy-verify` to confirm everything works

---

**Made with ❤️ for the Claude Code community**

If this plugin helps you, please ⭐ star the repository!
