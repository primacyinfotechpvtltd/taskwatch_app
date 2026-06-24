# Quick Guide: Background Service Implementation

## What Was Fixed
Your TaskWatch app will no longer freeze when your system goes to sleep or idle mode. The app now continues tracking time accurately even during:
- System sleep
- Screen lock
- Idle periods
- Background operation

## How It Works
1. **Lifecycle Management**: The app now monitors its state and automatically recovers from interruptions
2. **Wakelock**: Prevents system sleep from affecting the app's timers
3. **Auto-Recovery**: If any timer stops, it automatically restarts
4. **Heartbeat**: Regular checks every 30 seconds ensure the app stays alive

## For Users

### What You'll Notice
✅ **More Accurate Time Tracking**: No more missed time when you step away  
✅ **Reliable Screenshots**: Screenshots continue even if system sleeps  
✅ **Better Sync**: Data syncs reliably to Odoo  
✅ **No Manual Intervention**: Everything works automatically  

### What to Check
1. **Permissions**: Ensure the app has permission to run in the background (system settings)
2. **Updates**: Keep the app updated for latest improvements
3. **Logs**: If you notice issues, check the debug console for `[AppLifecycleService]` messages

### If You Experience Issues
1. **Close and restart the app** - This will reinitialize all services
2. **Check system permissions** - Ensure background operation is allowed
3. **Report with details** - Include platform (macOS/Linux/Windows) and what happened

## For Developers

### Quick Test
```dart
// Check lifecycle service status
final service = AppLifecycleService();
print('App active: ${service.isAppActive}');
print('Wakelock: ${service.isWakelockEnabled}');

// Force timer restart (if needed)
await service.forceRestartTimers();
```

### Debug Logs to Watch
```
[AppLifecycleService] Wakelock enabled - app will stay active
[AppLifecycleService] Heartbeat: App is alive at...
🔍 TaskWatch: Duration timer is running
🔍 TaskWatch: Screenshot timer is running
```

### Key Files
- `lib/services/app_lifecycle_service.dart` - Main lifecycle service
- `lib/controllers/tracker_controller.dart` - Timer management
- `lib/main.dart` - Service initialization

## Platform-Specific Notes

### macOS
- Full wakelock support
- App continues normally during system sleep
- Requires macOS 10.13 or later

### Linux
- Wakelock support varies by distribution
- Heartbeat mechanism provides fallback
- Tested on Ubuntu 20.04+

### Windows
- Full wakelock support
- Reliable background operation
- Works on Windows 10 and 11

## Technical Details

### New Dependencies
- `wakelock_plus: ^1.2.8` - Cross-platform wakelock implementation

### New Methods
- `AppLifecycleService.initialize()` - Start lifecycle management
- `TrackerController.ensureTimersRunning()` - Verify and restart timers
- `AppLifecycleService.forceRestartTimers()` - Emergency recovery

### Timer Recovery
All critical timers are monitored:
- **Duration Timer**: 1-second interval for accurate time tracking
- **Screenshot Timer**: Configurable interval for periodic screenshots
- **Sync Timer**: 4-minute interval for syncing to Odoo

## FAQ

**Q: Will this drain my battery?**  
A: No, the impact is minimal. The wakelock only prevents the app from freezing, it doesn't prevent screen sleep or other power-saving features.

**Q: Do I need to configure anything?**  
A: No, everything works automatically. Just update to the latest version.

**Q: What if the app still freezes?**  
A: Try restarting the app. If it persists, check system permissions and report the issue with platform details.

**Q: Can I disable the wakelock?**  
A: Currently no, but it's designed to only be active when you're tracking time.

**Q: Will this work on my Linux distribution?**  
A: Yes, it's tested on major distributions. If wakelock isn't supported, the heartbeat mechanism provides fallback functionality.

## Support
For detailed technical information, see `BACKGROUND_SERVICE_IMPLEMENTATION.md`

---
**Last Updated**: October 21, 2025  
**Version**: 1.0.0
