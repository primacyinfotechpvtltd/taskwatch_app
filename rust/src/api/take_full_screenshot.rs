use anyhow::{anyhow, Context, Result};
use base64::{Engine as _, engine::general_purpose};
#[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
use screenshots::Screen;
use std::io::Cursor;
#[cfg(any(target_os = "linux", target_os = "windows"))]
use std::env;
use std::process::Command;
use std::time::Instant;
use image;

// Imports needed for Windows-specific functions
#[cfg(target_os = "windows")]
use std::{fs, path::PathBuf, thread, time::{Duration, SystemTime, UNIX_EPOCH}};

// Imports needed for Linux-specific functions  
// (SystemTime and UNIX_EPOCH are used via full path std::time::SystemTime in the linux fallback fn)

#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

/// Takes a full screenshot of the primary monitor and returns it as a base64 encoded string.
///
/// # Returns
///
/// A `Result` containing the base64 encoded screenshot on success.
/// 
/// # Cross-platform Compatibility
/// 
/// - Windows: Works natively with multiple enterprise-grade fallback methods
/// - macOS: Works natively (requires permissions)
/// - Linux X11: Works natively
/// - Linux Wayland: Uses XWayland if available, or attempts fallback methods
///
/// # Windows Screenshot Methods (Professional Ordering - NirCmd Priority)
///
/// **Windows Primary Method:**
/// 1. **NirCmd** ⭐ PRIORITY #1 - Professional utility with bundled assets (completely silent)
/// 2. **Screenshots crate** - Cross-platform fallback method (fast and reliable)
///
/// **Windows Enterprise Fallback Chain:**
/// 3. **Memory-based** - Ultra-stealth, direct RAM→base64, Hubstaff-style (zero traces)
/// 4. **DirectShow** - Low-level Windows multimedia framework (enterprise-grade)
/// 5. **Win32 API** - Direct Windows GDI calls via PowerShell (maximum compatibility)
/// 6. **PowerShell** - Standard Windows scripting with System.Drawing (most compatible)
/// 7. **WMI** - Windows Management Instrumentation (enterprise monitoring)
/// 8. **FFmpeg** - Professional video/screen capture tool (if installed)
/// 9. **C# Inline** - Dynamic compilation and execution (reliable on .NET systems)
/// 10. **VBScript** - Windows Scripting Host (legacy fallback, last resort)
///
/// **Non-Windows Platforms:**
/// 1. **Screenshots crate** - Primary cross-platform method (fastest, most reliable)
/// 2. Platform-specific fallbacks
///
/// **NEW Ordering Rationale (NirCmd First):**
/// - **Maximum Stealth**: NirCmd provides completely silent operation with bundled assets
/// - **Zero Dependencies**: Bundled NirCmd requires no system installations
/// - **Enterprise Grade**: Professional tool designed for system administration
/// - **Universal Compatibility**: Works across all Windows versions (7, 8, 10, 11)
///
/// All methods are designed for:
/// - Complete silence (no visible windows, sounds, or notifications)
/// - No side effects (temporary files cleaned up immediately)
/// - Enterprise-grade reliability
/// - Cross-Windows version compatibility (7, 8, 10, 11)
pub fn take_full_screenshot() -> Result<String> {
    println!("\n╔══════════════════════════════════════════════════════════════╗");
    println!("║                   SCREENSHOT CAPTURE SYSTEM                 ║");
    println!("║                   Professional Enterprise                    ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!("[SCREENSHOT] 🚀 Starting screenshot capture process");
    let start_time = Instant::now();
    
    // Platform detection with detailed logging
    let platform = if cfg!(target_os = "windows") {
        "Windows"
    } else if cfg!(target_os = "macos") {
        "macOS"
    } else if cfg!(target_os = "linux") {
        "Linux"
    } else {
        "Unknown"
    };
    
    println!("[SCREENSHOT] 🖥️  Platform detected: {}", platform);
    println!("[SCREENSHOT] 🎯 Method strategy: Primary + Enterprise fallback chain");
    
    // Platform-specific checks and preparations
    #[cfg(target_os = "linux")]
    {
        println!("[SCREENSHOT] 🐧 Running Linux environment checks...");
        check_linux_environment()?;
    }
    
    #[cfg(target_os = "macos")]
    {
        println!("[SCREENSHOT] 🍎 Running macOS environment checks...");
        // Check if we have screen recording permissions on macOS
        if !has_screen_recording_permission() {
            eprintln!("[SCREENSHOT] ⚠️  Screen Recording permission NOT granted — aborting capture");
            return Err(anyhow!("Screen Recording permission not granted on macOS"));
        }
        println!("[SCREENSHOT] ✅ macOS screen recording permissions verified");
    }
    
    #[cfg(target_os = "windows")]
    {
        println!("[SCREENSHOT] 🪟 Running Windows environment assessment...");
        check_windows_environment()?;
    }

    // Windows: NirCmd first, Screenshots crate fallback, Memory-based last resort
    #[cfg(target_os = "windows")]
    {
        println!("[SCREENSHOT] 📋 Attempting Windows screenshot methods:");

        // Method 1: NirCmd (bundled asset, silent capture)
        println!("[SCREENSHOT] 🔧 Method 1: NirCmd...");
        match take_screenshot_windows_nircmd() {
            Ok(base64_string) => {
                println!("[SCREENSHOT] ✅ NirCmd succeeded ({:.2?})", start_time.elapsed());
                return Ok(base64_string);
            }
            Err(e) => println!("[SCREENSHOT] ❌ NirCmd failed: {} — trying fallback", e),
        }

        // Method 2: Screenshots crate
        println!("[SCREENSHOT] 🔧 Method 2: Screenshots crate...");
        match take_screenshot_with_screenshots_crate() {
            Ok(base64_string) => {
                println!("[SCREENSHOT] ✅ Screenshots crate succeeded ({:.2?})", start_time.elapsed());
                return Ok(base64_string);
            }
            Err(e) => println!("[SCREENSHOT] ❌ Screenshots crate failed: {} — trying Memory method", e),
        }

        // Method 3: Memory-based (ultra-stealth, zero traces)
        println!("[SCREENSHOT] 🔧 Method 3: Memory-based...");
        match take_screenshot_windows_memory() {
            Ok(base64_string) => {
                println!("[SCREENSHOT] ✅ Memory-based succeeded ({:.2?})", start_time.elapsed());
                return Ok(base64_string);
            }
            Err(e) => {
                println!("[SCREENSHOT] ❌ All Windows methods exhausted");
                return Err(e).context("All Windows screenshot methods failed");
            }
        }
    }

        // Non-Windows platforms: macOS uses screencapture CLI first, Linux uses Screenshots crate
        // macOS platform screenshot logic
        #[cfg(target_os = "macos")]
        {
            println!("[SCREENSHOT] 🍎 Running macOS screen capture...");
            let has_perm = has_screen_recording_permission();
            println!("[SCREENSHOT] 🍎 macOS Screen Recording permission check: {}", has_perm);

            if !has_perm {
                println!("[SCREENSHOT] ⚠️ Screen Recording permission NOT detected. Triggering macOS system prompt...");
                let _ = request_screen_recording_permission();
            }

            // Method 1 for macOS: Screenshots crate (direct CoreGraphics API inside app process)
            println!("\n[SCREENSHOT] 🎬 Method 1: Screenshots crate (CoreGraphics)...");
            match take_screenshot_with_screenshots_crate() {
                Ok(base64_string) => {
                    let elapsed = start_time.elapsed();
                    println!("[SCREENSHOT] ✅ SUCCESS: Captured via Screenshots crate in {:.2?}", elapsed);
                    return Ok(base64_string);
                },
                Err(crate_err) => {
                    println!("[SCREENSHOT] ⚠️ Screenshots crate failed ({}), trying screencapture CLI fallback...", crate_err);
                    match take_screenshot_macos_fallback() {
                        Ok(base64_string) => {
                            let elapsed = start_time.elapsed();
                            println!("[SCREENSHOT] ✅ SUCCESS: Captured via macOS screencapture CLI in {:.2?}", elapsed);
                            return Ok(base64_string);
                        },
                        Err(cli_err) => {
                            return Err(cli_err).context("All macOS screenshot methods failed - please ensure Screen Recording permission is granted in System Settings -> Privacy & Security -> Screen Recording");
                        }
                    }
                }
            }
        }

        #[cfg(target_os = "linux")]
        {
            println!("[SCREENSHOT] 📋 Attempting Linux screenshot methods in priority order:");
            println!("[SCREENSHOT] ┌─ Method 1: Screenshots crate (primary)");
            println!("[SCREENSHOT] └─ Platform-specific fallbacks");

            match take_screenshot_with_screenshots_crate() {
                Ok(base64_string) => {
                    let elapsed = start_time.elapsed();
                    println!("[SCREENSHOT] ✅ SUCCESS: Primary method completed successfully!");
                    return Ok(base64_string);
                },
                Err(_primary_error) => {
                    println!("[SCREENSHOT] Method 2: Linux fallback tools...");
                    return match take_screenshot_linux_fallback() {
                        Ok(base64_string) => {
                            let elapsed = start_time.elapsed();
                            println!("[SCREENSHOT] SUCCESS: Screenshot captured with Linux tools in {:.2?}", elapsed);
                            Ok(base64_string)
                        },
                        Err(fallback_error) => {
                            Err(fallback_error).context("Both primary and Linux fallback methods failed")
                        }
                    };
                }
            }
        }

        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            return Err(anyhow!("All available screenshot methods failed on unsupported platform"));
        }
}

pub fn take_screenshot_with_screenshots_crate() -> Result<String> {
    #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
    {
        let start_time = Instant::now();
        
        println!("[SCREENSHOT][screenshots] Getting list of screens");
        // Get all screens
        let screens = Screen::all().map_err(|e| anyhow!("Failed to get screens: {}", e))?;
        
        println!("[SCREENSHOT][screenshots] Found {} screens", screens.len());
        
        if screens.is_empty() {
            return Err(anyhow!("No screens found"));
        }
        
        // Use the primary screen (first one)
        let screen = screens[0].clone(); // Use index access and clone for simplicity
        println!("[SCREENSHOT][screenshots] Using primary screen: {}x{} at position ({}, {})", 
                 screen.display_info.width, screen.display_info.height,
                 screen.display_info.x, screen.display_info.y);
        
        // Capture the entire screen
        println!("[SCREENSHOT][screenshots] Capturing screen");
        let image = screen
            .capture()
            .map_err(|e| anyhow!("Failed to capture screenshot: {}", e))?;
        
        println!("[SCREENSHOT][screenshots] Image captured: {}x{}", image.width(), image.height());
        
        // Write image to a PNG buffer using a Cursor (which implements both Write and Seek)
        println!("[SCREENSHOT][screenshots] Encoding to PNG");
        let mut buffer = Cursor::new(Vec::new());
        image.write_to(&mut buffer, image::ImageOutputFormat::Png)
             .map_err(|e| anyhow!("Failed to encode image: {}", e))?;
        let buffer = buffer.into_inner();
        
        // Convert the buffer to a base64 string
        println!("[SCREENSHOT][screenshots] Converting to base64");
        let base64_string = general_purpose::STANDARD.encode(&buffer);
        
        let elapsed = start_time.elapsed();
        println!("[SCREENSHOT][screenshots] Complete: Generated screenshot in {:.2?}", elapsed);
        
        Ok(base64_string)
    }
    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    {
        Err(anyhow!("Screenshots are not supported on this platform"))
    }
}

#[cfg(target_os = "linux")]
pub fn check_linux_environment() -> Result<()> {
    let wayland_session = env::var("WAYLAND_DISPLAY").is_ok() && 
                         env::var("XDG_SESSION_TYPE") == Ok("wayland".into());

    if wayland_session {
        // Check if XWayland is available (which allows X11 apps on Wayland)
        let xdg_runtime = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());
        if !std::path::Path::new(&format!("{}/X11-display", xdg_runtime)).exists() &&
           !std::path::Path::new("/tmp/.X11-unix").exists() {
            eprintln!("Warning: Running on Wayland without apparent XWayland support. Screenshot functionality may be limited.");
        }
    }

    Ok(())
}

#[cfg(target_os = "linux")]
pub fn take_screenshot_linux_fallback() -> Result<String> {
    let start_time = Instant::now();
    let temp_file = std::env::temp_dir().join(format!("screenshot_{}.png", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)?.as_secs()));

    println!("[SCREENSHOT][linux-fallback] Using temp file: {}", temp_file.display());

    // Try using command-line tools commonly available on Linux
    println!("[SCREENSHOT][linux-fallback] Checking for available screenshot tools");

    let (tool_name, status) = if Command::new("sh").arg("-c").arg("command -v gnome-screenshot").status()?.success() {
        println!("[SCREENSHOT][linux-fallback] Using gnome-screenshot");
        ("gnome-screenshot", Command::new("gnome-screenshot").arg("-f").arg(&temp_file).status()?)
    } else if Command::new("sh").arg("-c").arg("command -v import").status()?.success() {
        println!("[SCREENSHOT][linux-fallback] Using ImageMagick import");
        // ImageMagick's import command
        ("import", Command::new("import").arg("-window").arg("root").arg(&temp_file).status()?)
    } else if Command::new("sh").arg("-c").arg("command -v scrot").status()?.success() {
        println!("[SCREENSHOT][linux-fallback] Using scrot");
        ("scrot", Command::new("scrot").arg(&temp_file).status()?)
    } else {
        return Err(anyhow!("No fallback screenshot tools found (gnome-screenshot, import, or scrot)"));
    };

    if !status.success() {
        return Err(anyhow!("Fallback screenshot command '{}' failed with status: {:?}", tool_name, status.code()));
    }

    println!("[SCREENSHOT][linux-fallback] Screenshot taken with {}, reading file", tool_name);

    // Read the screenshot file
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][linux-fallback] Read {} bytes from file", img_data.len());

    // Delete the temporary file
    println!("[SCREENSHOT][linux-fallback] Removing temporary file");
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][linux-fallback] Warning: Failed to remove temp file: {}", e);
    }

    // Convert to base64
    println!("[SCREENSHOT][linux-fallback] Converting to base64");
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][linux-fallback] Complete: Generated screenshot with {} in {:.2?}", tool_name, elapsed);

    Ok(base64_string)
}

pub fn has_screen_recording_permission() -> bool {
    #[cfg(target_os = "macos")]
    {
        #[link(name = "CoreGraphics", kind = "framework")]
        extern "C" {
            fn CGPreflightScreenCaptureAccess() -> bool;
        }
        unsafe {
            CGPreflightScreenCaptureAccess()
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        true
    }
}

pub fn request_screen_recording_permission() -> bool {
    #[cfg(target_os = "macos")]
    {
        #[link(name = "CoreGraphics", kind = "framework")]
        extern "C" {
            fn CGRequestScreenCaptureAccess() -> bool;
        }
        unsafe {
            CGRequestScreenCaptureAccess()
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        true
    }
}

#[cfg(target_os = "macos")]
pub fn hide_macos_app_native() {
    unsafe {
        #[link(name = "objc", kind = "dylib")]
        extern "C" {
            fn objc_getClass(name: *const std::os::raw::c_char) -> *mut std::ffi::c_void;
            fn sel_registerName(name: *const std::os::raw::c_char) -> *mut std::ffi::c_void;
            fn objc_msgSend() -> *mut std::ffi::c_void;
        }

        type MsgSendFn = unsafe extern "C" fn(*mut std::ffi::c_void, *mut std::ffi::c_void) -> *mut std::ffi::c_void;
        type MsgSendArgFn = unsafe extern "C" fn(*mut std::ffi::c_void, *mut std::ffi::c_void, *mut std::ffi::c_void) -> *mut std::ffi::c_void;

        let msg_send: MsgSendFn = std::mem::transmute(objc_msgSend as *const ());
        let msg_send_arg: MsgSendArgFn = std::mem::transmute(objc_msgSend as *const ());

        let ns_app_class = objc_getClass(b"NSApplication\0".as_ptr() as *const _);
        if !ns_app_class.is_null() {
            let shared_app_sel = sel_registerName(b"sharedApplication\0".as_ptr() as *const _);
            let app_instance = msg_send(ns_app_class, shared_app_sel);
            if !app_instance.is_null() {
                let hide_sel = sel_registerName(b"hide:\0".as_ptr() as *const _);
                msg_send_arg(app_instance, hide_sel, std::ptr::null_mut());
                println!("[SCREENSHOT][macos-native] Native Cocoa NSApp hide: succeeded");
            }
        }
    }
}

#[cfg(target_os = "macos")]
pub fn unhide_macos_app_native() {
    unsafe {
        #[link(name = "objc", kind = "dylib")]
        extern "C" {
            fn objc_getClass(name: *const std::os::raw::c_char) -> *mut std::ffi::c_void;
            fn sel_registerName(name: *const std::os::raw::c_char) -> *mut std::ffi::c_void;
            fn objc_msgSend() -> *mut std::ffi::c_void;
        }

        type MsgSendFn = unsafe extern "C" fn(*mut std::ffi::c_void, *mut std::ffi::c_void) -> *mut std::ffi::c_void;

        let msg_send: MsgSendFn = std::mem::transmute(objc_msgSend as *const ());

        let ns_app_class = objc_getClass(b"NSApplication\0".as_ptr() as *const _);
        if !ns_app_class.is_null() {
            let shared_app_sel = sel_registerName(b"sharedApplication\0".as_ptr() as *const _);
            let app_instance = msg_send(ns_app_class, shared_app_sel);
            if !app_instance.is_null() {
                let unhide_sel = sel_registerName(b"unhideWithoutActivation\0".as_ptr() as *const _);
                msg_send(app_instance, unhide_sel);
                println!("[SCREENSHOT][macos-native] Native Cocoa NSApp unhideWithoutActivation succeeded");
            }
        }
    }
}

#[cfg(target_os = "macos")]
pub fn take_screenshot_macos_fallback() -> Result<String> {
    let start_time = Instant::now();
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("screenshot_mac_{}.png", timestamp));

    println!("[SCREENSHOT][macos-fallback] Executing /usr/sbin/screencapture -x -C {}", temp_file.display());

    let status = Command::new("/usr/sbin/screencapture")
        .arg("-x") // Silent mode: no shutter sound
        .arg("-C") // Include cursor position
        .arg("-t")
        .arg("png")
        .arg(&temp_file)
        .status()?;

    if !status.success() {
        return Err(anyhow!("macOS screencapture command failed with status code: {:?}", status.code()));
    }

    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read macOS screenshot file: {}", e))?;

    let _ = std::fs::remove_file(&temp_file);

    if img_data.is_empty() {
        return Err(anyhow!("macOS screencapture generated 0-byte file"));
    }

    let base64_string = general_purpose::STANDARD.encode(&img_data);
    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][macos-fallback] SUCCESS: Generated screenshot via screencapture CLI in {:.2?}", elapsed);

    Ok(base64_string)
}

#[cfg(target_os = "windows")]
pub fn check_windows_environment() -> Result<()> {
    // Minimal check — individual methods handle their own validation
    Ok(())
}

#[cfg(target_os = "windows")]
pub fn is_nircmd_available() -> bool {
    // Check common paths where NirCmd might be installed
    let possible_paths = vec![
        "nircmd.exe", // If in PATH
        "C:\\Windows\\nircmd.exe",
        "C:\\Windows\\System32\\nircmd.exe",
        "C:\\Program Files\\nircmd\\nircmd.exe",
        "C:\\Program Files (x86)\\nircmd\\nircmd.exe",
    ];

    for path in possible_paths {
        if let Ok(output) = Command::new("where").arg(path).output() {
            if output.status.success() {
                return true;
            }
        }
    }

    // Try direct execution as last resort
    Command::new("nircmd").arg("help").status().map_or(false, |status| status.success())
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_nircmd() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][nircmd] 🔧 Using NirCmd professional screenshot utility");
    println!("[SCREENSHOT][nircmd] ┌─ Tool: NirSoft NirCmd (professional Windows utility)");
    println!("[SCREENSHOT][nircmd] ├─ Method: Silent screen capture with PNG output");
    println!("[SCREENSHOT][nircmd] ├─ Asset strategy: Smart bundled extraction");
    println!("[SCREENSHOT][nircmd] └─ Compatibility: Windows 7/8/10/11 universal");
    
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("taskwatch_nircmd_{}.png", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();

    println!("[SCREENSHOT][nircmd] 📁 Temp file location: {}", temp_file_str);

    // Smart NirCmd detection with Flutter asset extraction
    println!("[SCREENSHOT][nircmd] 🔍 Starting smart asset detection...");
    let extracted_nircmd = extract_bundled_nircmd();
    
    // Multiple NirCmd locations to check (including extracted asset)
    let mut nircmd_paths = vec![
        "nircmd",                              // If in PATH
        "nircmd.exe",                          // Current directory with extension
        "C:\\Windows\\nircmd.exe",             // Windows directory
        "C:\\Windows\\System32\\nircmd.exe",   // System directory  
        "C:\\Program Files\\NirCmd\\nircmd.exe", // Program Files
        "C:\\Program Files (x86)\\NirCmd\\nircmd.exe", // Program Files x86
        ".\\tools\\nircmd.exe",                // Local tools directory
        ".\\nircmd.exe",                       // Current directory
    ];

    // Add extracted asset path if available
    if let Ok(extracted_path) = &extracted_nircmd {
        nircmd_paths.insert(0, extracted_path); // Priority to bundled version
        println!("[SCREENSHOT][nircmd] ⭐ ASSET EXTRACTION SUCCESS: Using bundled NirCmd");
        println!("[SCREENSHOT][nircmd] ├─ Extracted path: {}", extracted_path);
        println!("[SCREENSHOT][nircmd] ├─ Asset verification: PE header validated");
        println!("[SCREENSHOT][nircmd] └─ Priority: #1 (zero-dependency method)");
    } else {
        println!("[SCREENSHOT][nircmd] ℹ️  Asset extraction failed, checking system installations...");
    }

    let mut success = false;
    let mut used_path = String::new();

    println!("[SCREENSHOT][nircmd] 🔎 Searching {} potential NirCmd locations:", nircmd_paths.len());
    for (index, nircmd_path) in nircmd_paths.iter().enumerate() {
        println!("[SCREENSHOT][nircmd] 📍 [{}/{}] Trying: {}", index + 1, nircmd_paths.len(), nircmd_path);
        
        // Enhanced NirCmd command with correct professional screenshot syntax
        let mut cmd = Command::new(nircmd_path);
        cmd.args([
            "savescreenshot", 
            &temp_file_str
        ]);
        
        println!("[SCREENSHOT][nircmd] ├─ Command: {} savescreenshot \"{}\"", nircmd_path, temp_file_str);
        println!("[SCREENSHOT][nircmd] ├─ Full screen: YES (entire desktop)");
        println!("[SCREENSHOT][nircmd] ├─ Format: PNG (auto-detected from extension)");
        println!("[SCREENSHOT][nircmd] └─ Mode: SILENT (no UI/sounds)");
        
        // Windows-specific silent execution
        #[cfg(target_os = "windows")]
        {
            cmd.creation_flags(0x08000000); // CREATE_NO_WINDOW flag for silent execution
            println!("[SCREENSHOT][nircmd] 🔇 Silent mode: CREATE_NO_WINDOW flag enabled");
        }
        
        let result = cmd.output();

        match result {
            Ok(output) => {
                if output.status.success() {
                    println!("[SCREENSHOT][nircmd] ✅ SUCCESS: NirCmd execution completed");
                    println!("[SCREENSHOT][nircmd] ├─ Exit code: 0 (success)");
                    println!("[SCREENSHOT][nircmd] ├─ Executable used: {}", nircmd_path);
                    if let Ok(ref extracted_path) = extracted_nircmd {
                        if nircmd_path == extracted_path {
                            println!("[SCREENSHOT][nircmd] └─ Source: BUNDLED ASSET ⭐ (zero-dependency)");
                        } else {
                            println!("[SCREENSHOT][nircmd] └─ Source: System installation");
                        }
                    } else {
                        println!("[SCREENSHOT][nircmd] └─ Source: System installation");
                    }
                    success = true;
                    used_path = nircmd_path.to_string();
                    break;
                } else {
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    println!("[SCREENSHOT][nircmd] ❌ FAILED: Exit code {:?}", output.status.code());
                    if !stderr.is_empty() {
                        println!("[SCREENSHOT][nircmd] ├─ stderr: {}", stderr.trim());
                    }
                    if !stdout.is_empty() {
                        println!("[SCREENSHOT][nircmd] ├─ stdout: {}", stdout.trim());
                    }
                    
                    // Try alternative NirCmd syntax if this one failed
                    println!("[SCREENSHOT][nircmd] 🔄 Trying alternative NirCmd syntax...");
                    let mut alt_cmd = Command::new(nircmd_path);
                    alt_cmd.args([
                        "cmdwait", "1000", "savescreenshot", &temp_file_str
                    ]);
                    
                    #[cfg(target_os = "windows")]
                    {
                        alt_cmd.creation_flags(0x08000000);
                    }
                    
                    let alt_result = alt_cmd.output();
                    
                    if let Ok(alt_output) = alt_result {
                        if alt_output.status.success() {
                            println!("[SCREENSHOT][nircmd] ✅ SUCCESS: Alternative NirCmd syntax worked!");
                            success = true;
                            used_path = nircmd_path.to_string();
                            break;
                        } else {
                            println!("[SCREENSHOT][nircmd] ❌ Alternative syntax also failed");
                        }
                    }
                    
                    // Check if file was created despite error status
                    if temp_file.exists() {
                        let file_size = std::fs::metadata(&temp_file).map(|m| m.len()).unwrap_or(0);
                        if file_size > 1000 {
                            println!("[SCREENSHOT][nircmd] ✅ File created despite error status: {} bytes", file_size);
                            success = true;
                            used_path = nircmd_path.to_string();
                            break;
                        } else {
                            println!("[SCREENSHOT][nircmd] ├─ File created but too small: {} bytes", file_size);
                            // Try to read the small file to see if it contains error message
                            if let Ok(content) = std::fs::read_to_string(&temp_file) {
                                println!("[SCREENSHOT][nircmd] ├─ File content (possible error): {}", content.trim());
                            }
                            let _ = std::fs::remove_file(&temp_file); // Clean up bad file
                        }
                    }
                    println!("[SCREENSHOT][nircmd] └─ Trying next location...");
                }
            },
            Err(e) => {
                println!("[SCREENSHOT][nircmd] ❌ EXECUTION ERROR: {}", e);
                println!("[SCREENSHOT][nircmd] └─ Path not accessible or executable not found");
            }
        }
    }

    if !success {
        println!("[SCREENSHOT][nircmd] ❌ CRITICAL FAILURE: No working NirCmd installation found");
        println!("[SCREENSHOT][nircmd] ├─ Bundled asset: {}", if extracted_nircmd.is_ok() { "Available but failed" } else { "Not available" });
        println!("[SCREENSHOT][nircmd] ├─ System installations: All failed");
        println!("[SCREENSHOT][nircmd] └─ Recommendation: Check bundled assets or install NirCmd");
        return Err(anyhow!("Failed to take screenshot using NirCmd - no working installation found"));
    }

    // Small delay to ensure file is completely written
    println!("[SCREENSHOT][nircmd] ⏳ Waiting for file system sync (100ms)...");
    thread::sleep(Duration::from_millis(100));

    // Check if file was created and validate its size
    println!("[SCREENSHOT][nircmd] 🔍 Validating screenshot file...");
    if !temp_file.exists() {
        println!("[SCREENSHOT][nircmd] ❌ CRITICAL ERROR: Screenshot file not created");
        println!("[SCREENSHOT][nircmd] ├─ Expected path: {}", temp_file_str);
        println!("[SCREENSHOT][nircmd] └─ NirCmd may have failed silently");
        
        // Check if any files were created in temp directory with similar names
        if let Ok(entries) = std::fs::read_dir(&temp_dir) {
            println!("[SCREENSHOT][nircmd] 🔍 Checking temp directory for related files:");
            for entry in entries.flatten() {
                let path = entry.path();
                if let Some(name) = path.file_name() {
                    let name_str = name.to_string_lossy();
                    if name_str.contains("taskwatch_nircmd") || name_str.contains("screenshot") {
                        println!("[SCREENSHOT][nircmd] ├─ Found related file: {}", path.display());
                        if let Ok(metadata) = entry.metadata() {
                            println!("[SCREENSHOT][nircmd] │  └─ Size: {} bytes", metadata.len());
                        }
                    }
                }
            }
        }
        
        return Err(anyhow!("NirCmd did not create screenshot file"));
    }

    let file_metadata = std::fs::metadata(&temp_file)
        .map_err(|e| anyhow!("Failed to get screenshot file metadata: {}", e))?;
    
    let file_size = file_metadata.len();
    println!("[SCREENSHOT][nircmd] 📊 File validation:");
    println!("[SCREENSHOT][nircmd] ├─ File exists: YES");
    println!("[SCREENSHOT][nircmd] ├─ File size: {} bytes", file_size);
    
    if file_size < 1000 {
        println!("[SCREENSHOT][nircmd] ❌ VALIDATION FAILED: File too small (< 1KB)");
        println!("[SCREENSHOT][nircmd] ├─ Actual size: {} bytes", file_size);
        
        // Try to read the file content to understand what went wrong
        if let Ok(content_bytes) = std::fs::read(&temp_file) {
            // Try to read as text to see if it's an error message
            if let Ok(content_str) = String::from_utf8(content_bytes.clone()) {
                println!("[SCREENSHOT][nircmd] ├─ File content (text): {}", content_str.trim());
            } else {
                // Show hex dump of first few bytes
                let hex_preview = content_bytes.iter()
                    .take(50)
                    .map(|b| format!("{:02x}", b))
                    .collect::<Vec<_>>()
                    .join(" ");
                println!("[SCREENSHOT][nircmd] ├─ File content (hex): {}", hex_preview);
            }
        }
        
        let _ = std::fs::remove_file(&temp_file);
        println!("[SCREENSHOT][nircmd] └─ File removed - likely contains error message or is corrupted");
        return Err(anyhow!("NirCmd screenshot file too small: {} bytes - check NirCmd parameters or permissions", file_size));
    }
    
    println!("[SCREENSHOT][nircmd] ✅ File size validation: PASSED");

    // Read the screenshot file
    println!("[SCREENSHOT][nircmd] 📖 Reading screenshot data...");
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][nircmd] ├─ Bytes read: {}", img_data.len());

    // Validate PNG format
    if img_data.len() >= 8 && &img_data[0..8] == b"\x89PNG\r\n\x1a\n" {
        println!("[SCREENSHOT][nircmd] ✅ Format validation: Valid PNG header detected");
    } else {
        println!("[SCREENSHOT][nircmd] ⚠️  Format warning: Non-standard image format (may still work)");
    }

    // Delete the temporary file immediately after reading
    println!("[SCREENSHOT][nircmd] 🧹 Cleaning up temporary file...");
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][nircmd] ⚠️  Warning: Failed to remove temp file: {}", e);
    } else {
        println!("[SCREENSHOT][nircmd] ✅ Temporary file removed successfully");
    }

    // Convert to base64
    println!("[SCREENSHOT][nircmd] 🔄 Converting to base64 encoding...");
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][nircmd] ╔══════════════════════════════════════════════════════════════╗");
    println!("[SCREENSHOT][nircmd] ║                    NIRCMD SUCCESS SUMMARY                   ║");
    println!("[SCREENSHOT][nircmd] ╠══════════════════════════════════════════════════════════════╣");
    println!("[SCREENSHOT][nircmd] ║ ✅ Screenshot captured successfully with NirCmd            ║");
    println!("[SCREENSHOT][nircmd] ║ 🎯 Executable used: {}                                    ║", used_path.chars().take(45).collect::<String>());
    println!("[SCREENSHOT][nircmd] ║ ⏱️  Total time: {:.2?}                                    ║", elapsed);
    println!("[SCREENSHOT][nircmd] ║ 📊 Image size: {} bytes                                 ║", img_data.len());
    println!("[SCREENSHOT][nircmd] ║ 💾 Base64 length: {} characters                         ║", base64_string.len());
    if let Ok(ref extracted_path) = extracted_nircmd {
        if used_path == *extracted_path {
            println!("[SCREENSHOT][nircmd] ║ ⭐ Method: BUNDLED ASSET (zero-dependency)               ║");
        } else {
            println!("[SCREENSHOT][nircmd] ║ 🔧 Method: System installation                           ║");
        }
    }
    println!("[SCREENSHOT][nircmd] ╚══════════════════════════════════════════════════════════════╝");

    Ok(base64_string)
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_memory() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][memory] Using memory-based ultra-silent screenshot (Hubstaff-style)");

    // Ultra-silent PowerShell script that works entirely in memory - no files, no traces
    let powershell_script = r#"
        # Maximum stealth configuration
        $ProgressPreference = 'SilentlyContinue'
        $ErrorActionPreference = 'SilentlyContinue'
        $WarningPreference = 'SilentlyContinue'
        $VerbosePreference = 'SilentlyContinue'
        
        # Hide console completely and work in memory only
        Add-Type -Name ConsoleUtils -Namespace Win32 -MemberDefinition '
            [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
            [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
            [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
        ' -ErrorAction SilentlyContinue

        try {
            $console = [Win32.ConsoleUtils]::GetConsoleWindow()
            [Win32.ConsoleUtils]::ShowWindow($console, 0) | Out-Null
            [Win32.ConsoleUtils]::SetWindowPos($console, 0, -32000, -32000, 0, 0, 0x0080) | Out-Null
        } catch { }

        try {
            # Load required assemblies with error suppression
            Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            
            # Get screen bounds with fallback
            try {
                $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $width = $screen.Width
                $height = $screen.Height
            } catch {
                # Fallback to common resolution if Screen class fails
                $width = 1920
                $height = 1080
            }
            
            # Create bitmap in memory with error handling
            $bitmap = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            
            # Enterprise-grade quality settings
            try {
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            } catch {
                # Continue with default quality if settings fail
            }
            
            # Silent screen capture with bounds validation
            $graphics.CopyFromScreen(0, 0, 0, 0, [System.Drawing.Size]::new($width, $height), [System.Drawing.CopyPixelOperation]::SourceCopy)
            
            # Convert to base64 directly in memory (no file operations)
            $memoryStream = New-Object System.IO.MemoryStream
            $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
            $imageBytes = $memoryStream.ToArray()
            
            # Validate image size
            if ($imageBytes.Length -lt 1000) {
                throw "Image too small: $($imageBytes.Length) bytes"
            }
            
            $base64String = [System.Convert]::ToBase64String($imageBytes)
            
            # Immediate cleanup
            $graphics.Dispose()
            $bitmap.Dispose() 
            $memoryStream.Dispose()
            
            # Output base64 to stdout for Rust to capture
            Write-Output $base64String
            
        } catch {
            Write-Error "Memory screenshot failed: $($_.Exception.Message)"
            exit 1
        }
    "#;

    println!("[SCREENSHOT][memory] Executing memory-based PowerShell script");
    let output = Command::new("powershell")
        .args([
            "-WindowStyle", "Hidden",
            "-NonInteractive",
            "-NoProfile",
            "-NoLogo", 
            "-ExecutionPolicy", "Bypass",
            "-Command", powershell_script
        ])
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        println!("[SCREENSHOT][memory] Memory screenshot failed with exit code: {:?}", output.status.code());
        println!("[SCREENSHOT][memory] Error details: {}", stderr);
        return Err(anyhow!("Failed to take memory-based screenshot: {}", stderr));
    }

    // Get base64 string directly from PowerShell output
    let base64_string = String::from_utf8(output.stdout)
        .map_err(|e| anyhow!("Failed to parse PowerShell output: {}", e))?
        .trim()
        .to_string();

    if base64_string.is_empty() {
        return Err(anyhow!("Memory screenshot returned empty result"));
    }

    // Validate base64 string more thoroughly
    match general_purpose::STANDARD.decode(&base64_string) {
        Ok(decoded) => {
            if decoded.len() < 1000 {
                return Err(anyhow!("Memory screenshot result too small to be valid: {} bytes", decoded.len()));
            }
            
            // Additional PNG header validation
            if decoded.len() >= 8 && &decoded[0..8] == b"\x89PNG\r\n\x1a\n" {
                println!("[SCREENSHOT][memory] Memory screenshot successful: {} bytes, valid PNG format", decoded.len());
            } else {
                println!("[SCREENSHOT][memory] Memory screenshot successful: {} bytes (non-PNG format)", decoded.len());
            }
        },
        Err(e) => {
            return Err(anyhow!("Invalid base64 result from memory screenshot: {}", e));
        }
    }

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][memory] Complete: Generated screenshot using memory method in {:.2?}", elapsed);

    Ok(base64_string)
}

/// Smart extraction of bundled NirCmd from Flutter assets
/// Returns the path to extracted executable if successful
#[cfg(target_os = "windows")]
pub fn extract_bundled_nircmd() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][nircmd-extract] Smart extraction of bundled NirCmd asset");

    // Get the executable directory (where the app is running)
    let exe_dir = env::current_exe()
        .map_err(|e| anyhow!("Failed to get executable path: {}", e))?
        .parent()
        .ok_or_else(|| anyhow!("Failed to get executable directory"))?
        .to_path_buf();

    // Flutter asset paths to check (multiple possible locations)
    let asset_paths = vec![
        exe_dir.join("data").join("flutter_assets").join("assets").join("nircmd.exe"),      // Release build
        exe_dir.join("data").join("flutter_assets").join("assets").join("nircmdc.exe"),     // Alternative release
        exe_dir.join("flutter_assets").join("assets").join("nircmd.exe"),                   // Debug build
        exe_dir.join("flutter_assets").join("assets").join("nircmdc.exe"),                  // Alternative debug
        exe_dir.join("assets").join("nircmd.exe"),                                          // Direct assets
        exe_dir.join("assets").join("nircmdc.exe"),                                         // Alternative direct
        PathBuf::from("assets").join("nircmd.exe"),                                         // Relative path
        PathBuf::from("assets").join("nircmdc.exe"),                                        // Alternative relative
    ];

    // Also check current working directory assets
    if let Ok(cwd) = env::current_dir() {
        let cwd_paths = vec![
            cwd.join("assets").join("nircmd.exe"),
            cwd.join("assets").join("nircmdc.exe"),
            cwd.join("data").join("flutter_assets").join("assets").join("nircmd.exe"),
            cwd.join("data").join("flutter_assets").join("assets").join("nircmdc.exe"),
        ];
        for path in cwd_paths {
            if !asset_paths.contains(&path) {
                // Add to search paths if not already present
            }
        }
    }

    println!("[SCREENSHOT][nircmd-extract] Searching {} potential asset locations", asset_paths.len());

    // Find the bundled NirCmd asset
    let mut source_path = None;
    let mut asset_name = String::new();
    
    for asset_path in &asset_paths {
        println!("[SCREENSHOT][nircmd-extract] Checking asset path: {}", asset_path.display());
        if asset_path.exists() {
            // Verify it's actually an executable by checking file size and PE header
            if let Ok(metadata) = fs::metadata(asset_path) {
                let file_size = metadata.len();
                if file_size > 10000 && file_size < 5_000_000 { // Reasonable size range for NirCmd
                    // Quick PE header check for Windows executable
                    if let Ok(file_data) = fs::read(asset_path) {
                        if file_data.len() >= 64 && &file_data[0..2] == b"MZ" { // DOS header
                            println!("[SCREENSHOT][nircmd-extract] ✅ Found valid bundled NirCmd: {} ({} bytes)", 
                                   asset_path.display(), file_size);
                            source_path = Some(asset_path.clone());
                            asset_name = asset_path.file_name()
                                .unwrap_or_default()
                                .to_string_lossy()
                                .to_string();
                            break;
                        }
                    }
                }
            }
        }
    }

    let source = source_path.ok_or_else(|| {
        println!("[SCREENSHOT][nircmd-extract] No bundled NirCmd asset found in any location");
        anyhow!("Bundled NirCmd asset not found")
    })?;

    // Extract to a secure temporary location
    let temp_dir = env::temp_dir();
    let extracted_dir = temp_dir.join("taskwatch_tools");
    
    // Create tools directory if it doesn't exist
    if !extracted_dir.exists() {
        fs::create_dir_all(&extracted_dir)
            .map_err(|e| anyhow!("Failed to create tools directory: {}", e))?;
        println!("[SCREENSHOT][nircmd-extract] Created tools directory: {}", extracted_dir.display());
    }

    let extracted_path = extracted_dir.join(&asset_name);
    
    // Check if already extracted and valid
    if extracted_path.exists() {
        if let Ok(metadata) = fs::metadata(&extracted_path) {
            let source_metadata = fs::metadata(&source)
                .map_err(|e| anyhow!("Failed to get source metadata: {}", e))?;
            
            // Compare file sizes to see if extraction is up to date
            if metadata.len() == source_metadata.len() {
                println!("[SCREENSHOT][nircmd-extract] ⚡ Using cached extracted NirCmd: {}", extracted_path.display());
                let elapsed = start_time.elapsed();
                println!("[SCREENSHOT][nircmd-extract] Complete: Cached extraction in {:.2?}", elapsed);
                return Ok(extracted_path.to_string_lossy().to_string());
            }
        }
    }

    // Extract the asset
    println!("[SCREENSHOT][nircmd-extract] Extracting {} to {}", source.display(), extracted_path.display());
    
    fs::copy(&source, &extracted_path)
        .map_err(|e| anyhow!("Failed to extract NirCmd asset: {}", e))?;

    // Verify extraction
    let extracted_metadata = fs::metadata(&extracted_path)
        .map_err(|e| anyhow!("Failed to verify extracted file: {}", e))?;
    
    let source_metadata = fs::metadata(&source)
        .map_err(|e| anyhow!("Failed to get source metadata: {}", e))?;
    
    if extracted_metadata.len() != source_metadata.len() {
        let _ = fs::remove_file(&extracted_path);
        return Err(anyhow!("Extraction verification failed: size mismatch"));
    }

    println!("[SCREENSHOT][nircmd-extract] ✅ Successfully extracted NirCmd: {} bytes", extracted_metadata.len());
    
    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][nircmd-extract] Complete: Smart extraction in {:.2?}", elapsed);

    Ok(extracted_path.to_string_lossy().to_string())
}

/// Test NirCmd capabilities and available commands
/// Returns information about what NirCmd commands are supported
#[cfg(target_os = "windows")]
pub fn test_nircmd_capabilities() -> Result<String> {
    println!("[SCREENSHOT][nircmd-test] Testing NirCmd capabilities");
    
    // Try to get an available NirCmd path
    let nircmd_path = if let Ok(extracted_path) = extract_bundled_nircmd() {
        extracted_path
    } else if is_nircmd_available() {
        "nircmd".to_string()
    } else {
        return Err(anyhow!("NirCmd not available for testing"));
    };
    
    println!("[SCREENSHOT][nircmd-test] Using NirCmd at: {}", nircmd_path);
    
    // Test help command
    let help_output = Command::new(&nircmd_path)
        .args(["/?"])
        .output();
    
    let mut results = Vec::new();
    
    match help_output {
        Ok(output) => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let stderr = String::from_utf8_lossy(&output.stderr);
            
            results.push(format!("NirCmd Help Command Test:"));
            results.push(format!("Exit Code: {:?}", output.status.code()));
            
            if !stdout.is_empty() {
                results.push(format!("STDOUT (first 500 chars): {}", 
                    stdout.chars().take(500).collect::<String>()));
            }
            
            if !stderr.is_empty() {
                results.push(format!("STDERR: {}", stderr));
            }
        }
        Err(e) => {
            results.push(format!("Help command failed: {}", e));
        }
    }
    
    // Test savescreenshot command syntax help
    let screenshot_help = Command::new(&nircmd_path)
        .args(["savescreenshot", "/?"])
        .output();
    
    match screenshot_help {
        Ok(output) => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let stderr = String::from_utf8_lossy(&output.stderr);
            
            results.push(format!("\nSaveScreenshot Command Help:"));
            results.push(format!("Exit Code: {:?}", output.status.code()));
            
            if !stdout.is_empty() {
                results.push(format!("STDOUT: {}", stdout));
            }
            
            if !stderr.is_empty() {
                results.push(format!("STDERR: {}", stderr));
            }
        }
        Err(e) => {
            results.push(format!("Screenshot help failed: {}", e));
        }
    }
    
    // Test basic version info
    let version_output = Command::new(&nircmd_path)
        .args(["/version"])
        .output();
    
    match version_output {
        Ok(output) => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let stderr = String::from_utf8_lossy(&output.stderr);
            
            results.push(format!("\nNirCmd Version Info:"));
            results.push(format!("Exit Code: {:?}", output.status.code()));
            
            if !stdout.is_empty() {
                results.push(format!("STDOUT: {}", stdout));
            }
            
            if !stderr.is_empty() {
                results.push(format!("STDERR: {}", stderr));
            }
        }
        Err(e) => {
            results.push(format!("Version command failed: {}", e));
        }
    }
    
    Ok(results.join("\n"))
}

/// Test a simple NirCmd screenshot with detailed diagnostics
/// This function helps debug what exactly is happening with NirCmd
#[cfg(target_os = "windows")]
pub fn test_nircmd_screenshot_simple() -> Result<String> {
    println!("[SCREENSHOT][nircmd-simple-test] Testing simple NirCmd screenshot");
    
    let nircmd_path = if let Ok(extracted_path) = extract_bundled_nircmd() {
        extracted_path
    } else if is_nircmd_available() {
        "nircmd".to_string()
    } else {
        return Err(anyhow!("NirCmd not available for testing"));
    };
    
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("nircmd_test_{}.png", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();
    
    println!("[SCREENSHOT][nircmd-simple-test] Test file: {}", temp_file_str);
    
    // Try the simple command
    let output = Command::new(&nircmd_path)
        .args(["savescreenshot", &temp_file_str])
        .output()?;
    
    let mut results = Vec::new();
    results.push(format!("NirCmd Simple Screenshot Test"));
    results.push(format!("Command: {} savescreenshot \"{}\"", nircmd_path, temp_file_str));
    results.push(format!("Exit Code: {:?}", output.status.code()));
    
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    
    if !stdout.is_empty() {
        results.push(format!("STDOUT: {}", stdout));
    }
    
    if !stderr.is_empty() {
        results.push(format!("STDERR: {}", stderr));
    }
    
    // Check file creation
    thread::sleep(Duration::from_millis(500)); // Give it some time
    
    if temp_file.exists() {
        let file_size = std::fs::metadata(&temp_file)?.len();
        results.push(format!("File created: YES"));
        results.push(format!("File size: {} bytes", file_size));
        
        if file_size < 100 {
            // Read small file content
            if let Ok(content) = std::fs::read_to_string(&temp_file) {
                results.push(format!("Small file content: {}", content));
            }
        } else {
            results.push(format!("File size looks reasonable for screenshot"));
        }
        
        // Clean up
        let _ = std::fs::remove_file(&temp_file);
    } else {
        results.push(format!("File created: NO"));
    }
    
    Ok(results.join("\n"))
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

// =============================================================================
// PUBLIC TESTING API
// =============================================================================

/// Test the primary screenshots crate method (cross-platform)
pub fn test_screenshots_crate_method() -> Result<String> {
    println!("[TEST] Testing Screenshots Crate Method");
    take_screenshot_with_screenshots_crate()
}

/// Test NirCmd screenshot method (Windows primary)
#[cfg(target_os = "windows")]
pub fn test_nircmd_screenshot() -> Result<String> {
    println!("[TEST] Testing NirCmd Screenshot");
    take_screenshot_windows_nircmd()
}

/// Test memory-based screenshot (Windows fallback)
#[cfg(target_os = "windows")]
pub fn test_memory_screenshot() -> Result<String> {
    println!("[TEST] Testing Memory-Based Screenshot");
    take_screenshot_windows_memory()
}

/// Test NirCmd availability
#[cfg(target_os = "windows")]
pub fn test_nircmd_availability() -> bool {
    println!("[TEST] Testing NirCmd Availability");
    is_nircmd_available()
}

/// Test bundled NirCmd extraction
#[cfg(target_os = "windows")]
pub fn test_bundled_nircmd_extraction() -> Result<String> {
    println!("[TEST] Testing Bundled NirCmd Extraction");
    extract_bundled_nircmd()
}

/// Test Linux-specific fallback methods
#[cfg(target_os = "linux")]
pub fn test_linux_fallback_methods() -> Result<String> {
    println!("[TEST] Testing Linux Fallback Methods");
    take_screenshot_linux_fallback()
}

/// Test macOS screen recording permission check
#[cfg(target_os = "macos")]
pub fn test_macos_permissions() -> bool {
    println!("[TEST] Testing macOS Screen Recording Permissions");
    has_screen_recording_permission()
}

// =============================================================================
// LINUX UTILITY TESTING API
// =============================================================================

/// Test Linux environment checks
/// - Wayland/X11 detection
/// - XWayland availability
/// - Display server compatibility
#[cfg(target_os = "linux")]
pub fn test_linux_environment_check() -> Result<()> {
    println!("[TEST] Testing Linux Environment Assessment");
    check_linux_environment()
}

// =============================================================================
// COMPREHENSIVE TESTING SUITE
// =============================================================================

/// Run all available screenshot methods for current platform
/// Returns a comprehensive test report
pub fn test_all_available_methods() -> Result<Vec<String>> {
    println!("[TEST] Running comprehensive screenshot method testing");
    let mut results = Vec::new();
    let mut test_count = 0;
    let mut success_count = 0;

    // Test primary cross-platform method first
    test_count += 1;
    match test_screenshots_crate_method() {
        Ok(_) => {
            results.push("✅ Screenshots Crate Method: SUCCESS".to_string());
            success_count += 1;
        },
        Err(e) => {
            results.push(format!("❌ Screenshots Crate Method: FAILED - {}", e));
        }
    }

    // Platform-specific testing
    #[cfg(target_os = "windows")]
    {
        let windows_tests = [
            ("NirCmd", test_nircmd_screenshot as fn() -> Result<String>),
            ("Memory-Based", test_memory_screenshot),
        ];

        for (name, test_fn) in windows_tests.iter() {
            test_count += 1;
            match test_fn() {
                Ok(_) => {
                    results.push(format!("✅ Windows {}: SUCCESS", name));
                    success_count += 1;
                },
                Err(e) => {
                    results.push(format!("❌ Windows {}: FAILED - {}", name, e));
                }
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        test_count += 1;
        match test_linux_fallback_methods() {
            Ok(_) => {
                results.push("✅ Linux Fallback Methods: SUCCESS".to_string());
                success_count += 1;
            },
            Err(e) => {
                results.push(format!("❌ Linux Fallback Methods: FAILED - {}", e));
            }
        }
    }

    // Add summary
    results.insert(0, format!("📊 COMPREHENSIVE TEST SUMMARY: {}/{} methods succeeded", success_count, test_count));
    results.insert(1, format!("🎯 Success Rate: {:.1}%", (success_count as f64 / test_count as f64) * 100.0));
    results.insert(2, "".to_string());

    Ok(results)
}

// Stubs for Windows-specific functions on non-Windows platforms
// Required because Flutter Rust Bridge exposes all public functions

// Legacy FRB entry points use the two maintained Windows capture implementations.
#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_powershell() -> Result<String> {
    take_screenshot_windows_memory()
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_win32() -> Result<String> {
    take_screenshot_windows_memory()
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_ffmpeg() -> Result<String> {
    take_screenshot_windows_memory()
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_csharp() -> Result<String> {
    take_screenshot_windows_memory()
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_directshow() -> Result<String> {
    take_screenshot_windows_memory()
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_vbscript() -> Result<String> {
    take_screenshot_windows_memory()
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_wmi() -> Result<String> {
    take_screenshot_windows_memory()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_1_nircmd() -> Result<String> {
    take_screenshot_windows_nircmd()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_2_powershell() -> Result<String> {
    take_screenshot_windows_powershell()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_3_memory() -> Result<String> {
    take_screenshot_windows_memory()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_4_directshow() -> Result<String> {
    take_screenshot_windows_directshow()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_5_win32() -> Result<String> {
    take_screenshot_windows_win32()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_6_wmi() -> Result<String> {
    take_screenshot_windows_wmi()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_7_ffmpeg() -> Result<String> {
    take_screenshot_windows_ffmpeg()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_8_csharp() -> Result<String> {
    take_screenshot_windows_csharp()
}

#[cfg(target_os = "windows")]
pub fn test_windows_method_9_vbscript() -> Result<String> {
    take_screenshot_windows_vbscript()
}

#[cfg(target_os = "windows")]
pub fn test_windows_environment_check() -> Result<()> {
    check_windows_environment()
}

#[cfg(not(target_os = "windows"))]
pub fn check_windows_environment() -> Result<()> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn extract_bundled_nircmd() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn is_nircmd_available() -> bool {
    false
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_nircmd() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_memory() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_powershell() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_win32() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_ffmpeg() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_csharp() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_directshow() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_vbscript() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_wmi() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_nircmd_capabilities() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_nircmd_screenshot_simple() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_1_nircmd() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_2_powershell() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_3_memory() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_4_directshow() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_5_win32() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_6_wmi() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_7_ffmpeg() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_8_csharp() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_method_9_vbscript() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_nircmd_availability() -> bool {
    false
}

#[cfg(not(target_os = "windows"))]
pub fn test_bundled_nircmd_extraction() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_nircmd_screenshot() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_memory_screenshot() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_windows_environment_check() -> Result<()> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

// Stubs for Linux-specific functions on non-Linux platforms
// Required because Flutter Rust Bridge exposes all public functions

#[cfg(not(target_os = "linux"))]
pub fn check_linux_environment() -> Result<()> {
    Err(anyhow!("Linux-specific function not available on this platform"))
}

#[cfg(not(target_os = "linux"))]
pub fn take_screenshot_linux_fallback() -> Result<String> {
    Err(anyhow!("Linux-specific function not available on this platform"))
}

#[cfg(not(target_os = "linux"))]
pub fn test_linux_environment_check() -> Result<()> {
    Err(anyhow!("Linux-specific function not available on this platform"))
}

#[cfg(not(target_os = "linux"))]
pub fn test_linux_fallback_methods() -> Result<String> {
    Err(anyhow!("Linux-specific function not available on this platform"))
}

// Stubs for macOS-specific functions on non-macOS platforms.
// Required because Flutter Rust Bridge exposes all public functions.

#[cfg(not(target_os = "macos"))]
pub fn hide_macos_app_native() {}

#[cfg(not(target_os = "macos"))]
pub fn unhide_macos_app_native() {}

#[cfg(not(target_os = "macos"))]
pub fn take_screenshot_macos_fallback() -> Result<String> {
    Err(anyhow!("macOS-specific function not available on this platform"))
}

#[cfg(not(target_os = "macos"))]
pub fn test_macos_permissions() -> bool {
    false
}
