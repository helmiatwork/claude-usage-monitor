#!/bin/bash

# Claude Usage Monitor — One-Click Installer
# Double-click this file to install everything.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"
LOCAL_BIN="$HOME/.local/bin"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.ichigo.claude-usage-fetch"
REFRESH_INTERVAL=180  # 3 minutes in seconds
SWIFTBAR_INTERVAL="5s"

echo "=== Claude Usage Monitor Installer ==="
echo ""

# 1. Check dependencies
echo "[1/7] Checking dependencies..."

if ! command -v jq &>/dev/null; then
  echo "  jq not found. Installing via Homebrew..."
  if command -v brew &>/dev/null; then
    brew install jq
  else
    echo "  ERROR: jq is required but Homebrew is not installed."
    echo "  Install Homebrew first: https://brew.sh"
    exit 1
  fi
else
  echo "  jq: OK"
fi

if ! command -v claude &>/dev/null && [ ! -f "$LOCAL_BIN/claude" ]; then
  echo "  ERROR: Claude Code CLI not found. Install it first."
  exit 1
else
  echo "  claude: OK"
fi

# 2. Install SwiftBar if needed
echo "[2/7] Checking SwiftBar..."
if [ ! -d "/Applications/SwiftBar.app" ] && [ ! -d "$HOME/Applications/SwiftBar.app" ]; then
  echo "  SwiftBar not found. Installing via Homebrew..."
  if command -v brew &>/dev/null; then
    brew install --cask swiftbar
  else
    echo "  ERROR: SwiftBar is required but Homebrew is not installed."
    exit 1
  fi
else
  echo "  SwiftBar: OK"
fi

# 3. Create directories
echo "[3/7] Creating directories..."
mkdir -p "$PLUGIN_DIR"
mkdir -p "$LOCAL_BIN"
mkdir -p "$LAUNCH_AGENTS"
echo "  Done"

# 4. Install fetcher script
echo "[4/7] Installing fetcher..."
cp "$SCRIPT_DIR/claude-usage-fetch.sh" "$LOCAL_BIN/claude-usage-fetch-real.sh"
chmod +x "$LOCAL_BIN/claude-usage-fetch-real.sh"
# Also create symlink for manual use
ln -sf "$SCRIPT_DIR/claude-usage-fetch.sh" "$LOCAL_BIN/claude-usage-fetch.sh"
echo "  Installed to $LOCAL_BIN/claude-usage-fetch-real.sh"

# 5. Install SwiftBar plugin
echo "[5/7] Installing SwiftBar plugin..."
# Remove any existing claude-usage plugin symlinks
rm -f "$PLUGIN_DIR"/claude-usage.*.sh
ln -sf "$SCRIPT_DIR/claude-usage.3m.sh" "$PLUGIN_DIR/claude-usage.${SWIFTBAR_INTERVAL}.sh"
echo "  Symlinked as claude-usage.${SWIFTBAR_INTERVAL}.sh"

# 6. Install and load launchd agent
echo "[6/7] Setting up auto-refresh (every $((REFRESH_INTERVAL / 60)) minutes)..."
# Unload existing if present
launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME.plist" 2>/dev/null || true

cat > "$LAUNCH_AGENTS/$PLIST_NAME.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$LOCAL_BIN/claude-usage-fetch-real.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>$REFRESH_INTERVAL</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claude-usage-fetch.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-usage-fetch.log</string>
</dict>
</plist>
PLIST

launchctl load "$LAUNCH_AGENTS/$PLIST_NAME.plist"
echo "  Loaded $PLIST_NAME (every ${REFRESH_INTERVAL}s)"

# 7. Start SwiftBar and set plugin directory
echo "[7/7] Starting SwiftBar..."
defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR"
open -a SwiftBar
echo "  SwiftBar started"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "  Menu bar plugin: claude-usage.${SWIFTBAR_INTERVAL}.sh"
echo "  Fetcher:         claude-usage-fetch-real.sh (every $((REFRESH_INTERVAL / 60))min)"
echo "  Cache:           /tmp/claude-usage-cache.json"
echo "  Log:             /tmp/claude-usage-fetch.log"
echo ""
echo "First data will appear in ~30 seconds after the fetcher completes."
echo "Press any key to close..."
read -n 1
