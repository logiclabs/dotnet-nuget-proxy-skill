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

# Check 3: Skills
echo -n "Checking skills... "
SKILL_COUNT=$(find "skills" -name "SKILL.md" 2>/dev/null | wc -l)
if [ "$SKILL_COUNT" -gt 0 ]; then
    echo -e "${GREEN}OK - Found $SKILL_COUNT skill(s)${NC}"
else
    echo -e "${RED}FAIL - No skills found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: Hooks
echo -n "Checking hooks... "
HOOK_COUNT=$(find "hooks" -name "*.sh" 2>/dev/null | wc -l)
if [ "$HOOK_COUNT" -gt 0 ]; then
    echo -e "${GREEN}OK - Found $HOOK_COUNT hook(s)${NC}"
else
    echo -e "${YELLOW}WARN - No hooks found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 5: C# credential provider source
echo -n "Checking credential provider source... "
if [ -f "skills/nuget-proxy-troubleshooting/files/nuget-plugin-proxy-auth-src/Program.cs" ] && \
   [ -f "skills/nuget-proxy-troubleshooting/files/nuget-plugin-proxy-auth-src/nuget-plugin-proxy-auth.csproj" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Missing C# source files${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 6: Install script
echo -n "Checking install script... "
if [ -f "skills/nuget-proxy-troubleshooting/files/install-credential-provider.sh" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Missing install-credential-provider.sh${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 7: Documentation
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

# Check 8: Git
echo -n "Checking git repository... "
if [ -d ".git" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - Not a git repository${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 9: No stale nested plugins directory
echo -n "Checking for stale plugins/ directory... "
if [ -d "plugins" ]; then
    echo -e "${YELLOW}WARN - 'plugins/' exists (structure should be flat at root)${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}OK - No stale nesting${NC}"
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
