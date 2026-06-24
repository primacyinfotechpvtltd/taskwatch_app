#!/bin/bash
set -e

echo "🔨 Building Flutter app for Ubuntu 22.04..."

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build Linux release
flutter build linux --release

# Install fastforge
dart pub global activate fastforge

# Add pub-cache to PATH
export PATH="$PATH:/root/.pub-cache/bin"

# Build .deb package
fastforge package --platform linux --targets deb

echo "✅ Build complete! Package location:"
find /app/dist -name "*.deb" -type f

# Copy to mounted volume for easy access
cp dist/*/*.deb /app/ 2>/dev/null || true

echo "📦 Package copied to /app directory"
