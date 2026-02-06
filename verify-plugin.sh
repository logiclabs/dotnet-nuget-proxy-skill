#!/bin/bash
# verify-plugin.sh - Verify plugin structure and readiness for publication

echo "🔍 .NET NuGet Proxy Plugin - Structure Verification"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Check 1: plugin.json exists and is valid
echo -n "Checking plugin.json... "
if [ -f ".claude-plugin/plugin.json" ]; then
    if python3 -m json.tool < .claude-plugin/plugin.json > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Invalid JSON${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: Required directories
echo -n "Checking directory structure... "
if [ -d "skills" ] && [ -d "commands" ] && [ -d "hooks" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Missing required directories${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: Skills
echo -n "Checking skills... "
SKILL_COUNT=$(find skills -name "SKILL.md" | wc -l)
if [ "$SKILL_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $SKILL_COUNT skill(s)${NC}"
else
    echo -e "${RED}✗ No skills found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: Commands
echo -n "Checking commands... "
CMD_COUNT=$(find commands -name "*.md" 2>/dev/null | wc -l)
if [ "$CMD_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $CMD_COUNT command(s)${NC}"
else
    echo -e "${YELLOW}⚠ No commands found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 5: Hooks
echo -n "Checking hooks... "
HOOK_COUNT=$(find hooks -name "*.sh" 2>/dev/null | wc -l)
if [ "$HOOK_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $HOOK_COUNT hook(s)${NC}"
else
    echo -e "${YELLOW}⚠ No hooks found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 6: Documentation
echo -n "Checking README.md... "
if [ -f "README.md" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Checking CHANGELOG.md... "
if [ -f "CHANGELOG.md" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Missing${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo -n "Checking LICENSE... "
if [ -f "LICENSE" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Missing${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 7: Git
echo -n "Checking git repository... "
if [ -d ".git" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Not a git repository${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 8: Placeholders
echo -n "Checking for placeholder URLs... "
if grep -r "YOUR-USERNAME" . --exclude-dir=.git -q 2>/dev/null; then
    echo -e "${YELLOW}⚠ Found placeholders (update before publishing)${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓ No placeholders${NC}"
fi

# Check 9: File count
echo -n "Counting files... "
FILE_COUNT=$(find . -type f | grep -v .git | wc -l)
echo -e "${GREEN}$FILE_COUNT files${NC}"

# Summary
echo ""
echo "Summary:"
echo "--------"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Plugin is ready for publication.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s). Review before publishing.${NC}"
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) found. Fix before publishing.${NC}"
    exit 1
fi
