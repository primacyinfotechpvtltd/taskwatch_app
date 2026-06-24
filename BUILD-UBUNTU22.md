# Building TaskWatch for Ubuntu 22.04

## Problem
When you build on Ubuntu 25.10, the resulting `.deb` package won't work on Ubuntu 22.04 due to library incompatibilities (specifically GLib version differences).

## Solution
Use Docker to build inside an Ubuntu 22.04 environment.

## One-Time Setup

1. **Install Docker** (if not already installed):
   ```bash
   sudo apt update
   sudo apt install -y docker.io
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   ```

2. **Log out and log back in** (required for group membership to take effect)

3. **Verify Docker works**:
   ```bash
   docker --version
   ```

## Building the Package

Simply run:

```bash
./build-ubuntu22.sh
```

This will:
1. Build a Docker image with Ubuntu 22.04 + Flutter (first time only, ~5-10 minutes)
2. Build your Flutter app inside that container
3. Create a `.deb` package compatible with Ubuntu 22.04
4. Output the package to `dist/` directory

## Finding Your Package

After the build completes:
```bash
ls -lh dist/*/pi_task_watch-*-linux.deb
```

## Installing on Ubuntu 22.04

Copy the `.deb` file to the Ubuntu 22.04 machine and install:
```bash
sudo apt install ./pi_task_watch-1.0.24+24-linux.deb
```

## Notes

- The Docker image is built once and reused for future builds
- Your source code is mounted into the container, not copied
- The build happens in an isolated Ubuntu 22.04 environment
- This ensures binary compatibility with Ubuntu 22.04 systems
