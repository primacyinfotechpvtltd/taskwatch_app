#!/bin/bash
# Build script for creating Ubuntu 22.04 compatible .deb package

set -e

echo "🏗️  Building TaskWatch for Ubuntu 22.04..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first:"
    echo "   sudo apt update && sudo apt install -y docker.io"
    echo "   sudo systemctl start docker"
    echo "   sudo usermod -aG docker $USER"
    echo "   Then log out and log back in."
    exit 1
fi

# Use sudo if not in docker group yet
DOCKER_CMD="docker"
if ! groups | grep -q docker; then
    echo "ℹ️  Using sudo for Docker (you haven't logged out yet after adding to docker group)"
    DOCKER_CMD="sudo docker"
fi

# Build Docker image if it doesn't exist
if [[ "$($DOCKER_CMD images -q taskwatch-builder-ubuntu22:latest 2> /dev/null)" == "" ]]; then
    echo "📦 Building Docker image (this may take a few minutes)..."
    $DOCKER_CMD build -f Dockerfile.ubuntu22 -t taskwatch-builder-ubuntu22:latest .
fi

# Run the build inside Docker container
echo "🔨 Building Flutter app inside Ubuntu 22.04 container..."
$DOCKER_CMD run --rm \
    -v "$(pwd):/app" \
    -w /app \
    taskwatch-builder-ubuntu22:latest \
    bash -c "
        flutter pub get && \
        flutter build linux --release && \
        dart pub global activate fastforge && \
        export PATH=\"\$PATH:/root/.pub-cache/bin\" && \
        fastforge package --platform linux --targets deb
    "

echo "✅ Build complete!"
echo "📦 Package location: dist/*/pi_task_watch-*-linux.deb"
ls -lh dist/*/pi_task_watch-*-linux.deb 2>/dev/null || echo "⚠️  Package not found in expected location"
