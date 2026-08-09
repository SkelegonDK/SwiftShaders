#!/bin/bash
# Builds the gallery and wraps it in a double-clickable .app bundle.
#
# A bare SwiftPM executable has no bundle, so macOS won't give it a Dock icon,
# a menu bar, or proper window focus. This packages the same binary as an app.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"

# The shell lives in its own package (Gallery/) that depends on this one by
# path, so everything below builds with --package-path and reads back the
# *nested* package's bin directory. default.metallib is still generated here:
# it is a resource of the library target in the root package, and the path
# dependency picks it up from this checkout.
./Scripts/build-shaders.sh
swift build --package-path Gallery -c "$CONFIG" --product SwiftShadersGallery

BIN_DIR="$(swift build --package-path Gallery -c "$CONFIG" --show-bin-path)"
APP="$BIN_DIR/SwiftShadersGallery.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/SwiftShadersGallery" "$APP/Contents/MacOS/"

# The SwiftPM resource bundle carries default.metallib, which Bundle.module
# resolves relative to the main bundle's Resources directory. A path dependency
# builds its resource bundles into the depending package's bin directory under
# the same name, so this copy is unchanged apart from where BIN_DIR points.
cp -R "$BIN_DIR/SwiftShaders_SwiftShaders.bundle" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SwiftShaders Gallery</string>
    <key>CFBundleDisplayName</key>
    <string>SwiftShaders Gallery</string>
    <key>CFBundleExecutable</key>
    <string>SwiftShadersGallery</string>
    <key>CFBundleIdentifier</key>
    <string>com.swiftshaders.gallery</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Built $APP"
