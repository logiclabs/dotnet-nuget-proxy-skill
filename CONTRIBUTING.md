# Contributing to .NET NuGet Proxy Plugin

Thank you for your interest in contributing to this Claude Code plugin! This document provides guidelines and instructions for contributing.

## 🌟 Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Submit code changes
- ✅ Add tests
- 🎨 Improve user experience

## 🐛 Reporting Bugs

Before submitting a bug report:

1. **Check existing issues** to avoid duplicates
2. **Use the latest version** of the plugin
3. **Test in a clean environment** if possible

When submitting a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **Environment details**:
  - OS and version
  - .NET SDK version
  - Claude Code version (desktop or web)
- **Logs and error messages**:
  - Output from `dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --status`
  - Content of `/tmp/nuget-proxy.log`
  - Relevant console output
- **Screenshots** if applicable

## 💡 Suggesting Features

Feature suggestions are welcome! Please:

1. **Check existing feature requests** first
2. **Clearly describe the feature** and its benefits
3. **Explain the use case** with concrete examples
4. **Consider edge cases** and potential issues
5. **Discuss implementation** if you have ideas

## 🔧 Pull Request Process

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill.git
cd dotnet-nuget-proxy-skill
```

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 3. Make Changes

Follow the code style and structure:

#### Plugin Structure Rules

- **ONLY** `plugin.json` and `marketplace.json` go in `.claude-plugin/`
- Skills go in `skills/` directory
- Hooks go in `hooks/` directory
- C# credential provider source goes in `skills/nuget-proxy-troubleshooting/files/nuget-plugin-proxy-auth-src/`

#### Skill Guidelines

```markdown
---
name: skill-name-in-kebab-case
description: Clear description for Claude to understand when to use this skill
---

# Skill Title

Clear, concise instructions for what this skill does...
```

#### Code Style

**C#**:
- Single-file implementation in `Program.cs`
- Use nullable reference types (`#nullable enable`)
- Handle errors gracefully with try/catch
- Log to stderr via `Console.Error.WriteLine`

**Bash**:
- Use clear variable names
- Quote all paths that might contain spaces
- Check command exit codes
- Provide helpful error messages

**Markdown**:
- Use consistent heading levels
- Keep lines under 120 characters when possible
- Use code blocks with language identifiers

### 4. Test Your Changes

#### Test in Claude Code

```bash
# Run the plugin structure verification
bash verify-plugin.sh

# Test the credential provider compiles
cd skills/nuget-proxy-troubleshooting/files/nuget-plugin-proxy-auth-src
dotnet build

# Test the install script (in a proxy environment)
source skills/nuget-proxy-troubleshooting/files/install-credential-provider.sh
dotnet restore
```

#### Test Checklist

- [ ] Skills load without errors
- [ ] Hooks trigger at appropriate times
- [ ] Credential provider compiles cleanly
- [ ] Proxy starts successfully
- [ ] `dotnet restore` works through proxy
- [ ] `verify-plugin.sh` passes all checks
- [ ] Documentation is accurate
- [ ] No broken links in README
- [ ] CHANGELOG.md is updated

#### Test Environments

Test on at least one of:
- Ubuntu/Linux (primary target for Claude Code web)
- macOS
- Windows

With:
- .NET 8.0 or later

### 5. Commit Your Changes

Use clear, descriptive commit messages:

```bash
# Good commit messages:
git commit -m "Add: Support for custom proxy ports"
git commit -m "Fix: Proxy detection failing on macOS"
git commit -m "Docs: Add troubleshooting for port conflicts"
git commit -m "Refactor: Simplify proxy startup logic"

# Message format:
# <type>: <description>
#
# Types: Add, Fix, Update, Docs, Refactor, Test, Chore
```

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub with:

- **Clear title** summarizing the change
- **Description** explaining what and why
- **Reference to issues** if applicable (e.g., "Fixes #123")
- **Test results** or screenshots
- **Breaking changes** if any

## 📝 Documentation

When adding features or changing behavior:

1. Update `README.md` if user-facing
2. Update skill documentation in `skills/*/SKILL.md`
3. Update `CHANGELOG.md` in the [Unreleased] section
4. Add comments to complex code
5. Include examples where helpful

## 🧪 Testing Guidelines

### Manual Testing

1. **Clean environment test**:
   ```bash
   # Remove existing credential provider
   rm -rf ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth

   # Test install
   source skills/nuget-proxy-troubleshooting/files/install-credential-provider.sh

   # Verify proxy is running
   dotnet ~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll --status
   ```

2. **Proxy restart test**:
   ```bash
   PLUGIN_DLL=~/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll

   # Stop proxy
   dotnet $PLUGIN_DLL --stop

   # Restart proxy
   dotnet $PLUGIN_DLL --start
   ```

3. **Real project test**:
   ```bash
   # In a .NET project
   dotnet restore
   dotnet build
   ```

### Automated Testing (Future)

We welcome contributions to add automated tests:
- Unit tests for the C# credential provider
- Integration tests for the install script
- End-to-end tests for full workflow

## 🎨 Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive experience for everyone.

### Our Standards

**Positive behavior**:
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what's best for the community
- Showing empathy towards other community members

**Unacceptable behavior**:
- Trolling, insulting, or derogatory comments
- Public or private harassment
- Publishing others' private information
- Other conduct which could be considered inappropriate

## 📋 Development Setup

### Prerequisites

```bash
# Install .NET SDK (8.0 or later)
dotnet --version

# Install Claude Code
# (follow Claude Code installation instructions)
```

### Local Development

```bash
# Clone your fork
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill.git
cd dotnet-nuget-proxy-skill

# Verify plugin structure
bash verify-plugin.sh

# Build the credential provider
dotnet build skills/nuget-proxy-troubleshooting/files/nuget-plugin-proxy-auth-src/
```

## 🔍 Code Review Process

1. **Automated checks** (if configured): Linting, formatting
2. **Manual review** by maintainers
3. **Testing** in Claude Code environment
4. **Feedback** and requested changes
5. **Approval** and merge

## 📢 Questions?

- Open an issue with the "question" label
- Start a discussion on GitHub Discussions
- Check existing documentation and issues first

## 🎉 Recognition

Contributors will be:
- Listed in release notes
- Mentioned in CHANGELOG.md
- Appreciated in the community!

---

Thank you for contributing to the .NET NuGet Proxy Plugin! 🙏
