import 'package:pi_task_watch/models/timesheet_model.dart';

import 'package:pi_task_watch/exports.dart';

/// Represents the result returned when starting a work session
class StartWorkResult {
  /// The selected project for this work session
  final ProjectModel project;

  /// The selected task to work on
  final TaskModel task;

  /// Optional notes related to this work session
  final String notes;

  /// The time when the work session started
  final DateTime startTime;

  /// The timesheet ID associated with this work session
  final TimesheetModel? timesheet;

  /// Creates a new StartWorkResult
  StartWorkResult({
    required this.project,
    required this.task,
    this.notes = '',
    DateTime? startTime,
    required this.timesheet,
  }) : startTime = startTime ?? DateTime.now();

  /// Creates a copy of this StartWorkResult with the given fields replaced with new values
  StartWorkResult copyWith({
    ProjectModel? project,
    TaskModel? task,
    String? notes,
    DateTime? startTime,
    TimesheetModel? timesheet,
  }) {
    return StartWorkResult(
      project: project ?? this.project,
      task: task ?? this.task,
      notes: notes ?? this.notes,
      startTime: startTime ?? this.startTime,
      timesheet: timesheet ?? timesheet,
    );
  }

  /// Returns a string representation of this StartWorkResult
  @override
  String toString() =>
      'StartWorkResult(project: ${project.name}, '
      'task: ${task.name}, notes: $notes, startTime: $startTime, timesheetId: $timesheet)';
}

/// Represents the result returned when ending a work session
class EndWorkResult {
  /// Optional notes about what was accomplished during the session
  final String notes;

  /// The time when the work session ended
  final DateTime endTime;

  /// Total duration of the work session
  final Duration duration;

  /// Creates a new EndWorkResult
  EndWorkResult({this.notes = '', DateTime? endTime, required this.duration})
    : endTime = endTime ?? DateTime.now();

  /// Creates a copy of this EndWorkResult with the given fields replaced with new values
  EndWorkResult copyWith({
    String? notes,
    DateTime? endTime,
    Duration? duration,
  }) {
    return EndWorkResult(
      notes: notes ?? this.notes,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
    );
  }

  /// Returns a string representation of this EndWorkResult
  @override
  String toString() =>
      'EndWorkResult(notes: $notes, '
      'endTime: $endTime, duration: ${_formatDuration(duration)})';

  /// Helper method to format duration for toString()
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
