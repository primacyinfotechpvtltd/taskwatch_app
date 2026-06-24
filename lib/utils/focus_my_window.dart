import 'dart:io';

import 'package:window_manager/window_manager.dart';
import 'package:window_to_front/window_to_front.dart';

Future<void> focusMyWindow() async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
    return;
  }
  try {
    await WindowManager.instance.focus();
    await WindowManager.instance.show();

    //
    // WindowManager.instance.;
    //
  } catch (e) {
    print('Primary window focus failed: $e');

    // Try platform-specific fallbacks
    try {
      if (Platform.isWindows) {
        WindowToFront.activate();
      } else if (Platform.isMacOS) {
        // macOS fallback - try bringing to front
        await WindowManager.instance.setAlwaysOnTop(true);
        await WindowManager.instance.setAlwaysOnTop(false);
      } else if (Platform.isLinux) {
        // Linux fallback - try show and focus separately
        await WindowManager.instance.show();
        await Future.delayed(Duration(milliseconds: 100));
        await WindowManager.instance.focus();
      }
    } catch (e2) {
      print('Fallback window focus failed: $e2');

      // Last resort - try basic operations
      try {
        await WindowManager.instance.restore();
        await WindowManager.instance.show();
      } catch (e3) {
        print('Final fallback failed: $e3');
      }
    }
  }
}
