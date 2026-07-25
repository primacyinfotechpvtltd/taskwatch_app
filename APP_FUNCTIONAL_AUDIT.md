# PI Task Watch - Functional Audit

Audit date: 2026-07-22

## Summary

PI Task Watch is a Flutter app with native Rust helpers for desktop monitoring. It connects to an Odoo backend and tracks employee work time, task sessions, idle time, screenshots, mouse activity, and keyboard activity.

Current verification result: partially working.

The main app code is present and analyzer does not show hard compile errors in the application source, but the project is not fully clean because `flutter analyze` reports 366 lint/warning issues and `flutter test` fails due to a broken/commented widget test file.

## Screens

The app has 6 visible screens in code:

1. Sign In screen
   - File: `lib/screens/signin_screen.dart`
   - Route constant: `/signin`
   - Purpose: server URL setup, database loading, email/password login, remember-me login, debug login.
   - Status from code review: implemented.

2. Dashboard / Tracker screen
   - File: `lib/screens/dashboard_screen.dart`
   - Route: `/dashboard`
   - Purpose: main tracker, work timer, current task, WFH warning, recent activity, bottom navigation.
   - Status from code review: implemented.

3. My Task List screen
   - File: `lib/screens/my_task_list_screen.dart`
   - Route: `/my-task-list`
   - Purpose: task list, search, filters, sort, task navigation.
   - Status from code review: implemented.

4. Task Detail screen
   - File: `lib/screens/task_detail_screen.dart`
   - Route: `/task-detail`
   - Purpose: task details, stages, chatter/activity, assignees, task actions.
   - Status from code review: implemented, but depends strongly on Odoo/backend data.

5. Discuss screen
   - File: `lib/screens/discuss_screen.dart`
   - Route: `/discuss`
   - Purpose: chats/channels, colleagues list, message thread.
   - Status from code review: implemented, but depends strongly on Odoo/backend data.

6. Maintenance screen
   - File: `lib/screens/maintenance_screen.dart`
   - Route: `/maintenance`
   - Purpose: shown when backend settings put the app in maintenance mode.
   - Status from code review: implemented.

There is also a `LoadingScreen` with route constant `/loading`, but it is not registered in the route manager at the time of this audit.

## Screenshot Assets In Repository

There are 7 existing screenshot image files:

1. `flutter_style_main_tracker_screenshot.png`
2. `flutter_style_projects_list_screenshot.png`
3. `main_tracker_widget_screenshot.png`
4. `pi_task_watch_main_tracker_screenshot.png`
5. `pi_task_watch_project_tracker_screenshot.png`
6. `pi_task_watch_projects_screenshot.png`
7. `projects_list_widget_screenshot.png`

These are static repository assets/examples. They are not proof that the current runtime build is fully working.

## Core Tracking Functions

### Work Timer

- Starts when `TrackerController.startWork()` is called.
- Stops when `TrackerController.stopWork()` is called.
- Updates every 1 second.
- Tracks:
  - total tracker duration
  - current time entry duration
  - break duration
  - current session start/end time

Status from code review: implemented.

### Timesheet Sync

- Runs every 4 minutes while tracking.
- Sends final sync when work is stopped.
- Updates the timesheet ID when backend returns a new ID.

Status from code review: implemented, backend-dependent.

### Screenshot Capture

- Runs silently every 10 minutes while tracking.
- Also captures a screenshot when idle is detected before entering idle mode.
- Upload payload sends `screenshot_count: 1` when a screenshot exists, otherwise `0`.

Status from code review: implemented for desktop/native platforms, backend/system-permission-dependent.

### Mouse Click Count

- Rust mouse listener polls every 50 ms.
- Dart activity service listens to mouse events and records `UserActivityType.mouseClick`.
- Session API payload sends:
  - `mouse_click_count`

Important finding: Rust emits both mouse press and mouse release events. Dart currently counts every mouse event as a click without checking `is_button_press`, so one physical click may be counted as 2 events.

Status: implemented but count accuracy needs fixing/verification.

### Keyboard Press Count

- Rust keyboard listener polls every 50 ms.
- Dart activity service listens to keyboard events and records `UserActivityType.keyboardPress`.
- Session API payload sends:
  - `keyboard_press_count`

Important finding: Rust emits both key press and key release events. Dart currently counts every keyboard event as a press without checking `is_key_press`, so one physical key press may be counted as 2 events.

Status: implemented but count accuracy needs fixing/verification.

### Idle Detection

- Compares current time with `lastUserActivityTime`.
- Uses backend/settings `idleThreshold`.
- Shows an idle dialog when threshold is reached.
- Lets user keep time, deduct time, add note, or switch task.
- Deducted idle time is added to break duration.
- Idle data is synced immediately, with retry storage if sync fails.

Status from code review: implemented, UI/backend-dependent.

### Overtime Alert

- Compares used task time against allocated task time.
- Shows warning when time exceeds allocation.
- Repeats at most every 30 minutes.

Status from code review: implemented.

### Background/Lifecycle Keep Alive

- Enables wakelock where supported.
- Runs heartbeat every 30 seconds.
- Checks and restarts tracker timers when tracking is active.

Status from code review: implemented, platform-dependent.

## Backend Features

The app depends on Odoo/API calls for:

- database list
- login/authentication
- user/settings loading
- WFH approval check
- projects
- tasks
- task detail data
- timesheet create/update
- idle sync
- taskwatch session upload
- discuss channels/messages
- announcements/recent activity

Status: implemented in code, but real working status requires valid server URL, database, credentials, and backend availability.

## Verification Commands Run

### `flutter analyze`

Result: failed with analyzer issues.

Important details:

- 366 issues reported.
- Mostly warnings/info such as unused imports, deprecated `withOpacity`, production `print`, unnecessary imports, unused variables.
- One analysis config warning: `trailing_comma` formatter option is unsupported.
- One nested build tool warning: missing `package:lints/recommended.yaml` under `rust_builder/cargokit/build_tool`.

Interpretation: app source is present and analyzable, but code quality checks are not passing cleanly.

### `flutter test`

Result: failed.

Reason:

- `test/widget_test.dart` contains only commented code and no active `main()` function.
- Flutter test runner reports `Undefined name 'main'`.
- `test/task_details_model_test.dart` did run and passed 2 tests, but the overall test suite fails because `widget_test.dart` fails to load.

Interpretation: automated tests are not currently fully working.

## Fully Working Status

Based on code inspection and local verification:

- App structure: implemented.
- Main screens: implemented.
- Login flow: implemented, needs backend to verify.
- Task tracker timer: implemented.
- Start/stop work: implemented, needs backend to verify full sync.
- Timesheet sync: implemented, backend-dependent.
- Screenshot capture: implemented, platform/permission-dependent.
- Mouse click count: implemented but likely over-counts because press and release are both counted.
- Keyboard press count: implemented but likely over-counts because press and release are both counted.
- Idle detection: implemented.
- Overtime alert: implemented.
- Discuss/chat: implemented, backend-dependent.
- Static screenshot files: 7 available.
- Analyzer: not clean.
- Tests: not passing.

Final status: the app is not fully verified as working. Core functionality is implemented, but the project needs test cleanup, analyzer cleanup, and manual runtime verification with real Odoo credentials/backend before it can be called fully working.

## Recommended Fixes Before Release

1. Fix mouse counting by counting only `event.isButtonPress == true`.
2. Fix keyboard counting by counting only `event.isKeyPress == true`.
3. Restore or delete `test/widget_test.dart` so `flutter test` can run.
4. Clean critical analyzer warnings, especially unsupported analysis options and missing lint include.
5. Run a real desktop test session:
   - login
   - start work
   - click mouse 10 times
   - press keyboard 10 times
   - wait for session upload
   - confirm backend receives correct counts
   - confirm screenshot upload
   - confirm idle dialog
   - stop work and confirm final timesheet sync

