# 🪟 How to Get the Windows .exe File

## Quick Steps:

### 1️⃣ **Go to GitHub Actions**
Visit: https://github.com/spandanhalder8100-tech/pi-task-watch/actions

### 2️⃣ **Find the Latest Successful Build**
- Look for a workflow run with a **green checkmark ✓**
- The name should be "Fix Dart SDK version for GitHub Actions compatibility" or similar
- Click on it

### 3️⃣ **Scroll to Bottom - Find "Artifacts"**
- Scroll all the way down the page
- You'll see a section called **"Artifacts"**
- Look for: **`PI-Task-Watch-Windows`** or **`windows-build`**

### 4️⃣ **Download the ZIP File**
- Click on the artifact name to download
- File will be named something like: `PI_Task_Watch_Windows_v1.0.23.zip`

### 5️⃣ **Extract and Find the .exe**
- Extract the ZIP file
- Inside you'll find: **`pi_task_watch.exe`**
- This is your Windows executable!

---

## 📂 What's Inside the ZIP:

```
PI_Task_Watch_Windows_v1.0.23.zip
├── pi_task_watch.exe          ← This is the main app!
├── flutter_windows.dll
├── data/
│   └── (app data files)
└── (other DLL files)
```

---

## 🚀 To Share with Employees:

**Option 1: Share the Entire ZIP**
- Send them the downloaded ZIP file
- They extract it and run `pi_task_watch.exe`

**Option 2: Share the GitHub Link**
- Send them: https://github.com/spandanhalder8100-tech/pi-task-watch/actions
- They follow steps 2-5 above

**Option 3: Use the Download Website**
- Send them: https://spandanhalder8100-tech.github.io/pi-task-watch/
- They click Windows and follow instructions

---

## ⚠️ Important Notes:

1. **All files needed**: Don't just copy the .exe alone - you need ALL files from the ZIP
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

If you have access to a Windows computer:

```bash
# On Windows machine:
git clone https://github.com/spandanhalder8100-tech/pi-task-watch.git
cd pi-task-watch
flutter pub get
flutter build windows --release
```

The .exe will be in: `build\windows\x64\runner\Release\pi_task_watch.exe`
