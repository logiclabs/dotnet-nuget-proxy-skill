#!/bin/bash
# verify-plugin.sh - Verify plugin structure and readiness for publication

echo "  .NET NuGet Proxy Plugin - Structure Verification"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

PLUGIN_DIR="plugins/dotnet-nuget-proxy"

# Check 1: Root plugin.json exists and is valid
echo -n "Checking .claude-plugin/plugin.json... "
if [ -f ".claude-plugin/plugin.json" ]; then
    if python3 -m json.tool < .claude-plugin/plugin.json > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL - Invalid JSON${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}FAIL - Missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: Marketplace config
echo -n "Checking marketplace.json... "
if [ -f ".claude-plugin/marketplace.json" ]; then
    if python3 -m json.tool < .claude-plugin/marketplace.json > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL - Invalid JSON${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}FAIL - Missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: Plugin directory structure
echo -n "Checking plugin directory ($PLUGIN_DIR)... "
if [ -d "$PLUGIN_DIR" ] && [ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Missing plugin directory or plugin.json${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: Skills
echo -n "Checking skills... "
SKILL_COUNT=$(find "$PLUGIN_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l)
if [ "$SKILL_COUNT" -gt 0 ]; then
    echo -e "${GREEN}OK - Found $SKILL_COUNT skill(s)${NC}"
else
    echo -e "${RED}FAIL - No skills found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 5: Hooks
echo -n "Checking hooks... "
HOOK_COUNT=$(find "$PLUGIN_DIR/hooks" -name "*.sh" 2>/dev/null | wc -l)
if [ "$HOOK_COUNT" -gt 0 ]; then
    echo -e "${GREEN}OK - Found $HOOK_COUNT hook(s)${NC}"
else
    echo -e "${YELLOW}WARN - No hooks found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 6: C# credential provider source
echo -n "Checking credential provider source... "
if [ -f "$PLUGIN_DIR/skills/nuget-proxy-troubleshooting/files/nuget-plugin-proxy-auth-src/Program.cs" ] && \
   [ -f "$PLUGIN_DIR/skills/nuget-proxy-troubleshooting/files/nuget-plugin-proxy-auth-src/nuget-plugin-proxy-auth.csproj" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Missing C# source files${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 7: Install script
echo -n "Checking install script... "
if [ -f "$PLUGIN_DIR/skills/nuget-proxy-troubleshooting/files/install-credential-provider.sh" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Missing install-credential-provider.sh${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 8: Documentation
echo -n "Checking README.md... "
if [ -f "README.md" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Checking CHANGELOG.md... "
if [ -f "CHANGELOG.md" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}WARN - Missing${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo -n "Checking LICENSE... "
if [ -f "LICENSE" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 9: Git
echo -n "Checking git repository... "
if [ -d ".git" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Not a git repository${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 10: Placeholders
echo -n "Checking for placeholder URLs... "
if grep -r "YOUR-USERNAME" . --exclude-dir=.git -q 2>/dev/null; then
    echo -e "${YELLOW}WARN - Found placeholders (update before publishing)${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}OK - No placeholders${NC}"
fi

# Check 11: No stale root-level duplicates
echo -n "Checking for stale root directories... "
STALE=0
for dir in skills commands; do
    if [ -d "$dir" ]; then
        echo -e "${YELLOW}WARN - Root '$dir/' still exists (should only be in $PLUGIN_DIR/)${NC}"
        STALE=1
        WARNINGS=$((WARNINGS + 1))
    fi
done
if [ $STALE -eq 0 ]; then
    echo -e "${GREEN}OK - No stale duplicates${NC}"
fi

# Summary
echo ""
echo "Summary:"
echo "--------"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed! Plugin is ready for publication.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS warning(s). Review before publishing.${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS error(s) found. Fix before publishing.${NC}"
    exit 1
fi
