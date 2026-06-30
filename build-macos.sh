#!/bin/bash
# PI Task Watch - macOS Local Build Script
# Developed by Primacy Infotech

set -e

echo "==================================================="
echo "🏗️  Building PI Task Watch for macOS Environment"
echo "==================================================="
echo

# 1. Check Prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter SDK is not installed or not in PATH!"
    echo "   Please install Flutter (v3.32.4 recommended) and add it to PATH."
    echo "   https://docs.flutter.dev/get-started/install/macos"
    exit 1
else
    echo "  [✓] Flutter SDK detected: $(flutter --version | head -n 1)"
fi

if ! command -v cargo &> /dev/null; then
    echo "❌ Rust Cargo is not installed or not in PATH!"
    echo "   Please install Rust toolchain (stable) and add it to PATH."
    echo "   https://www.rust-lang.org/tools/install"
    exit 1
else
    echo "  [✓] Rust / Cargo toolchain detected: $(cargo --version)"
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "⚠️  Xcode is not detected! Make sure Xcode is installed from the App Store."
    echo "   You also need Command Line Tools: xcode-select --install"
    exit 1
else
    echo "  [✓] Xcode command line tools detected."
fi

if ! command -v python3 &> /dev/null; then
    echo "⚠️  Python3 is not installed or not in PATH."
    echo "   Fastforge config generation might be skipped."
else
    echo "  [✓] Python3 detected."
fi

echo
echo "📦 Getting Flutter dependencies..."
flutter pub get

if [ -f "generate_fastforge_configs.py" ]; then
    if command -v python3 &> /dev/null; then
        echo "⚙️  Generating packaging configurations..."
        python3 generate_fastforge_configs.py
    fi
fi

echo
echo "🔨 Building macOS App Bundle (Release)..."
flutter build macos --release

echo
echo "🎉 Build successful!"
echo
echo "📂 Release app bundle is located at:"
echo "   build/macos/Build/Products/Release/PI Task Watch.app"
echo
echo "⚠️  Note: Since this app might be unsigned, users running it for the first time"
echo "   may need to right-click the app and choose 'Open' to bypass macOS Gatekeeper."
echo

# Check if Fastforge is activated to package it as DMG
echo "📦 Attempting to compile DMG Installer using Fastforge..."
dart pub global activate fastforge &> /dev/null || true
export PATH="$PATH:$HOME/.pub-cache/bin"

if command -v fastforge &> /dev/null; then
    if fastforge package --platform macos --targets dmg; then
        echo "  [✓] DMG installer package generated! Check: dist/macos/dmg/"
    else
        echo "  [i] Fastforge DMG package skipped or failed. Zipping the .app bundle..."
        mkdir -p dist/zip
        zip -r dist/zip/PI_Task_Watch_macOS.zip "build/macos/Build/Products/Release/PI Task Watch.app"
        echo "  [✓] Zip archive created: dist/zip/PI_Task_Watch_macOS.zip"
    fi
else
    echo "  [i] Fastforge not found. Zipping the .app bundle..."
    mkdir -p dist/zip
    zip -r dist/zip/PI_Task_Watch_macOS.zip "build/macos/Build/Products/Release/PI Task Watch.app"
    echo "  [✓] Zip archive created: dist/zip/PI_Task_Watch_macOS.zip"
fi

echo
echo "==================================================="
echo "Done!"
echo "==================================================="
