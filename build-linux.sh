#!/bin/bash
# PI Task Watch - Linux Local Build Script
# Developed by Primacy Infotech

set -e

echo "==================================================="
echo "🏗️  Building PI Task Watch for Linux Environment"
echo "==================================================="
echo

# 1. Check Prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter SDK is not installed or not in PATH!"
    echo "   Please install Flutter (v3.32.4 recommended) and add it to PATH."
    echo "   https://docs.flutter.dev/get-started/install/linux"
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

# Check system packages needed for compiling Flutter desktop apps on Linux
MISSING_DEPS=""
for pkg in clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev; do
    if ! dpkg -s "$pkg" &> /dev/null; then
        MISSING_DEPS="$MISSING_DEPS $pkg"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "⚠️  Missing compiling dependencies:$MISSING_DEPS"
    echo "   Please install them using:"
    echo "   sudo apt-get update && sudo apt-get install -y$MISSING_DEPS"
    echo
else
    echo "  [✓] Linux compile dependencies detected."
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
echo "🔨 Building Linux App Bundle (Release)..."
flutter build linux --release

echo
echo "🎉 Build successful!"
echo
echo "📂 Release app bundle is located at:"
echo "   build/linux/x64/release/bundle/"
echo

# Check if Fastforge is activated to package it as DEB
echo "📦 Attempting to compile DEB Installer using Fastforge..."
dart pub global activate fastforge &> /dev/null || true
export PATH="$PATH:$HOME/.pub-cache/bin"

if command -v fastforge &> /dev/null; then
    if fastforge package --platform linux --targets deb; then
        echo "  [✓] DEB installer package generated! Check: dist/linux/deb/"
    else
        echo "  [i] Fastforge DEB package skipped or failed. Zipping the build bundle..."
        mkdir -p dist/zip
        cd build/linux/x64/release/bundle/
        zip -r ../../../../../dist/zip/PI_Task_Watch_Linux.zip .
        echo "  [✓] Zip archive created: dist/zip/PI_Task_Watch_Linux.zip"
    fi
else
    echo "  [i] Fastforge not found. Zipping the build bundle..."
    mkdir -p dist/zip
    cd build/linux/x64/release/bundle/
    zip -r ../../../../../dist/zip/PI_Task_Watch_Linux.zip .
    echo "  [✓] Zip archive created: dist/zip/PI_Task_Watch_Linux.zip"
fi

echo
echo "==================================================="
echo "Done!"
echo "==================================================="
