import 'dart:io';
import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/rust/api/take_full_screenshot.dart';
import 'package:pi_task_watch/utils/compress_image.dart';
import 'package:window_manager/window_manager.dart';

Future<String> captureScreenshot() async {
  if (GetPlatform.isAndroid || GetPlatform.isIOS) {
    print('🔵 Skipping screenshot on mobile platform');
    return '';
  }

  bool wasVisible = false;
  bool wasMinimized = false;

  if (GetPlatform.isDesktop) {
    try {
      wasVisible = await windowManager.isVisible();
      wasMinimized = await windowManager.isMinimized();
      if (wasVisible && !wasMinimized) {
        print('🔵 Hiding TaskWatch window before screenshot...');
        await windowManager.hide();
        // Give the OS compositor a brief moment to hide the window
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (e) {
      print('⚠️ Failed to hide window: $e');
    }
  }

  try {
    // macOS: pre-flight permission check — ask once, guide user, retry next tick
    if (GetPlatform.isMacOS) {
      final hasPerm = await hasScreenRecordingPermission();
      if (!hasPerm) {
        print('⚠️ macOS screen recording permission not granted — requesting...');
        // Trigger the system permission dialog (may not appear if unsigned)
        await requestScreenRecordingPermission();
        await Future.delayed(const Duration(milliseconds: 500));
        // Show UI guiding user to System Settings → Privacy & Security → Screen Recording
        checkAndPromptScreenRecordingPermission(Get.context!);
        print('⚠️ Returning empty — will retry on next 10-minute timer tick');
        return '';
      }
      print('✅ macOS screen recording permission verified');
    }

    print('🔵 Starting screenshot capture process...');

    String? rawImage;
    String? compressedImage;

    print('🔵 Platform check: isWindows = ${GetPlatform.isWindows}');

    if (GetPlatform.isWindows) {
      print('🔵 Using Windows optimized screenshot method...');
      try {
        // Use the Rust backend which has multiple Windows-specific methods:
        // 1. Screenshots crate (in-process and silent)
        // 2. Existing NirCmd and PowerShell fallback chain
        print('🔵 Attempting silent in-process Windows screenshot...');
        rawImage = await takeScreenshotWithScreenshotsCrate();
        print('✅ Windows screenshot captured successfully');
      } catch (e) {
        print('❌ Windows in-process screenshot failed: $e, trying fallback...');
        try {
          rawImage = await takeFullScreenshot();
          print('✅ Windows fallback screenshot captured successfully');
        } catch (e2) {
          print('❌ All Windows screenshot methods exhausted: $e2');
          return '';
        }
      }
    } else if (GetPlatform.isLinux) {
      print('🔵 Using Linux screenshot method...');
      try {
        rawImage = await takeFullScreenshot();
        print('✅ Linux screenshot captured successfully');
      } catch (e) {
        print('❌ Linux primary screenshot failed: $e, trying fallback...');
        // Surface Wayland issue — user can't see stderr
        if (Platform.environment.containsKey('WAYLAND_DISPLAY')) {
          print('⚠️ Wayland session detected. Screen capture may require xdg-desktop-portal or switching to X11 (Login → Gear icon → "Ubuntu on Xorg").');
        }
        try {
          rawImage = await takeScreenshotLinuxFallback();
          print('✅ Linux fallback screenshot captured successfully');
        } catch (e2) {
          print('❌ All Linux screenshot methods failed: $e2');
          return '';
        }
      }
    } else if (GetPlatform.isMacOS) {
      print('🔵 Using macOS screenshot method...');
      try {
        rawImage = await takeFullScreenshot();
        print('✅ macOS screenshot captured successfully');
      } catch (e) {
        print('❌ macOS screenshot failed: $e');
        return '';
      }
    } else {
      print('🔵 Using cross-platform screenshot method...');
      rawImage = await takeFullScreenshot();
      print('✅ Cross-platform screenshot captured successfully');
    }

    // Guard: if rawImage is null or empty, skip compression
    if (rawImage == null || rawImage.isEmpty) {
      print('⚠️ Screenshot returned empty data, skipping compression');
      return '';
    }

    print('🔵 Starting image compression...');
    compressedImage = compressBase64Image(rawImage);
    print('✅ Image compression completed');

    print('🔵 Screenshot capture process finished successfully');
    return compressedImage;
  } catch (e, stackTrace) {
    print('❌ Unexpected screenshot error: $e');
    print('❌ Stack trace: $stackTrace');
    return '';
  } finally {
    if (GetPlatform.isDesktop && wasVisible && !wasMinimized) {
      try {
        print('🔵 Restoring TaskWatch window visibility...');
        await windowManager.show(inactive: true);
      } catch (e) {
        print('⚠️ Failed to restore window: $e');
      }
    }
  }
}
