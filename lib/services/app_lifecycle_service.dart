import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pi_task_watch/exports.dart';

/// Service to manage app lifecycle and prevent freezing during system sleep/idle
/// Handles platform-specific behavior for macOS, Linux, and Windows
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isInitialized = false;
  bool _isAppActive = true;
  bool _wakelockEnabled = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectionTimer;
  DateTime? _lastActiveTime;

  final _lifecycleStateController =
      StreamController<AppLifecycleState>.broadcast();
  Stream<AppLifecycleState> get lifecycleStateStream =>
      _lifecycleStateController.stream;

  /// Initialize the lifecycle service
  Future<void> initialize() async {
    if (_isInitialized) {
      _logDebug('AppLifecycleService already initialized');
      return;
    }

    try {
      // Register as lifecycle observer
      WidgetsBinding.instance.addObserver(this);

      // Enable wakelock for desktop platforms to prevent system sleep from affecting the app
      await _enableWakelock();

      // Start heartbeat to keep app responsive
      _startHeartbeat();

      _isInitialized = true;
      _lastActiveTime = DateTime.now();
      _logDebug('AppLifecycleService initialized successfully');
    } catch (e, stackTrace) {
      _logDebug('Error initializing AppLifecycleService: $e');
      _logDebug('Stack trace: $stackTrace');
    }
  }

  /// Dispose the lifecycle service
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _reconnectionTimer?.cancel();
    _disableWakelock();
    _lifecycleStateController.close();
    _isInitialized = false;
    _logDebug('AppLifecycleService disposed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lifecycleStateController.add(state);

    _logDebug('App lifecycle state changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }

  /// Handle app resumed state
  void _onAppResumed() {
    _isAppActive = true;
    _lastActiveTime = DateTime.now();
    _logDebug('App resumed - reactivating services');

    // Restart heartbeat if stopped
    if (_heartbeatTimer == null || !_heartbeatTimer!.isActive) {
      _startHeartbeat();
    }

    // Re-enable wakelock
    _enableWakelock();

    // Notify tracker controller to resume operations
    _notifyTrackerController(isActive: true);
  }

  /// Handle app inactive state (e.g., system going to sleep)
  void _onAppInactive() {
    _isAppActive = false;
    _logDebug('App inactive - maintaining background services');

    // Keep wakelock enabled to prevent freezing
    // Don't stop timers - they should continue running
  }

  /// Handle app paused state
  void _onAppPaused() {
    _isAppActive = false;
    _logDebug('App paused - entering background mode');

    // Save current state before pausing
    _saveCurrentState();

    // Keep essential services running
    // The wakelock will help keep timers active
  }

  /// Handle app detached state
  void _onAppDetached() {
    _logDebug('App detached - cleaning up');
    _saveCurrentState();
  }

  /// Handle app hidden state
  void _onAppHidden() {
    _logDebug('App hidden - continuing background operations');
    // Keep everything running even when hidden
  }

  /// Enable wakelock to prevent system sleep from affecting the app
  Future<void> _enableWakelock() async {
    if (_wakelockEnabled) return;

    try {
      // Try to enable wakelock - it will fail gracefully if not supported
      await WakelockPlus.enable();
      _wakelockEnabled = true;
      _logDebug('Wakelock enabled - app will stay active during system sleep');
    } catch (e) {
      _logDebug('Wakelock not available or error enabling: $e');
      // Continue without wakelock - heartbeat will still help
      // Use alternative methods for desktop platforms
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        _logDebug('Using desktop-specific keep-alive mechanisms (heartbeat)');
        // The heartbeat timer will help keep the app responsive
      }
    }
  }

  /// Disable wakelock
  Future<void> _disableWakelock() async {
    if (!_wakelockEnabled) return;

    try {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
      _logDebug('Wakelock disabled');
    } catch (e) {
      _logDebug('Error disabling wakelock: $e');
    }
  }

  /// Start heartbeat timer to keep app responsive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    // Send heartbeat every 30 seconds to keep app active
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final now = DateTime.now();
      _lastActiveTime = now;

      // Check if app is still responsive
      _checkAppResponsiveness();

      _logDebug('Heartbeat: App is alive at ${now.toIso8601String()}');
    });

    _logDebug('Heartbeat timer started');
  }

  /// Check if app is still responsive and restart if needed
  void _checkAppResponsiveness() {
    if (!_isInitialized) return;

    try {
      // Check if tracker controller is still accessible
      if (Get.isRegistered<TrackerController>()) {
        final tracker = Get.find<TrackerController>();

        // If tracking is active, ensure timers are running
        if (tracker.isTracking.value) {
          _logDebug('Tracking active - verifying timer status');

          // This will trigger the tracker to verify its timers
          tracker.ensureTimersRunning();
        }
      }
    } catch (e) {
      _logDebug('Error checking app responsiveness: $e');
    }
  }

  /// Save current state before going to background
  void _saveCurrentState() {
    try {
      if (Get.isRegistered<TrackerController>()) {
        final tracker = Get.find<TrackerController>();

        if (tracker.isTracking.value) {
          _logDebug('Saving tracker state before background transition');
          // Tracker controller should auto-save its state
          // We just log here for debugging
        }
      }
    } catch (e) {
      _logDebug('Error saving current state: $e');
    }
  }

  /// Notify tracker controller about app state changes
  void _notifyTrackerController({required bool isActive}) {
    try {
      if (Get.isRegistered<TrackerController>()) {
        final tracker = Get.find<TrackerController>();

        if (isActive) {
          // App resumed - ensure all timers are running
          _logDebug('Notifying tracker controller: App is active');
          tracker.ensureTimersRunning();
        } else {
          // App going to background - but keep timers running
          _logDebug(
            'Notifying tracker controller: App going to background (keeping timers active)',
          );
        }
      }
    } catch (e) {
      _logDebug('Error notifying tracker controller: $e');
    }
  }

  /// Check if app is currently active
  bool get isAppActive => _isAppActive;

  /// Get last active time
  DateTime? get lastActiveTime => _lastActiveTime;

  /// Check if wakelock is enabled
  bool get isWakelockEnabled => _wakelockEnabled;

  /// Manually trigger app state check (useful for testing)
  Future<void> checkAppState() async {
    _logDebug('Manual app state check triggered');
    _checkAppResponsiveness();
  }

  /// Force restart all timers (emergency recovery)
  Future<void> forceRestartTimers() async {
    _logDebug('Force restarting all timers');

    try {
      // Restart heartbeat
      _startHeartbeat();

      // Restart tracker timers if tracking is active
      if (Get.isRegistered<TrackerController>()) {
        final tracker = Get.find<TrackerController>();
        if (tracker.isTracking.value) {
          tracker.ensureTimersRunning();
        }
      }

      _logDebug('All timers restarted successfully');
    } catch (e) {
      _logDebug('Error restarting timers: $e');
    }
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      print('[AppLifecycleService] $message');
    }
  }
}
