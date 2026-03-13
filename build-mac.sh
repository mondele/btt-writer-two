#!/bin/bash
# Build BTT-Writer 2 as a macOS .app bundle with bundled OpenSSL.
# Usage: ./build-mac.sh
# Requires: fpc, lazbuild, openssl (via Homebrew)

set -e

APP_NAME="BTT-Writer"
BUNDLE="${APP_NAME}.app"
CONTENTS="${BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
FRAMEWORKS_DIR="${CONTENTS}/Frameworks"
RESOURCES_DIR="${CONTENTS}/Resources"
EXECUTABLE="bttwriter2"

# Detect Homebrew OpenSSL location
if [ -d "/opt/homebrew/opt/openssl/lib" ]; then
  OPENSSL_LIB="/opt/homebrew/opt/openssl/lib"
elif [ -d "/usr/local/opt/openssl/lib" ]; then
  OPENSSL_LIB="/usr/local/opt/openssl/lib"
else
  echo "Error: OpenSSL not found. Install with: brew install openssl"
  exit 1
fi

echo "Using OpenSSL from: ${OPENSSL_LIB}"

# Find the actual dylib files (not symlinks to versioned names)
LIBSSL=$(ls "${OPENSSL_LIB}"/libssl.*.dylib 2>/dev/null | grep -v '\.a$' | head -1)
LIBCRYPTO=$(ls "${OPENSSL_LIB}"/libcrypto.*.dylib 2>/dev/null | grep -v '\.a$' | head -1)

if [ -z "$LIBSSL" ] || [ -z "$LIBCRYPTO" ]; then
  echo "Error: Could not find libssl/libcrypto dylibs in ${OPENSSL_LIB}"
  exit 1
fi

LIBSSL_NAME=$(basename "$LIBSSL")
LIBCRYPTO_NAME=$(basename "$LIBCRYPTO")

echo "Found: ${LIBSSL_NAME}, ${LIBCRYPTO_NAME}"

# Step 1: Build with lazbuild (Cocoa widgetset is the macOS default)
echo "Building ${EXECUTABLE}..."
lazbuild bttwriter2.lpi

# Step 2: Create .app bundle structure
echo "Creating ${BUNDLE}..."
rm -rf "${BUNDLE}"
mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}"

# Step 3: Copy executable
cp "${EXECUTABLE}" "${MACOS_DIR}/${EXECUTABLE}"

# Step 4: Copy OpenSSL dylibs
cp "$LIBSSL" "${FRAMEWORKS_DIR}/"
cp "$LIBCRYPTO" "${FRAMEWORKS_DIR}/"

# Also create versionless symlinks (FPC may try loading "libssl.dylib")
ln -sf "${LIBSSL_NAME}" "${FRAMEWORKS_DIR}/libssl.dylib"
ln -sf "${LIBCRYPTO_NAME}" "${FRAMEWORKS_DIR}/libcrypto.dylib"

# Step 5: Fix dylib rpaths so they find each other within the bundle
install_name_tool -id "@rpath/${LIBSSL_NAME}" "${FRAMEWORKS_DIR}/${LIBSSL_NAME}"
install_name_tool -id "@rpath/${LIBCRYPTO_NAME}" "${FRAMEWORKS_DIR}/${LIBCRYPTO_NAME}"

# Fix libssl's reference to libcrypto
CRYPTO_REF=$(otool -L "${FRAMEWORKS_DIR}/${LIBSSL_NAME}" | grep libcrypto | awk '{print $1}')
if [ -n "$CRYPTO_REF" ]; then
  install_name_tool -change "$CRYPTO_REF" "@rpath/${LIBCRYPTO_NAME}" "${FRAMEWORKS_DIR}/${LIBSSL_NAME}"
fi

# Add rpath to the executable so it finds Frameworks/
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${EXECUTABLE}" 2>/dev/null || true

# Step 6: Copy app icon
if [ -f ".claude/assets/icon.icns" ]; then
  cp ".claude/assets/icon.icns" "${RESOURCES_DIR}/bttwriter2.icns"
  echo "Copied app icon"
fi

# Step 7: Create Info.plist
cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>BTT-Writer</string>
  <key>CFBundleDisplayName</key>
  <string>BTT-Writer</string>
  <key>CFBundleIdentifier</key>
  <string>org.bibletranslationtools.bttwriter2</string>
  <key>CFBundleVersion</key>
  <string>2.0.0</string>
  <key>CFBundleShortVersionString</key>
  <string>2.0.0-dev</string>
  <key>CFBundleExecutable</key>
  <string>bttwriter2</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>bttwriter2</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>tstudio</string>
      </array>
      <key>CFBundleTypeName</key>
      <string>Translation Studio Package</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
    </dict>
  </array>
</dict>
</plist>
PLIST

echo ""
echo "Done! Created ${BUNDLE}"
echo "  Executable: ${MACOS_DIR}/${EXECUTABLE}"
echo "  OpenSSL:    ${FRAMEWORKS_DIR}/${LIBSSL_NAME}"
echo "              ${FRAMEWORKS_DIR}/${LIBCRYPTO_NAME}"
echo ""
echo "Run with:  open ${BUNDLE}"
echo "  or:      ${MACOS_DIR}/${EXECUTABLE}"
