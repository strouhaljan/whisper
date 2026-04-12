#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Check dependencies
if ! command -v xcodegen &>/dev/null; then
    echo "Installing xcodegen…"
    brew install xcodegen
fi

# Generate Xcode project from project.yml
echo "→ Generating Xcode project…"
xcodegen generate --quiet

# Build release
echo "→ Building Whisper.app (Release)…"
xcodebuild \
    -project Whisper.xcodeproj \
    -scheme Whisper \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    ONLY_ACTIVE_ARCH=NO \
    -quiet

APP="build/DerivedData/Build/Products/Release/Whisper.app"

if [ -d "$APP" ]; then
    echo ""
    echo "✓ Built successfully: $APP"
    echo ""
    echo "To install:"
    echo "  cp -R \"$APP\" /Applications/"
    echo ""
    echo "To run now:"
    echo "  open \"$APP\""
else
    echo "✗ Build failed — check the output above."
    exit 1
fi
