#!/bin/bash
set -euo pipefail

SOURCE="$HOME/.config/ghostty/ghostty-cmd-scroll-zoom.swift"
APP="$HOME/Applications/Ghostty Cmd Scroll Zoom.app"
EXECUTABLE="$APP/Contents/MacOS/GhosttyCmdScrollZoom"
PLIST="$HOME/Library/LaunchAgents/com.mobe.ghostty-cmd-scroll-zoom.plist"
LABEL="com.mobe.ghostty-cmd-scroll-zoom"
LOG="$HOME/Library/Logs/ghostty-cmd-scroll-zoom.log"
GUI_DOMAIN="gui/$(id -u)"

if [[ "${1:-install}" == "uninstall" ]]; then
  launchctl bootout "$GUI_DOMAIN" "$PLIST" >/dev/null 2>&1 || true
  rm -f "$PLIST"
  rm -rf "$APP"
  echo "Removed Ghostty Cmd Scroll Zoom and its LaunchAgent."
  exit 0
fi

mkdir -p "$APP/Contents/MacOS" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

swiftc "$SOURCE" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework Carbon \
  -o "$EXECUTABLE"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>GhosttyCmdScrollZoom</string>
    <key>CFBundleIdentifier</key>
    <string>com.mobe.ghostty-cmd-scroll-zoom</string>
    <key>CFBundleName</key>
    <string>Ghostty Cmd Scroll Zoom</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Detect Command+trackpad scrolling in Ghostty to change the terminal font size.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$EXECUTABLE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist" "$PLIST"
launchctl bootout "$GUI_DOMAIN" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "$GUI_DOMAIN" "$PLIST"

echo "Installed Ghostty Cmd Scroll Zoom and loaded its LaunchAgent."
echo "Grant Input Monitoring and Accessibility to: $APP; the helper will activate when both are enabled."
echo "Log: $LOG"
