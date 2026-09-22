import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/utils/date_to_simple_string.dart';

class SessionModel {
  //
  final String uniqueId;
  final ProjectModel project;
  final TaskModel task;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final List<UserActivityType> activities;
  final String? screenshotImage;
  final bool isSynced;
  final bool isIdleSession;
  final int timesheetId;
  final int userId;
  final int? employeeId;
  final String? employeeName;
  final String? appName;
  final String? windowTitle;

  SessionModel({
    String? uniqueId,
    required this.project,
    required this.task,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.activities,
    required this.screenshotImage,
    required this.isSynced,
    required this.isIdleSession,
    required this.timesheetId,
    required this.userId,
    this.employeeId,
    this.employeeName,
    this.appName,
    this.windowTitle,
  }) : uniqueId = uniqueId ?? const Uuid().v4();

  // Create a copy with modified fields
  SessionModel copyWith({
    String? uniqueId,
    ProjectModel? project,
    TaskModel? task,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    List<UserActivityType>? activities,
    String? screenshotImage,
    bool? isSynced,
    bool? isIdleSession,
    int? timesheetId,
    int? userId,
    int? employeeId,
    String? employeeName,
    String? appName,
    String? windowTitle,
  }) {
    return SessionModel(
      uniqueId: uniqueId ?? this.uniqueId,
      project: project ?? this.project,
      task: task ?? this.task,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      activities: activities ?? this.activities,
      screenshotImage: screenshotImage ?? this.screenshotImage,
      isSynced: isSynced ?? this.isSynced,
      isIdleSession: isIdleSession ?? this.isIdleSession,
      timesheetId: timesheetId ?? this.timesheetId,
      userId: userId ?? this.userId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      appName: appName ?? this.appName,
      windowTitle: windowTitle ?? this.windowTitle,
    );
  }

  // Convert SessionModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'uniqueId': uniqueId,
      'project': project.toJson(),
      'task': task.json,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'duration': duration.inSeconds,
      'activities': activities.map((activity) => activity.name).toList(),
      'screenshotImage': screenshotImage,
      'isSynced': isSynced,
      'isIdleSession': isIdleSession,
      'timesheetId': timesheetId,
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'appName': appName,
      'windowTitle': windowTitle,
    };
  }

  // Create SessionModel from JSON
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      uniqueId: json['uniqueId'],
      project: ProjectModel.fromJson(json['project']),
      task: TaskModel.fromJson(json['task']),
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      duration: Duration(seconds: json['duration']),
      activities: (json['activities'] as List)
          .map(
            (activity) => UserActivityType.values.firstWhere(
              (type) => type.name == activity,
              orElse: () => UserActivityType.values.first,
            ),
          )
          .toList(),
      screenshotImage: json['screenshotImage'],
      isSynced: json['isSynced'] ?? false,
      isIdleSession: json['isIdleSession'] ?? false,
      timesheetId: json['timesheetId'],
      userId: json['userId'],
      employeeId: json['employeeId'] as int?,
      employeeName: json['employeeName'] as String?,
      appName: json['appName'] as String?,
      windowTitle: json['windowTitle'] as String?,
    );
  }

  //
  Map<String, dynamic> toJsonForAPi() {
    final bool hasScreenshot =
        screenshotImage != null && screenshotImage!.isNotEmpty;

    String formatDuration(Duration d) {
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
    }

    final int mouseClicks = activities
        .where((activity) => activity == UserActivityType.mouseClick)
        .length;
    final int mouseScrolls = activities
        .where((activity) => activity == UserActivityType.mouseScroll)
        .length;
    final int keyPresses = activities
        .where((activity) => activity == UserActivityType.keyboardPress)
        .length;

    final int durationSeconds = duration.inSeconds;
    final int durationMinutes = (durationSeconds / 60.0).round();
    final double timeSpentMinutes = durationSeconds / 60.0;

    final int totalActions = mouseClicks + mouseScrolls + keyPresses;
    double productivity = 0.0;
    if (durationSeconds > 0 && totalActions > 0) {
      final expectedActions = (durationSeconds / 60.0) * 30.0;
      productivity = expectedActions > 0
          ? ((totalActions / expectedActions) * 100.0).clamp(0.0, 100.0)
          : 100.0;
    } else if (totalActions > 0) {
      productivity = 100.0;
    }
    final double prodValue = double.parse(productivity.toStringAsFixed(2));

    final resolvedAppName = appName ?? '';
    final resolvedWindowTitle = windowTitle ?? '';
    final resolvedEmpName = employeeName ?? '';
    final resolvedEmpId = employeeId ?? userId;

    final List<Map<String, dynamic>> screenshotList = hasScreenshot
        ? [
            {
              "url": screenshotImage!,
              "timestamp": dateToSimpleString(endTime),
              "tracker_timestamp": formatDuration(duration),
              "app": resolvedAppName,
              "app_name": resolvedAppName,
              "application": resolvedAppName,
              "process_name": resolvedAppName,
              "window_title": resolvedWindowTitle,
              "title": resolvedWindowTitle,
              "active_window": resolvedWindowTitle,
              "project_id": project.id,
              "project_name": project.name,
              "project": project.name,
              "task_id": task.id,
              "task_name": task.name,
              "task": task.name,
              "user_id": userId,
              "employee_id": resolvedEmpId,
              if (resolvedEmpName.isNotEmpty) ...{
                "employee_name": resolvedEmpName,
                "employee": resolvedEmpName,
              },
              "duration": durationSeconds,
              "duration_in_minutes": durationMinutes,
              "time_spent": timeSpentMinutes,
              "mouse_clicks": mouseClicks,
              "mouse_click_count": mouseClicks,
              "mouse_scrolls": mouseScrolls,
              "mouse_scroll_count": mouseScrolls,
              "key_presses": keyPresses,
              "keyboard_press_count": keyPresses,
              "keyboard_presses": keyPresses,
              "productivity": prodValue,
            },
          ]
        : [];

    return {
      "session_id": uniqueId,
      "timesheet_id": timesheetId,
      "start_date": dateToSimpleString(startTime),
      "end_date": dateToSimpleString(endTime),
      "user_id": userId,
      "employee_id": resolvedEmpId,
      if (resolvedEmpName.isNotEmpty) ...{
        "employee_name": resolvedEmpName,
        "employee": resolvedEmpName,
      },
      "project_id": project.id,
      "project_name": project.name,
      "project": project.name,
      "task_id": task.id,
      "task_name": task.name,
      "task": task.name,
      "app": resolvedAppName,
      "app_name": resolvedAppName,
      "application": resolvedAppName,
      "process_name": resolvedAppName,
      "window_title": resolvedWindowTitle,
      "title": resolvedWindowTitle,
      "active_window": resolvedWindowTitle,
      "screenshot_list": screenshotList,
      "duration": durationSeconds,
      "duration_in_minutes": durationMinutes,
      "time_spent": timeSpentMinutes,
      "mouse_click_count": mouseClicks,
      "mouse_clicks": mouseClicks,
      "mouse_scroll_count": mouseScrolls,
      "mouse_scrolls": mouseScrolls,
      "keyboard_press_count": keyPresses,
      "keyboard_presses": keyPresses,
      "key_presses": keyPresses,
      "key_press_count": keyPresses,
      "screenshot_count": hasScreenshot ? 1 : 0,
      "productivity": prodValue,
    };
  }
  //
}
