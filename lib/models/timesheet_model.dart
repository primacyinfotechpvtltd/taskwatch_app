class TimesheetModel {
  final int timesheetId;
  final DateTime date;
  final String description;
  final int? taskId; // Made nullable to handle false values
  final String? taskName; // Made nullable to handle false values
  final int projectId;
  final String projectName;
  final double timeSpent;
  final int userId;
  final int employeeId;

  Duration get timeSpentDuration => Duration(minutes: timeSpent.toInt());

  TimesheetModel({
    required this.timesheetId,
    required this.date,
    required this.description,
    this.taskId, // Now optional
    this.taskName, // Now optional
    required this.projectId,
    required this.projectName,
    required this.timeSpent,
    required this.userId,
    required this.employeeId,
  });

  /// Calculates total time spent from a list of timesheets
  static Duration calculateTotalDuration({
    required List<TimesheetModel> timesheetList,
  }) {
    int totalMinutes = 0;
    for (final timesheet in timesheetList) {
      totalMinutes += timesheet.timeSpent.toInt();
    }
    return Duration(minutes: totalMinutes);
  }

  factory TimesheetModel.fromJson(Map<String, dynamic> json) {
    return TimesheetModel(
      timesheetId: json['timesheet_id'],
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
      taskId: _safeIntConversion(json['task_id']),
      taskName: _safeStringConversion(json['task_name']),
      projectId: json['project_id'],
      projectName: json['project_name'] ?? '',
      timeSpent: (json['time_spent'] as num).toDouble(),
      userId: json['user_id'],
      employeeId: json['employee_id'],
    );
  }

  /// Safely converts dynamic value to int, handling false/null cases
  static int? _safeIntConversion(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }

  /// Safely converts dynamic value to string, handling false/null cases
  static String? _safeStringConversion(dynamic value) {
    if (value == null || value == false) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'timesheet_id': timesheetId,
      'date': date.toIso8601String(),
      'description': description,
      'task_id': taskId,
      'task_name': taskName,
      'project_id': projectId,
      'project_name': projectName,
      'time_spent': timeSpent,
      'user_id': userId,
      'employee_id': employeeId,
    };
  }
}
