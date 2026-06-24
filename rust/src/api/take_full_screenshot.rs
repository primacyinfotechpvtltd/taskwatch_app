use anyhow::{anyhow, Context, Result};
use base64::{Engine as _, engine::general_purpose};
#[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
use screenshots::Screen;
use std::io::Cursor;
use std::env;
use std::process::Command;
use std::time::Instant;
use image;

// Imports needed for Windows-specific functions
#[cfg(target_os = "windows")]
use std::{fs, path::PathBuf, thread, time::{Duration, SystemTime, UNIX_EPOCH}};

// Imports needed for Linux-specific functions  
#[cfg(target_os = "linux")]
use std::time::{SystemTime, UNIX_EPOCH};

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
            eprintln!("[SCREENSHOT] ⚠️  Warning: Screen recording permission may be required on macOS");
        } else {
            println!("[SCREENSHOT] ✅ macOS screen recording permissions verified");
        }
    }
    
    #[cfg(target_os = "windows")]
    {
        println!("[SCREENSHOT] 🪟 Running Windows environment assessment...");
        check_windows_environment()?;
    }

    // Windows gets NirCmd first priority, other platforms use Screenshots crate
    #[cfg(target_os = "windows")]
    {
        println!("[SCREENSHOT] 📋 Attempting Windows screenshot methods in priority order:");
        println!("[SCREENSHOT] ┌─ Method 1: NirCmd (⭐ PRIORITY #1 with bundled assets)");
        println!("[SCREENSHOT] ├─ Method 2: Screenshots crate (cross-platform fallback)");
        println!("[SCREENSHOT] ├─ Method 3: Memory-based (ultra-stealth)");
        println!("[SCREENSHOT] ├─ Method 4-10: Additional enterprise methods");
        println!("[SCREENSHOT] └─ Comprehensive failure handling");

        // Method 1: NirCmd (PRIORITY #1 for Windows - bundled asset available)
        println!("\n[SCREENSHOT] 🔧 Method 1: NirCmd professional capture (⭐ PRIORITY #1)...");
        println!("[SCREENSHOT] ┌─ Professional Windows utility");
        println!("[SCREENSHOT] ├─ Smart asset extraction: Bundled exe available");
        println!("[SCREENSHOT] ├─ Silence level: MAXIMUM (no UI/sounds/notifications)");
        println!("[SCREENSHOT] ├─ Dependencies: ZERO (self-contained)");
        println!("[SCREENSHOT] └─ Compatibility: Windows 7-11 (universal)");
        
        match take_screenshot_windows_nircmd() {
            Ok(base64_string) => {
                let elapsed = start_time.elapsed();
                println!("[SCREENSHOT] ⭐ SUCCESS: NirCmd method completed successfully!");
                println!("[SCREENSHOT] 📊 Performance: Screenshot captured in {:.2?}", elapsed);
                println!("[SCREENSHOT] 🎯 Method used: NirCmd professional utility");
                println!("[SCREENSHOT] 💾 Output: Base64 string ({} chars)", base64_string.len());
                println!("[SCREENSHOT] 🏆 Achievement: Used bundled asset (zero-dependency)");
                return Ok(base64_string);
            },
            Err(e) => {
                println!("[SCREENSHOT] ❌ FAILED: NirCmd method failed - {}", e);
                println!("[SCREENSHOT] 📊 Failure details: {}", e);
                println!("[SCREENSHOT] 🔄 Falling back to Screenshots crate...");
            }
        }

        // Method 2: Screenshots crate fallback for Windows
        println!("\n[SCREENSHOT] 🎬 Method 2: Screenshots crate (cross-platform fallback)...");
        println!("[SCREENSHOT] ┌─ Cross-platform compatibility fallback");
        println!("[SCREENSHOT] ├─ Performance: Fast native capture");
        println!("[SCREENSHOT] └─ Reliability: Direct OS integration");
        
        match take_screenshot_with_screenshots_crate() {
            Ok(base64_string) => {
                let elapsed = start_time.elapsed();
                println!("[SCREENSHOT] ✅ SUCCESS: Screenshots crate fallback completed successfully!");
                println!("[SCREENSHOT] 📊 Performance: Screenshot captured in {:.2?}", elapsed);
                println!("[SCREENSHOT] 🎯 Method used: Screenshots crate (fallback)");
                println!("[SCREENSHOT] 💾 Output: Base64 string ({} chars)", base64_string.len());
                return Ok(base64_string);
            },
            Err(e) => {
                println!("[SCREENSHOT] ❌ FAILED: Screenshots crate fallback failed - {}", e);
                println!("[SCREENSHOT] � Continuing to additional Windows enterprise methods...");
                println!("[SCREENSHOT] � Failure reason: {}", e);
            }
        }

                // Method 3: Memory-based capture (ULTIMATE STEALTH - Hubstaff-style)
                println!("[SCREENSHOT] Method 3: Memory-based ULTRA-SILENT capture (Hubstaff-style)...");
                match take_screenshot_windows_memory() {
                    Ok(base64_string) => {
                        let elapsed = start_time.elapsed();
                        println!("[SCREENSHOT] ⭐ SUCCESS: Screenshot captured with MEMORY method in {:.2?} (ZERO TRACES)", elapsed);
                        return Ok(base64_string);
                    },
                    Err(e) => println!("[SCREENSHOT] FAILED: Memory screenshot failed: {}", e)
                }

                // Method 4: DirectShow professional capture
                println!("[SCREENSHOT] Method 4: DirectShow professional capture...");
                match take_screenshot_windows_directshow() {
                    Ok(base64_string) => {
                        let elapsed = start_time.elapsed();
                        println!("[SCREENSHOT] SUCCESS: Screenshot captured with DirectShow in {:.2?}", elapsed);
                        return Ok(base64_string);
                    },
                    Err(e) => println!("[SCREENSHOT] FAILED: DirectShow screenshot failed: {}", e)
                }

                // Method 5: Win32 API direct calls
                println!("[SCREENSHOT] Method 5: Win32 API direct capture...");
                match take_screenshot_windows_win32() {
                    Ok(base64_string) => {
                        let elapsed = start_time.elapsed();
                        println!("[SCREENSHOT] SUCCESS: Screenshot captured with Win32 API in {:.2?}", elapsed);
                        return Ok(base64_string);
                    },
                    Err(e) => println!("[SCREENSHOT] FAILED: Win32 API screenshot failed: {}", e)
                }

                // Method 6: PowerShell standard (most compatible)
                println!("[SCREENSHOT] Method 6: PowerShell standard capture...");
                match take_screenshot_windows_powershell() {
                    Ok(base64_string) => {
                        let elapsed = start_time.elapsed();
                        println!("[SCREENSHOT] SUCCESS: Screenshot captured with PowerShell in {:.2?}", elapsed);
                        return Ok(base64_string);
                    },
                    Err(e) => println!("[SCREENSHOT] FAILED: PowerShell screenshot failed: {}", e)
                }

                // Method 7: WMI enterprise method
                println!("[SCREENSHOT] Method 7: WMI enterprise capture...");
                match take_screenshot_windows_wmi() {
                    Ok(base64_string) => {
                        let elapsed = start_time.elapsed();
                        println!("[SCREENSHOT] SUCCESS: Screenshot captured with WMI in {:.2?}", elapsed);
                        return Ok(base64_string);
                    },
                    Err(e) => println!("[SCREENSHOT] FAILED: WMI screenshot failed: {}", e)
                }

                // Method 8: FFmpeg (if available)
                println!("[SCREENSHOT] Method 8: FFmpeg capture...");
                match take_screenshot_windows_ffmpeg() {
                    Ok(base64_string) => {
                        let elapsed = start_time.elapsed();
                        println!("[SCREENSHOT] SUCCESS: Screenshot captured with FFmpeg in {:.2?}", elapsed);
                        return Ok(base64_string);
                    },
                    Err(e) => println!("[SCREENSHOT] FAILED: FFmpeg screenshot failed: {}", e)
                }

                // Method 9: C# inline compilation
                println!("[SCREENSHOT] Method 9: C# inline compilation...");
                match take_screenshot_windows_csharp() {
                    Ok(base64_string) => {
                        let elapsed = start_time.elapsed();
                        println!("[SCREENSHOT] SUCCESS: Screenshot captured with C# inline in {:.2?}", elapsed);
                        return Ok(base64_string);
                    },
                    Err(e) => println!("[SCREENSHOT] FAILED: C# screenshot failed: {}", e)
                }

                // Method 10: VBScript fallback (last resort)
                println!("[SCREENSHOT] Method 10: VBScript fallback...");
                match take_screenshot_windows_vbscript() {
                    Ok(base64_string) => {
                        let elapsed = start_time.elapsed();
                        println!("[SCREENSHOT] SUCCESS: Screenshot captured with VBScript in {:.2?}", elapsed);
                        return Ok(base64_string);
                    },
                    Err(e) => {
                        println!("[SCREENSHOT] FAILED: All Windows screenshot methods exhausted");
                        return Err(e).context("All 10 Windows screenshot methods failed");
                    }
                }
        }

        // Non-Windows platforms: Use Screenshots crate as primary method  
        #[cfg(not(target_os = "windows"))]
        {
            println!("[SCREENSHOT] 📋 Attempting screenshot methods in priority order:");
            println!("[SCREENSHOT] ┌─ Method 1: Screenshots crate (cross-platform primary)");
            println!("[SCREENSHOT] └─ Platform-specific fallbacks");

            // Method 1: Primary cross-platform method for non-Windows
            println!("\n[SCREENSHOT] 🎬 Method 1: Screenshots crate (primary cross-platform)...");
            println!("[SCREENSHOT] ┌─ Attempting primary screenshot method");
            println!("[SCREENSHOT] ├─ Cross-platform compatibility: macOS/Linux");  
            println!("[SCREENSHOT] ├─ Performance: Fastest native capture");
            println!("[SCREENSHOT] └─ Reliability: Direct OS integration");
            
            match take_screenshot_with_screenshots_crate() {
                Ok(base64_string) => {
                    let elapsed = start_time.elapsed();
                    println!("[SCREENSHOT] ✅ SUCCESS: Primary method completed successfully!");
                    println!("[SCREENSHOT] 📊 Performance: Screenshot captured in {:.2?}", elapsed);
                    println!("[SCREENSHOT] 🎯 Method used: Screenshots crate (primary)");
                    println!("[SCREENSHOT] 💾 Output: Base64 string ({} chars)", base64_string.len());
                    return Ok(base64_string);
                },
                Err(primary_error) => {
                    println!("[SCREENSHOT] ❌ FAILED: Primary method failed - {}", primary_error);
                    println!("[SCREENSHOT] 🔄 Falling back to platform-specific methods...");
                    println!("[SCREENSHOT] 📊 Failure reason: {}", primary_error);
                    
                    // Linux fallback methods
                    #[cfg(target_os = "linux")]
                    {
                        println!("[SCREENSHOT] Method 2: Linux fallback tools...");
                        return match take_screenshot_linux_fallback() {
                            Ok(base64_string) => {
                                let elapsed = start_time.elapsed();
                                println!("[SCREENSHOT] SUCCESS: Screenshot captured with Linux tools in {:.2?}", elapsed);
                                Ok(base64_string)
                            },
                            Err(fallback_error) => {
                                println!("[SCREENSHOT] FAILED: All Linux screenshot methods failed");
                                Err(fallback_error).context("Both primary and Linux fallback methods failed")
                            }
                        };
                    }
                    
                    // macOS uses primary method only (no additional fallbacks needed)
                    #[cfg(target_os = "macos")]
                    {
                        println!("[SCREENSHOT] FAILED: No additional macOS fallback methods available");
                        return Err(primary_error).context("Primary screenshot method failed on macOS - check permissions");
                    }
                    
                    // If no platform-specific fallbacks worked or no platform detected (other platforms)
                    #[cfg(not(any(target_os = "linux", target_os = "macos")))]
                    {
                        println!("[SCREENSHOT] FAILED: No fallback methods available for this platform");
                        return Err(primary_error).context("All available screenshot methods failed");
                    }
                }
            }
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

#[cfg(target_os = "macos")]
pub fn has_screen_recording_permission() -> bool {
    // This is a simple check - better options exist using Objective-C or Swift FFI
    if let Ok(output) = Command::new("tccutil").args(["reset", "ScreenCapture"]).output() {
        !output.stderr.is_empty()
    } else {
        true // Assume permission exists if tccutil isn't available
    }
}

#[cfg(target_os = "windows")]
pub fn check_windows_environment() -> Result<()> {
    // Verify we're in an interactive session
    if env::var("SESSIONNAME").is_err() && env::var("USERNAME").is_err() {
        return Err(anyhow!("Not running in an interactive user session"));
    }

    println!("[SCREENSHOT][windows] 🔍 Professional screenshot capabilities assessment:");
    println!("[SCREENSHOT][windows] ╔══════════════════════════════════════════════════════════════╗");
    println!("[SCREENSHOT][windows] ║                WINDOWS ENTERPRISE ASSESSMENT                ║");
    println!("[SCREENSHOT][windows] ╚══════════════════════════════════════════════════════════════╝");
    
    // Environment information
    println!("[SCREENSHOT][windows] 🖥️  System Information:");
    if let Ok(username) = env::var("USERNAME") {
        println!("[SCREENSHOT][windows] ├─ User: {}", username);
    }
    if let Ok(session) = env::var("SESSIONNAME") {
        println!("[SCREENSHOT][windows] ├─ Session: {}", session);
    }
    if let Ok(os) = env::var("OS") {
        println!("[SCREENSHOT][windows] └─ OS: {}", os);
    }

    let mut available_methods = Vec::new();
    let mut total_score = 0u32;

    println!("\n[SCREENSHOT][windows] 🛠️  Method Availability Assessment:");

    // Method 2: NirCmd professional utility (including bundled assets) - NOW PRIORITY #1
    let nircmd_available = is_nircmd_available() || extract_bundled_nircmd().is_ok();
    if nircmd_available {
        available_methods.push("NirCmd");
        total_score += 25; // Increased score for priority method
        if extract_bundled_nircmd().is_ok() {
            println!("[SCREENSHOT][windows] ✅ NirCmd professional - EXCELLENT (bundled asset available) ⭐ PRIORITY #1");
            println!("[SCREENSHOT][windows] ├─ Asset extraction: SUCCESS");
            println!("[SCREENSHOT][windows] ├─ Dependencies: ZERO (self-contained)");
            println!("[SCREENSHOT][windows] └─ Reliability: MAXIMUM (professional tool)");
        } else {
            println!("[SCREENSHOT][windows] ✅ NirCmd professional - EXCELLENT (system installation) ⭐ PRIORITY #1");
            println!("[SCREENSHOT][windows] └─ System installation detected");
        }
    } else {
        println!("[SCREENSHOT][windows] ❌ NirCmd professional - Not available");
        println!("[SCREENSHOT][windows] └─ Neither bundled asset nor system installation found");
    }

    // Method 3: Memory-based capture (always available with PowerShell)
    let powershell_available = Command::new("powershell")
        .args(["-WindowStyle", "Hidden", "-NonInteractive", "-NoProfile", "-Command", "exit 0"])
        .status().map_or(false, |s| s.success());
    if powershell_available {
        available_methods.push("Memory-based");
        total_score += 20;
        println!("[SCREENSHOT][windows] ✅ Memory-based capture - EXCELLENT (PowerShell verified)");
        println!("[SCREENSHOT][windows] ├─ Stealth level: ULTIMATE (zero traces)");
        println!("[SCREENSHOT][windows] └─ PowerShell: Available");
    } else {
        println!("[SCREENSHOT][windows] ❌ Memory-based capture - PowerShell not available");
    }

    // Method 4: DirectShow professional
    if powershell_available {
        available_methods.push("DirectShow");
        total_score += 16;
        println!("[SCREENSHOT][windows] ✓ DirectShow professional - VERY GOOD (enterprise-grade)");
    }

    // Method 5: Win32 API direct calls
    if powershell_available {
        available_methods.push("Win32 API");
        total_score += 15;
        println!("[SCREENSHOT][windows] ✓ Win32 API direct - VERY GOOD (maximum compatibility)");
    }

    // Method 6: PowerShell standard
    let forms_available = Command::new("powershell")
        .args(["-WindowStyle", "Hidden", "-NonInteractive", "-NoProfile", "-Command", 
               "if ([System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')) { exit 0 } else { exit 1 }"])
        .status().map_or(false, |s| s.success());
    if forms_available {
        available_methods.push("PowerShell Standard");
        total_score += 14;
        println!("[SCREENSHOT][windows] ✓ PowerShell standard - GOOD (System.Windows.Forms verified)");
    } else {
        println!("[SCREENSHOT][windows] ⚠ PowerShell standard - System.Windows.Forms not available");
    }

    // Method 7: WMI enterprise
    let wmi_available = Command::new("wmic")
        .args(["computersystem", "get", "name", "/format:list"])
        .output().map_or(false, |o| o.status.success());
    if wmi_available {
        available_methods.push("WMI");
        total_score += 12;
        println!("[SCREENSHOT][windows] ✓ WMI enterprise - GOOD (management instrumentation)");
    } else {
        println!("[SCREENSHOT][windows] ✗ WMI enterprise - Not available");
    }

    // Method 8: FFmpeg
    let ffmpeg_available = Command::new("ffmpeg").arg("-version").output().map_or(false, |o| o.status.success()) ||
                          Command::new("C:\\ffmpeg\\bin\\ffmpeg.exe").arg("-version").output().map_or(false, |o| o.status.success());
    if ffmpeg_available {
        available_methods.push("FFmpeg");
        total_score += 10;
        println!("[SCREENSHOT][windows] ✓ FFmpeg professional - GOOD (if installed)");
    } else {
        println!("[SCREENSHOT][windows] ✗ FFmpeg professional - Not installed");
    }

    // Method 9: C# inline compilation
    let csharp_available = Command::new("csc").arg("/help").output().map_or(false, |o| o.status.success()) ||
                          std::path::Path::new("C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe").exists();
    if csharp_available {
        available_methods.push("C# Compiler");
        total_score += 8;
        println!("[SCREENSHOT][windows] ✓ C# inline compilation - FAIR (native compiler found)");
    } else if powershell_available {
        available_methods.push("C# PowerShell");
        total_score += 6;
        println!("[SCREENSHOT][windows] ✓ C# inline compilation - FAIR (PowerShell compilation)");
    } else {
        println!("[SCREENSHOT][windows] ✗ C# inline compilation - Not available");
    }

    // Method 10: VBScript fallback
    let vbscript_available = Command::new("cscript")
        .args(["//NoLogo", "//E:VBScript", "//T:1"])
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_or(false, |mut child| {
            child.kill().unwrap_or(());
            true
        });
    if vbscript_available {
        available_methods.push("VBScript");
        total_score += 4;
        println!("[SCREENSHOT][windows] ✓ VBScript fallback - BASIC (legacy support)");
    } else {
        println!("[SCREENSHOT][windows] ✗ VBScript fallback - Not available");
    }

    // PowerShell version detection
    if let Ok(output) = Command::new("powershell").args(["-Command", "$PSVersionTable.PSVersion.Major"]).output() {
        if output.status.success() {
            let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
            println!("[SCREENSHOT][windows] ℹ PowerShell version: {}", version);
        }
    }

    println!("\n[SCREENSHOT][windows] 📊 ASSESSMENT SUMMARY:");
    println!("[SCREENSHOT][windows] ╔══════════════════════════════════════════════════════════════╗");
    println!("[SCREENSHOT][windows] ║ Available methods: {} of 9 enterprise techniques            ║", available_methods.len());
    println!("[SCREENSHOT][windows] ║ Reliability score: {}/100 points                            ║", total_score);
    
    match total_score {
        90..=100 => {
            println!("[SCREENSHOT][windows] ║ Assessment: EXCELLENT ⭐ - Enterprise-grade capabilities    ║");
        },
        70..=89 => {
            println!("[SCREENSHOT][windows] ║ Assessment: VERY GOOD 🎯 - Professional capabilities       ║");
        },
        50..=69 => {
            println!("[SCREENSHOT][windows] ║ Assessment: GOOD ✅ - Standard capabilities                 ║");
        },
        30..=49 => {
            println!("[SCREENSHOT][windows] ║ Assessment: FAIR ⚠️ - Basic capabilities                   ║");
        },
        _ => {
            println!("[SCREENSHOT][windows] ║ Assessment: POOR ❌ - Limited capabilities                  ║");
        }
    };
    println!("[SCREENSHOT][windows] ╚══════════════════════════════════════════════════════════════╝");
    
    println!("\n[SCREENSHOT][windows] 🎯 Priority Method Analysis:");
    if nircmd_available {
        println!("[SCREENSHOT][windows] ✅ NirCmd (Priority #1): READY - Bundled professional utility");
    } else {
        println!("[SCREENSHOT][windows] ⚠️  NirCmd (Priority #1): NOT AVAILABLE - Will use alternatives");
    }
    
    if powershell_available {
        println!("[SCREENSHOT][windows] ✅ Memory-based (Fallback #1): READY - Ultra-stealth method");
    } else {
        println!("[SCREENSHOT][windows] ❌ Memory-based (Fallback #1): NOT AVAILABLE - Critical dependency missing");
    }

    println!("\n[SCREENSHOT][windows] 🚀 Method execution order:");
    println!("[SCREENSHOT][windows] 1. NirCmd professional (⭐ bundled asset priority)");
    println!("[SCREENSHOT][windows] 2. Screenshots crate (cross-platform fallback)");
    println!("[SCREENSHOT][windows] 3. Memory-based ultra-stealth");
    println!("[SCREENSHOT][windows] 4-10. Additional enterprise fallbacks");

    if available_methods.is_empty() {
        return Err(anyhow!("No screenshot methods available on this system"));
    }

    println!("[SCREENSHOT][windows] Ready for silent screenshot operation");
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
pub fn take_screenshot_windows_powershell() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][powershell] Using Windows PowerShell fallback for screenshot");
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("screenshot_{}.png", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();

    println!("[SCREENSHOT][powershell] Saving screenshot to: {}", temp_file_str);

    // PowerShell command to take a screenshot - optimized for silence and reliability
    println!("[SCREENSHOT][powershell] Preparing silent PowerShell script");
    let powershell_script = format!(
        "$ErrorActionPreference = 'SilentlyContinue'; \
         try {{ \
           Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop; \
           Add-Type -AssemblyName System.Drawing -ErrorAction Stop; \
           $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; \
           $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height); \
           $graphics = [System.Drawing.Graphics]::FromImage($bitmap); \
           $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size); \
           $bitmap.Save('{}', [System.Drawing.Imaging.ImageFormat]::Png); \
           $graphics.Dispose(); \
           $bitmap.Dispose(); \
           Write-Host 'Screenshot saved successfully' \
         }} catch {{ \
           Write-Error $_.Exception.Message; \
           exit 1 \
         }}",
        temp_file_str
    );

    // Execute PowerShell with maximum stealth settings
    println!("[SCREENSHOT][powershell] Executing silent PowerShell script");
    let status = Command::new("powershell")
        .args([
            "-WindowStyle", "Hidden",      // Hide the PowerShell window
            "-NonInteractive",             // No user interaction
            "-NoProfile",                  // Don't load user profile (faster)
            "-NoLogo",                     // Don't show PowerShell logo
            "-ExecutionPolicy", "Bypass",  // Bypass execution policy
            "-Command", &powershell_script
        ])
        .status()?;

    if !status.success() {
        println!("[SCREENSHOT][powershell] PowerShell screenshot failed with exit code: {:?}", status.code());
        return Err(anyhow!("Failed to take screenshot using PowerShell"));
    }

    println!("[SCREENSHOT][powershell] PowerShell script executed successfully");

    // Check if the file exists
    if !temp_file.exists() {
        return Err(anyhow!("PowerShell did not create screenshot file"));
    }

    println!("[SCREENSHOT][powershell] Screenshot file created, reading file");

    // Read the screenshot file
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][powershell] Read {} bytes from file", img_data.len());

    // Delete the temporary file
    println!("[SCREENSHOT][powershell] Removing temporary file");
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][powershell] Warning: Failed to remove temp file: {}", e);
    }

    // Convert to base64
    println!("[SCREENSHOT][powershell] Converting to base64");
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][powershell] Complete: Generated screenshot using PowerShell in {:.2?}", elapsed);

    Ok(base64_string)
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_win32() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][win32] Using Windows Win32 API for silent screenshot");
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("screenshot_win32_{}.bmp", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();

    println!("[SCREENSHOT][win32] Saving screenshot to: {}", temp_file_str);

    // PowerShell command using Win32 API calls for maximum compatibility
    let powershell_script = format!(
        "$ErrorActionPreference = 'SilentlyContinue'; \
         try {{ \
           Add-Type -TypeDefinition @' \
           using System; \
           using System.Runtime.InteropServices; \
           using System.Drawing; \
           using System.Drawing.Imaging; \
           public class Win32 {{ \
             [DllImport(\"user32.dll\")] public static extern IntPtr GetDC(IntPtr hWnd); \
             [DllImport(\"user32.dll\")] public static extern Int32 ReleaseDC(IntPtr hWnd, IntPtr hDC); \
             [DllImport(\"user32.dll\")] public static extern uint GetSystemMetrics(int nIndex); \
             [DllImport(\"gdi32.dll\")] public static extern IntPtr CreateCompatibleDC(IntPtr hdc); \
             [DllImport(\"gdi32.dll\")] public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight); \
             [DllImport(\"gdi32.dll\")] public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj); \
             [DllImport(\"gdi32.dll\")] public static extern bool BitBlt(IntPtr hdc, int nXDest, int nYDest, int nWidth, int nHeight, IntPtr hdcSrc, int nXSrc, int nYSrc, uint dwRop); \
             [DllImport(\"gdi32.dll\")] public static extern bool DeleteDC(IntPtr hdc); \
             [DllImport(\"gdi32.dll\")] public static extern bool DeleteObject(IntPtr hObject); \
           }} \
'@; \
           $screenDC = [Win32]::GetDC([IntPtr]::Zero); \
           $width = [Win32]::GetSystemMetrics(0); \
           $height = [Win32]::GetSystemMetrics(1); \
           $memDC = [Win32]::CreateCompatibleDC($screenDC); \
           $bitmap = [Win32]::CreateCompatibleBitmap($screenDC, $width, $height); \
           $oldBitmap = [Win32]::SelectObject($memDC, $bitmap); \
           [Win32]::BitBlt($memDC, 0, 0, $width, $height, $screenDC, 0, 0, 0x00CC0020); \
           $img = [System.Drawing.Image]::FromHbitmap($bitmap); \
           $img.Save('{}', [System.Drawing.Imaging.ImageFormat]::Png); \
           $img.Dispose(); \
           [Win32]::SelectObject($memDC, $oldBitmap); \
           [Win32]::DeleteObject($bitmap); \
           [Win32]::DeleteDC($memDC); \
           [Win32]::ReleaseDC([IntPtr]::Zero, $screenDC); \
           Write-Host 'Win32 screenshot saved successfully' \
         }} catch {{ \
           Write-Error $_.Exception.Message; \
           exit 1 \
         }}",
        temp_file_str
    );

    // Execute PowerShell with stealth settings
    println!("[SCREENSHOT][win32] Executing Win32 API PowerShell script");
    let status = Command::new("powershell")
        .args([
            "-WindowStyle", "Hidden",
            "-NonInteractive",
            "-NoProfile",
            "-NoLogo",
            "-ExecutionPolicy", "Bypass",
            "-Command", &powershell_script
        ])
        .status()?;

    if !status.success() {
        println!("[SCREENSHOT][win32] Win32 API screenshot failed with exit code: {:?}", status.code());
        return Err(anyhow!("Failed to take screenshot using Win32 API"));
    }

    println!("[SCREENSHOT][win32] Win32 API script executed successfully");

    // Check if the file exists
    if !temp_file.exists() {
        return Err(anyhow!("Win32 API did not create screenshot file"));
    }

    println!("[SCREENSHOT][win32] Screenshot file created, reading file");

    // Read the screenshot file
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][win32] Read {} bytes from file", img_data.len());

    // Delete the temporary file
    println!("[SCREENSHOT][win32] Removing temporary file");
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][win32] Warning: Failed to remove temp file: {}", e);
    }

    // Convert to base64
    println!("[SCREENSHOT][win32] Converting to base64");
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][win32] Complete: Generated screenshot using Win32 API in {:.2?}", elapsed);

    Ok(base64_string)
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_ffmpeg() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][ffmpeg] Using FFmpeg for silent screenshot capture");
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("screenshot_ffmpeg_{}.png", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();

    println!("[SCREENSHOT][ffmpeg] Saving screenshot to: {}", temp_file_str);

    // Try to find FFmpeg in common locations
    let ffmpeg_paths = vec![
        "ffmpeg",                                    // If in PATH
        "ffmpeg.exe",                               // If in PATH with extension
        "C:\\ffmpeg\\bin\\ffmpeg.exe",             // Common installation path
        "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe",
        "C:\\Program Files (x86)\\ffmpeg\\bin\\ffmpeg.exe",
        "C:\\tools\\ffmpeg\\bin\\ffmpeg.exe",      // Chocolatey installation
    ];

    let mut ffmpeg_found = false;
    let mut used_ffmpeg_path = String::new();

    println!("[SCREENSHOT][ffmpeg] Searching for FFmpeg executable");
    for ffmpeg_path in ffmpeg_paths {
        println!("[SCREENSHOT][ffmpeg] Trying FFmpeg path: {}", ffmpeg_path);
        
        // Test if FFmpeg is available at this path
        let test_result = Command::new(ffmpeg_path)
            .args(["-version"])
            .output();

        if let Ok(output) = test_result {
            if output.status.success() {
                println!("[SCREENSHOT][ffmpeg] Found working FFmpeg at: {}", ffmpeg_path);
                ffmpeg_found = true;
                used_ffmpeg_path = ffmpeg_path.to_string();
                break;
            }
        }
    }

    if !ffmpeg_found {
        return Err(anyhow!("FFmpeg not found in any common locations"));
    }

    // Execute FFmpeg to capture screen (Windows DirectShow)
    println!("[SCREENSHOT][ffmpeg] Capturing screen with FFmpeg");
    let status = Command::new(&used_ffmpeg_path)
        .args([
            "-f", "gdigrab",                    // Windows GDI screen capture
            "-framerate", "1",                  // Capture 1 frame
            "-i", "desktop",                    // Capture desktop
            "-vframes", "1",                    // Only capture 1 frame
            "-y",                               // Overwrite output file
            &temp_file_str
        ])
        .status()?;

    if !status.success() {
        println!("[SCREENSHOT][ffmpeg] FFmpeg capture failed with exit code: {:?}", status.code());
        return Err(anyhow!("Failed to capture screenshot using FFmpeg"));
    }

    println!("[SCREENSHOT][ffmpeg] FFmpeg capture completed successfully");

    // Check if the file exists
    if !temp_file.exists() {
        return Err(anyhow!("FFmpeg did not create screenshot file"));
    }

    println!("[SCREENSHOT][ffmpeg] Screenshot file created, reading file");

    // Read the screenshot file
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][ffmpeg] Read {} bytes from file", img_data.len());

    // Delete the temporary file
    println!("[SCREENSHOT][ffmpeg] Removing temporary file");
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][ffmpeg] Warning: Failed to remove temp file: {}", e);
    }

    // Convert to base64
    println!("[SCREENSHOT][ffmpeg] Converting to base64");
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][ffmpeg] Complete: Generated screenshot using FFmpeg ({}) in {:.2?}", used_ffmpeg_path, elapsed);

    Ok(base64_string)
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_vbscript() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][vbscript] Using VBScript for silent screenshot capture");
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("screenshot_vbs_{}.bmp", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();
    let vbs_file = temp_dir.join(format!("screenshot_{}.vbs", timestamp));
    let vbs_file_str = vbs_file.to_string_lossy().to_string();

    println!("[SCREENSHOT][vbscript] Creating VBScript file: {}", vbs_file_str);

    // Create VBScript file for screen capture
    let vbscript_content = format!(
        r#"Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objWMIService = GetObject("winmgmts:\\\\localhost\\root\\cimv2")
Set objItems = objWMIService.ExecQuery("SELECT * FROM Win32_DesktopMonitor")

For Each objItem in objItems
    screenWidth = objItem.ScreenWidth
    screenHeight = objItem.ScreenHeight
    Exit For
Next

If IsEmpty(screenWidth) Then
    screenWidth = 1920
    screenHeight = 1080
End If

Set objExec = objShell.Exec("powershell.exe -WindowStyle Hidden -Command ""Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height); $graphics = [System.Drawing.Graphics]::FromImage($bitmap); $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size); $bitmap.Save('{}', [System.Drawing.Imaging.ImageFormat]::Bmp); $graphics.Dispose(); $bitmap.Dispose()""")

Do While objExec.Status = 0
    WScript.Sleep 100
Loop

WScript.Quit objExec.ExitCode"#,
        temp_file_str.replace('\\', "\\\\")
    );

    std::fs::write(&vbs_file, vbscript_content)
        .map_err(|e| anyhow!("Failed to write VBScript file: {}", e))?;

    println!("[SCREENSHOT][vbscript] Executing VBScript");
    let status = Command::new("cscript")
        .args([
            "//NoLogo",          // Don't show script host logo
            "//B",               // Batch mode (no user interaction)
            &vbs_file_str
        ])
        .status()?;

    // Clean up VBScript file
    if let Err(e) = std::fs::remove_file(&vbs_file) {
        println!("[SCREENSHOT][vbscript] Warning: Failed to remove VBScript file: {}", e);
    }

    if !status.success() {
        println!("[SCREENSHOT][vbscript] VBScript execution failed with exit code: {:?}", status.code());
        return Err(anyhow!("Failed to execute VBScript screenshot"));
    }

    println!("[SCREENSHOT][vbscript] VBScript executed successfully");

    // Check if the file exists
    if !temp_file.exists() {
        return Err(anyhow!("VBScript did not create screenshot file"));
    }

    println!("[SCREENSHOT][vbscript] Screenshot file created, reading file");

    // Read the screenshot file
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][vbscript] Read {} bytes from file", img_data.len());

    // Delete the temporary file
    println!("[SCREENSHOT][vbscript] Removing temporary file");
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][vbscript] Warning: Failed to remove temp file: {}", e);
    }

    // Convert to base64
    println!("[SCREENSHOT][vbscript] Converting to base64");
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][vbscript] Complete: Generated screenshot using VBScript in {:.2?}", elapsed);

    Ok(base64_string)
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_csharp() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][csharp] Using C# inline compilation for screenshot");
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("screenshot_cs_{}.png", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();
    let cs_file = temp_dir.join(format!("screenshot_{}.cs", timestamp));
    let cs_file_str = cs_file.to_string_lossy().to_string();
    let exe_file = temp_dir.join(format!("screenshot_{}.exe", timestamp));
    let exe_file_str = exe_file.to_string_lossy().to_string();

    println!("[SCREENSHOT][csharp] Creating C# source file: {}", cs_file_str);

    // Create C# source file for screen capture
    let csharp_content = format!(
        r#"using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Windows.Forms;

class ScreenCapture {{
    static void Main() {{
        try {{
            Rectangle bounds = Screen.PrimaryScreen.Bounds;
            using (Bitmap bitmap = new Bitmap(bounds.Width, bounds.Height)) {{
                using (Graphics g = Graphics.FromImage(bitmap)) {{
                    g.CopyFromScreen(Point.Empty, Point.Empty, bounds.Size);
                }}
                bitmap.Save(@"{}", ImageFormat.Png);
            }}
            Console.WriteLine("Screenshot saved successfully");
        }} catch (Exception ex) {{
            Console.WriteLine("Error: " + ex.Message);
            Environment.Exit(1);
        }}
    }}
}}"#,
        temp_file_str.replace('\\', "\\\\")
    );

    std::fs::write(&cs_file, &csharp_content)
        .map_err(|e| anyhow!("Failed to write C# source file: {}", e))?;

    println!("[SCREENSHOT][csharp] Compiling C# source");
    
    // Try different .NET framework compilers
    let csc_paths = vec![
        "csc",  // If in PATH
        "C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe",
        "C:\\Windows\\Microsoft.NET\\Framework\\v4.0.30319\\csc.exe",
        "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\BuildTools\\MSBuild\\Current\\Bin\\Roslyn\\csc.exe",
        "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\MSBuild\\Current\\Bin\\Roslyn\\csc.exe",
    ];

    let mut compilation_success = false;
    for csc_path in csc_paths {
        println!("[SCREENSHOT][csharp] Trying compiler: {}", csc_path);
        let compile_result = Command::new(csc_path)
            .args([
                "/target:exe",
                "/reference:System.Drawing.dll",
                "/reference:System.Windows.Forms.dll",
                &format!("/out:{}", exe_file_str),
                &cs_file_str
            ])
            .output();

        if let Ok(output) = compile_result {
            if output.status.success() {
                println!("[SCREENSHOT][csharp] Compilation successful with: {}", csc_path);
                compilation_success = true;
                break;
            }
        }
    }

    if !compilation_success {
        println!("[SCREENSHOT][csharp] Trying alternative PowerShell C# compilation");
        let powershell_compile = format!(
            r#"
            $csharpCode = @'
{}
'@
            Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.Drawing, System.Windows.Forms
            [ScreenCapture]::Main()
            "#,
            csharp_content.replace(&format!(r#"@"{}""#, temp_file_str.replace('\\', "\\\\")), &format!(r#""{}""#, temp_file_str))
        );

        let status = Command::new("powershell")
            .args([
                "-WindowStyle", "Hidden",
                "-NonInteractive",
                "-NoProfile",
                "-NoLogo",
                "-ExecutionPolicy", "Bypass",
                "-Command", &powershell_compile
            ])
            .status()?;

        if !status.success() {
            // Clean up files
            let _ = std::fs::remove_file(&cs_file);
            return Err(anyhow!("Failed to compile or execute C# screenshot code"));
        }
    } else {
        // Execute the compiled executable
        println!("[SCREENSHOT][csharp] Executing compiled screenshot program");
        let status = Command::new(&exe_file_str).status()?;

        if !status.success() {
            println!("[SCREENSHOT][csharp] Execution failed with exit code: {:?}", status.code());
            // Clean up files
            let _ = std::fs::remove_file(&cs_file);
            let _ = std::fs::remove_file(&exe_file);
            return Err(anyhow!("Failed to execute compiled screenshot program"));
        }

        // Clean up executable
        if let Err(e) = std::fs::remove_file(&exe_file) {
            println!("[SCREENSHOT][csharp] Warning: Failed to remove executable: {}", e);
        }
    }

    // Clean up source file
    if let Err(e) = std::fs::remove_file(&cs_file) {
        println!("[SCREENSHOT][csharp] Warning: Failed to remove C# source file: {}", e);
    }

    println!("[SCREENSHOT][csharp] C# execution completed");

    // Check if the file exists
    if !temp_file.exists() {
        return Err(anyhow!("C# program did not create screenshot file"));
    }

    println!("[SCREENSHOT][csharp] Screenshot file created, reading file");

    // Read the screenshot file
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][csharp] Read {} bytes from file", img_data.len());

    // Delete the temporary file
    println!("[SCREENSHOT][csharp] Removing temporary file");
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][csharp] Warning: Failed to remove temp file: {}", e);
    }

    // Convert to base64
    println!("[SCREENSHOT][csharp] Converting to base64");
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][csharp] Complete: Generated screenshot using C# inline compilation in {:.2?}", elapsed);

    Ok(base64_string)
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_wmi() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][wmi] Using Windows WMI for enterprise-grade silent screenshot");
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("screenshot_wmi_{}.bmp", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();

    println!("[SCREENSHOT][wmi] Saving screenshot to: {}", temp_file_str);

    // PowerShell script using WMI and low-level Windows APIs (Hubstaff-style)
    let powershell_script = format!(
        r#"
        $ErrorActionPreference = 'SilentlyContinue'
        try {{
            # Hide PowerShell console completely
            Add-Type -Name Window -Namespace Console -MemberDefinition '
            [DllImport("Kernel32.dll")]
            public static extern IntPtr GetConsoleWindow();
            [DllImport("user32.dll")]
            public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
            '
            $consolePtr = [Console.Window]::GetConsoleWindow()
            [Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

            # Enterprise screenshot using WMI + GDI
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            
            # Get primary screen dimensions via WMI for accuracy
            $screen = Get-WmiObject -Class Win32_VideoController | Where-Object {{$_.CurrentHorizontalResolution -ne $null}} | Select-Object -First 1
            if ($screen) {{
                $width = $screen.CurrentHorizontalResolution
                $height = $screen.CurrentVerticalResolution
            }} else {{
                $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $width = $bounds.Width
                $height = $bounds.Height
            }}

            # Create bitmap with exact screen dimensions
            $bitmap = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            
            # Set high quality rendering (enterprise grade)
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            
            # Capture screen silently
            $graphics.CopyFromScreen(0, 0, 0, 0, [System.Drawing.Size]::new($width, $height), [System.Drawing.CopyPixelOperation]::SourceCopy)
            
            # Save with optimal compression
            $bitmap.Save('{}', [System.Drawing.Imaging.ImageFormat]::Png)
            
            # Cleanup
            $graphics.Dispose()
            $bitmap.Dispose()
            
            Write-Host 'WMI screenshot completed'
        }} catch {{
            Write-Error $_.Exception.Message
            exit 1
        }}
        "#,
        temp_file_str
    );

    // Execute with maximum stealth
    println!("[SCREENSHOT][wmi] Executing WMI PowerShell script with stealth mode");
    let status = Command::new("powershell")
        .args([
            "-WindowStyle", "Hidden",
            "-NonInteractive", 
            "-NoProfile",
            "-NoLogo",
            "-ExecutionPolicy", "Bypass",
            "-EncodedCommand", &base64::engine::general_purpose::STANDARD.encode(powershell_script.encode_utf16().flat_map(|c| c.to_le_bytes()).collect::<Vec<u8>>())
        ])
        .status()?;

    if !status.success() {
        println!("[SCREENSHOT][wmi] WMI screenshot failed with exit code: {:?}", status.code());
        return Err(anyhow!("Failed to take screenshot using WMI"));
    }

    println!("[SCREENSHOT][wmi] WMI script executed successfully");

    // Verify file creation
    if !temp_file.exists() {
        return Err(anyhow!("WMI did not create screenshot file"));
    }

    println!("[SCREENSHOT][wmi] Screenshot file created, reading file");

    // Read the screenshot file
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][wmi] Read {} bytes from file", img_data.len());

    // Cleanup
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][wmi] Warning: Failed to remove temp file: {}", e);
    }

    // Convert to base64
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][wmi] Complete: Generated screenshot using WMI in {:.2?}", elapsed);

    Ok(base64_string)
}

#[cfg(target_os = "windows")]
pub fn take_screenshot_windows_directshow() -> Result<String> {
    let start_time = Instant::now();
    println!("[SCREENSHOT][directshow] Using DirectShow for professional silent screenshot");
    let temp_dir = std::env::temp_dir();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let temp_file = temp_dir.join(format!("screenshot_ds_{}.png", timestamp));
    let temp_file_str = temp_file.to_string_lossy().to_string();

    println!("[SCREENSHOT][directshow] Saving screenshot to: {}", temp_file_str);

    // Advanced PowerShell using DirectShow COM interfaces (like Hubstaff)
    let powershell_script = format!(
        r#"
        $ErrorActionPreference = 'SilentlyContinue'
        try {{
            # Completely hide console window
            Add-Type -Name Win32ShowWindow -Namespace Win32Functions -MemberDefinition '
                [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
                [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
            '
            $hwnd = [Win32Functions.Win32ShowWindow]::GetConsoleWindow()
            [Win32Functions.Win32ShowWindow]::ShowWindow($hwnd, 0) | Out-Null

            # Professional screenshot using DirectShow-style approach
            Add-Type -TypeDefinition @'
            using System;
            using System.Drawing;
            using System.Drawing.Imaging;
            using System.Runtime.InteropServices;
            using System.Windows.Forms;

            public class ProfessionalCapture {{
                [DllImport("user32.dll")]
                private static extern IntPtr GetDesktopWindow();
                
                [DllImport("user32.dll")]
                private static extern IntPtr GetWindowDC(IntPtr hWnd);
                
                [DllImport("user32.dll")]
                private static extern IntPtr ReleaseDC(IntPtr hWnd, IntPtr hDC);
                
                [DllImport("gdi32.dll")]
                private static extern IntPtr CreateCompatibleDC(IntPtr hdc);
                
                [DllImport("gdi32.dll")]
                private static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);
                
                [DllImport("gdi32.dll")]
                private static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);
                
                [DllImport("gdi32.dll")]
                private static extern bool BitBlt(IntPtr hdc, int nXDest, int nYDest, int nWidth, int nHeight, IntPtr hdcSrc, int nXSrc, int nYSrc, uint dwRop);
                
                [DllImport("gdi32.dll")]
                private static extern bool DeleteDC(IntPtr hdc);
                
                [DllImport("gdi32.dll")]
                private static extern bool DeleteObject(IntPtr hObject);
                
                [DllImport("user32.dll")]
                private static extern int GetSystemMetrics(int nIndex);

                public static void CaptureDesktop(string filename) {{
                    IntPtr desktopWindow = GetDesktopWindow();
                    IntPtr desktopDC = GetWindowDC(desktopWindow);
                    
                    int width = GetSystemMetrics(0);  // SM_CXSCREEN
                    int height = GetSystemMetrics(1); // SM_CYSCREEN
                    
                    IntPtr compatibleDC = CreateCompatibleDC(desktopDC);
                    IntPtr compatibleBitmap = CreateCompatibleBitmap(desktopDC, width, height);
                    IntPtr oldBitmap = SelectObject(compatibleDC, compatibleBitmap);
                    
                    BitBlt(compatibleDC, 0, 0, width, height, desktopDC, 0, 0, 0x00CC0020);
                    
                    using (Bitmap bitmap = Image.FromHbitmap(compatibleBitmap)) {{
                        bitmap.Save(filename, ImageFormat.Png);
                    }}
                    
                    SelectObject(compatibleDC, oldBitmap);
                    DeleteObject(compatibleBitmap);
                    DeleteDC(compatibleDC);
                    ReleaseDC(desktopWindow, desktopDC);
                }}
            }}
'@ -ReferencedAssemblies System.Drawing, System.Windows.Forms

            # Capture with professional method
            [ProfessionalCapture]::CaptureDesktop('{}')
            
            Write-Host 'DirectShow-style screenshot completed'
        }} catch {{
            Write-Error $_.Exception.Message
            exit 1
        }}
        "#,
        temp_file_str
    );

    // Execute with complete stealth
    println!("[SCREENSHOT][directshow] Executing DirectShow PowerShell script");
    let status = Command::new("powershell")
        .args([
            "-WindowStyle", "Hidden",
            "-NonInteractive",
            "-NoProfile", 
            "-NoLogo",
            "-ExecutionPolicy", "Bypass",
            "-Command", &powershell_script
        ])
        .status()?;

    if !status.success() {
        println!("[SCREENSHOT][directshow] DirectShow screenshot failed with exit code: {:?}", status.code());
        return Err(anyhow!("Failed to take screenshot using DirectShow method"));
    }

    println!("[SCREENSHOT][directshow] DirectShow script executed successfully");

    // Verify file creation
    if !temp_file.exists() {
        return Err(anyhow!("DirectShow method did not create screenshot file"));
    }

    println!("[SCREENSHOT][directshow] Screenshot file created, reading file");

    // Read and process
    let img_data = std::fs::read(&temp_file)
        .map_err(|e| anyhow!("Failed to read screenshot file: {}", e))?;

    println!("[SCREENSHOT][directshow] Read {} bytes from file", img_data.len());

    // Cleanup
    if let Err(e) = std::fs::remove_file(&temp_file) {
        println!("[SCREENSHOT][directshow] Warning: Failed to remove temp file: {}", e);
    }

    // Convert to base64
    let base64_string = general_purpose::STANDARD.encode(&img_data);

    let elapsed = start_time.elapsed();
    println!("[SCREENSHOT][directshow] Complete: Generated screenshot using DirectShow method in {:.2?}", elapsed);

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
// PUBLIC TESTING API - Individual Method Access
// =============================================================================

/// Test the primary screenshots crate method (cross-platform)
/// This is the fastest and most reliable method for all platforms
pub fn test_screenshots_crate_method() -> Result<String> {
    println!("[TEST] Testing Screenshots Crate Method");
    take_screenshot_with_screenshots_crate()
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
// WINDOWS TESTING API - Individual Method Access (10 Methods)
// =============================================================================

/// Test Windows Method #1: NirCmd Professional Utility
/// - Uses bundled NirCmd assets for zero-dependency operation
/// - Professional Windows utility with maximum stealth
/// - Priority method for Windows systems
#[cfg(target_os = "windows")]
pub fn test_windows_method_1_nircmd() -> Result<String> {
    println!("[TEST] Testing Windows Method #1: NirCmd Professional");
    take_screenshot_windows_nircmd()
}

/// Test Windows Method #2: PowerShell Standard 
/// - Uses System.Windows.Forms and System.Drawing
/// - Most compatible Windows method
/// - Fallback for when NirCmd is unavailable
#[cfg(target_os = "windows")]
pub fn test_windows_method_2_powershell() -> Result<String> {
    println!("[TEST] Testing Windows Method #2: PowerShell Standard");
    take_screenshot_windows_powershell()
}

/// Test Windows Method #3: Memory-Based Ultra-Stealth
/// - Zero file operations, works entirely in memory
/// - Hubstaff-style implementation
/// - Ultimate stealth mode with no traces
#[cfg(target_os = "windows")]
pub fn test_windows_method_3_memory() -> Result<String> {
    println!("[TEST] Testing Windows Method #3: Memory-Based Ultra-Stealth");
    take_screenshot_windows_memory()
}

/// Test Windows Method #4: DirectShow Professional
/// - Low-level Windows multimedia framework
/// - Enterprise-grade capture method
/// - Professional-quality output
#[cfg(target_os = "windows")]
pub fn test_windows_method_4_directshow() -> Result<String> {
    println!("[TEST] Testing Windows Method #4: DirectShow Professional");
    take_screenshot_windows_directshow()
}

/// Test Windows Method #5: Win32 API Direct Calls
/// - Direct Windows GDI calls via PowerShell
/// - Maximum compatibility across Windows versions
/// - Low-level system API access
#[cfg(target_os = "windows")]
pub fn test_windows_method_5_win32() -> Result<String> {
    println!("[TEST] Testing Windows Method #5: Win32 API Direct Calls");
    take_screenshot_windows_win32()
}

/// Test Windows Method #6: WMI Enterprise
/// - Windows Management Instrumentation
/// - Enterprise monitoring approach
/// - System administration grade capture
#[cfg(target_os = "windows")]
pub fn test_windows_method_6_wmi() -> Result<String> {
    println!("[TEST] Testing Windows Method #6: WMI Enterprise");
    take_screenshot_windows_wmi()
}

/// Test Windows Method #7: FFmpeg Professional
/// - Professional video/screen capture tool
/// - High-quality output if FFmpeg is installed
/// - Uses Windows GDI grabber
#[cfg(target_os = "windows")]
pub fn test_windows_method_7_ffmpeg() -> Result<String> {
    println!("[TEST] Testing Windows Method #7: FFmpeg Professional");
    take_screenshot_windows_ffmpeg()
}

/// Test Windows Method #8: C# Inline Compilation
/// - Dynamic C# compilation and execution
/// - Reliable on .NET systems
/// - Native Windows development approach
#[cfg(target_os = "windows")]
pub fn test_windows_method_8_csharp() -> Result<String> {
    println!("[TEST] Testing Windows Method #8: C# Inline Compilation");
    take_screenshot_windows_csharp()
}

/// Test Windows Method #9: VBScript Legacy
/// - Windows Scripting Host approach
/// - Legacy fallback method
/// - Last resort compatibility method
#[cfg(target_os = "windows")]
pub fn test_windows_method_9_vbscript() -> Result<String> {
    println!("[TEST] Testing Windows Method #9: VBScript Legacy");
    take_screenshot_windows_vbscript()
}

// =============================================================================
// WINDOWS UTILITY TESTING API
// =============================================================================

/// Test Windows environment assessment
/// - Checks all available screenshot methods
/// - Provides capability scoring
/// - Enterprise-grade assessment
#[cfg(target_os = "windows")]
pub fn test_windows_environment_check() -> Result<()> {
    println!("[TEST] Testing Windows Environment Assessment");
    check_windows_environment()
}

/// Test NirCmd availability detection
/// - Checks system installations
/// - Verifies bundled assets
/// - Professional utility detection
#[cfg(target_os = "windows")]
pub fn test_nircmd_availability() -> bool {
    println!("[TEST] Testing NirCmd Availability Detection");
    is_nircmd_available()
}

/// Test bundled NirCmd asset extraction
/// - Smart Flutter asset detection
/// - Secure extraction process  
/// - Zero-dependency method setup
#[cfg(target_os = "windows")]
pub fn test_bundled_nircmd_extraction() -> Result<String> {
    println!("[TEST] Testing Bundled NirCmd Asset Extraction");
    extract_bundled_nircmd()
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
            ("NirCmd Professional", test_windows_method_1_nircmd as fn() -> Result<String>),
            ("PowerShell Standard", test_windows_method_2_powershell),
            ("Memory Ultra-Stealth", test_windows_method_3_memory),
            ("DirectShow Professional", test_windows_method_4_directshow),
            ("Win32 API Direct", test_windows_method_5_win32),
            ("WMI Enterprise", test_windows_method_6_wmi),
            ("FFmpeg Professional", test_windows_method_7_ffmpeg),
            ("C# Inline Compilation", test_windows_method_8_csharp),
            ("VBScript Legacy", test_windows_method_9_vbscript),
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

// Stub implementations for Windows-specific functions on non-Windows platforms
// These are required because Flutter Rust Bridge exposes all public functions

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
pub fn take_screenshot_windows_csharp() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_directshow() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_ffmpeg() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_memory() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_nircmd() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_powershell() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_vbscript() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_win32() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn take_screenshot_windows_wmi() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_bundled_nircmd_extraction() -> Result<String> {
    Err(anyhow!("Windows-specific function not available on this platform"))
}

#[cfg(not(target_os = "windows"))]
pub fn test_nircmd_availability() -> bool {
    false
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
pub fn test_windows_environment_check() -> Result<()> {
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

// Stub implementations for Linux-specific functions on non-Linux platforms
// These are required because Flutter Rust Bridge exposes all public functions

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