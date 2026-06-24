use crate::frb_generated::StreamSink;
#[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
use device_query::{DeviceQuery, DeviceState};
use serde::Serialize;
use std::collections::HashSet;
use std::thread;
use std::time::Duration;

#[derive(Serialize, Debug)]
pub struct KeyboardEvent {
    pub key: String,
    pub is_key_press: bool,
}

/// Starts a polling-based keyboard listener that sends key events through the provided StreamSink.
/// It converts each Keycode into a lowercase String so we can track keys in a HashSet.
pub fn start_keyboard_listener(sink: StreamSink<KeyboardEvent>) -> Result<(), String> {
    thread::spawn(move || {
        #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
        {
            let device_state = DeviceState::new();
            // Track keys by their string representation.
            let mut previous_keys: HashSet<String> = HashSet::new();

            loop {
                // Convert current keys into lowercase strings.
                let current_keys: HashSet<String> = device_state
                    .get_keys()
                    .into_iter()
                    .map(|k| format!("{:?}", k).to_lowercase())
                    .collect();

                // Detect new key press events: keys in current_keys but not in previous_keys.
                for key in current_keys.difference(&previous_keys) {
                    let event = KeyboardEvent {
                        key: key.clone(),
                        is_key_press: true,
                    };
                    // Ignore any errors
                    let _ = sink.add(event);
                }

                // Detect key release events: keys in previous_keys but not in current_keys.
                for key in previous_keys.difference(&current_keys) {
                    let event = KeyboardEvent {
                        key: key.clone(),
                        is_key_press: false,
                    };
                    let _ = sink.add(event);
                }

                previous_keys = current_keys;
                thread::sleep(Duration::from_millis(50));
            }
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            // Do nothing on unsupported platforms, just exit or sleep if required
        }
    });

    Ok(())
}
