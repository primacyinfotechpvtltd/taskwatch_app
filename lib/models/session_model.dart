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
    );
  }

  //
  Map<String, dynamic> toJsonForAPi() {
    final bool hasScreenshot =
        screenshotImage != null && screenshotImage!.isNotEmpty;
    return {
      "session_id": uniqueId,
      "timesheet_id": timesheetId,
      "start_date": dateToSimpleString(startTime),
      "end_date": dateToSimpleString(endTime),
      "user_id": userId,
      "project_id": project.id,
      "task_id": task.id,
      "screenshot_list": hasScreenshot
          ? [
              {
                "url": screenshotImage!,
                "timestamp": dateToSimpleString(endTime),
                "tracker_timestamp": "00:00:00",
              },
            ]
          : [],
      "mouse_click_count": activities
          .where((activity) => activity == UserActivityType.mouseClick)
          .length,
      "keyboard_press_count": activities
          .where((activity) => activity == UserActivityType.keyboardPress)
          .length,
      "screenshot_count": hasScreenshot ? 1 : 0,
    };
  }
  //
}
