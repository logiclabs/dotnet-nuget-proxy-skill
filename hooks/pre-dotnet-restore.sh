#!/bin/bash
# pre-dotnet-restore.sh
# Hook that runs before dotnet restore commands to check proxy configuration

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Checking NuGet proxy configuration...${NC}"

# Check if we're in a .NET project
if ! ls *.csproj *.sln 2>/dev/null | grep -q .; then
    exit 0
fi

# Check if proxy environment variables are set
if [ -z "$HTTP_PROXY" ] && [ -z "$HTTPS_PROXY" ]; then
    echo -e "${YELLOW}  HTTP_PROXY and HTTPS_PROXY are not set${NC}"
    echo -e "${BLUE}  Tip: Run 'source install-credential-provider.sh' to set up the proxy${NC}"
    exit 0
fi

# Check if the C# credential provider plugin is installed
PLUGIN_DLL="$HOME/.nuget/plugins/netcore/nuget-plugin-proxy-auth/nuget-plugin-proxy-auth.dll"
if [ -f "$PLUGIN_DLL" ]; then
    echo -e "${GREEN}  NuGet credential provider installed${NC}"
else
    echo -e "${YELLOW}  NuGet credential provider not installed${NC}"
    echo -e "${BLUE}  Tip: Run 'source install-credential-provider.sh' to install${NC}"
fi

# Check if proxy is running on port 8888
if python3 -c "import socket; s=socket.socket(); s.settimeout(1); exit(0 if s.connect_ex(('127.0.0.1', 8888)) == 0 else 1)" 2>/dev/null; then
    echo -e "${GREEN}  Proxy running on localhost:8888${NC}"
elif command -v ss &>/dev/null && ss -tlnp 2>/dev/null | grep -q ':8888'; then
    echo -e "${GREEN}  Proxy running on localhost:8888${NC}"
else
    echo -e "${YELLOW}  Proxy not running on port 8888${NC}"
    if [ -f "$PLUGIN_DLL" ]; then
        echo -e "${BLUE}  Tip: Run 'dotnet $PLUGIN_DLL --start' to start the proxy${NC}"
    else
        echo -e "${BLUE}  Tip: Run 'source install-credential-provider.sh' to set up${NC}"
    fi
fi

echo -e "${GREEN}  Proxy check complete${NC}"
echo ""
