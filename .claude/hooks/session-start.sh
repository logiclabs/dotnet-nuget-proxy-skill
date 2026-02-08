#!/bin/bash
set -euo pipefail

# SessionStart hook — delegates to the plugin's session-start.sh
#
# The plugin hook handles everything:
#   - Skips on desktop (checks CLAUDE_CODE_REMOTE)
#   - Detects required .NET SDK version from .csproj files
#   - Installs .NET SDK from packages.microsoft.com
#   - Compiles and installs the C# NuGet credential provider
#   - Starts the proxy daemon on localhost:8888
#   - Creates a dotnet() shell function (proxy scoped to dotnet only)
#   - Persists environment via $CLAUDE_ENV_FILE

PLUGIN_HOOK="$CLAUDE_PROJECT_DIR/hooks/session-start.sh"

if [ -f "$PLUGIN_HOOK" ]; then
  exec bash "$PLUGIN_HOOK"
else
  echo "WARNING: Plugin hook not found at $PLUGIN_HOOK"
  exit 0
fi
