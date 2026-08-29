import 'package:pi_task_watch/utils/duration_utils.dart';

class TaskModelException implements Exception {
  final String message;
  TaskModelException(this.message);
  @override
  String toString() => 'TaskModelException: $message';
}

class TaskModel {
  //
  final int id;
  final String name;
  final int? projectId;
  final String? projectName;
  final int? stageId;
  final String? stageName;
  final String? task_url;
  final Duration? _allocatedTimeInHours;
  final Duration? _usedTime; // Changed from _remainingTime to _usedTime
  final String? _startDate;
  final String? _endDate;
  final Map<String, dynamic> json;
  //

  //
  TaskModel({
    required this.id,
    required this.name,
    this.projectId,
    this.projectName,
    this.stageId,
    this.stageName,
    this.task_url,
    Duration? allocatedTimeInHours,
    Duration? usedTime, // Changed parameter name
    String? startDate,
    String? endDate,
    required this.json,
  })  : _usedTime = usedTime, // Updated assignment
        _allocatedTimeInHours = allocatedTimeInHours,
        _endDate = endDate,
        _startDate = startDate;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    try {
      // Validate required fields
      if (json['id'] == null) throw TaskModelException('Task ID is required');
      if (json['name'] == null) {
        throw TaskModelException('Task name is required');
      }

      return TaskModel(
        id: json['id'],
        name: json['name'].toString().trim(),
        projectId: json['project_id'],
        projectName: json['project_name']?.toString().trim(),
        stageId: json['stage_id'],
        stageName: json['stage_name']?.toString().trim(),
        task_url: json['task_url']?.toString().trim(),
        allocatedTimeInHours: DurationUtils.tryParseDuration(
          json['allocated_time_in_hours'],
        ),
        usedTime: DurationUtils.tryParseDuration(
          json['used_time'],
        ), // Updated to use 'used_time'
        startDate: json['start_date']?.toString().trim(),
        endDate: json['end_date']?.toString().trim(),
        json: json,
      );
    } catch (e) {
      print("Error parsing TaskModel: $e\nJSON: $json");
      rethrow;
    }
  }

  // Improved DateTime parsing with validation
  DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final date = DateTime.parse(dateStr);
      // Validate date is not too far in past or future
      if (date.year < 2000 || date.year > 2100) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  DateTime? getStartDateTime() => _parseDateTime(_startDate)?.toLocal();
  DateTime? getEndDateTime() => _parseDateTime(_endDate)?.toLocal();

  // Enhanced task status methods
  bool isOverdue() {
    final endDateTime = getEndDateTime();
    if (endDateTime == null) return false;

    final now = DateTime.now();
    return endDateTime.isBefore(now) && !isCompleted();
  }

  bool hasNegativeRemainingTime() {
    final remaining = getRemainingTimeDuration();
    return remaining?.isNegative ?? false;
  }

  bool isInProgress() {
    if (isCompleted()) return false;
    final startDateTime = getStartDateTime();
    if (startDateTime == null) return false;

    final now = DateTime.now();
    return startDateTime.isBefore(now) && !isOverdue();
  }

  // Improved time calculations
  Duration? getAllocatedTimeDuration() => _allocatedTimeInHours;

  // Add getter for URL with null safety
  String get url => task_url ?? '';

  String? get description {
    if (json['description'] != null) {
      final desc = json['description'].toString();
      return desc != 'false' ? desc : null;
    }
    return null;
  }

  double? get allocatedHours {
    if (_allocatedTimeInHours != null) {
      return _allocatedTimeInHours!.inMinutes / 60.0;
    }
    if (json['allocated_hours'] is num) {
      return (json['allocated_hours'] as num).toDouble();
    }
    return null;
  }

  // Computed remaining time from allocated - used
  Duration? getRemainingTimeDuration() {
    if (_allocatedTimeInHours != null && _usedTime != null) {
      final remainingMinutes =
          _allocatedTimeInHours.inMinutes - _usedTime.inMinutes;
      return Duration(minutes: remainingMinutes);
    }
    return null;
  }

  Duration? getUsedTime() =>
      _usedTime; // Simplified - now directly returns used time

  String getFormattedAllocatedTime() {
    return DurationUtils.formatDuration(_allocatedTimeInHours);
  }

  String getFormattedRemainingTime() {
    // Use specialized formatter for remaining time that handles negative values better
    return DurationUtils.formatDuration(getRemainingTimeDuration());
  }

  // Enhanced progress calculation
  double getTimeUsedPercentage() {
    final allocated = _allocatedTimeInHours;
    final used = _usedTime;

    if (allocated == null || used == null || allocated.inMinutes <= 0) {
      return 0.0;
    }

    // Calculate percentage based on used time vs allocated time
    final percentage = (used.inMinutes / allocated.inMinutes);

    // For over-allocated time, cap the percentage at 1.0 (100%)
    return percentage.clamp(0.0, 1.0);
  }

  bool isOverAllocatedTime() {
    final allocated = _allocatedTimeInHours;
    final used = _usedTime;

    if (allocated == null || used == null) return false;
    // Check if used time exceeds allocated time
    return used.inMinutes > allocated.inMinutes;
  }

  bool isCompleted() {
    // Check if used time equals or exceeds allocated time
    final allocated = _allocatedTimeInHours;
    final used = _usedTime;

    if (allocated == null || used == null) return false;
    return used.inMinutes >= allocated.inMinutes;
  }

  double getCompletionPercentage() {
    if (isCompleted()) return 1.0;
    return getTimeUsedPercentage();
  }

  // New helper methods for task management
  bool isStartingSoon() {
    final startDateTime = getStartDateTime();
    if (startDateTime == null) return false;

    final now = DateTime.now();
    final difference = startDateTime.difference(now);
    return difference.inHours <= 1 && difference.isNegative == false;
  }

  bool isDueSoon() {
    final endDateTime = getEndDateTime();
    if (endDateTime == null) return false;

    final now = DateTime.now();
    final difference = endDateTime.difference(now);
    return difference.inHours <= 2 && difference.isNegative == false;
  }

  Duration? getTimeUntilDue() {
    final endDateTime = getEndDateTime();
    if (endDateTime == null) return null;

    final now = DateTime.now();
    return endDateTime.difference(now);
  }

  // Validation method for task data integrity
  bool isValid() {
    if (id <= 0 || name.isEmpty) return false;

    final start = getStartDateTime();
    final end = getEndDateTime();

    if (start != null && end != null) {
      if (end.isBefore(start)) return false;
    }

    return true;
  }

  // Enhanced progress calculation methods
  TaskProgress getProgress() {
    final allocated = _allocatedTimeInHours;
    final used = _usedTime;

    if (allocated == null || used == null || allocated.inMinutes <= 0) {
      return TaskProgress(
        percentage: 0.0,
        status: TaskProgressStatus.notStarted,
        usedTime: Duration.zero,
        totalTime: Duration.zero,
      );
    }

    // Calculate percentage based on used vs allocated time
    final percentage = (used.inMinutes / allocated.inMinutes).clamp(0.0, 1.0);
    final remaining = getRemainingTimeDuration();

    TaskProgressStatus status;
    if (isCompleted()) {
      status = TaskProgressStatus.completed;
    } else if (isOverdue()) {
      status = TaskProgressStatus.overdue;
    } else if (percentage > 0.9) {
      status = TaskProgressStatus.critical;
    } else if (percentage > 0.75) {
      status = TaskProgressStatus.warning;
    } else if (percentage > 0) {
      status = TaskProgressStatus.inProgress;
    } else {
      status = TaskProgressStatus.notStarted;
    }

    return TaskProgress(
      percentage: percentage,
      status: status,
      usedTime: used,
      totalTime: allocated,
      remainingTime: remaining,
    );
  }

  String getProgressDisplay() {
    final progress = getProgress();
    return '${(progress.percentage * 100).toStringAsFixed(1)}%';
  }

  Map<String, dynamic> getProgressDetails() {
    final progress = getProgress();
    return {
      'percentage': progress.percentage,
      'status': progress.status.name,
      'usedTime': progress.usedTime.inMinutes,
      'totalTime': progress.totalTime.inMinutes,
      'remainingTime': progress.remainingTime?.inMinutes,
      'isOverdue': isOverdue(),
      'isCompleted': isCompleted(),
      'isDueSoon': isDueSoon(),
    };
  }

  // Enhanced progress display methods
  String getFormattedProgress() {
    final progress = getProgress();
    final percentage = (progress.percentage * 100).toStringAsFixed(0);
    switch (progress.status) {
      case TaskProgressStatus.completed:
        return '✓ Complete';
      case TaskProgressStatus.overdue:
        return '⚠️ Overdue ($percentage%)';
      case TaskProgressStatus.critical:
        return '🔴 Critical ($percentage%)';
      case TaskProgressStatus.warning:
        return '🟡 At Risk ($percentage%)';
      case TaskProgressStatus.inProgress:
        return '🟢 In Progress ($percentage%)';
      case TaskProgressStatus.notStarted:
        return '⭘ Not Started';
    }
  }

  Map<String, dynamic> getProgressStyleInfo() {
    final progress = getProgress();
    switch (progress.status) {
      case TaskProgressStatus.completed:
        return {'color': 0xFF4CAF50, 'icon': '✓', 'label': 'Complete'};
      case TaskProgressStatus.overdue:
        return {'color': 0xFFF44336, 'icon': '⚠️', 'label': 'Overdue'};
      case TaskProgressStatus.critical:
        return {'color': 0xFFFF5722, 'icon': '🔴', 'label': 'Critical'};
      case TaskProgressStatus.warning:
        return {'color': 0xFFFFC107, 'icon': '🟡', 'label': 'At Risk'};
      case TaskProgressStatus.inProgress:
        return {'color': 0xFF2196F3, 'icon': '🟢', 'label': 'In Progress'};
      case TaskProgressStatus.notStarted:
        return {'color': 0xFF9E9E9E, 'icon': '⭘', 'label': 'Not Started'};
    }
  }

  String getRemainingProgressDisplay() {
    final remaining = getRemainingTimeDuration();
    if (remaining == null || _allocatedTimeInHours == null) return 'N/A';

    final progress = getProgress();
    final remainingPercentage =
        ((1 - progress.percentage) * 100).toStringAsFixed(0);

    if (isCompleted()) {
      return '✓ Completed';
    } else if (isOverdue()) {
      return '⚠️ Overdue';
    } else {
      return '$remainingPercentage% Remaining';
    }
  }
}

enum TaskProgressStatus {
  notStarted,
  inProgress,
  warning,
  critical,
  overdue,
  completed,
}

class TaskProgress {
  final double percentage;
  final TaskProgressStatus status;
  final Duration usedTime;
  final Duration totalTime;
  final Duration? remainingTime;

  const TaskProgress({
    required this.percentage,
    required this.status,
    required this.usedTime,
    required this.totalTime,
    this.remainingTime,
  });

  bool get isAtRisk =>
      status == TaskProgressStatus.warning ||
      status == TaskProgressStatus.critical;

  String getStatusEmoji() {
    switch (status) {
      case TaskProgressStatus.completed:
        return '✓';
      case TaskProgressStatus.overdue:
        return '⚠️';
      case TaskProgressStatus.critical:
        return '🔴';
      case TaskProgressStatus.warning:
        return '🟡';
      case TaskProgressStatus.inProgress:
        return '🟢';
      case TaskProgressStatus.notStarted:
        return '⭘';
    }
  }
}
