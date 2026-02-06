#!/bin/bash
# pre-dotnet-restore.sh
# Hook that runs before dotnet restore commands to check proxy configuration

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Checking NuGet proxy configuration...${NC}"

# Check if we're in a .NET project
if ! ls *.csproj *.sln 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}⚠️  No .NET project files found in current directory${NC}"
    exit 0
fi

# Check if proxy environment variables are set
if [ -z "$HTTP_PROXY" ] && [ -z "$HTTPS_PROXY" ]; then
    echo -e "${YELLOW}⚠️  HTTP_PROXY and HTTPS_PROXY are not set${NC}"
    echo -e "${BLUE}💡 Tip: Run '/nuget-proxy-debug' to diagnose proxy issues${NC}"
    echo -e "${BLUE}💡 Tip: Run '/nuget-proxy-fix' to set up the proxy solution${NC}"
    exit 0
fi

# Check if custom proxy is running
if ps aux | grep -v grep | grep -q "nuget-proxy.py"; then
    echo -e "${GREEN}✅ NuGet proxy is running${NC}"
else
    echo -e "${YELLOW}⚠️  NuGet proxy (nuget-proxy.py) is not running${NC}"

    # Check if proxy files exist
    if [ -f "nuget-proxy.py" ]; then
        echo -e "${BLUE}💡 Tip: Start proxy with: python3 nuget-proxy.py &${NC}"
        echo -e "${BLUE}💡 Or use: ./dotnet-with-proxy.sh restore (auto-starts proxy)${NC}"
    else
        echo -e "${BLUE}💡 Tip: Run '/nuget-proxy-fix' to create proxy files${NC}"
    fi
fi

# Check if NuGet.config exists
if [ ! -f "NuGet.config" ] && [ ! -f "$HOME/.nuget/NuGet/NuGet.config" ]; then
    echo -e "${YELLOW}⚠️  No NuGet.config file found${NC}"
    echo -e "${BLUE}💡 Tip: Run '/nuget-proxy-fix' to create NuGet.config${NC}"
fi

# Check if wrapper script exists
if [ -f "dotnet-with-proxy.sh" ]; then
    echo -e "${GREEN}✅ Wrapper script available: ./dotnet-with-proxy.sh${NC}"
fi

echo -e "${GREEN}✓ Proxy configuration check complete${NC}"
echo ""
