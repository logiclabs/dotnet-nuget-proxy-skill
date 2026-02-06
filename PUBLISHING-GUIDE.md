# Publishing Guide for .NET NuGet Proxy Plugin

This guide provides step-by-step instructions for publishing this Claude Code plugin to GitHub.

## ✅ Pre-Publication Checklist

- [x] Plugin structure correct (`.claude-plugin/plugin.json` only in that directory)
- [x] All skills have proper frontmatter
- [x] All commands have proper frontmatter
- [x] README.md complete with installation instructions
- [x] CHANGELOG.md documents version 1.0.0
- [x] LICENSE file included (MIT)
- [x] CONTRIBUTING.md with guidelines
- [x] .gitignore configured
- [x] Git repository initialized
- [x] Initial commit created
- [x] Version tag v1.0.0 created
- [x] plugin.json is valid JSON

## 📋 Current State

The plugin is **ready for publication**! All files are committed and tagged as v1.0.0.

Location: `~/dotnet-nuget-proxy-skill/`

## 🚀 Publishing Steps

### Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository settings:
   - **Name**: `dotnet-nuget-proxy-skill`
   - **Description**: "Claude Code plugin for fixing .NET NuGet proxy authentication issues"
   - **Visibility**: Public
   - **Initialize**: Do NOT check any boxes (we have everything already)
3. Click "Create repository"

### Step 2: Update URLs in Files

Before pushing, update placeholder URLs with your actual GitHub username:

```bash
cd ~/dotnet-nuget-proxy-skill

# Replace logiclabs with your actual GitHub username
GITHUB_USER="your-actual-username"

# Update plugin.json
sed -i "s/logiclabs/$GITHUB_USER/g" .claude-plugin/plugin.json

# Update README.md
sed -i "s/logiclabs/$GITHUB_USER/g" README.md

# Update CHANGELOG.md
sed -i "s/logiclabs/$GITHUB_USER/g" CHANGELOG.md

# Commit the changes
git add .
git commit -m "Update: Replace placeholder URLs with actual GitHub username"
```

### Step 3: Push to GitHub

```bash
cd ~/dotnet-nuget-proxy-skill

# Add GitHub as remote (replace logiclabs)
git remote add origin https://github.com/logiclabs/dotnet-nuget-proxy-skill.git

# Push code and tags
git push -u origin main
git push origin v1.0.0
```

### Step 4: Create GitHub Release

1. Go to your repository on GitHub
2. Click "Releases" → "Create a new release"
3. **Tag**: Select `v1.0.0`
4. **Release title**: "v1.0.0 - Initial Release"
5. **Description**:

```markdown
# .NET NuGet Proxy Plugin v1.0.0

First production-ready release of the Claude Code plugin for fixing .NET NuGet proxy authentication issues.

## 🎯 What This Solves

Fixes 401 authentication errors when running `dotnet restore` in proxy-authenticated environments, particularly Claude Code containerized environments where NuGet cannot authenticate with JWT-based proxies.

## ✨ Features

- 🔍 **Automatic Diagnostics**: `/nuget-proxy-debug` command
- 🔧 **One-Command Fix**: `/nuget-proxy-fix` sets up complete solution
- ✅ **Verification Testing**: `/nuget-proxy-verify` validates configuration
- 🤖 **AI-Powered Help**: Claude understands proxy issues automatically
- ⚡ **Auto-Starting Proxy**: Wrapper script manages proxy lifecycle
- 🌍 **Cross-Platform**: Windows, macOS, and Linux

## 📦 Installation

```bash
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill ~/.claude/plugins/dotnet-nuget-proxy
```

Then restart Claude Code.

## 🚀 Quick Start

1. `/nuget-proxy-debug` - Diagnose issues
2. `/nuget-proxy-fix` - Auto-fix configuration
3. `/nuget-proxy-verify` - Verify it works

## 📚 Documentation

- [README](README.md) - Complete documentation
- [CHANGELOG](CHANGELOG.md) - Version history
- [CONTRIBUTING](CONTRIBUTING.md) - Contribution guidelines

## 🙏 Acknowledgments

Built for the Claude Code community to solve real-world .NET development challenges.

---

If this helps you, please ⭐ star the repository!
```

6. Click "Publish release"

### Step 5: Test Installation

Test that others can install your plugin:

```bash
# Fresh install in a test location
mkdir -p ~/.claude/plugins
cd ~/.claude/plugins
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill dotnet-nuget-proxy

# Verify structure
ls -la dotnet-nuget-proxy/.claude-plugin/plugin.json

# Start Claude Code and test commands
# /nuget-proxy-debug
# /nuget-proxy-fix
# /nuget-proxy-verify
```

### Step 6: Share with Community

#### GitHub Topics

Add relevant topics to your repository:
- `claude-code`
- `claude-plugin`
- `dotnet`
- `nuget`
- `proxy`
- `troubleshooting`
- `developer-tools`

#### Social Media

Share on:
- Twitter/X
- LinkedIn
- Dev.to
- Reddit (r/dotnet, r/programming)
- Hacker News

#### Sample Announcement

```markdown
🚀 Just published a Claude Code plugin for .NET developers!

If you've struggled with NuGet proxy authentication errors (401) in
containerized or corporate proxy environments, this plugin provides:

✅ Automatic diagnostics
✅ One-command setup
✅ Custom proxy bridge solution
✅ AI-powered troubleshooting

Installation:
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill ~/.claude/plugins/dotnet-nuget-proxy

Feedback welcome! ⭐

#ClaudeCode #DotNet #NuGet #DevTools
```

## 📊 Post-Publication

### Monitor

- GitHub Issues for bug reports
- GitHub Discussions for questions
- Pull Requests for contributions
- Stars and forks for popularity

### Maintenance

- Respond to issues within 48 hours
- Review pull requests within a week
- Update CHANGELOG.md for all releases
- Test with new .NET versions
- Keep dependencies updated

### Future Releases

When making updates:

1. Update version in `.claude-plugin/plugin.json`
2. Document changes in CHANGELOG.md
3. Commit changes
4. Create new tag: `git tag -a v1.1.0 -m "Version 1.1.0"`
5. Push: `git push origin main --tags`
6. Create new GitHub release

## 🎉 Success Metrics

Track:
- ⭐ GitHub stars
- 🍴 Forks
- 👥 Contributors
- 📝 Issue reports (indicates usage)
- 🔀 Pull requests
- 📥 Clone/download counts

## 🆘 Need Help?

If you encounter issues during publication:

1. Check GitHub's documentation
2. Validate JSON with `python3 -m json.tool < .claude-plugin/plugin.json`
3. Test plugin locally first
4. Ask in Claude Code community

## ✅ Verification Commands

Run these to verify everything is ready:

```bash
cd ~/dotnet-nuget-proxy-skill

# Check git status
git status

# Check tags
git tag

# Verify file count
find . -type f | grep -v .git | wc -l
# Should show: 16 files

# Verify plugin.json is valid
cat .claude-plugin/plugin.json | python3 -m json.tool > /dev/null && echo "✅ Valid JSON"

# Check for placeholder URLs
grep -r "logiclabs" . --exclude-dir=.git && echo "⚠️ Found placeholders" || echo "✅ No placeholders"

# Verify structure
[ -f .claude-plugin/plugin.json ] && echo "✅ Plugin manifest exists"
[ -d skills ] && echo "✅ Skills directory exists"
[ -d commands ] && echo "✅ Commands directory exists"
[ -d hooks ] && echo "✅ Hooks directory exists"
```

---

**Ready to publish?** Follow steps 1-6 above and share with the community! 🚀
