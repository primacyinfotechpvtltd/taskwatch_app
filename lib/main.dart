import 'dart:io';

import 'package:pi_task_watch/controllers/timesheet_controller.dart';
import 'package:pi_task_watch/my_app.dart';
import 'package:pi_task_watch/rust/frb_generated.dart';
import 'package:pi_task_watch/services/services.dart';
import 'package:pi_task_watch/utils/log_utils.dart'; // Added
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart';

import 'package:pi_task_watch/exports.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging first
  // await LogUtils.init();
  // LogUtils.i('App starting...');

  try {
    // Initialize Rust library
    // LogUtils.i('Initializing Rust library...');
    await RustLib.init();
    // LogUtils.i('Rust library initialized successfully');

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // LogUtils.i('Initializing Window Manager...');
      await WindowManager.instance.ensureInitialized();
      // LogUtils.i('Window Manager initialized');
    }

    // Initialize controllers before the app starts
    // LogUtils.i('Setting up controllers...');
    setAllController();
    // LogUtils.i('Controllers setup complete');

    // Initialize lifecycle service to prevent freezing during system sleep/idle
    // LogUtils.i('Initializing AppLifecycleService...');
    await AppLifecycleService().initialize();
    // LogUtils.i('AppLifecycleService initialized');

    // Start user activity monitoring
    LogUtils.i('Starting UserActivityService...');
    UserActivityService().startWork();
    LogUtils.i('UserActivityService started');

    // Check for Wayland session on Linux
    if (Platform.isLinux) {
      final isWayland = Platform.environment['XDG_SESSION_TYPE'] == 'wayland' ||
          Platform.environment['WAYLAND_DISPLAY'] != null;
      if (isWayland) {
        // LogUtils.w(
        //     'DETECTED WAYLAND SESSION: Global input monitoring and window tracking may be limited by system security.');
        // LogUtils.w(
        //     'For full functionality on Zorin OS/Ubuntu, switching to Xorg (X11) at login is recommended.');
      } else {
        // LogUtils.i('Detected X11 session');
      }
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // LogUtils.i('Setting up window size...');
      setupWindowSize();
    }

    runApp(const MyApp());
    // LogUtils.i('App running');
  } catch (e, stackTrace) {
    // LogUtils.e('FATAL ERROR DURING INITIALIZATION', e, stackTrace);

    // Show a simple error app if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Application failed to start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This might be due to missing system dependencies or hardware incompatibility.\n\nError: $e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Text(
                //   'Log file: ${LogUtils.logFilePath}',
                //   style: const TextStyle(fontSize: 12, color: Colors.grey),
                // ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => exit(1),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

void setupWindowSize() {
  // We'll set the sizes after getting screen information
  getCurrentScreen().then((screen) async {
    if (screen != null) {
      final screenFrame = screen.visibleFrame;
      final screenWidth = screenFrame.width;
      final screenHeight = screenFrame.height;

      // Calculate window dimensions based on screen size with dynamic bounds
      double windowWidth = screenWidth * 0.25; // 25% of screen width
      double windowHeight =
          screenHeight * 0.85; // 75% of screen height (increased from 60%)

      // Set minimum size based on screen dimensions
      final minWidth = screenWidth * 0.15; // At least 15% of screen width
      final maxWidth = screenWidth * 0.3; // At most 30% of screen width
      windowWidth = windowWidth.clamp(minWidth, maxWidth);

      // Set minimum and maximum height relative to screen size
      final minHeight = screenHeight * 0.3; // At least 30% of screen height
      final maxHeight = screenHeight *
          0.8; // At most 80% of screen height (increased from 70%)

      // Adjust width-to-height ratio for better appearance
      final aspectRatio =
          0.7; // Width to height ratio (reduced from 0.9 to make window taller)
      windowHeight = windowWidth / aspectRatio;

      // Ensure the height is within reasonable bounds relative to screen
      windowHeight = windowHeight.clamp(minHeight, maxHeight);

      // Hide default window frame for custom header
      await WindowManager.instance.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );

      // Set minimum and maximum window size with the calculated dimensions
      setWindowMinSize(Size(windowWidth, windowHeight));
      // setWindowMaxSize(Size(windowWidth, windowHeight));

      // Calculate position for bottom right corner with platform-specific adjustments
      double windowLeft;
      double windowTop;

      // Calculate margin as a percentage of screen size
      final marginFactor = 0.02; // 2% of screen dimension
      final horizontalMargin = screenWidth * marginFactor;
      final verticalMargin = screenHeight * marginFactor;

      // Platform-specific positioning
      if (Platform.isLinux) {
        // Linux often needs different offsets due to window manager decorations
        windowLeft = screenWidth - windowWidth - horizontalMargin;
        windowTop = screenHeight - windowHeight - verticalMargin;

        // Add dynamic adjustment for panels/docks based on screen height
        final panelAdjustment =
            screenHeight * 0.03; // Approximately 3% of screen height
        windowTop -= panelAdjustment;
      } else {
        // macOS and Windows
        // Use the visibleFrame which already accounts for dock/taskbar on macOS
        windowLeft = screenFrame.right - windowWidth - horizontalMargin;
        windowTop = screenFrame.bottom - windowHeight - verticalMargin;
      }

      // Set window position to bottom right corner with margin
      setWindowFrame(
        Rect.fromLTWH(windowLeft, windowTop, windowWidth, windowHeight),
      );

      // Make sure window is visible and on top
      setWindowTitle('PI Task Watch');
      setWindowVisibility(visible: true);
    }
  });
}

void setAllController() {
  Get.put(ThemeController(), permanent: true);
  Get.put(TrackerController(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(ProjectController(), permanent: true);
  Get.put(TaskController(), permanent: true);
  Get.put(TimesheetController(), permanent: true);
  Get.put(AnnouncementController(), permanent: true);
  Get.put(DiscussController(), permanent: true);
}

// user : mailto:mark.brown23@example.com
// password : 123456
//
// Thats is complete
//
//
