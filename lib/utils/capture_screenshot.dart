import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/rust/api/take_full_screenshot.dart';
import 'package:pi_task_watch/utils/compress_image.dart';

Future<String> captureScreenshot() async {
  if (GetPlatform.isAndroid || GetPlatform.isIOS) {
    print('🔵 Skipping screenshot on mobile platform');
    return '';
  }
  //
  print('🔵 Starting screenshot capture process...');

  String? rawImage;
  String? compressedImage;

  print('🔵 Platform check: isWindows = ${GetPlatform.isWindows}');

  try {
    if (GetPlatform.isWindows) {
      print('🔵 Using Windows optimized screenshot method...');
      try {
        // Use the Rust backend which has multiple Windows-specific methods:
        // 1. Screenshots crate (primary)
        // 2. NirCmd (silent, Windows native)
        // 3. PowerShell with hidden window (fallback)
        print('🔵 Attempting Rust-based Windows screenshot...');
        rawImage = await takeScreenshotWindowsNircmd();
        print('✅ Windows screenshot captured successfully');
      } catch (e) {
        print('❌ Windows NirCmd screenshot failed: $e, trying fallback...');
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
  }
}
