#!/bin/bash
# PUBLISH-NOW.sh - Quick script to publish to GitHub

set -e

echo "🚀 Publishing .NET NuGet Proxy Plugin to GitHub"
echo "================================================"
echo ""

# Check if GitHub username is provided
if [ -z "$1" ]; then
    echo "❌ Error: GitHub username required"
    echo ""
    echo "Usage: ./PUBLISH-NOW.sh <your-github-username>"
    echo ""
    echo "Example:"
    echo "  ./PUBLISH-NOW.sh myusername"
    echo ""
    exit 1
fi

GITHUB_USER="$1"
REPO_NAME="dotnet-nuget-proxy-skill"

echo "📝 Settings:"
echo "  GitHub User: $GITHUB_USER"
echo "  Repository: $REPO_NAME"
echo ""

# Step 1: Update placeholders
echo "Step 1/4: Updating YOUR-USERNAME placeholders..."
sed -i "s/YOUR-USERNAME/$GITHUB_USER/g" .claude-plugin/plugin.json
sed -i "s/YOUR-USERNAME/$GITHUB_USER/g" README.md
sed -i "s/YOUR-USERNAME/$GITHUB_USER/g" CHANGELOG.md
sed -i "s/YOUR-USERNAME/$GITHUB_USER/g" CONTRIBUTING.md
sed -i "s/YOUR-USERNAME/$GITHUB_USER/g" PUBLISHING-GUIDE.md
sed -i "s/YOUR-USERNAME/$GITHUB_USER/g" QUICK-SETUP.md

git add .
git commit -m "Update: Add GitHub username ($GITHUB_USER) to URLs" || echo "No changes to commit"
echo "✅ Placeholders updated"
echo ""

# Step 2: Add remote
echo "Step 2/4: Adding GitHub remote..."
if git remote get-url origin > /dev/null 2>&1; then
    echo "⚠️  Remote 'origin' already exists. Updating..."
    git remote set-url origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
else
    git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
fi
echo "✅ Remote configured: https://github.com/$GITHUB_USER/$REPO_NAME.git"
echo ""

# Step 3: Push
echo "Step 3/4: Pushing to GitHub..."
echo "  Pushing main branch..."
git push -u origin main

echo "  Pushing v1.0.0 tag..."
git push origin v1.0.0

echo "✅ Pushed to GitHub"
echo ""

# Step 4: Instructions for release
echo "Step 4/4: Create GitHub Release"
echo "================================"
echo ""
echo "1. Go to: https://github.com/$GITHUB_USER/$REPO_NAME/releases/new"
echo "2. Choose tag: v1.0.0"
echo "3. Release title: v1.0.0 - Initial Release"
echo "4. Copy/paste the description from QUICK-SETUP.md"
echo "5. Click 'Publish release'"
echo ""
echo "🎉 Done! Your plugin is now published at:"
echo "   https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "📦 Users can install with:"
echo "   git clone https://github.com/$GITHUB_USER/$REPO_NAME ~/.claude/plugins/dotnet-nuget-proxy"
echo ""
