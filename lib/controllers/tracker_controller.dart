import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/controllers/timesheet_controller.dart';
import 'package:pi_task_watch/models/idle_time_data.dart';
import 'package:pi_task_watch/models/timesheet_model.dart';
import 'package:pi_task_watch/utils/log_utils.dart'; // Added
import 'package:pi_task_watch/services/services.dart';
import 'package:pi_task_watch/utils/capture_screenshot.dart';
import 'package:pi_task_watch/utils/focus_my_window.dart';
import 'package:pi_task_watch/widgets/idle_time_widget.dart';
import 'package:window_manager/window_manager.dart';

import 'package:pi_task_watch/exports.dart';

class TrackerController extends GetxController {
  // User and settings
  final Rx<UserModel?> _user = Rx<UserModel?>(null);
  final Rx<SettingsModel?> _settings = Rx<SettingsModel?>(null);

  // Tracking state
  final RxBool isTracking = false.obs;
  final Rx<Duration> trackerDuration = Duration.zero.obs;
  final Rx<Duration> currentTimeEntryDuration = Duration.zero.obs;
  final Rx<StartWorkModel?> startWorkData = Rxn<StartWorkModel>();
  final RxList<UserActivityType> activityList = <UserActivityType>[].obs;
  final Rx<DateTime?> todaysFirstStartDate = Rx<DateTime?>(null);

  // Break time tracking
  final Rx<Duration> totalBreakDuration = Duration.zero.obs;
  // Overtime alert tracking
  DateTime? _lastOvertimeAlertTime;
  bool _isOvertimeDialogShowing = false;
  DateTime? _lastStopTime;

  // Snapshot of the timesheet duration when a work session starts.
  // This lets the UI add only the *extra* time you work after a restart,
  // so we don't double-count time that is already saved in the timesheet.
  Duration _initialTimeEntryDuration = Duration.zero;

  Duration get initialTimeEntryDuration => _initialTimeEntryDuration;

  // Session tracking
  final RxList<SessionModel> sessionsList = <SessionModel>[].obs;
  Rx<DateTime?> lastSessionTime = Rxn<DateTime>();

  // Idle detection
  final Rx<DateTime> lastUserActivityTime = DateTime.now().obs;
  final RxBool _isIdleMode = false.obs;
  final RxBool _isIdleDialogShowing = false.obs;
  final RxList<IdleTimeData> _idleEntryList = <IdleTimeData>[].obs;
  String _lastIdleNote = '';
  bool get isIdleMode => _isIdleMode.value;

  // Timers
  Timer? _durationTimer;
  Timer? _idleCheckTimer;
  Timer? _screenshotTimer;
  Timer? _timesheetSyncTimer;

  // Safeguard flags to prevent multiple operations
  bool _isInitialized = false;
  bool _isDurationTimerRunning = false;
  bool _isTimesheetSyncRunning = false;
  bool _isSessionCreationInProgress = false;
  bool _isStoppingWork = false;
  DateTime? _lastTimerTick;
  int _screenshotCount = 0;

  void setUser({required UserModel? user}) {
    _user.value = user;
  }

  @override
  void onClose() {
    _cleanupAllTimers();
    super.onClose();
  }

  /// Safely cleanup all timers
  void _cleanupAllTimers() {
    _logDebug('Cleaning up all timers');
    _durationTimer?.cancel();
    _durationTimer = null;
    _idleCheckTimer?.cancel();
    _idleCheckTimer = null;
    _screenshotTimer?.cancel();
    _screenshotTimer = null;
    _timesheetSyncTimer?.cancel();
    _timesheetSyncTimer = null;
    _isDurationTimerRunning = false;
    _isTimesheetSyncRunning = false;
  }

  /// Safely cleanup work-related timers (but keep initialization timers)
  void _cleanupWorkTimers() {
    _logDebug('Cleaning up work-related timers');
    _durationTimer?.cancel();
    _durationTimer = null;
    _idleCheckTimer?.cancel();
    _idleCheckTimer = null;
    _screenshotTimer?.cancel();
    _screenshotTimer = null;
    _timesheetSyncTimer?.cancel();
    _timesheetSyncTimer = null;
    _isDurationTimerRunning = false;
    _isTimesheetSyncRunning = false;
  }

  // Initialize controller
  void onFullyReady({
    required SettingsModel settings,
    required UserModel user,
    required Duration workedDuration,
  }) {
    print("onFullyReady called");

    // Prevent multiple initializations
    if (_isInitialized || _user.value != null) {
      _logDebug('Controller already initialized, skipping setup');
      return;
    }

    print("worked duration: $workedDuration");

    trackerDuration.value = workedDuration;

    _user.value = user;
    _isInitialized = true;
    _logDebug('Initializing controller for user: ${user.email}');
    setBaseConfig(settingModel: settings);
    _startDurationUpdates();
    _startScreenshotTakingListenerWork();
    _startListenAndSendTimesheet();
  }

  void setBaseConfig({required SettingsModel settingModel}) {
    _settings.value = settingModel;
    _logDebug(
      'Settings configured: idle threshold=${settingModel.idleThreshold.inMinutes}m, '
      'screenshots=${settingModel.perSessionScreenshot} per session',
    );
  }

  // Session management methods
  void startWork({
    required ProjectModel project,
    required TaskModel task,
    required TimesheetModel? timesheet,
    String notes = '',
  }) async {
    try {
      // Prevent multiple start operations
      if (isTracking.value) {
        _logDebug('Work already in progress, ignoring start request');
        return;
      }

      // Validate required dependencies
      if (_user.value == null) {
        _logDebug('Cannot start work: User not initialized');
        throw Exception('User not initialized. Please login again.');
      }

      if (_settings.value == null) {
        _logDebug('Cannot start work: Settings not initialized');
        throw Exception('Settings not initialized. Please restart the app.');
      }

      // Validate input parameters
      if (project.name.trim().isEmpty) {
        throw Exception('Invalid project: Project name cannot be empty');
      }

      if (task.name.trim().isEmpty) {
        throw Exception('Invalid task: Task name cannot be empty');
      }

      final now = DateTime.now();

      // Handle break time tracking and daily reset
      if (todaysFirstStartDate.value == null ||
          !_isSameDay(todaysFirstStartDate.value!, now)) {
        // New day - reset break time
        totalBreakDuration.value = Duration.zero;
        todaysFirstStartDate.value = now;
        _logDebug(
          'New day started - reset break time and set first start date: ${now.toString()}',
        );
      } else if (_lastStopTime != null && _isSameDay(_lastStopTime!, now)) {
        // Same day - calculate and add break duration
        final breakDuration = now.difference(_lastStopTime!);
        totalBreakDuration.value += breakDuration;
        _logDebug(
          'Break time calculated: ${breakDuration.inMinutes}m, Total break today: ${totalBreakDuration.value.inMinutes}m',
        );
      }

      // Remember how much time was already on this timesheet when we started.
      // For a brand new timesheet this will be zero; for a resumed one it will
      // be whatever was already recorded (e.g. 2h 38m).
      _initialTimeEntryDuration = timesheet?.timeSpentDuration ?? Duration.zero;

      final startModel = StartWorkModel(
        user: _user.value!,
        project: project,
        task: task,
        notes: notes.trim(),
        startTime: now,
        timesheetId: timesheet?.timesheetId ?? 0,
        duration: timesheet?.timeSpentDuration ?? Duration.zero,
      );

      startWorkData.value = startModel;
      isTracking.value = true;
      // currentTimeEntryDuration always holds the *total* duration for this
      // timesheet row (initial saved time + newly tracked time).
      currentTimeEntryDuration.value = _initialTimeEntryDuration;
      lastSessionTime.value = now;

      // Reset idle state when starting work
      _isIdleMode.value = false;
      _isIdleDialogShowing.value = false;
      _isStoppingWork = false;
      lastUserActivityTime.value = now;
      _lastIdleNote = ''; // Clear last idle note when starting new work
      _screenshotCount = 0; // Reset screenshot counter for new work session

      // Restart ALL necessary timers when work starts
      if (!_isDurationTimerRunning) {
        _startDurationUpdates();
      }

      // Always restart these timers when work begins
      _startListenAndSendTimesheet();
      _startScreenshotTakingListenerWork();

      _logDebug(
        'Started work on ${project.name} / ${task.name} at ${now.toString()}',
      );

      // Check for overtime immediately upon starting
      Future.delayed(const Duration(milliseconds: 500), () {
        _checkOvertimeAlert();
      });
    } catch (e, stackTrace) {
      _logDebug('Error starting work: $e');
      _logDebug('Stack trace: $stackTrace');

      // Cleanup any partial state
      isTracking.value = false;
      startWorkData.value = null;
      lastSessionTime.value = null;

      rethrow; // Re-throw so the UI can handle it
    }
  }

  void stopWork({required String notes}) async {
    if (!isTracking.value || _isStoppingWork) {
      _logDebug(
        'Stop work called but tracking is not active or already stopping',
      );
      return;
    }

    _isStoppingWork = true;
    _lastStopTime = DateTime.now(); // Record stop time for break calculation
    _logDebug('Stopping work tracking, creating final session');

    // Create final session before stopping
    await updateNotes(notes);
    _createSession();

    // Stop timesheet sync timer and send final sync
    stopListenAndSendTimesheet();
    await _sendFinalTimesheetSync();

    // Clean up all work-related timers
    _cleanupWorkTimers();

    isTracking.value = false;
    startWorkData.value = null;
    lastSessionTime.value = null;
    _initialTimeEntryDuration = Duration.zero;
    _isStoppingWork = false;

    await Get.find<TimesheetController>().getAllTimesheet(date: DateTime.now());
  }

  Future<void> updateNotes(String notes) async {
    if (startWorkData.value != null) {
      final updatedModel = startWorkData.value!.copyWith(notes: notes);
      startWorkData.value = updatedModel;
    }
    await Get.find<TimesheetController>().updateSyncTimesheet(
      startWorkData: startWorkData.value!,
    );
  }

  // Activity tracking
  void onUserActivity({required UserActivityType type}) {
    if (!isTracking.value) return;

    activityList.add(type);
    lastUserActivityTime.value = DateTime.now();
  }

  // Session and screenshot methods
  void _createSession({
    bool takeScreenshot = false,
    bool isIdleSession = false,
  }) async {
    // Prevent concurrent session creation
    if (_isSessionCreationInProgress) {
      _logDebug('Session creation already in progress, skipping');
      return;
    }

    _isSessionCreationInProgress = true;

    try {
      if (startWorkData.value?.timesheetId == 0) {
        _logDebug('Skipping session creation: timesheetId is 0');
        return;
      }
      if (startWorkData.value == null || lastSessionTime.value == null) {
        _logDebug('Cannot create session: missing work model or session time');
        return;
      }

      // Snapshot session metadata NOW (before any async work)
      final sessionEndTime = DateTime.now();
      final sessionStartTime = lastSessionTime.value!;
      final sessionDuration = sessionEndTime.difference(sessionStartTime);
      final snapshotProject = startWorkData.value!.project;
      final snapshotTask = startWorkData.value!.task;
      final snapshotActivities = List<UserActivityType>.from(activityList);
      final snapshotUserId = _user.value!.userId;
      final snapshotTimesheetId = startWorkData.value!.timesheetId;

      _logDebug(
        'Creating new session with duration: ${sessionDuration.inMinutes}m:${sessionDuration.inSeconds % 60}s, idle: $isIdleSession, screenshot: $takeScreenshot',
      );

      // Advance the session pointer and clear activities BEFORE async work
      // so the next session records correct time even if screenshot takes long
      lastSessionTime.value = sessionEndTime;
      activityList.clear();

      // Release the lock so other timers are not blocked during screenshot capture
      _isSessionCreationInProgress = false;

      // Now perform the (potentially slow) screenshot capture
      String? imageBase64String;
      if (takeScreenshot) {
        try {
          _logDebug('Attempting to capture screenshot...');
          final captured = await captureScreenshot();
          // Treat empty string as no screenshot
          imageBase64String =
              (captured.isNotEmpty) ? captured : null;
          if (imageBase64String != null) {
            _logDebug('Screenshot captured successfully (${imageBase64String.length} chars)');
          } else {
            _logDebug('Screenshot capture returned empty data');
          }
        } catch (e) {
          _logDebug('Screenshot capture failed: $e');
          imageBase64String = null;
        }
      }

      final session = SessionModel(
        project: snapshotProject,
        task: snapshotTask,
        startTime: sessionStartTime,
        endTime: sessionEndTime,
        duration: sessionDuration,
        activities: snapshotActivities,
        screenshotImage: imageBase64String, // null = no screenshot
        isSynced: false,
        isIdleSession: isIdleSession,
        userId: snapshotUserId,
        timesheetId: snapshotTimesheetId,
      );

      sessionsList.add(session);
      _logDebug(
        'Session saved — activities: ${snapshotActivities.length}, '
        'screenshot: ${imageBase64String != null ? "yes" : "no"}',
      );
      syncSessions();
    } catch (e, st) {
      _logDebug('Unexpected error in _createSession: $e\n$st');
    } finally {
      // Ensure the flag is always released
      _isSessionCreationInProgress = false;
    }
  }

  void _startScreenshotTakingListenerWork() {
    if (_settings.value == null) {
      _logDebug('Screenshot timer not started - invalid settings');
      return;
    }

    // Always cancel existing timer first
    _screenshotTimer?.cancel();

    // Fixed 10-minute interval for screenshots (ensures ~50+ screenshots in 9-hour workday)
    const int screenshotIntervalMinutes = 10;

    _screenshotTimer = Timer.periodic(
      const Duration(minutes: screenshotIntervalMinutes),
      (_) async {
        if (isTracking.value &&
            !_isStoppingWork &&
            !_isIdleMode.value &&
            !_isIdleDialogShowing.value) {
          _logDebug('Regular screenshot timer triggered (10-minute interval)');

          // Take screenshot silently in background (completely secret mode)
          _createSession(takeScreenshot: true);
          _screenshotCount++;
          _logDebug(
              'Screenshot #$_screenshotCount captured silently (secret mode)');
        }
      },
    );

    _logDebug(
      'Started screenshot timer with ${screenshotIntervalMinutes}m intervals (fixed)',
    );
  }

  /// Synchronizes all unsynchronized sessions with the backend
  Future<void> syncSessions() async {
    if (sessionsList.isEmpty) {
      _logDebug('No sessions to sync');
      return;
    }

    final List<SessionModel> unsyncedSessions =
        sessionsList.where((session) => !session.isSynced).toList();

    if (unsyncedSessions.isEmpty) {
      _logDebug('All sessions already synced');
      return;
    }

    _logDebug('Syncing ${unsyncedSessions.length} unsynchronized sessions');

    await Future.wait(
      unsyncedSessions.map((session) => _syncSingleSession(session)),
    );
  }

  /// Synchronizes a single session with the backend
  Future<bool> _syncSingleSession(SessionModel session) async {
    try {
      final bool result = await ApiService().sendSessionScreenshot(
        session: session,
      );

      if (result) {
        // Remove session from the list after successful sync
        final index = sessionsList.indexOf(session);
        if (index >= 0) {
          sessionsList.removeAt(index);
          _logDebug(
            'Successfully synced and removed session from ${session.startTime}',
          );
        }
        return true;
      } else {
        _logDebug(
          'Session sync reported failure for session ${session.startTime}',
        );
        return false;
      }
    } catch (e) {
      _logDebug('Failed to sync session from ${session.startTime}: $e');
      return false;
    }
  }

  /// Immediately attempts to sync idle data to API, stores locally if failed
  Future<void> _syncIdleDataImmediately(IdleTimeData idleData) async {
    try {
      _logDebug('Attempting immediate idle data sync to API');
      final success = await Get.find<TimesheetController>().updateSyncIdle(
        idleData: idleData,
      );

      if (success) {
        _logDebug('Idle data synced successfully to API');
        // Also retry any pending idle entries
        await _retryPendingIdleEntries();
      } else {
        _logDebug('API sync failed, storing idle data locally for retry');
        _idleEntryList.add(idleData);
      }
    } catch (e) {
      _logDebug(
        'Exception during idle data sync: $e, storing locally for retry',
      );
      _idleEntryList.add(idleData);
    }
  }

  /// Retries syncing all pending idle entries stored locally
  Future<void> _retryPendingIdleEntries() async {
    if (_idleEntryList.isEmpty) return;

    _logDebug('Retrying ${_idleEntryList.length} pending idle entries');
    final List<IdleTimeData> failedEntries = [];

    for (final idleData in _idleEntryList) {
      try {
        final success = await Get.find<TimesheetController>().updateSyncIdle(
          idleData: idleData,
        );
        if (success) {
          _logDebug('Successfully synced pending idle entry');
        } else {
          _logDebug(
            'Failed to sync pending idle entry, keeping for next retry',
          );
          failedEntries.add(idleData);
        }
      } catch (e) {
        _logDebug('Exception syncing pending idle entry: $e');
        failedEntries.add(idleData);
      }
    }

    // Update the list to only contain failed entries
    _idleEntryList.clear();
    _idleEntryList.addAll(failedEntries);
    _logDebug('${failedEntries.length} idle entries remaining for next retry');
  }

  void _startListenAndSendTimesheet() {
    // Always cancel existing timer first
    _timesheetSyncTimer?.cancel();

    // Reset the flag to allow restart
    _isTimesheetSyncRunning = false;

    // Prevent multiple sync timers
    if (_isTimesheetSyncRunning) {
      _logDebug('Timesheet sync already running, skipping');
      return;
    }

    _isTimesheetSyncRunning = true;

    _timesheetSyncTimer = Timer.periodic(Duration(minutes: 4), (timer) async {
      if (isIdleMode) {
        focusMyWindow();
        return;
      }
      try {
        // Check if we're still tracking and have valid data
        if (!isTracking.value || startWorkData.value == null) {
          _logDebug('Skipping timesheet sync - not tracking or no work data');
          return;
        }

        final result = await Get.find<TimesheetController>()
            .updateSyncTimesheet(startWorkData: startWorkData.value!);

        if (result is int && startWorkData.value!.timesheetId == 0) {
          startWorkData.value = startWorkData.value!.copyWith(
            timesheetId: result,
          );
          _logDebug('Updated timesheet ID: $result');
        }

        // Also retry pending idle entries during regular sync
        await _retryPendingIdleEntries();
      } catch (e) {
        _logDebug('Failed to sync timesheet: $e');
      }
    });

    _logDebug('Started timesheet sync timer (4-minute intervals)');
  }

  void stopListenAndSendTimesheet() {
    _timesheetSyncTimer?.cancel();
    _timesheetSyncTimer = null;
    _isTimesheetSyncRunning = false;
    _logDebug('Stopped timesheet sync timer');
  }

  /// Sends final timesheet sync when work is stopped
  Future<void> _sendFinalTimesheetSync() async {
    if (isIdleMode) {
      _logDebug('Skipping final timesheet sync due to idle mode');
      return;
    }
    if (startWorkData.value == null) {
      _logDebug('No work data for final timesheet sync');
      return;
    }

    try {
      _logDebug('Sending final timesheet sync');
      final result = await Get.find<TimesheetController>().updateSyncTimesheet(
        startWorkData: startWorkData.value!,
      );

      if (result is int) {
        _logDebug('Final timesheet sync completed with ID: $result');
      } else {
        _logDebug('Final timesheet sync completed');
      }
    } catch (e) {
      _logDebug('Failed to send final timesheet sync: $e');
    }
  }

  // Timing methods
  void _startDurationUpdates() {
    // Always cancel existing timer first
    _durationTimer?.cancel();

    // Reset the flag to allow restart
    _isDurationTimerRunning = false;

    // Prevent multiple duration timers
    if (_isDurationTimerRunning) {
      _logDebug('Duration timer already running, skipping');
      return;
    }

    _isDurationTimerRunning = true;
    _lastTimerTick = DateTime.now();

    _durationTimer = Timer.periodic(Duration(seconds: 1), (_) {
      // Additional safeguard: check for rapid timer ticks
      final now = DateTime.now();
      if (_lastTimerTick != null &&
          now.difference(_lastTimerTick!).inMilliseconds < 500) {
        _logDebug(
          'Detected rapid timer tick, skipping to prevent double counting',
        );
        return;
      }
      _lastTimerTick = now;

      if (isTracking.value && !_isStoppingWork) {
        trackerDuration.value += Duration(seconds: 1);
        currentTimeEntryDuration.value += Duration(seconds: 1);
        startWorkData.value?.duration = currentTimeEntryDuration.value;
        checkIdleStatus();
        _checkOvertimeAlert();
      }
    });

    _logDebug('Started duration timer');
  }

  // Idle detection methods
  void checkIdleStatus() async {
    if (_isIdleMode.value ||
        !isTracking.value ||
        _isIdleDialogShowing.value ||
        _settings.value == null) {
      return;
    }

    final idleTime = DateTime.now().difference(lastUserActivityTime.value);
    if (idleTime >= _settings.value!.idleThreshold) {
      focusMyWindow();

      _logDebug(
        'Idle time detected: ${idleTime.inMinutes}m:${idleTime.inSeconds % 60}s',
      );

      _isIdleMode.value = true;
      _isIdleDialogShowing.value = true;

      // Create a session before entering idle mode (with screenshot)
      // Add small delay to ensure we don't conflict with regular screenshot timer
      await Future.delayed(Duration(milliseconds: 500));
      _createSession(takeScreenshot: true, isIdleSession: true);
      _logDebug('Created session before entering idle mode');

      bool previouslyIsAlwaysOnTop = false;
      if (GetPlatform.isDesktop) {
        previouslyIsAlwaysOnTop =
            await WindowManager.instance.isAlwaysOnTop();

        if (!previouslyIsAlwaysOnTop) {
          WindowManager.instance.setAlwaysOnTop(true);
        }
      }

      final idleResult = await DialogUtils.showAppDialog(
        context: Get.context!,
        title: "Idle Time Detected",
        canOutsideDismiss: false,
        content: IdleTimeWidget(
          idleTime: idleTime.inSeconds,
          initialNote: (startWorkData.value?.notes.isNotEmpty ?? false)
              ? startWorkData.value?.notes
              : _lastIdleNote,
        ),
      );

      if (GetPlatform.isDesktop && !previouslyIsAlwaysOnTop) {
        WindowManager.instance.setAlwaysOnTop(false);
      }

      _logDebug('Idle dialog completed, processing result');

      if (idleResult != null) {
        final activeWork = startWorkData.value;
        final originalProjectId = activeWork?.project.id;
        final originalTaskId = activeWork?.task.id;

        final dynamic timesheetId;
        if (idleResult.projectId != originalProjectId ||
            idleResult.taskId != originalTaskId) {
          timesheetId = "";
        } else {
          timesheetId = activeWork?.timesheetId ?? 0;
        }

        // Create idle data with current timesheet ID, preserving all other fields
        final idleDataWithTimesheetId = (idleResult as IdleTimeData).copyWith(
          timesheetId: timesheetId,
        );

        // Save note for next time
        _lastIdleNote = idleDataWithTimesheetId.note;

        _logDebug(
          'Idle result: mode=${idleDataWithTimesheetId.mode}, keep time=${idleDataWithTimesheetId.keepTime}, seconds=${idleDataWithTimesheetId.idleSeconds}, timesheetId=${idleDataWithTimesheetId.timesheetId}, projectId=${idleDataWithTimesheetId.projectId}, taskId=${idleDataWithTimesheetId.taskId}',
        );

        // Immediately attempt to sync idle data to API
        await _syncIdleDataImmediately(idleDataWithTimesheetId);

        // Check if user selected a different task
        if (idleDataWithTimesheetId.taskId != null &&
            idleDataWithTimesheetId.taskId != startWorkData.value?.task.id) {
          _logDebug('User selected different task, switching via stop/start');

          // Find the selected task from available tasks
          final taskController = Get.find<TaskController>();
          final selectedTask = taskController.taskList.firstWhere(
            (task) => task.id == idleDataWithTimesheetId.taskId,
            orElse: () => startWorkData.value!.task,
          );

          // Switch to new task via stop/start approach
          if (selectedTask.id == idleDataWithTimesheetId.taskId) {
            try {
              // Save current work data before stopping
              final oldProject = startWorkData.value!.project;
              final oldTask = startWorkData.value!.task;
              final newProject = ProjectModel(
                id: selectedTask.projectId ?? oldProject.id,
                name: selectedTask.projectName ?? oldProject.name,
              );

              _logDebug('Stopping work on ${oldTask.name}');

              // Stop current work (this saves time to the old task)
              // Don't use the public stopWork method as it cleans up too much
              // Instead, just finalize the current timesheet
              // Finalize current work with its ORIGINAL notes
              // The idle note will still be synced separately via _syncIdleDataImmediately
              final noteForFinalSession = startWorkData.value!.notes;

              await updateNotes(noteForFinalSession);
              _createSession();
              stopListenAndSendTimesheet();
              await _sendFinalTimesheetSync();

              _logDebug('Starting work on ${selectedTask.name}');

              // Start new work on the selected task (fresh timesheet, time starts at 0)
              final noteForNewTask = idleDataWithTimesheetId.note.isNotEmpty &&
                      idleDataWithTimesheetId.note != 'Time deducted'
                  ? idleDataWithTimesheetId.note
                  : '';

              startWork(
                project: newProject,
                task: selectedTask,
                timesheet: null,
                notes: noteForNewTask,
              );

              _logDebug('Successfully switched to task: ${selectedTask.name}');
            } catch (e) {
              _logDebug('Error during task switch: $e');
              // If switch fails, try to keep tracking on current task
            }
          }
        }
      }

      _isIdleDialogShowing.value = false;
      _isIdleMode.value = false;

      // Create a session when exiting idle mode (without screenshot to avoid duplication)
      // Add small delay to ensure proper sequencing
      await Future.delayed(Duration(milliseconds: 300));
      _createSession(takeScreenshot: false, isIdleSession: false);
      _logDebug('Created session after exiting idle mode (no screenshot)');

      if (idleResult != null) {
        if (!idleResult.keepTime) {
          trackerDuration.value -= Duration(seconds: idleResult.idleSeconds);
          currentTimeEntryDuration.value -= Duration(
            seconds: idleResult.idleSeconds,
          );

          // Add removed idle time to break duration
          totalBreakDuration.value += Duration(seconds: idleResult.idleSeconds);

          if (trackerDuration.value.isNegative) {
            trackerDuration.value = Duration.zero;
          }
          if (currentTimeEntryDuration.value.isNegative) {
            currentTimeEntryDuration.value = Duration.zero;
          }
        }

        lastUserActivityTime.value = DateTime.now();

        // Update timesheet without creating another session
        // This preserves the ORIGINAL notes in startWorkData while updating duration if needed
        Get.find<TimesheetController>().updateSyncTimesheet(
          startWorkData: startWorkData.value!,
        );
      } else {
        lastUserActivityTime.value = DateTime.now();
        if (kDebugMode) {
          print(
            '📝 Idle dialog dismissed without result, resetting activity time',
          );
        }
      }
    }
  }

  // Timer management and recovery methods
  /// Ensures all necessary timers are running when tracking is active
  /// This is called by AppLifecycleService to prevent freezing during system sleep/idle
  void ensureTimersRunning() {
    if (!isTracking.value) {
      _logDebug('Not tracking, no timers to ensure');
      return;
    }

    _logDebug('Ensuring all timers are running...');

    // Check and restart duration timer if needed
    if (_durationTimer == null || !_durationTimer!.isActive) {
      _logDebug('Duration timer not running, restarting...');
      _isDurationTimerRunning = false; // Reset flag
      _startDurationUpdates();
    } else {
      _logDebug('Duration timer is running');
    }

    // Check and restart screenshot timer if needed
    if (_screenshotTimer == null || !_screenshotTimer!.isActive) {
      _logDebug('Screenshot timer not running, restarting...');
      _startScreenshotTakingListenerWork();
    } else {
      _logDebug('Screenshot timer is running');
    }

    // Check and restart timesheet sync timer if needed
    if (_timesheetSyncTimer == null || !_timesheetSyncTimer!.isActive) {
      _logDebug('Timesheet sync timer not running, restarting...');
      _isTimesheetSyncRunning = false; // Reset flag
      _startListenAndSendTimesheet();
    } else {
      _logDebug('Timesheet sync timer is running');
    }

    _logDebug('Timer check complete');
  }

  void _checkOvertimeAlert() {
    if (!isTracking.value ||
        _isStoppingWork ||
        _isIdleMode.value ||
        _isIdleDialogShowing.value ||
        _isOvertimeDialogShowing) {
      return;
    }

    final task = startWorkData.value?.task;
    if (task == null) return;

    final allocated = task.getAllocatedTimeDuration();
    if (allocated == null || allocated.inSeconds <= 0) return;

    final initialDuration = _initialTimeEntryDuration;
    final currentSessionDuration = currentTimeEntryDuration.value;
    final additionalDuration = currentSessionDuration - initialDuration;

    // Total used time is existing task used time + additional time in current session
    final existingUsedTime = task.getUsedTime() ?? Duration.zero;
    final totalUsedTime = existingUsedTime + additionalDuration;

    if (totalUsedTime > allocated) {
      final now = DateTime.now();
      if (_lastOvertimeAlertTime == null ||
          now.difference(_lastOvertimeAlertTime!) >=
              const Duration(minutes: 30)) {
        _showOvertimeAlert(totalUsedTime);
      }
    }
  }

  Future<void> _showOvertimeAlert(Duration totalUsedTime) async {
    _isOvertimeDialogShowing = true;
    _lastOvertimeAlertTime = DateTime.now();

    _logDebug('Showing overtime alert');

    final task = startWorkData.value?.task;
    final allocated = task?.getAllocatedTimeDuration() ?? Duration.zero;
    final overtime = totalUsedTime - allocated;

    await DialogUtils.showAppDialog(
      context: Get.context!,
      title: "Overtime Alert",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            "You have exceeded the allocated time for this task.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                _buildOvertimeRow("Allocated:", _formatTimeHM(allocated)),
                const SizedBox(height: 4),
                _buildOvertimeRow("Used:", _formatTimeHM(totalUsedTime)),
                const Divider(),
                _buildOvertimeRow(
                  "Overtime:",
                  _formatTimeHM(overtime),
                  isBold: true,
                  color: Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "This alert will reappear in 30 minutes if you continue working on this task.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Get.back(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
          ),
          child: const Text("OK"),
        ),
      ],
    );

    _isOvertimeDialogShowing = false;
  }

  Widget _buildOvertimeRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? const Color(0xFF25181E),
          ),
        ),
      ],
    );
  }

  String _formatTimeHM(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  // Utility methods
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Logging methods
  void _logDebug(String message) {
   // LogUtils.i('[TrackerController] $message');
  }
}
