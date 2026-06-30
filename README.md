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

#### macOS Environment
To build the macOS application locally inside your workspace, make sure you have the Flutter SDK, Xcode, and Rust installed. Then, simply execute the automated build script:
```bash
./build-macos.sh
```
The script will install package dependencies, compile the app bundle, and generate a ZIP archive/DMG installer.

*   **App Bundle Path**: `build/macos/Build/Products/Release/PI Task Watch.app`
*   **DMG Installer Path**: `dist/macos/dmg/PI Task Watch.dmg`

#### Windows Environment
To build the Windows application locally inside your workspace, ensure you have the Flutter SDK, Visual Studio (with C++ Desktop development), and Rust installed. Then, run the batch script:
```cmd
build-windows.bat
```
The script will automate the package setup, compile the Windows executable, and generate the Windows installer.

*   **Release Executable Path**: `build\windows\x64\runner\Release\pi_task_watch.exe`
*   **Installer Path**: `dist\windows\exe\PI Task Watch.exe`

### Cloud Build (GitHub Actions)

This repository includes a GitHub Actions workflow that automatically builds for multiple platforms on push to `main`/`master` or via manual triggers:

1. **Push your code to GitHub**
2. **Go to the "Actions" tab** in your repository
3. Select **"Build Task Watch for Windows and macOS"**
4. Run the workflow manually, or let it run automatically on push.
5. **Download the built apps** from the Artifacts section at the bottom of the run.

The workflow automatically compiles and publishes:
- ✅ Windows ZIP Release & Installer (.exe)
- ✅ macOS ZIP Release & DMG Installer (.dmg)

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
