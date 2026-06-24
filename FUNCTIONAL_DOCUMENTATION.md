# PI Task Watch
## Functional Specification Report

**Application Version:** 1.0.19  
**Developed by:** Primacy Infotech  
**Platforms:** Windows • macOS • Linux  
**Integration:** Odoo ERP System  
**Document Date:** October 17, 2025

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Application Overview](#application-overview)
3. [Implemented Features](#implemented-features)
4. [User Experience](#user-experience)
5. [Security & Privacy](#security--privacy)
6. [System Integration](#system-integration)
7. [System Requirements](#system-requirements)
8. [Support & Maintenance](#support--maintenance)

---

## Executive Summary

PI Task Watch is a cross-platform employee productivity monitoring and time tracking application that integrates seamlessly with Odoo ERP systems. The application enables organizations to monitor employee work activities, track time accurately, and automatically generate timesheets while respecting user privacy.

### Key Benefits

✅ **Automated Time Tracking** - Eliminates manual timesheet entry  
✅ **Real-time Monitoring** - Track employee activities as they happen  
✅ **Odoo Integration** - Direct synchronization with existing Odoo projects and tasks  
✅ **Multi-platform** - Works on Windows, macOS, and Linux  
✅ **Privacy-Conscious** - Configurable monitoring with clear privacy boundaries  
✅ **Idle Time Management** - Intelligent detection and handling of inactive periods

---

## Application Overview

### Business Purpose

PI Task Watch helps organizations:
- **Improve Accountability** - Transparent tracking of work hours and activities
- **Accurate Billing** - Precise time records for client billing
- **Productivity Analysis** - Understand work patterns and optimize workflows
- **Remote Work Management** - Monitor distributed teams effectively
- **Automated Reporting** - Eliminate manual timesheet entry errors

### How It Works

The application runs quietly in the background on employee computers, positioned in the bottom-right corner of the screen. When an employee starts working on a task, the application:
1. Tracks the time spent
2. Monitors basic computer activities (mouse, keyboard, active applications)
3. Periodically captures screenshots
4. Automatically syncs all data to Odoo
5. Creates accurate timesheet entries

---

## Implemented Features

### 1. User Authentication

**What It Does:**
- Secure login using Odoo credentials
- Multi-database support for organizations with multiple Odoo instances
- Automatic login on subsequent application launches
- Server URL customization for different Odoo installations

**User Benefits:**
- Single sign-on with existing Odoo credentials
- No need to create separate accounts
- Quick access after initial setup

---

### 2. Work Session Management

#### Starting Work

**What It Does:**
- Users select their current project from a dropdown list
- Users select the specific task they're working on
- Optional notes can be added to provide context
- One-click "Start Work" button begins tracking

**What Happens:**
- Timer starts counting work duration
- Timesheet entry is automatically created in Odoo
- Activity monitoring begins
- Screenshot capture timer is activated

#### During Work

**What the Application Tracks:**
- **Time Duration** - Precise time from start to current moment
- **Mouse Activity** - Clicks and movements to detect active work
- **Keyboard Activity** - Key presses to measure engagement (NOT the actual keys typed)
- **Active Applications** - Which programs are being used
- **Screenshots** - Periodic screen captures at configurable intervals

**What Users See:**
- Real-time timer showing elapsed time
- Current project and task information
- Activity indicator showing the application is running
- Compact window that stays out of the way

#### Stopping Work

**What It Does:**
- One-click "Stop Work" button ends the session
- All tracked data is finalized and sent to Odoo
- Session summary is displayed to the user
- User returns to the dashboard ready to start a new session

**What Happens in Odoo:**
- Timesheet is updated with final duration
- All activity data is attached to the timesheet record
- Session screenshots are uploaded
- Task progress is reflected

---

### 3. Activity Monitoring

**What Is Monitored:**

| Activity | What's Tracked | Purpose |
|----------|----------------|---------|
| **Mouse Clicks** | Number of clicks | Measure active engagement |
| **Mouse Movement** | Cursor movement events | Detect user presence |
| **Keyboard Typing** | Number of keystrokes | Measure work activity |
| **Active Window** | Application name and window title | Understand work context |

**Privacy Protection:**
- ✅ Only tracks THAT activity happened, not the content
- ✅ Keyboard tracking counts keypresses, does NOT record what was typed
- ✅ No password or sensitive field tracking
- ✅ No clipboard monitoring
- ✅ Screenshots are taken at intervals, not continuously

---

### 4. Screenshot Capture

**What It Does:**
- Automatically captures full-screen screenshots at regular intervals
- Screenshots are timestamped with the exact moment in the work session
- Images are immediately uploaded to Odoo and attached to timesheet records
- Original screenshots are deleted from the local computer after upload

**Configuration:**
- Screenshot frequency is configurable by administrators
- Default: 3 screenshots per 10-minute session
- Can be adjusted per company requirements

**Purpose:**
- Verify active work engagement
- Provide context for time tracking disputes
- Support remote work accountability
- Assist in project documentation

---

### 5. Idle Time Detection

**What It Does:**
- Monitors user activity continuously
- Detects when there's no mouse or keyboard activity for a set period
- Default threshold: 5 minutes of inactivity
- Automatically pauses the timer when idle is detected
- Shows a dialog asking the user to explain the idle time

**When Idle Is Detected:**

Users have three options:

1. **Keep Time** - Count the idle period as work time
   - Requires a note explaining why (e.g., "Reading documentation," "In a meeting")
   - Time is kept in the timesheet

2. **Deduct Time** - Remove the idle period from tracked time
   - Automatically adjusts the timesheet
   - Work session continues from the current time

3. **Dismiss** - Make a decision later
   - Dialog can be temporarily dismissed
   - Decision must be made before ending the work session

**Benefits:**
- Fair time tracking for employees
- Prevents accidental time tracking when away from desk
- Allows legitimate breaks to be properly categorized
- Reduces disputes about tracked hours

---

### 6. Project & Task Selection

**What It Does:**
- Automatically fetches all projects assigned to the logged-in user from Odoo
- Displays projects in an easy-to-search dropdown menu
- When a project is selected, loads all associated tasks
- Tasks show relevant information: name, stage, allocated time, time already spent

**User Experience:**
- Type to search for projects and tasks quickly
- See task progress at a glance
- Understand time remaining on tasks before starting work
- Clear indication of task stages (To Do, In Progress, Done, etc.)

**Data Synchronization:**
- Project and task lists are refreshed on each login
- Changes made in Odoo are immediately available
- No manual data entry required

---

### 7. Timesheet Automation

**What It Does:**
- Automatically creates a new timesheet entry in Odoo when work starts
- Continuously updates the timesheet as work progresses
- Finalizes the timesheet when work stops
- Syncs activity data, screenshots, and notes to the timesheet

**Timesheet Information Recorded:**
- User name and ID
- Project and task details
- Start date and time
- Duration (in hours and minutes)
- Activity summary (mouse clicks, keystrokes, applications used)
- Screenshots with timestamps
- Any notes added by the user
- System information (computer name, operating system)

**Benefits:**
- Eliminates manual timesheet entry
- 100% accurate time records
- Reduced administrative overhead
- Improved billing accuracy
- Audit trail for compliance

---

### 8. Dashboard & Interface

**What Users See:**

#### Main Dashboard
- **Current Status** - Whether tracking is active or stopped
- **Today's Summary** - Total time worked today across all tasks
- **Recent Activity** - List of recent work sessions
- **Quick Actions** - Start work, view timesheets, settings, logout

#### Compact Window Design
- Small, unobtrusive window positioned in the bottom-right corner
- Always-on-top mode (optional) keeps it visible
- Custom window controls (minimize, close)
- Responsive design that adapts to screen size

#### Work Session View (When Tracking)
- Large timer display showing elapsed time
- Project and task name clearly visible
- Activity indicators showing monitoring status
- Stop work button prominently placed
- Visual confirmation that tracking is active

---

### 9. Multi-Platform Support

**Supported Operating Systems:**

#### Windows (10 and later)
- Native Windows application
- Installer (.exe) for easy deployment
- System tray integration
- Automatic startup option

#### macOS (10.14 Mojave and later)
- Native macOS application
- Disk image (.dmg) installation
- Supports both Intel and Apple Silicon
- Full macOS permissions integration

#### Linux (Ubuntu 20.04+, Fedora 34+, etc.)
- Native Linux application
- Multiple formats: .deb, .rpm, AppImage
- Supports both X11 and Wayland
- Compatible with major desktop environments

**Platform-Specific Features:**
- Automatic window positioning adjusted for taskbars/docks
- Native permission requests for accessibility and screen recording
- OS-specific screenshot optimization
- Adaptive UI based on system theme

---

### 10. Settings & Configuration

**User Settings:**
- **Server URL** - Connect to different Odoo instances
- **Auto-login** - Stay logged in between sessions
- **Window Position** - Choose where the window appears (currently bottom-right)
- **Logout** - Securely end the session

**Administrator Settings (Configured in Odoo):**
- **Idle Threshold** - How long before considering user idle (default: 5 minutes)
- **Session Duration** - Length of tracking sessions (default: 10 minutes)
- **Screenshots Per Session** - Number of screenshots to capture (default: 3)
- **Offline Timeout** - How long the app can work without server connection
- **Timezone** - User's timezone for accurate time recording
- **Maintenance Mode** - Temporarily disable tracking for all users

---

### 11. System Information Capture

**What It Records:**
For audit and troubleshooting purposes, each session includes:
- Operating system type and version
- Computer hostname
- CPU architecture
- System locale/language
- Number of CPU cores
- Local and public IP addresses
- Application version

**Purpose:**
- Identify system compatibility issues
- Troubleshoot technical problems
- Generate usage reports by platform
- Support multi-device users
- Compliance and audit requirements

---

## User Experience

### Typical User Journey

#### First-Time Setup (One-time, 2-3 minutes)
1. Install the application on their computer
2. Launch the application
3. Grant required system permissions (macOS/Linux)
4. Enter Odoo server URL (if not pre-configured)
5. Select their Odoo database
6. Login with their Odoo email and password
7. Application remembers credentials for future use

#### Daily Use (Under 30 seconds per session)
1. Application starts automatically or user launches it
2. User is already logged in
3. Click "Start Work"
4. Select project from dropdown
5. Select task from dropdown
6. Click "Confirm" - tracking begins
7. Work normally - application runs in background
8. Click "Stop Work" when done - session ends

#### Managing Idle Time (When prompted)
1. Idle dialog appears after inactivity
2. User reads the idle duration shown
3. Chooses to keep time (with note) or deduct time
4. Continues working normally

---

### User Interface Highlights

✅ **Clean & Minimal** - No clutter, just essential information  
✅ **Non-Intrusive** - Small window that doesn't block work  
✅ **Clear Status** - Always know if tracking is active  
✅ **Quick Actions** - Start/stop work with one click  
✅ **Visual Feedback** - Timer and activity indicators provide confidence  
✅ **Searchable Dropdowns** - Find projects/tasks quickly by typing

---

## Security & Privacy

### Data Security

**Credential Protection:**
- User passwords are never stored in plain text
- Token-based authentication for API communication
- Secure HTTPS connections to Odoo server
- Local storage uses platform-secure methods

**Screenshot Security:**
- Screenshots transmitted over encrypted HTTPS
- Deleted from local computer after successful upload
- Stored securely in Odoo with access controls
- Only administrators and assigned managers can view

**Network Security:**
- All communication encrypted with SSL/TLS
- Custom certificate validation
- Timeout and retry mechanisms
- No data transmitted to third parties

### Privacy Considerations

**What We DON'T Track:**
- ❌ Actual keyboard content (passwords, emails, messages)
- ❌ Clipboard data
- ❌ Web browser history in detail
- ❌ Personal files or documents
- ❌ Email content
- ❌ Chat messages
- ❌ Audio or video from webcam/microphone

**What We DO Track:**
- ✅ Time worked on tasks
- ✅ Number of mouse clicks and keystrokes
- ✅ Which applications are used (by name)
- ✅ Periodic screenshots of the screen
- ✅ Computer activity vs. idle time

**Transparency:**
- Employees always know when tracking is active
- Visible window indicator shows tracking status
- All tracked data is accessible to the employee
- Clear privacy policy explaining what's monitored

### Permission Requirements

**macOS & Linux:**
- **Accessibility Permission** - Required to monitor keyboard and mouse
- **Screen Recording Permission** - Required to capture screenshots

**Windows:**
- Runs with standard user permissions
- No elevated privileges required

**User Control:**
- Permissions requested on first launch
- Clear explanations for why each permission is needed
- Cannot function without required permissions
- Users can revoke permissions via system settings

---

## System Integration

### Odoo ERP Integration

**Seamless Connection:**
The application integrates directly with your existing Odoo installation:

**What Syncs from Odoo to Application:**
- User account and authentication
- Assigned projects
- Project tasks with full details
- Task stages and progress
- Time already spent on tasks
- Application settings and configurations
- User permissions and access levels

**What Syncs from Application to Odoo:**
- Timesheet entries (created automatically)
- Work session duration
- Activity data (mouse, keyboard, window changes)
- Screenshots attached to timesheets
- Idle time records with user notes
- System information for audit logs

**Real-time Synchronization:**
- Data syncs every 10 minutes during active sessions
- Immediate sync when starting or stopping work
- Offline queue for when server is unreachable
- Automatic retry on connection failure
- Visual indicators for sync status

### Odoo Modules Required

The application works with:
- **Project Management** module
- **Timesheet** module
- **HR** module (for employee records)
- **Custom TaskWatch API** (provided by Primacy Infotech)

---

## System Requirements

### Computer Requirements

**Minimum Specifications:**
- **Processor:** Dual-core 2.0 GHz or faster
- **RAM:** 4 GB minimum
- **Storage:** 200 MB available space
- **Display:** 1280x720 resolution or higher
- **Network:** Broadband internet connection

**Recommended Specifications:**
- **Processor:** Quad-core 2.5 GHz or faster
- **RAM:** 8 GB or more
- **Storage:** 500 MB available space
- **Display:** 1920x1080 resolution or higher
- **Network:** Stable wired or WiFi connection

### Operating System Compatibility

| Platform | Supported Versions |
|----------|-------------------|
| **Windows** | Windows 10, Windows 11 |
| **macOS** | macOS 10.14 (Mojave) through latest |
| **Linux** | Ubuntu 20.04+, Fedora 34+, Debian 11+, and equivalents |

### Network Requirements

**Required Access:**
- HTTPS access to Odoo server
- Ports: 443 (HTTPS), 80 (HTTP for redirect)
- No firewall blocking of Odoo domain
- Stable internet connection (3G/4G/WiFi/Ethernet)

**Bandwidth:**
- Minimal during normal operation (< 100 KB/hour)
- Screenshot uploads: ~500 KB per screenshot
- Average: 1-2 MB per hour of work

**Offline Capability:**
- Can continue tracking when offline
- Data queued locally for up to 30 minutes
- Automatic sync when connection restored
- Warning shown if offline too long

---

## Support & Maintenance

### Installation & Deployment

**Installation Methods:**
- **Windows:** Download and run installer (.exe), follow wizard
- **macOS:** Download disk image (.dmg), drag to Applications folder
- **Linux:** Install package (.deb/.rpm) or run AppImage directly

**Deployment Options:**
- Individual user installation
- IT department mass deployment via group policy/MDM
- Pre-configured installers with server URL embedded
- Silent installation for enterprise environments

### Updates

**Update Mechanism:**
- Automatic update notifications
- One-click update process
- No data loss during updates
- Rollback capability if issues occur

**Update Frequency:**
- Security updates: As needed
- Feature updates: Monthly
- Bug fixes: Weekly

### Troubleshooting

**Common Issues & Solutions:**

| Issue | Solution |
|-------|----------|
| Cannot login | Verify database selection, check credentials, test network |
| Permissions denied | Grant Accessibility/Screen Recording in system settings |
| Screenshots not captured | Check permissions, restart application |
| Idle detection not working | Grant Accessibility permission on macOS/Linux |
| Data not syncing | Check network connection, verify Odoo server status |

**Support Channels:**
- In-app help documentation
- Email support: support@primacyinfotech.com
- Phone support: [To be provided]
- Remote assistance available for troubleshooting

### Logs & Diagnostics

**For Troubleshooting:**
- Application maintains detailed logs
- Logs stored locally in user directory
- Can be exported and sent to support team
- Privacy-safe (no passwords or sensitive data in logs)

**Debug Mode:**
- Can be enabled for detailed troubleshooting
- Provides verbose logging
- Helps diagnose connection issues
- Should be disabled for normal use

---

## Conclusion

PI Task Watch provides a complete, turnkey solution for employee time tracking and productivity monitoring with seamless Odoo integration. The application balances the need for accurate time tracking and accountability with respect for employee privacy and system security.

### Key Advantages

✅ **Zero Manual Entry** - Timesheets created automatically  
✅ **Accurate Billing** - Precise time records for clients  
✅ **Remote Work Ready** - Perfect for distributed teams  
✅ **Privacy Conscious** - Clear boundaries on what's monitored  
✅ **Easy to Use** - Minimal training required  
✅ **Multi-Platform** - Works on all major operating systems  
✅ **Odoo Native** - Direct integration with existing workflows

### Ready for Deployment

The application is production-ready and has been tested across all supported platforms. It includes:
- Comprehensive error handling
- Automatic retry mechanisms
- Offline capability
- Data validation
- Security best practices
- User-friendly interface
- Administrator controls

---

**For more information or to schedule a demo, please contact:**

**Primacy Infotech**  
Email: info@primacyinfotech.com  
Website: https://primacyinfotech.com

---

*This functional specification describes PI Task Watch version 1.0.19 as of October 17, 2025.*




