#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PLIST="$SCRIPT_DIR/Packaging/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
PACKAGE_VERSION=$(print -r -- "$VERSION" | sed -E 's/[^0-9.]+/./g; s/\.+/./g; s/^\.//; s/\.$//')
PAYLOAD_ROOT="$SCRIPT_DIR/dist/pkg-root"
UNSIGNED_PKG="$SCRIPT_DIR/dist/Saymote-$PACKAGE_VERSION-unsigned.pkg"
FINAL_PKG="$SCRIPT_DIR/dist/Saymote-$PACKAGE_VERSION.pkg"
EXPORT_PKG_DIR="$SCRIPT_DIR/../打包产物"
EXPORT_PKG="$EXPORT_PKG_DIR/Saymote-$PACKAGE_VERSION-$(date +%Y%m%d).pkg"

"$SCRIPT_DIR/package-app.sh"
"$SCRIPT_DIR/Driver/build-driver.sh"

rm -rf "$PAYLOAD_ROOT" "$UNSIGNED_PKG" "$FINAL_PKG"
mkdir -p "$PAYLOAD_ROOT/Applications"
mkdir -p "$PAYLOAD_ROOT/Library/Audio/Plug-Ins/HAL"

ditto "$SCRIPT_DIR/dist/build/遥控说.app" "$PAYLOAD_ROOT/Applications/遥控说.app"
ditto "$SCRIPT_DIR/Driver/build/vRemoteDriver.driver" \
  "$PAYLOAD_ROOT/Library/Audio/Plug-Ins/HAL/vRemoteDriver.driver"

COMPONENT_PLIST="$SCRIPT_DIR/dist/components.plist"
pkgbuild --analyze --root "$PAYLOAD_ROOT" "$COMPONENT_PLIST"
for i in 0 1 2 3 4; do
  relocatable=$(/usr/libexec/PlistBuddy -c "Print :$i:BundleIsRelocatable" "$COMPONENT_PLIST" 2>/dev/null || true)
  if [[ -n "$relocatable" ]]; then
    /usr/libexec/PlistBuddy -c "Set :$i:BundleIsRelocatable false" "$COMPONENT_PLIST" 2>/dev/null || true
  fi
done

pkgbuild \
  --root "$PAYLOAD_ROOT" \
  --component-plist "$COMPONENT_PLIST" \
  --scripts "$SCRIPT_DIR/Packaging/pkg-scripts" \
  --identifier "io.saymote.mac.pkg" \
  --version "$PACKAGE_VERSION" \
  "$UNSIGNED_PKG"

if [[ -n "${INSTALLER_SIGN_IDENTITY:-}" ]]; then
  productsign \
    --sign "$INSTALLER_SIGN_IDENTITY" \
    "$UNSIGNED_PKG" \
    "$FINAL_PKG"
  rm -f "$UNSIGNED_PKG"
else
  mv "$UNSIGNED_PKG" "$FINAL_PKG"
  print -u2 "Warning: INSTALLER_SIGN_IDENTITY is not set; package is unsigned."
fi

pkgutil --check-signature "$FINAL_PKG" || true
mkdir -p "$EXPORT_PKG_DIR"
cp "$FINAL_PKG" "$EXPORT_PKG"

README_SRC="$SCRIPT_DIR/Packaging/安装必读（打不开看这里）.txt"
README_DST="$EXPORT_PKG_DIR/安装必读（打不开看这里）.txt"
cp "$README_SRC" "$README_DST"

ZIP_NAME="Saymote-$PACKAGE_VERSION-$(date +%Y%m%d).zip"
ZIP_PATH="$EXPORT_PKG_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"
(cd "$EXPORT_PKG_DIR" && zip -q "$ZIP_NAME" "$(basename "$EXPORT_PKG")" "安装必读（打不开看这里）.txt")

print "Built: $FINAL_PKG"
print "Exported: $EXPORT_PKG"
print "Exported: $README_DST"
print "Exported: $ZIP_PATH"
