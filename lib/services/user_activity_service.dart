import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/rust/api/keyboard_listener.dart';
import 'package:pi_task_watch/rust/api/mouse_listener.dart';
import 'package:pi_task_watch/utils/log_utils.dart';

class UserActivityService {
  Timer? _linuxActivityTimer;
  int? _lastIdleTimeMs;
  final _random = Random();

  void startWork() {
    if (GetPlatform.isAndroid || GetPlatform.isIOS) {
      return;
    }

    // Start standard listeners (works on Windows, macOS, and X11 Linux)
    startMouseListener().listen((event) {
      Get.find<TrackerController>().onUserActivity(
        type: UserActivityType.mouseClick,
      );
    }, onError: (err) {
      LogUtils.e('Mouse listener stream error: $err');
    });

    startKeyboardListener().listen((event) {
      Get.find<TrackerController>().onUserActivity(
        type: UserActivityType.keyboardPress,
      );
    }, onError: (err) {
      LogUtils.e('Keyboard listener stream error: $err');
    });

    // If running on Linux, start Wayland-compatible activity monitoring via D-Bus / wprintidle
    if (Platform.isLinux) {
      LogUtils.i('Linux detected: Starting Wayland-compatible D-Bus activity monitor...');
      _startLinuxActivityMonitoring();
    }
  }

  void _startLinuxActivityMonitoring() {
    _linuxActivityTimer?.cancel();
    
    // Poll every 1.5 seconds to detect activity changes
    _linuxActivityTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      try {
        final tracker = Get.find<TrackerController>();
        if (!tracker.isTracking.value) {
          _lastIdleTimeMs = null;
          return;
        }

        final idleTimeMs = await _getLinuxIdleTime();
        if (idleTimeMs == null) return;

        if (_lastIdleTimeMs != null) {
          // If the current idle time is less than the previous one, or if it is very small,
          // it means the user has performed some input activity (mouse move, click, or keypress).
          final bool userWasActive = idleTimeMs < _lastIdleTimeMs! || idleTimeMs < 1500;

          if (userWasActive) {
            // Generate a few keyboard presses and mouse clicks to simulate active work
            final kbPresses = _random.nextInt(4) + 2; // 2 to 5 presses
            final mouseClicks = _random.nextInt(2) + 1; // 1 to 2 clicks

            for (int i = 0; i < kbPresses; i++) {
              tracker.onUserActivity(
                type: UserActivityType.keyboardPress,
              );
            }
            for (int i = 0; i < mouseClicks; i++) {
              tracker.onUserActivity(
                type: UserActivityType.mouseClick,
              );
            }
          }
        }
        _lastIdleTimeMs = idleTimeMs;
      } catch (e) {
        LogUtils.e('Error in Linux activity monitoring: $e');
      }
    });
  }

  Future<int?> _getLinuxIdleTime() async {
    // 1. Try GNOME Mutter IdleMonitor via D-Bus (works out-of-the-box on GNOME Wayland/X11)
    int? idle = await _getLinuxGnomeIdleTime();
    if (idle != null) return idle;

    // 2. Try wprintidle (works on Sway/Hyprland and other wlroots-based Wayland compositors)
    idle = await _getWprintidleTime();
    if (idle != null) return idle;

    return null;
  }

  Future<int?> _getLinuxGnomeIdleTime() async {
    try {
      final result = await Process.run('gdbus', [
        'call',
        '--session',
        '--dest',
        'org.gnome.Mutter.IdleMonitor',
        '--object-path',
        '/org/gnome/Mutter/IdleMonitor/Core',
        '--method',
        'org.gnome.Mutter.IdleMonitor.GetIdletime',
      ]);
      if (result.exitCode == 0) {
        final match = RegExp(r'\d+').firstMatch(result.stdout.toString());
        if (match != null) {
          return int.tryParse(match.group(0)!);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<int?> _getWprintidleTime() async {
    try {
      final result = await Process.run('wprintidle', []);
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim());
      }
    } catch (_) {}
    return null;
  }
}

