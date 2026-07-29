# PI Task Watch

Employee monitoring application with Odoo integration

## Version
1.0.39+39

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

#### Linux Environment
To build the Linux application locally inside your workspace, ensure you have the Flutter SDK, Rust, and compiler toolchain/GTK development libraries installed. Then, run the shell script:
```bash
./build-linux.sh
```
The script will automate the package setup, compile the Linux release binary, and generate the Debian (.deb) package.

*   **Release Executable Path**: `build/linux/x64/release/bundle/pi_task_watch`
*   **DEB Package Path**: `dist/linux/deb/pi-task-watch_1.0.39_amd64.deb`

### Cloud Build (GitHub Actions)

This repository includes a GitHub Actions workflow that builds all desktop platforms on pushes, pull requests, or manual runs. Pushing a version tag also publishes the packages permanently on the GitHub Releases page.

1. **Push your code to GitHub**
2. **Go to the "Actions" tab** in your repository
3. Select **"Build Task Watch for Windows, macOS, and Linux"**
4. Run the workflow manually, or let it run automatically on push.
5. **Download the built apps** from the Artifacts section at the bottom of the run.

To publish a release after updating the version in `pubspec.yaml`:

```bash
git tag v1.0.39
git push origin v1.0.39
```

The workflow automatically compiles and publishes:
- ✅ Windows ZIP Release & Installer (.exe)
- ✅ macOS ZIP Release & DMG Installer (.dmg)
- ✅ Linux ZIP Release & Debian Package (.deb)

### Code Signing Secrets (Optional but Recommended)

To produce signed, notarized binaries that install without warnings:

#### macOS — Required secrets

| Secret | Value |
|--------|-------|
| `MACOS_CERT_P12` | Base64-encoded `.p12` certificate from your Apple Developer account |
| `MACOS_CERT_PASSWORD` | Password protecting the `.p12` file |
| `MACOS_SIGNING_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAM_ID)` |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_APP_PASSWORD` | App-specific password from appleid.apple.com |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID |

Generate the `.p12` from Xcode: Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority.

#### Windows — Required secrets

| Secret | Value |
|--------|-------|
| `WINDOWS_CERT_PFX` | Base64-encoded `.pfx` code signing certificate |
| `WINDOWS_CERT_PASSWORD` | Password protecting the `.pfx` file |
| `WINDOWS_SIGNING_SUBJECT` | Certificate subject name (e.g. `"Your Company Ltd"`) |

If signing secrets are not configured, the workflow still builds successfully and produces unsigned artifacts.

## Distribution Files

### For macOS Users
Send them: `PI_Task_Watch_macOS_v1.0.39.dmg`

### For Windows Users
Send them: `PI_Task_Watch_Windows_v1.0.39.zip` or the Installer executable

### For Linux Users
Send them: `pi-task-watch_1.0.39_amd64.deb` or `PI_Task_Watch_Linux_v1.0.39.zip`

## Installation

### macOS
1. Download the DMG file
2. Double-click to mount
3. Drag the app to Applications folder
4. Right-click and select "Open" (first time only, due to unsigned app). **Signed builds skip this step.**

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
