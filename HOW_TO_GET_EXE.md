# 🪟 How to Get the Windows .exe File

## Quick Steps:

### 1️⃣ **Go to GitHub Actions**
Visit: https://github.com/primacyinfotechpvtltd/taskwatch_app/actions

### 2️⃣ **Find the Latest Successful Build**
- Look for a workflow run with a **green checkmark ✓**
- Click on it

### 3️⃣ **Scroll to Bottom - Find "Artifacts"**
- Scroll all the way down the page
- You'll see a section called **"Artifacts"**
- Look for: **`PI-Task-Watch-Windows-Installer`** or **`PI-Task-Watch-Windows-ZIP`**

### 4️⃣ **Download the ZIP File / Installer**
- Click on the artifact name to download
- The file contains: `PI_Task_Watch_Windows_v1.0.29.zip` or the Installer executable

### 5️⃣ **Extract and Find the .exe**
- Extract the ZIP file (or run the installer)
- Inside the extracted folder you'll find: **`pi_task_watch.exe`**
- This is your Windows executable!

---

## 📂 What's Inside the ZIP:

```
PI_Task_Watch_Windows_v1.0.29.zip
├── pi_task_watch.exe          ← This is the main app!
├── flutter_windows.dll
├── data/
│   └── (app data files)
└── (other DLL files)
```

---

## 🚀 To Share with Employees:

**Option 1: Share the Entire ZIP / Installer**
- Send them the downloaded ZIP file or Installer executable
- They extract it and run `pi_task_watch.exe` or complete the installer

**Option 2: Share the GitHub Link**
- Send them: https://github.com/primacyinfotechpvtltd/taskwatch_app/actions
- They follow steps 2-5 above

---

## ⚠️ Important Notes:

1. **All files needed**: If sharing the ZIP, don't just copy the .exe alone - you need ALL files from the ZIP
2. **Keep together**: All files must stay in the same folder
3. **Run from folder**: Double-click `pi_task_watch.exe` to run the app

---

## 🔍 Can't Find the Artifact?

If you don't see artifacts, the build might still be running or failed:
- **Yellow circle** = Build is still running (wait a few minutes)
- **Red X** = Build failed (check the logs)
- **Green checkmark** = Build succeeded (artifacts available)

---

## 💡 Alternative: Build Locally on Windows

If you have access to a Windows computer with Git, Flutter, and Rust:

```bash
# On Windows machine:
git clone https://github.com/primacyinfotechpvtltd/taskwatch_app.git
cd taskwatch_app
# Run the automated build script
build-windows.bat
```

The .exe will be in: `build\windows\x64\runner\Release\pi_task_watch.exe`
