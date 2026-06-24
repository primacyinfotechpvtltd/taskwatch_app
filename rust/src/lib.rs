#[cfg(target_os = "macos")]
#[link(name = "Carbon", kind = "framework")]
extern "C" {}

#[cfg(target_os = "macos")]
#[link(name = "CoreServices", kind = "framework")]
extern "C" {}

// Re-export necessary types for Flutter Rust Bridge
pub use std::sync::{Arc, Mutex};

// Export API modules
pub mod api;

// This line is needed for the generated code to work properly
pub use api::*;

mod frb_generated;
