#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

CERT_NAME="Whisper Dev"

# ── Dependencies ──────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
    echo "Installing xcodegen…"
    brew install xcodegen
fi

# ── Signing certificate (one-time setup) ──────────────────────
# Create a persistent self-signed certificate so the code signature
# stays the same across rebuilds. This keeps macOS Accessibility and
# Microphone grants stable — no more remove-and-re-add dance.
if ! security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "→ Creating self-signed certificate \"$CERT_NAME\"…"
    cat > /tmp/whisper-cert.cfg <<CERTEOF
[ req ]
distinguished_name = req_dn
prompt             = no
[ req_dn ]
CN = $CERT_NAME
[ extensions ]
keyUsage         = digitalSignature
extendedKeyUsage = codeSigning
CERTEOF

    # Generate key + cert, import into login keychain, trust for code signing
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout /tmp/whisper-cert.key \
        -out /tmp/whisper-cert.pem \
        -days 3650 \
        -config /tmp/whisper-cert.cfg \
        -extensions extensions \
        2>/dev/null

    openssl pkcs12 -export -passout pass:whisperdev \
        -inkey /tmp/whisper-cert.key \
        -in /tmp/whisper-cert.pem \
        -out /tmp/whisper-cert.p12 \
        -legacy

    security import /tmp/whisper-cert.p12 \
        -k ~/Library/Keychains/login.keychain-db \
        -T /usr/bin/codesign \
        -P "whisperdev" \
        -A

    rm -f /tmp/whisper-cert.cfg /tmp/whisper-cert.key /tmp/whisper-cert.pem /tmp/whisper-cert.p12

    echo "  ✓ Certificate created. You may see a Keychain prompt — click Always Allow."
    echo "  ⚠ If this is the first time, go to Keychain Access → login → Certificates"
    echo "    → double-click \"$CERT_NAME\" → Trust → Code Signing → Always Trust."
    echo ""
fi

# ── Generate Xcode project ───────────────────────────────────
echo "→ Generating Xcode project…"
xcodegen generate --quiet

# ── Build ─────────────────────────────────────────────────────
echo "→ Building Whisper.app (Release)…"
xcodebuild \
    -project Whisper.xcodeproj \
    -scheme Whisper \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY="$CERT_NAME" \
    CODE_SIGNING_ALLOWED=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
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
