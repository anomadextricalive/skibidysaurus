#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Skibidysaurus"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_HOME="$HOME/Library/Application Support/$APP_NAME"
TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
  TARGET_DIR="$HOME/Applications"
fi
APP_BUNDLE="$TARGET_DIR/$APP_NAME.app"
BUILD_DIR="$SCRIPT_DIR/SkibidysaurusApp"
RELEASE_BIN="$BUILD_DIR/.build/release/Skibidysaurus"
STAGE_DIR="$SCRIPT_DIR/.dist"

printf "\n==> preparing install home\n"
mkdir -p "$INSTALL_HOME"
rsync -a --delete \
  "$SCRIPT_DIR/backend.py" \
  "$SCRIPT_DIR/requirements.txt" \
  "$SCRIPT_DIR/core" \
  "$SCRIPT_DIR/llm" \
  "$INSTALL_HOME/"

printf "\n==> setting up python environment\n"
if [ ! -x "$INSTALL_HOME/venv/bin/python" ]; then
  python3 -m venv "$INSTALL_HOME/venv"
fi
"$INSTALL_HOME/venv/bin/pip" install --upgrade pip >/dev/null
"$INSTALL_HOME/venv/bin/pip" install -r "$INSTALL_HOME/requirements.txt"

printf "\n==> building mac app\n"
(cd "$BUILD_DIR" && swift build -c release)

printf "\n==> creating app bundle\n"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$STAGE_DIR/$APP_NAME.app/Contents/Resources"

cat > "$STAGE_DIR/$APP_NAME.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>Skibidysaurus</string>
  <key>CFBundleIdentifier</key>
  <string>com.skibidysaurus.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cp "$RELEASE_BIN" "$STAGE_DIR/$APP_NAME.app/Contents/MacOS/Skibidysaurus-bin"
cat > "$STAGE_DIR/$APP_NAME.app/Contents/MacOS/Skibidysaurus" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
export SKIBIDYSAURUS_HOME="$HOME/Library/Application Support/Skibidysaurus"
exec "$(dirname "$0")/Skibidysaurus-bin"
LAUNCHER
chmod +x "$STAGE_DIR/$APP_NAME.app/Contents/MacOS/Skibidysaurus"
chmod +x "$STAGE_DIR/$APP_NAME.app/Contents/MacOS/Skibidysaurus-bin"

printf "\n==> installing app into %s\n" "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
rm -rf "$APP_BUNDLE"
cp -R "$STAGE_DIR/$APP_NAME.app" "$APP_BUNDLE"

printf "\n==> done\n"
printf "installed: %s\n" "$APP_BUNDLE"
printf "backend:   %s\n" "$INSTALL_HOME"
printf "launch with: open -a $APP_NAME\n\n"
