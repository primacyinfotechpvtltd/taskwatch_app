pub mod simple;
pub mod take_full_screenshot;

// Import the desktop notification module
pub mod desktop_notification;
pub mod get_all_process_list;
pub mod keyboard_listener;
pub mod mouse_listener;
pub mod active_window_listener;

// Re-export types needed by frb_generated.rs
pub use std::sync::{Arc, Mutex};