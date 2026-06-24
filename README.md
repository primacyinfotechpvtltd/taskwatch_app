# PI Task Watch

Employee monitoring application with Odoo integration

## Version
1.0.23+23

## Description
PI Task Watch is an employee monitoring application that integrates with Odoo for comprehensive task tracking and productivity monitoring.

## Building the Application

### Prerequisites
- Flutter SDK 3.7.2 or higher
- Rust toolchain (for native components)

### Local Build

#### macOS
```bash
flutter pub get
flutter build macos
```

The built app will be in `build/macos/Build/Products/Release/PI Task Watch.app`

#### Windows
```bash
flutter pub get
flutter build windows
```

The built app will be in `build/windows/x64/runner/Release/`

### Cloud Build (GitHub Actions)

This repository includes GitHub Actions workflows that automatically build for multiple platforms:

1. **Push your code to GitHub**
2. **Go to the "Actions" tab** in your repository
3. **Run the "Build Multi-Platform" workflow** manually or it will run automatically on push
4. **Download the built apps** from the Artifacts section

The workflow builds:
- ✅ Windows (ZIP file)
- ✅ macOS (DMG file)

## Distribution Files

### For macOS Users
Send them: `PI_Task_Watch_macOS_v1.0.23.dmg`

### For Windows Users
Send them: `PI_Task_Watch_Windows_v1.0.23.zip`

## Installation

### macOS
1. Download the DMG file
2. Double-click to mount
3. Drag the app to Applications folder
4. Right-click and select "Open" (first time only, due to unsigned app)

### Windows
1. Download the ZIP file
2. Extract all files
3. Run `pi_task_watch.exe`

## Development

### Watch Rust Code Generation
```bash
flutter_rust_bridge_codegen generate --watch
```

### Package for Distribution
```bash
# macOS DMG
fastforge package --platform macos --targets dmg

# Windows EXE
fastforge package --platform windows --targets exe

# Linux DEB
fastforge package --platform linux --targets deb
```

## License
Proprietary - All rights reserved
