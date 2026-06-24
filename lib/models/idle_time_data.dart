enum IdleMode { meeting, thinking, discussion, keep, remove }

/// Represents idle time data for tracking user inactivity periods
class IdleTimeData {
  /// The selected idle mode
  final IdleMode? mode;

  /// Whether to keep the idle time or deduct it (keep == true means not deducted)
  final bool keepTime;

  /// Duration of idle time in seconds
  final int idleSeconds;

  /// Optional note or topic explaining the idle time
  final String note;

  /// ID of the associated timesheet
  final dynamic timesheetId;

  /// Optional project ID
  final int? projectId;

  /// Optional task ID
  final int? taskId;

  /// Optional project name for display
  final String? projectName;

  /// Optional task name for display
  final String? taskName;

  /// Type of idle mode selected (meeting, thinking, discussion, keep, remove)
  final String? idleType;

  /// Project name for Meeting mode
  final String? meetingProject;

  /// Employee names for Discussion mode (comma-separated)
  final String? discussionWith;

  /// List of employee IDs for Discussion mode
  final List<int>? employeeIds;

  /// Break time in format "HH:mm:ss"
  final String? breakTime;

  /// Unique generated id
  final int? id;

  /// Start time string
  final String? startTime;

  /// End time string
  final String? endTime;

  /// Duration string
  final String? duration;

  /// Duration in minutes
  final int? durationInMinutes;

  /// Indicates if the time was deducted (opposite of keepTime in some contexts)
  final bool? wasDeducted;

  /// Creates an idle time data instance
  IdleTimeData({
    this.mode,
    required this.keepTime,
    required this.idleSeconds,
    required this.timesheetId,
    this.note = '',
    this.projectId,
    this.taskId,
    this.projectName,
    this.taskName,
    this.idleType,
    this.meetingProject,
    this.discussionWith,
    this.employeeIds,
    this.breakTime,
    this.id,
    this.startTime,
    this.endTime,
    this.duration,
    this.durationInMinutes,
    this.wasDeducted,
  });

  /// Creates an idle time data instance from JSON
  factory IdleTimeData.fromJson(Map<String, dynamic> json) {
    return IdleTimeData(
      keepTime: json['keepTime'] as bool? ?? false,
      idleSeconds: json['idleSeconds'] as int? ?? 0,
      timesheetId: json['timesheetId'],
      note: json['note'] as String? ?? '',
      projectId: json['project_id'] as int? ?? json['projectId'] as int?,
      taskId: json['task_id'] as int? ?? json['taskId'] as int?,
      projectName:
          json['project_name'] as String? ?? json['projectName'] as String?,
      taskName: json['task_name'] as String? ?? json['taskName'] as String?,
      idleType: json['idle_type'] as String? ?? json['idleType'] as String?,
      meetingProject: json['meeting_project'] as String? ??
          json['meetingProject'] as String?,
      discussionWith: json['discussion_with'] as String? ??
          json['discussionWith'] as String?,
      id: json['id'] as int?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      duration: json['duration'] as String?,
      durationInMinutes: json['duration_in_minutes'] as int?,
      wasDeducted: json['wasDeducted'] as bool?,
      breakTime: json['breakTime'] as String?,
    );
  }

  /// Creates a copy of this IdleTimeData with the given fields replaced
  IdleTimeData copyWith({
    IdleMode? mode,
    bool? keepTime,
    int? idleSeconds,
    String? note,
    dynamic timesheetId,
    int? projectId,
    int? taskId,
    String? projectName,
    String? taskName,
    String? idleType,
    String? meetingProject,
    String? discussionWith,
    List<int>? employeeIds,
    String? breakTime,
    int? id,
    String? startTime,
    String? endTime,
    String? duration,
    int? durationInMinutes,
    bool? wasDeducted,
  }) {
    return IdleTimeData(
      mode: mode ?? this.mode,
      keepTime: keepTime ?? this.keepTime,
      idleSeconds: idleSeconds ?? this.idleSeconds,
      note: note ?? this.note,
      timesheetId: timesheetId ?? this.timesheetId,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      projectName: projectName ?? this.projectName,
      taskName: taskName ?? this.taskName,
      idleType: idleType ?? this.idleType,
      meetingProject: meetingProject ?? this.meetingProject,
      discussionWith: discussionWith ?? this.discussionWith,
      employeeIds: employeeIds ?? this.employeeIds,
      breakTime: breakTime ?? this.breakTime,
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      durationInMinutes: durationInMinutes ?? this.durationInMinutes,
      wasDeducted: wasDeducted ?? this.wasDeducted,
    );
  }

  /// Converts the idle time data to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'timesheetId': timesheetId,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'project_id': projectId,
      'task_id': taskId,
      if (projectName != null) 'project_name': projectName,
      if (taskName != null) 'task_name': taskName,
      if (idleType != null) 'idle_type': idleType,
      if (meetingProject != null) 'meeting_project': meetingProject,
      if (discussionWith != null) 'discussion_with': discussionWith,
      'duration': duration ?? _formatDuration(idleSeconds),
      'duration_in_minutes': durationInMinutes ?? (idleSeconds / 60).ceil(),
      'note': note,
      'description': note,
      'notes': note,
      'wasDeducted': wasDeducted ?? !keepTime,
      if (breakTime != null) 'breakTime': breakTime,
      if (employeeIds != null) 'employee_ids': employeeIds,
    };
  }

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
