use sysinfo::{System, ProcessesToUpdate};
use std::time::Duration;

/// Struct to represent process information
/// Compatible with Flutter Rust Bridge
#[derive(Debug, Clone)]
pub struct ProcessInfo {
    pub pid: u32,
    pub name: String,
    pub cmd: Vec<String>,
    pub memory_usage: u64,
    pub cpu_usage: f32,
}

/// Returns a list of all running processes on the system
/// Works on macOS, Linux, and Windows
pub fn get_all_processes() -> Vec<ProcessInfo> {
    // Create a new system instance with all data
    let mut system = System::new_all();
    
    // Some versions/platforms need a small delay and multiple refreshes
    system.refresh_all();
    std::thread::sleep(Duration::from_millis(50));
    system.refresh_processes(ProcessesToUpdate::All, true);
    
    // Log platform info for debugging
    println!("Platform: {}", std::env::consts::OS);
    
    let count = system.processes().len();
    println!("Found {} processes", count);
    
    // Add a warning if no processes are found
    if count == 0 {
        println!("Warning: No processes found. This is likely a permissions issue.");
        println!("On macOS: Run with sudo or adjust app permissions.");
        println!("On Linux: Run with sudo if needed.");
        println!("On Windows: Run as administrator if needed.");
    }
    
    // Collect and convert process information
    system
        .processes()
        .iter()
        .map(|(pid, process)| {
            ProcessInfo {
                pid: pid.as_u32(),
                name: process.name().to_string_lossy().into_owned(),
                cmd: process.cmd().iter().map(|s| s.to_string_lossy().into_owned()).collect(),
                memory_usage: process.memory(),
                cpu_usage: process.cpu_usage(),
            }
        })
        .collect()
}

/// Provides platform-specific information about process access
pub fn get_process_access_info() -> String {
    match std::env::consts::OS {
        "macos" => "On macOS, accessing process information may require running as an administrator or adjusting privacy settings.".to_string(),
        "linux" => "On Linux, some process information may require elevated privileges.".to_string(),
        "windows" => "On Windows, some process information may require administrator rights.".to_string(),
        _ => "Access to process information may be restricted on this platform.".to_string()
    }
}

/// Returns a boolean indicating if the function can access process information
/// This can help diagnose permission issues
pub fn can_access_processes() -> bool {
    let mut system = System::new_all();
    system.refresh_processes(ProcessesToUpdate::All, false);
    !system.processes().is_empty()
}

/// Finds a process by name (partial match)
pub fn find_process_by_name(name: &str) -> Vec<ProcessInfo> {
    get_all_processes()
        .into_iter()
        .filter(|process| process.name.to_lowercase().contains(&name.to_lowercase()))
        .collect()
}

/// Kills a process by PID
/// Returns true if successful, false otherwise
pub fn kill_process(pid: u32) -> bool {
    let mut system = System::new_all();
    system.refresh_all();
    
    // Cast u32 to usize since Pid implements From<usize> but not From<u32>
    let sys_pid = sysinfo::Pid::from(pid as usize);
    if let Some(process) = system.process(sys_pid) {
        process.kill()
    } else {
        false
    }
}
