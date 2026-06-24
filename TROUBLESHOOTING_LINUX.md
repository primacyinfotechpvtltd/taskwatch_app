# Troubleshooting TaskWatch on Linux (Zorin OS, Ubuntu, Mint)

If TaskWatch is not tracking your activity (time remains 0 or stays idle) or screenshots are failing on Zorin OS or other Linux distributions, please follow these steps.

## 1. Wayland vs Xorg (Most Common Issue)

Many modern Linux distributions (like Zorin OS 17 and Ubuntu 22.04+) use **Wayland** by default. For security reasons, Wayland prevents applications from monitoring global input (keyboard/mouse) or tracking other windows.

### Symptoms:
- App shows "Wayland Session Detected" warning.
- Mouse and keyboard activity is not detected.
- App constantly goes into "Idle Mode".
- Screenshots show a black screen or only the TaskWatch window.

### Solution:
Switch to **Xorg (X11)** session:
1. Logout of your current session.
2. At the login screen, select your user.
3. Click the **gear icon** (usually in the bottom right corner).
4. Select **"Zorin Desktop on Xorg"** or **"Ubuntu on Xorg"**.
5. Log in again.

## 2. Missing System Dependencies

TaskWatch requires certain system libraries to handle the tray icon and input monitoring.

### Solution:
Run the following command in your terminal:
```bash
sudo apt update
sudo apt install -y libayatana-appindicator3-1 libxtst6 libx11-6
```

## 3. Library Incompatibility (GLIBC)

If you are using a version of TaskWatch built on a newer system (like Ubuntu 24.04/25.10), it may not run on Zorin OS due to library version differences.

### Solution:
Use the compatible build for Zorin OS / Ubuntu 22.04:
- Download the version specifically marked for **Ubuntu 22.04**.
- If you are building from source, use the Docker build script:
  ```bash
  ./build-ubuntu22.sh
  ```

## 4. Screen Recording Permissions

On some Gnome-based systems (like Zorin OS), you may need to grant permission for screen recording.

### Solution:
- If a system dialog appears asking for screen recording permission, select **"Allow"**.
- Ensure `gnome-screenshot` is installed as a fallback: `sudo apt install gnome-screenshot`.
