use anyhow::{anyhow, Result};
use std::process::Command;
#[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
use notify_rust::Notification;

/// Sends a desktop notification with the specified title and message.
///
/// # Arguments
///
/// * `title` - The title of the notification
/// * `message` - The content/body of the notification
/// * `icon_path` - Optional path to an icon file (PNG, JPEG, etc.)
///
/// # Returns
///
/// A `Result` indicating success or failure
///
/// # Cross-platform Compatibility
///
/// - Windows: Uses PowerShell or Windows Toast Notifications
/// - macOS: Uses AppleScript or terminal-notifier
/// - Linux: Uses notify-send, kdialog, zenity, or xmessage
///
/// # Example
///
/// ```rust
/// use crate::api::desktop_notification::send_notification;
///
/// fn notify_user() -> Result<()> {
///     send_notification(
///         "Task Complete".to_string(),
///         "Your long-running task has finished successfully!".to_string(),
///         None
///     )
/// }
/// ```
#[flutter_rust_bridge::frb]
pub fn send_notification(title: String, message: String, icon_path: Option<String>) -> Result<()> {
    #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
    {
        if Notification::new()
            .summary(&title)
            .body(&message)
            .icon(icon_path.as_deref().unwrap_or(""))
            .show()
            .is_ok()
        {
            return Ok(())
        }
    }
    fallback_send_notification(title, message, icon_path)
}

fn fallback_send_notification(title: String, message: String, icon_path: Option<String>) -> Result<()> {
    #[cfg(target_os = "windows")]
    {
        return send_notification_windows(&title, &message, icon_path.as_deref());
    }
    #[cfg(target_os = "macos")]
    {
        return send_notification_macos(&title, &message, icon_path.as_deref());
    }
    #[cfg(target_os = "linux")]
    {
        return send_notification_linux(&title, &message, icon_path.as_deref());
    }
    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    {
        return Err(anyhow!("Notifications not supported on this platform"));
    }
}

#[cfg(target_os = "windows")]
fn send_notification_windows(title: &str, message: &str, _icon_path: Option<&str>) -> Result<()> {
    // Try Windows 10+ toast notification first
    if let Ok(status) = Command::new("powershell")
        .args([
            "-Command",
            &format!(
                r#"
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null;
                [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null;

                $app = '{{{:?}}}';
                $template = @'
                <toast>
                    <visual>
                        <binding template='ToastGeneric'>
                            <text>{}</text>
                            <text>{}</text>
                        </binding>
                    </visual>
                </toast>
                '@;

                $xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
                $xml.LoadXml($template);
                $toast = [Windows.UI.Notifications.ToastNotification]::new($xml);
                [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show($toast);
                "#,
                "PowerShell",
                escape_powershell_string(title),
                escape_powershell_string(message)
            ),
        ])
        .status()
    {
        if status.success() {
            return Ok(());
        }
    }

    // Fallback to older style notification using PowerShell
    let script = format!(
        r#"
        [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null;
        $notification = New-Object System.Windows.Forms.NotifyIcon;
        $notification.Icon = [System.Drawing.SystemIcons]::Information;
        $notification.BalloonTipTitle = '{}';
        $notification.BalloonTipText = '{}';
        $notification.Visible = $true;
        $notification.ShowBalloonTip(5000);
        "#,
        escape_powershell_string(title),
        escape_powershell_string(message)
    );

    let status = Command::new("powershell")
        .args(["-Command", &script])
        .status()?;

    if !status.success() {
        // Last resort - message box (blocks UI but at least shows notification)
        let msgbox_script = format!(
            r#"
            Add-Type -AssemblyName PresentationFramework;
            [System.Windows.MessageBox]::Show('{}', '{}')
            "#,
            escape_powershell_string(message),
            escape_powershell_string(title)
        );
        
        let status = Command::new("powershell")
            .args(["-Command", &msgbox_script])
            .status()?;
            
        if !status.success() {
            return Err(anyhow!("Failed to show notification on Windows"));
        }
    }

    Ok(())
}

#[cfg(target_os = "macos")]
fn send_notification_macos(title: &str, message: &str, icon_path: Option<&str>) -> Result<()> {
    // Try terminal-notifier first (it's more feature-rich)
    if Command::new("sh")
        .args(["-c", "command -v terminal-notifier"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        let mut cmd = Command::new("terminal-notifier");
        cmd.args(["-title", title, "-message", message]);
        
        if let Some(icon) = icon_path {
            cmd.args(["-appIcon", icon]);
        }
        
        let status = cmd.status()?;
        if status.success() {
            return Ok(());
        }
    }

    // Fallback to AppleScript
    let apple_script = format!(
        r#"display notification "{}" with title "{}""#,
        escape_applescript_string(message),
        escape_applescript_string(title)
    );

    let status = Command::new("osascript")
        .args(["-e", &apple_script])
        .status()?;

    if !status.success() {
        return Err(anyhow!("Failed to show notification on macOS"));
    }

    Ok(())
}

#[cfg(target_os = "linux")]
fn send_notification_linux(title: &str, message: &str, icon_path: Option<&str>) -> Result<()> {
    // First try with notify-send (most common notification tool)
    if Command::new("sh")
        .args(["-c", "command -v notify-send"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false) 
    {
        let mut cmd = Command::new("notify-send");
        cmd.args([title, message]);
        
        if let Some(icon) = icon_path {
            cmd.args(["--icon", icon]);
        }
        
        let status = cmd.status()?;
        if status.success() {
            return Ok(());
        }
    }
    
    // Try KDE's kdialog
    if Command::new("sh")
        .args(["-c", "command -v kdialog"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        let status = Command::new("kdialog")
            .args(["--title", title, "--passivepopup", message, "5"])
            .status()?;
            
        if status.success() {
            return Ok(());
        }
    }
    
    // Try GNOME/GTK's zenity
    if Command::new("sh")
        .args(["-c", "command -v zenity"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        let status = Command::new("zenity")
            .args(["--notification", "--text", &format!("{}: {}", title, message)])
            .status()?;
            
        if status.success() {
            return Ok(());
        }
    }
    
    // Last resort, use xmessage if available
    if Command::new("sh")
        .args(["-c", "command -v xmessage"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        let status = Command::new("xmessage")
            .args(["-center", &format!("{}\n\n{}", title, message)])
            .status()?;
            
        if status.success() {
            return Ok(());
        }
    }

    Err(anyhow!("No supported notification system found on Linux"))
}

/// Escapes special characters in a string for use in PowerShell commands.
#[cfg(target_os = "windows")]
fn escape_powershell_string(s: &str) -> String {
    s.replace("'", "''")
     .replace("`", "``")
     .replace("\"", "`\"")
     .replace("$", "`$")
}

/// Escapes special characters in a string for use in AppleScript.
#[cfg(target_os = "macos")]
fn escape_applescript_string(s: &str) -> String {
    s.replace("\"", "\\\"")
     .replace("\\", "\\\\")
}

/// Adds the current module to the lib.rs file to make it accessible.
/// This function is purely for documentation and should not be called.
#[doc(hidden)]
pub fn register_module() {
    // Add this to lib.rs:
    // pub mod desktop_notification;
}

/// Advanced notification with additional options - FFI-friendly version
#[flutter_rust_bridge::frb]
pub fn send_notification_with_options(
    title: String, 
    message: String, 
    icon_path: Option<String>, 
    timeout_seconds: Option<u64>,
    urgency_level: Option<i32>
) -> Result<()> {
    let urgency = urgency_level.map(|level| match level {
        0 => NotificationUrgency::Low,
        1 => NotificationUrgency::Normal,
        _ => NotificationUrgency::Critical,
    });
    
    let builder = NotificationBuilder {
        title: &title,
        message: &message,
        icon_path: icon_path.as_deref(),
        timeout: timeout_seconds,
        urgency,
        actions: Vec::new(),
    };
    
    builder.send()
}

/// Urgency level for notifications (primarily used on Linux, but mapped to other platforms)
#[derive(Debug, Clone, Copy)]
pub enum NotificationUrgency {
    Low,
    Normal,
    Critical,
}

#[allow(dead_code)]
struct NotificationBuilder<'a> {
    title: &'a str,
    message: &'a str,
    icon_path: Option<&'a str>,
    timeout: Option<u64>,
    urgency: Option<NotificationUrgency>,
    actions: Vec<(&'a str, &'a str)>, // (action_id, label)
}

impl<'a> NotificationBuilder<'a> {
    /// Sends the notification with the configured options
    fn send(self) -> Result<()> {
        // Default implementation falls back to basic notification
        send_notification(self.title.to_string(), self.message.to_string(), self.icon_path.map(String::from))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_notification_builder() {
        // This test doesn't actually send notifications, just checks the builder pattern works
        let builder = NotificationBuilder {
            title: "Test Title",
            message: "Test Message",
            icon_path: Some("/path/to/icon.png"),
            timeout: Some(5),
            urgency: Some(NotificationUrgency::Normal),
            actions: vec![("dismiss", "Dismiss"), ("view", "View")],
        };

        assert_eq!(builder.title, "Test Title");
        assert_eq!(builder.message, "Test Message");
        assert_eq!(builder.icon_path, Some("/path/to/icon.png"));
        assert_eq!(builder.timeout, Some(5));
        assert_eq!(builder.actions.len(), 2);
    }
}
