#!/bin/bash
# Setup script to create a dotnet alias that automatically uses the proxy
# Usage: source ./setup-dotnet-alias.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create alias for dotnet command
alias dotnet="$SCRIPT_DIR/dotnet-with-proxy.sh"

echo "✓ dotnet alias created for this session"
echo ""
echo "Now you can use dotnet commands normally:"
echo "  dotnet restore"
echo "  dotnet build"
echo "  dotnet test"
echo ""
echo "The proxy will start automatically if needed."
echo ""
echo "To make this permanent, add this line to your ~/.bashrc:"
echo "  alias dotnet='$SCRIPT_DIR/dotnet-with-proxy.sh'"
