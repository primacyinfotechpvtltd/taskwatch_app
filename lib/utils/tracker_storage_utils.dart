// import 'dart:convert';

// import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'package:pi_task_watch/exports.dart';

// class TrackerStorageUtils {
//   static const String _trackingStateKey = 'tracking_state';
//   static const String _startWorkModelKey = 'start_work_model';
//   static const String _trackerDurationKey = 'tracker_duration';
//   static const String _currentTimeEntryDurationKey =
//       'current_time_entry_duration';
//   static const String _lastSessionTimeKey = 'last_session_time';
//   static const String _todaysFirstStartDateKey = 'todays_first_start_date';
//   static const String _activityListKey = 'activity_list';
//   static const String _sessionsListKey = 'sessions_list';
//   static const String _userEmailKey = 'user_email';
//   static const String _lastActiveDateKey = 'last_active_date';

//   // User identification for tracking recovery
//   static Future<void> saveUserEmail(String email) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_userEmailKey, email);
//   }

//   static Future<String?> loadUserEmail() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_userEmailKey);
//   }

//   // Save the last date the app was active with tracking
//   static Future<void> saveLastActiveDate(DateTime date) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_lastActiveDateKey, date.toIso8601String());
//   }

//   static Future<DateTime?> loadLastActiveDate() async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? dateTimeString = prefs.getString(_lastActiveDateKey);
//     if (dateTimeString == null) return null;

//     try {
//       return DateTime.parse(dateTimeString);
//     } catch (e) {
//       _logDebug('Error parsing last active date: $e');
//       return null;
//     }
//   }

//   // Save tracking state
//   static Future<void> saveTrackingState(bool isTracking) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(_trackingStateKey, isTracking);
//     _logDebug('Saved tracking state: $isTracking');
//   }

//   // Save start work model
//   static Future<void> saveStartWorkModel(StartWorkModel? model) async {
//     final prefs = await SharedPreferences.getInstance();
//     if (model == null) {
//       await prefs.remove(_startWorkModelKey);
//       _logDebug('Cleared start work model');
//     } else {
//       await prefs.setString(_startWorkModelKey, jsonEncode(model.toJson()));
//       _logDebug(
//         'Saved start work model: ${model.project.name}/${model.task.name}',
//       );
//     }
//   }

//   // Save durations
//   static Future<void> saveTrackerDuration(Duration duration) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setInt(_trackerDurationKey, duration.inSeconds);
//   }

//   static Future<void> saveCurrentTimeEntryDuration(Duration duration) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setInt(_currentTimeEntryDurationKey, duration.inSeconds);
//   }

//   // Save dates
//   static Future<void> saveLastSessionTime(DateTime? dateTime) async {
//     final prefs = await SharedPreferences.getInstance();
//     if (dateTime == null) {
//       await prefs.remove(_lastSessionTimeKey);
//     } else {
//       await prefs.setString(_lastSessionTimeKey, dateTime.toIso8601String());
//     }
//   }

//   static Future<void> saveTodaysFirstStartDate(DateTime? dateTime) async {
//     final prefs = await SharedPreferences.getInstance();
//     if (dateTime == null) {
//       await prefs.remove(_todaysFirstStartDateKey);
//     } else {
//       await prefs.setString(
//         _todaysFirstStartDateKey,
//         dateTime.toIso8601String(),
//       );
//     }
//   }

//   // Save activity and session lists
//   static Future<void> saveActivityList(
//     List<UserActivityType> activities,
//   ) async {
//     final prefs = await SharedPreferences.getInstance();
//     final List<String> activityStrings =
//         activities.map((activity) => activity.toString()).toList();
//     await prefs.setStringList(_activityListKey, activityStrings);
//   }

//   static Future<void> saveSessionsList(List<SessionModel> sessions) async {
//     final prefs = await SharedPreferences.getInstance();
//     try {
//       final List<String> sessionsJson =
//           sessions.map((session) => jsonEncode(session.toJson())).toList();
//       await prefs.setStringList(_sessionsListKey, sessionsJson);
//       _logDebug('Saved ${sessions.length} sessions');
//     } catch (e) {
//       _logDebug('Error saving sessions list: $e');
//     }
//   }

//   // Load tracking state
//   static Future<bool> loadTrackingState() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool(_trackingStateKey) ?? false;
//   }

//   // Load start work model
//   static Future<StartWorkModel?> loadStartWorkModel() async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? modelJson = prefs.getString(_startWorkModelKey);
//     if (modelJson == null) return null;

//     try {
//       return StartWorkModel.fromJson(jsonDecode(modelJson));
//     } catch (e) {
//       _logDebug('Error loading start work model: $e');
//       return null;
//     }
//   }

//   // Load durations
//   static Future<Duration> loadTrackerDuration() async {
//     final prefs = await SharedPreferences.getInstance();
//     final int seconds = prefs.getInt(_trackerDurationKey) ?? 0;
//     return Duration(seconds: seconds);
//   }

//   static Future<Duration> loadCurrentTimeEntryDuration() async {
//     final prefs = await SharedPreferences.getInstance();
//     final int seconds = prefs.getInt(_currentTimeEntryDurationKey) ?? 0;
//     return Duration(seconds: seconds);
//   }

//   // Load dates
//   static Future<DateTime?> loadLastSessionTime() async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? dateTimeString = prefs.getString(_lastSessionTimeKey);
//     if (dateTimeString == null) return null;

//     try {
//       return DateTime.parse(dateTimeString);
//     } catch (e) {
//       _logDebug('Error parsing last session time: $e');
//       return null;
//     }
//   }

//   static Future<DateTime?> loadTodaysFirstStartDate() async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? dateTimeString = prefs.getString(_todaysFirstStartDateKey);
//     if (dateTimeString == null) return null;

//     try {
//       return DateTime.parse(dateTimeString);
//     } catch (e) {
//       _logDebug('Error parsing today\'s first start date: $e');
//       return null;
//     }
//   }

//   // Load activity and session lists
//   static Future<List<UserActivityType>> loadActivityList() async {
//     final prefs = await SharedPreferences.getInstance();
//     final List<String>? activityStrings = prefs.getStringList(_activityListKey);
//     if (activityStrings == null) return [];

//     try {
//       return activityStrings
//           .map(
//             (str) => UserActivityType.values.firstWhere(
//               (e) => e.toString() == str,
//               orElse: () => UserActivityType.mouseClick,
//             ),
//           )
//           .toList();
//     } catch (e) {
//       _logDebug('Error loading activity list: $e');
//       return [];
//     }
//   }

//   static Future<List<SessionModel>> loadSessionsList() async {
//     final prefs = await SharedPreferences.getInstance();
//     final List<String>? sessionsJson = prefs.getStringList(_sessionsListKey);
//     if (sessionsJson == null) return [];

//     try {
//       final sessions =
//           sessionsJson
//               .map((jsonStr) => SessionModel.fromJson(jsonDecode(jsonStr)))
//               .toList();
//       _logDebug('Loaded ${sessions.length} sessions');
//       return sessions;
//     } catch (e) {
//       _logDebug('Error loading sessions list: $e');
//       return [];
//     }
//   }

//   // Clear all stored tracking data
//   static Future<void> clearAllTrackingData() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_trackingStateKey);
//     await prefs.remove(_startWorkModelKey);
//     await prefs.remove(_trackerDurationKey);
//     await prefs.remove(_currentTimeEntryDurationKey);
//     await prefs.remove(_lastSessionTimeKey);
//     await prefs.remove(_todaysFirstStartDateKey);
//     await prefs.remove(_activityListKey);
//     await prefs.remove(_sessionsListKey);
//     // Don't remove user email when clearing tracking data
//     // But do clear the last active date
//     await prefs.remove(_lastActiveDateKey);
//     _logDebug('Cleared all tracking data from storage');
//   }

//   // Helper for logging
//   static void _logDebug(String message) {
//     if (kDebugMode) {
//       print('💾 TrackerStorage: $message');
//     }
//   }
// }
