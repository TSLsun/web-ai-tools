#!/usr/bin/env bash
# Installs Mac server as a LaunchAgent (auto-starts on login)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/newssummarizer"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.tslsun.newssummarizer.plist"

# Check dependencies
if ! command -v claude &>/dev/null; then
    echo "Error: 'claude' CLI not found. Install Claude Code first."
    exit 1
fi

# Create config if not exists
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    SECRET=$(openssl rand -hex 32)
    echo "{\"secret\": \"$SECRET\"}" > "$CONFIG_DIR/config.json"
    echo "Generated secret: $SECRET"
    echo "Save this in your iOS app Settings > Shared Secret"
else
    echo "Config already exists at $CONFIG_DIR/config.json"
    SECRET=$(python3 -c "import json; print(json.load(open('$CONFIG_DIR/config.json'))['secret'])")
    echo "Existing secret: $SECRET"
fi

# Install LaunchAgent
mkdir -p "$PLIST_DIR"
cat > "$PLIST_DIR/$PLIST_NAME" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tslsun.newssummarizer</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$SCRIPT_DIR/server.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/newssummarizer.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/newssummarizer.error.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$PLIST_DIR/$PLIST_NAME"

echo ""
echo "✓ Server installed and started"
echo "✓ Verify: curl -s http://localhost:8765/summarize || echo 'server running'"
echo ""
echo "Next steps:"
echo "  1. Open iOS app > Settings"
echo "  2. Enter Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'run: tailscale ip -4')"
echo "  3. Enter secret: $SECRET"
