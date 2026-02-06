# Quick Setup Guide for dotnet-nuget-proxy-skill

Your repository is named: **dotnet-nuget-proxy-skill**

## ✅ Current Status

- ✓ Plugin structure complete and verified
- ✓ Git repository initialized with v1.0.0 tag
- ✓ All files updated to use "dotnet-nuget-proxy-skill" name
- ⚠ Need to replace logiclabs with your actual GitHub username

## 🚀 Push to GitHub (3 Steps)

### Step 1: Update logiclabs Placeholder

```bash
cd ~/dotnet-nuget-proxy-plugin

# Replace with YOUR actual GitHub username
GITHUB_USER="your-github-username"

sed -i "s/logiclabs/$GITHUB_USER/g" .claude-plugin/plugin.json
sed -i "s/logiclabs/$GITHUB_USER/g" README.md
sed -i "s/logiclabs/$GITHUB_USER/g" CHANGELOG.md
sed -i "s/logiclabs/$GITHUB_USER/g" CONTRIBUTING.md
sed -i "s/logiclabs/$GITHUB_USER/g" PUBLISHING-GUIDE.md

git add .
git commit -m "Update: Add GitHub username to URLs"
```

### Step 2: Add GitHub Remote and Push

```bash
cd ~/dotnet-nuget-proxy-plugin

# Add your repository as remote (replace logiclabs)
git remote add origin https://github.com/logiclabs/dotnet-nuget-proxy-skill.git

# Push main branch and tags
git push -u origin main
git push origin v1.0.0
```

### Step 3: Create GitHub Release

1. Go to: `https://github.com/logiclabs/dotnet-nuget-proxy-skill/releases/new`
2. Choose tag: `v1.0.0`
3. Release title: **v1.0.0 - Initial Release**
4. Description:

```markdown
# .NET NuGet Proxy Plugin v1.0.0

First production-ready release! Fixes 401 authentication errors when running `dotnet restore` in proxy-authenticated environments.

## ✨ Features

- 🔍 `/nuget-proxy-debug` - Comprehensive diagnostics
- 🔧 `/nuget-proxy-fix` - One-command setup
- ✅ `/nuget-proxy-verify` - Validate configuration
- 🤖 AI-powered troubleshooting
- ⚡ Auto-starting proxy wrapper

## 📦 Installation

```bash
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill ~/.claude/plugins/dotnet-nuget-proxy
```

Restart Claude Code and you're ready!

## 🚀 Quick Start

1. `/nuget-proxy-debug` - Diagnose issues
2. `/nuget-proxy-fix` - Auto-setup
3. `/nuget-proxy-verify` - Verify it works

---

If this helps you, please ⭐ star the repository!
```

5. Click **Publish release**

## 📦 How Users Install

Once published, users can install with one command:

```bash
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill ~/.claude/plugins/dotnet-nuget-proxy
```

Then restart Claude Code!

## 🧪 Test Your Installation

After publishing, test the installation:

```bash
# Remove if already exists
rm -rf ~/.claude/plugins/dotnet-nuget-proxy

# Install from GitHub
git clone https://github.com/logiclabs/dotnet-nuget-proxy-skill ~/.claude/plugins/dotnet-nuget-proxy

# Verify structure
ls -la ~/.claude/plugins/dotnet-nuget-proxy/.claude-plugin/plugin.json

# Restart Claude Code and test:
# /nuget-proxy-debug
# /nuget-proxy-fix
# /nuget-proxy-verify
```

## 📢 Share with Community

Once published, share on:

**Twitter/X**:
```
🚀 Just published a Claude Code plugin for .NET devs!

Fixes NuGet proxy authentication errors (401) in containerized/corporate
proxy environments.

✅ Auto diagnostics
✅ One-command setup
✅ AI-powered troubleshooting

https://github.com/logiclabs/dotnet-nuget-proxy-skill

#ClaudeCode #DotNet #NuGet
```

**LinkedIn**:
```
Excited to share my new Claude Code plugin for .NET developers!

If you've struggled with NuGet package restore in proxy-authenticated
environments, this plugin provides automated diagnostics and fixes.

Check it out: https://github.com/logiclabs/dotnet-nuget-proxy-skill
```

**Reddit** (r/dotnet):
```
Title: [Tool] Claude Code Plugin for NuGet Proxy Authentication Issues

I created a Claude Code plugin that helps fix NuGet 401 errors in
proxy-authenticated environments. It includes automated diagnostics,
one-command setup, and comprehensive troubleshooting.

GitHub: https://github.com/logiclabs/dotnet-nuget-proxy-skill

Feedback welcome!
```

## ✅ Verification Checklist

Before publishing, verify:

```bash
cd ~/dotnet-nuget-proxy-plugin

# Run verification script
./verify-plugin.sh

# Should show:
# ✓ All checks passed!
# or
# ⚠ Found placeholders (update logiclabs)
```

## 📋 Summary of What You Have

- **Plugin name**: `dotnet-nuget-proxy`
- **Repository**: `dotnet-nuget-proxy-skill`
- **Installation path**: `~/.claude/plugins/dotnet-nuget-proxy`
- **Version**: 1.0.0
- **License**: MIT
- **Total size**: 302KB

---

**Ready to publish?** Follow steps 1-3 above! 🎉
