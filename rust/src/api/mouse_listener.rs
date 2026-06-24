use crate::frb_generated::StreamSink;
#[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
use device_query::{DeviceQuery, DeviceState};
use serde::Serialize;
use std::collections::HashSet;
use std::thread;
use std::time::Duration;

#[derive(Serialize, Debug)]
pub struct MouseEvent {
    pub button: String,
    pub is_button_press: bool,
    pub coords: (i32, i32),
    pub is_left_click: bool,
    pub is_right_click: bool,
}

// Updated helper function that matches the lowercase debug string.
#[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
fn mouse_button_to_event_data_from_str(s: &str) -> (String, bool, bool) {
    let s_lower = s.to_lowercase();
    if s_lower.contains("left") {
        ("left".to_owned(), true, false)
    } else if s_lower.contains("right") {
        ("right".to_owned(), false, true)
    } else if s_lower.contains("middle") {
        ("middle".to_owned(), false, false)
    } else {
        (s_lower, false, false)
    }
}

/// Starts a polling-based mouse listener that sends mouse events (button press/release with coordinates)
/// through the provided StreamSink.
pub fn start_mouse_listener(sink: StreamSink<MouseEvent>) -> Result<(), String> {
    thread::spawn(move || {
        #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
        {
            let device_state = DeviceState::new();
            // Track pressed buttons by their friendly names.
            let mut previous_buttons: HashSet<String> = HashSet::new();

            loop {
                let mouse_state = device_state.get_mouse();
                // Map each pressed button's Debug representation (converted to lowercase)
                // into a tuple: (friendly name, is_left_click, is_right_click).
                let current_events: Vec<(String, bool, bool)> = mouse_state
                    .button_pressed
                    .iter()
                    .map(|b| {
                        let btn_str = format!("{:?}", b);
                        mouse_button_to_event_data_from_str(&btn_str)
                    })
                    .collect();
                // Build a HashSet of button names for state comparison.
                let current_buttons: HashSet<String> = current_events
                    .iter()
                    .map(|(name, _, _)| name.clone())
                    .collect();

                let current_coords = mouse_state.coords;

                // For new button press events: buttons present now but not previously.
                for (name, is_left, is_right) in current_events.iter() {
                    if !previous_buttons.contains(name) {
                        let event = MouseEvent {
                            button: name.clone(),
                            is_button_press: true,
                            coords: current_coords,
                            is_left_click: *is_left,
                            is_right_click: *is_right,
                        };
                        let _ = sink.add(event);
                    }
                }

                // For button release events: buttons that were pressed before but not anymore.
                for name in previous_buttons.difference(&current_buttons) {
                    let (is_left, is_right) = match name.as_str() {
                        "left" => (true, false),
                        "right" => (false, true),
                        "middle" => (false, false),
                        _ => (false, false),
                    };
                    let event = MouseEvent {
                        button: name.clone(),
                        is_button_press: false,
                        coords: current_coords,
                        is_left_click: is_left,
                        is_right_click: is_right,
                    };
                    let _ = sink.add(event);
                }

                previous_buttons = current_buttons;
                thread::sleep(Duration::from_millis(50));
            }
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            // Do nothing on unsupported platforms
        }
    });

    Ok(())
}
