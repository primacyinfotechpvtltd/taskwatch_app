import 'package:pi_task_watch/models/task_details_model.dart';
import 'package:pi_task_watch/utils/duration_utils.dart';
import 'package:pi_task_watch/utils/format_utils.dart';

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

  // Assignee helper getters
  List<TaskAssignee> get userIds {
    if (json['user_ids'] is List) {
      return (json['user_ids'] as List)
          .map<TaskAssignee>((x) => TaskAssignee.fromJson(x))
          .toList();
    } else if (json['user_id'] != null) {
      return [TaskAssignee.fromJson(json['user_id'])];
    }
    return [];
  }

  List<String> get userNames {
    if (json['user_names'] is List) {
      return List<String>.from(json['user_names'].map((x) => x.toString()));
    }
    if (json['user_ids'] is List) {
      return (json['user_ids'] as List)
          .map<String>((x) {
            if (x is List && x.length > 1) return x[1].toString();
            if (x is Map) return (x['name'] ?? '').toString();
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (json['user_name'] != null && json['user_name'].toString().isNotEmpty) {
      return [json['user_name'].toString()];
    }
    if (json['user_id'] is List && (json['user_id'] as List).length > 1) {
      return [json['user_id'][1].toString()];
    }
    return [];
  }

  int? get primaryAssigneeId {
    if (userIds.isNotEmpty && userIds.first.id > 0) {
      return userIds.first.id;
    }
    if (json['user_id'] is List && (json['user_id'] as List).isNotEmpty) {
      return json['user_id'][0] is int
          ? json['user_id'][0]
          : int.tryParse(json['user_id'][0].toString());
    }
    if (json['user_id'] is int) return json['user_id'];
    return null;
  }

  String? get primaryAssigneeName {
    if (userIds.isNotEmpty &&
        userIds.first.name.isNotEmpty &&
        userIds.first.name != 'Unknown') {
      return userIds.first.name;
    }
    if (userNames.isNotEmpty && userNames.first.isNotEmpty) {
      return userNames.first;
    }
    if (json['user_id'] is List && (json['user_id'] as List).length > 1) {
      return json['user_id'][1].toString();
    }
    if (json['user_name'] != null) return json['user_name'].toString();
    return null;
  }

  String? get primaryAssigneeEmail {
    if (json['user_email'] != null && json['user_email'].toString().isNotEmpty) {
      return json['user_email'].toString();
    }
    if (json['email'] != null && json['email'].toString().isNotEmpty) {
      return json['email'].toString();
    }
    if (json['login'] != null && json['login'].toString().contains('@')) {
      return json['login'].toString();
    }
    return null;
  }

  // Tags getters
  List<String> get tags {
    if (json['tags'] is List) {
      final list = (json['tags'] as List).map<String>((x) {
        if (x is String) return x.trim();
        if (x is Map && (x['name'] != null || x['display_name'] != null)) {
          return (x['name'] ?? x['display_name']).toString().trim();
        }
        if (x is List && x.length > 1 && x[1] != null && x[1] != false) {
          return x[1].toString().trim();
        }
        return '';
      }).where((s) => s.isNotEmpty).toList();
      if (list.isNotEmpty) return list;
    }
    if (json['tag_ids'] is List) {
      final list = (json['tag_ids'] as List).map<String>((x) {
        if (x is String) return x.trim();
        if (x is Map && (x['name'] != null || x['display_name'] != null)) {
          return (x['name'] ?? x['display_name']).toString().trim();
        }
        if (x is List && x.length > 1 && x[1] != null && x[1] != false) {
          return x[1].toString().trim();
        }
        return '';
      }).where((s) => s.isNotEmpty).toList();
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  List<int> get tagIds {
    if (json['tag_ids'] is List) {
      final list = (json['tag_ids'] as List).map<int>((x) {
        if (x is int) return x;
        if (x is Map && x['id'] is int) return x['id'] as int;
        if (x is List && x.isNotEmpty && x[0] is int) return x[0] as int;
        return int.tryParse(x.toString()) ?? 0;
      }).where((id) => id > 0).toList();
      if (list.isNotEmpty) return list;
    }
    if (json['tags'] is List) {
      final list = (json['tags'] as List).map<int>((x) {
        if (x is int) return x;
        if (x is Map && x['id'] is int) return x['id'] as int;
        if (x is List && x.isNotEmpty && x[0] is int) return x[0] as int;
        return 0;
      }).where((id) => id > 0).toList();
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  // Milestone getters
  int? get milestoneId {
    final m = json['milestone_id'] ?? json['milestone'];
    if (m is int && m > 0) return m;
    if (m is List && m.isNotEmpty && m[0] is int && (m[0] as int) > 0) return m[0] as int;
    if (m is Map && m['id'] is int && (m['id'] as int) > 0) return m['id'] as int;
    return null;
  }

  String? get milestoneName {
    if (json['milestone_name'] is String && (json['milestone_name'] as String).trim().isNotEmpty && json['milestone_name'] != 'false') {
      return json['milestone_name'].toString().trim();
    }
    final m = json['milestone_id'] ?? json['milestone'];
    if (m is String && m != 'false' && m.trim().isNotEmpty) return m.trim();
    if (m is List && m.length > 1 && m[1] != null && m[1] != false) {
      final str = m[1].toString().trim();
      if (str.isNotEmpty && str != 'false') return str;
    }
    if (m is Map && (m['name'] != null || m['display_name'] != null)) {
      final str = (m['name'] ?? m['display_name'])?.toString().trim();
      if (str != null && str.isNotEmpty && str != 'false') return str;
    }
    return null;
  }

  // Assigner / Creator (Who assigned this task)
  int? get createUid {
    // 1. json['create_uid']
    if (json['create_uid'] is List && (json['create_uid'] as List).isNotEmpty) {
      return json['create_uid'][0] is int
          ? json['create_uid'][0]
          : int.tryParse(json['create_uid'][0].toString());
    }
    if (json['create_uid'] is Map) {
      return json['create_uid']['id'] is int
          ? json['create_uid']['id']
          : int.tryParse(json['create_uid']['id'].toString());
    }
    if (json['create_uid'] is int) return json['create_uid'];

    // 2. json['created_by_id'] / json['create_user_id'] / json['created_by']
    if (json['created_by_id'] is int) return json['created_by_id'];
    if (json['create_user_id'] is int) return json['create_user_id'];
    if (json['created_by'] is List && (json['created_by'] as List).isNotEmpty) {
      return json['created_by'][0] is int
          ? json['created_by'][0]
          : int.tryParse(json['created_by'][0].toString());
    }
    if (json['created_by'] is Map) {
      return json['created_by']['id'] is int
          ? json['created_by']['id']
          : int.tryParse(json['created_by']['id'].toString());
    }
    if (json['created_by'] is int) return json['created_by'];

    // 3. json['assigned_by_id'] / json['assigned_by']
    if (json['assigned_by_id'] is int) return json['assigned_by_id'];
    if (json['assigned_by'] is List && (json['assigned_by'] as List).isNotEmpty) {
      return json['assigned_by'][0] is int
          ? json['assigned_by'][0]
          : int.tryParse(json['assigned_by'][0].toString());
    }
    if (json['assigned_by'] is Map) {
      return json['assigned_by']['id'] is int
          ? json['assigned_by']['id']
          : int.tryParse(json['assigned_by']['id'].toString());
    }
    if (json['assigned_by'] is int) return json['assigned_by'];

    return null;
  }

  String? get createUserName {
    // 1. json['create_uid']
    if (json['create_uid'] is List && (json['create_uid'] as List).length > 1) {
      final name = json['create_uid'][1]?.toString().trim();
      if (name != null && name.isNotEmpty && name != 'false') return name;
    }
    if (json['create_uid'] is Map) {
      final name = (json['create_uid']['name'] ?? json['create_uid']['display_name'])?.toString().trim();
      if (name != null && name.isNotEmpty && name != 'false') return name;
    }

    // 2. json['created_by']
    if (json['created_by'] is List && (json['created_by'] as List).length > 1) {
      final name = json['created_by'][1]?.toString().trim();
      if (name != null && name.isNotEmpty && name != 'false') return name;
    }
    if (json['created_by'] is Map) {
      final name = (json['created_by']['name'] ?? json['created_by']['display_name'])?.toString().trim();
      if (name != null && name.isNotEmpty && name != 'false') return name;
    }
    if (json['created_by'] is String && json['created_by'].toString().trim().isNotEmpty) {
      final name = json['created_by'].toString().trim();
      if (name != 'false') return name;
    }

    // 3. json['create_user_name'] / json['creator_name'] / json['created_by_name']
    if (json['create_user_name'] != null && json['create_user_name'].toString().trim().isNotEmpty) {
      final name = json['create_user_name'].toString().trim();
      if (name != 'false') return name;
    }
    if (json['creator_name'] != null && json['creator_name'].toString().trim().isNotEmpty) {
      final name = json['creator_name'].toString().trim();
      if (name != 'false') return name;
    }
    if (json['created_by_name'] != null && json['created_by_name'].toString().trim().isNotEmpty) {
      final name = json['created_by_name'].toString().trim();
      if (name != 'false') return name;
    }

    // 4. json['assigned_by']
    if (json['assigned_by'] is List && (json['assigned_by'] as List).length > 1) {
      final name = json['assigned_by'][1]?.toString().trim();
      if (name != null && name.isNotEmpty && name != 'false') return name;
    }
    if (json['assigned_by'] is Map) {
      final name = (json['assigned_by']['name'] ?? json['assigned_by']['display_name'])?.toString().trim();
      if (name != null && name.isNotEmpty && name != 'false') return name;
    }
    if (json['assigned_by'] is String && json['assigned_by'].toString().trim().isNotEmpty) {
      final name = json['assigned_by'].toString().trim();
      if (name != 'false') return name;
    }
    if (json['assigned_by_name'] != null && json['assigned_by_name'].toString().trim().isNotEmpty) {
      final name = json['assigned_by_name'].toString().trim();
      if (name != 'false') return name;
    }

    return null;
  }

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
      if (desc.isNotEmpty && desc != 'false') {
        return FormatUtils.cleanHtml(desc);
      }
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
