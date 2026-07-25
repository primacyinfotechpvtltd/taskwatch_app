@echo off
:: PI Task Watch - Windows Local Build Script
:: Developed by Primacy Infotech

title PI Task Watch - Build for Windows
echo ===================================================
echo 🏗️  Building PI Task Watch for Windows Environment
echo ===================================================
echo.

:: 1. Check Prerequisites
echo 🔍 Checking prerequisites...

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter SDK is not installed or not in PATH!
    echo    Please install Flutter (v3.32.4 recommended) and add it to PATH.
    echo    https://docs.flutter.dev/get-started/install/windows
    pause
    exit /b 1
) else (
    echo   [✓] Flutter SDK detected.
)

where cargo >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Rust Cargo is not installed or not in PATH!
    echo    Please install Rust toolchain (stable) and add it to PATH.
    echo    https://www.rust-lang.org/tools/install
    pause
    exit /b 1
) else (
    echo   [✓] Rust / Cargo toolchain detected.
)

where python >nul 2>nul
if %errorlevel% neq 0 (
    echo ⚠️  Python is not installed or not in PATH.
    echo    Fastforge config generation might be skipped.
) else (
    echo   [✓] Python detected.
)

echo.
echo 📦 Getting Flutter dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Failed to fetch Flutter packages!
    pause
    exit /b 1
)

if exist generate_fastforge_configs.py (
    where python >nul 2>nul
    if %errorlevel% eq 0 (
        echo ⚙️  Generating packaging configurations...
        python generate_fastforge_configs.py
    )
)

echo.
echo 🔨 Building Windows Executable (Release)...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo ❌ Flutter Windows build failed!
    pause
    exit /b 1
)

echo.
echo 📦 Bundling MSVC C++ Runtime DLLs for Windows 10/11 compatibility...
powershell -Command "$ReleaseDir = 'build\windows\x64\runner\Release'; $RequiredDlls = @('msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'vcruntime140_threads.dll', 'vcomp140.dll'); foreach ($dll in $RequiredDlls) { $sysPath = 'C:\Windows\System32\' + $dll; if (Test-Path $sysPath) { Copy-Item -Path $sysPath -Destination (Join-Path $ReleaseDir $dll) -Force } }"

echo.
echo 🎉 Build successful!
echo.
echo 📂 Release folder is located at:
echo    build\windows\x64\runner\Release\
echo.
echo 💡 Inside this folder you will find:
echo    - pi_task_watch.exe (The application executable)
echo    - flutter_windows.dll
echo    - msvcp140.dll, vcruntime140.dll (Bundled C++ Runtimes for clean Windows 10/11 installs)
echo    - data/ (Application assets)
echo.
echo ⚠️  Note: When distributing, make sure to send the entire Release folder, not just the .exe!
echo.

:: Check if Fastforge is activated to package it
echo 📦 Attempting to compile Installer using Fastforge...
call dart pub global activate fastforge >nul 2>nul
call fastforge package --platform windows --targets exe >nul 2>nul
if %errorlevel% eq 0 (
    echo   [✓] Installer generated! Check: dist\windows\exe\
) else (
    echo   [i] Fastforge installer package skipped or failed.
    echo       You can manually zip the build\windows\x64\runner\Release\ folder.
)

echo.
echo ===================================================
echo Done!
echo ===================================================
pause
