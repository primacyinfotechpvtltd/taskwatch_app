use crate::frb_generated::StreamSink;
#[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
use rdev::{listen, Event, EventType};
use serde::Serialize;
use std::thread;

#[derive(Serialize, Debug)]
pub struct MouseEvent {
    pub button: String,
    pub is_button_press: bool,
    pub coords: (i32, i32),
    pub is_left_click: bool,
    pub is_right_click: bool,
}

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

/// Starts an event-driven mouse listener that sends mouse events (clicks, scrolls) through the provided StreamSink.
pub fn start_mouse_listener(sink: StreamSink<MouseEvent>) -> Result<(), String> {
    thread::spawn(move || {
        #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
        {
            let mut last_x = 0;
            let mut last_y = 0;
            let callback = move |event: Event| {
                match event.event_type {
                    EventType::MouseMove { x, y } => {
                        last_x = x as i32;
                        last_y = y as i32;
                    }
                    EventType::ButtonPress(button) => {
                        let btn_str = format!("{:?}", button);
                        let (name, is_left, is_right) = mouse_button_to_event_data_from_str(&btn_str);
                        let _ = sink.add(MouseEvent {
                            button: name,
                            is_button_press: true,
                            coords: (last_x, last_y),
                            is_left_click: is_left,
                            is_right_click: is_right,
                        });
                    }
                    EventType::ButtonRelease(button) => {
                        let btn_str = format!("{:?}", button);
                        let (name, is_left, is_right) = mouse_button_to_event_data_from_str(&btn_str);
                        let _ = sink.add(MouseEvent {
                            button: name,
                            is_button_press: false,
                            coords: (last_x, last_y),
                            is_left_click: is_left,
                            is_right_click: is_right,
                        });
                    }
                    EventType::Wheel { .. } => {
                        // Send scroll as a custom button type so Dart handles it
                        let _ = sink.add(MouseEvent {
                            button: "scroll".to_string(),
                            is_button_press: true,
                            coords: (last_x, last_y),
                            is_left_click: false,
                            is_right_click: false,
                        });
                    }
                    _ => {}
                }
            };
            if let Err(error) = listen(callback) {
                println!("Error in mouse listener: {:?}", error);
            }
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            // Do nothing on unsupported platforms
        }
    });

    Ok(())
}
