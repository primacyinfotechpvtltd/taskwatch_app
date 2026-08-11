use crate::frb_generated::StreamSink;
#[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
use rdev::{listen, Event, EventType};
use serde::Serialize;
use std::thread;

#[derive(Serialize, Debug)]
pub struct KeyboardEvent {
    pub key: String,
    pub is_key_press: bool,
}

/// Starts an event-driven keyboard listener that sends key events through the provided StreamSink.
pub fn start_keyboard_listener(sink: StreamSink<KeyboardEvent>) -> Result<(), String> {
    thread::spawn(move || {
        #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
        {
            let callback = move |event: Event| {
                match event.event_type {
                    EventType::KeyPress(key) => {
                        let _ = sink.add(KeyboardEvent {
                            key: format!("{:?}", key).to_lowercase(),
                            is_key_press: true,
                        });
                    }
                    EventType::KeyRelease(key) => {
                        let _ = sink.add(KeyboardEvent {
                            key: format!("{:?}", key).to_lowercase(),
                            is_key_press: false,
                        });
                    }
                    _ => {}
                }
            };
            if let Err(error) = listen(callback) {
                println!("Error in keyboard listener: {:?}", error);
            }
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            // Do nothing on unsupported platforms
        }
    });

    Ok(())
}
