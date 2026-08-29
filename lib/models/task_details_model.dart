import 'package:pi_task_watch/utils/format_utils.dart';

class TaskDetailsModel {
  final int id;
  final String name;
  final String? description;
  final int? projectId;
  final String? projectName;
  final int stageId;
  final String? stageName;
  final List<TaskAssignee> userIds;
  final List<String> userNames;
  final List<String>? tags;
  final DateTime? dateDeadline;
  final DateTime? dateStart;
  final double allocatedHours;
  final double progressPercentage;
  final String? priority;
  final String? state;
  final int? parentId;
  final DateTime? createDate;
  final DateTime? writeDate;
  final String? usedTime;
  final String? taskUrl;

  TaskDetailsModel({
    required this.id,
    required this.name,
    this.description,
    this.projectId,
    this.projectName,
    required this.stageId,
    this.stageName,
    this.userIds = const <TaskAssignee>[],
    this.userNames = const [],
    this.tags,
    this.dateDeadline,
    this.dateStart,
    this.allocatedHours = 0.0,
    this.progressPercentage = 0.0,
    this.priority,
    this.state,
    this.parentId,
    this.createDate,
    this.writeDate,
    this.usedTime,
    this.taskUrl,
  });

  /// Create TaskModel from JSON (API response)
  factory TaskDetailsModel.fromJson(Map<String, dynamic> json) {
    return TaskDetailsModel(
      id: (json['id'] is int)
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] is String
          ? json['name']
          : (json['name'] == false ? '' : json['name']?.toString() ?? ''),
      description: json['description'] is String
          ? json['description']
          : (json['description'] == false
              ? null
              : json['description']?.toString()),
      projectId: json['project_id'] is List
          ? (json['project_id'] as List).first
          : (json['project_id'] is int ? json['project_id'] : null),
      projectName: json['project_name'] is String
          ? json['project_name']
          : (json['project_id'] is List && (json['project_id'] as List).length > 1
              ? json['project_id'][1]?.toString()
              : null),
      stageId: json['stage_id'] is List
          ? (json['stage_id'] as List).first
          : (json['stage_id'] is int
              ? json['stage_id']
              : int.tryParse(json['stage_id']?.toString() ?? '0') ?? 0),
      stageName: json['stage_name'] is String
          ? json['stage_name']
          : (json['stage_id'] is List && (json['stage_id'] as List).length > 1
              ? json['stage_id'][1]?.toString()
              : null),
      userIds: json['user_ids'] is List
          ? (json['user_ids'] as List)
              .map<TaskAssignee>((x) => TaskAssignee.fromJson(x))
              .toList()
          : [],
      userNames: json['user_names'] is List
          ? List<String>.from(json['user_names'].map((x) => x.toString()))
          : (json['user_ids'] is List
              ? (json['user_ids'] as List)
                  .map<String>((x) {
                    if (x is List && x.length > 1) return x[1].toString();
                    if (x is Map) return (x['name'] ?? '').toString();
                    return '';
                  })
                  .where((s) => s.isNotEmpty)
                  .toList()
              : []),
      tags: json['tag_ids'] is List
          ? (json['tag_ids'] as List).map((x) {
              if (x is List && x.length > 1) return x[1].toString();
              if (x is Map) return (x['name'] ?? '').toString();
              return x.toString();
            }).toList()
          : null,
      dateDeadline: (json['date_deadline'] ?? json['end_date']) is String
          ? DateTime.tryParse(json['date_deadline'] ?? json['end_date'])
          : null,
      dateStart: (json['date_start'] ?? json['start_date']) is String
          ? DateTime.tryParse(json['date_start'] ?? json['start_date'])
          : null,
      allocatedHours: json['allocated_time_in_hours'] is String
          ? _parseDurationToHours(json['allocated_time_in_hours'])
          : (json['allocated_hours'] is num
              ? (json['allocated_hours'] as num).toDouble()
              : 0.0),
      progressPercentage: (json['progress'] is num
          ? (json['progress'] as num).toDouble()
          : 0.0),
      priority: json['priority'] is String
          ? json['priority']
          : (json['priority'] == false ? null : json['priority']?.toString()),
      state: json['state'] is String
          ? json['state']
          : (json['state'] == false ? null : json['state']?.toString()),
      parentId: json['parent_id'] is List
          ? (json['parent_id'] as List).first
          : (json['parent_id'] is int ? json['parent_id'] : null),
      createDate: json['create_date'] is String
          ? DateTime.tryParse(json['create_date'])
          : null,
      writeDate: json['write_date'] is String
          ? DateTime.tryParse(json['write_date'])
          : null,
      usedTime: json['used_time'] is String
          ? json['used_time']
          : (json['used_time'] == false ? null : json['used_time']?.toString()),
      taskUrl: json['task_url'] is String
          ? json['task_url']
          : (json['task_url'] == false ? null : json['task_url']?.toString()),
    );
  }

  static double _parseDurationToHours(String? duration) {
    if (duration == null || duration.isEmpty) return 0.0;
    final parts = duration.split(':');
    if (parts.length != 2) return 0.0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours + (minutes / 60.0);
  }

  /// Convert TaskModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'project_id': projectId,
      'project_name': projectName,
      'stage_id': stageId,
      'stage_name': stageName,
      'user_ids': userIds.map((u) => u.toJson()).toList(),
      'user_names': userNames,
      'tag_ids': tags,
      'date_deadline': dateDeadline?.toIso8601String(),
      'date_start': dateStart?.toIso8601String(),
      'allocated_hours': allocatedHours,
      'progress': progressPercentage,
      'priority': priority,
      'state': state,
      'parent_id': parentId,
      'create_date': createDate?.toIso8601String(),
      'write_date': writeDate?.toIso8601String(),
      'used_time': usedTime,
      'task_url': taskUrl,
    };
  }

  /// Create a copy of TaskModel with some fields updated
  TaskDetailsModel copyWith({
    int? id,
    String? name,
    String? description,
    int? projectId,
    String? projectName,
    int? stageId,
    String? stageName,
    List<TaskAssignee>? userIds,
    List<String>? userNames,
    List<String>? tags,
    DateTime? dateDeadline,
    DateTime? dateStart,
    double? allocatedHours,
    double? progressPercentage,
    String? priority,
    String? state,
    int? parentId,
    DateTime? createDate,
    DateTime? writeDate,
  }) {
    return TaskDetailsModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      stageId: stageId ?? this.stageId,
      stageName: stageName ?? this.stageName,
      userIds: userIds ?? this.userIds,
      userNames: userNames ?? this.userNames,
      tags: tags ?? this.tags,
      dateDeadline: dateDeadline ?? this.dateDeadline,
      dateStart: dateStart ?? this.dateStart,
      allocatedHours: allocatedHours ?? this.allocatedHours,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      parentId: parentId ?? this.parentId,
      createDate: createDate ?? this.createDate,
      writeDate: writeDate ?? this.writeDate,
      usedTime: usedTime ?? this.usedTime,
      taskUrl: taskUrl ?? this.taskUrl,
    );
  }

  /// Get end date/time (same as deadline)
  DateTime? getEndDateTime() => dateDeadline;

  /// Get formatted allocated time
  String getFormattedAllocatedTime() {
    if (allocatedHours == 0) return '00:00';

    final hours = allocatedHours.floor();
    final minutes = ((allocatedHours - hours) * 60).round();

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Get formatted progress percentage
  String getFormattedProgress() {
    return '${progressPercentage.toStringAsFixed(0)}%';
  }

  /// Check if task is overdue
  bool isOverdue() {
    if (dateDeadline == null) return false;
    return DateTime.now().isAfter(dateDeadline!);
  }

  /// Check if task has high priority
  bool isHighPriority() {
    return priority == '1' || priority == 'high';
  }

  /// Get time remaining until deadline
  Duration? getTimeRemaining() {
    if (dateDeadline == null) return null;
    return dateDeadline!.difference(DateTime.now());
  }

  /// Get formatted time remaining
  String getFormattedTimeRemaining() {
    final timeRemaining = getTimeRemaining();
    if (timeRemaining == null) return 'No deadline';

    if (timeRemaining.isNegative) {
      return 'Overdue';
    }

    final days = timeRemaining.inDays;
    final hours = timeRemaining.inHours % 24;

    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''} ${hours}h';
    } else if (hours > 0) {
      final minutes = timeRemaining.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } else {
      final minutes = timeRemaining.inMinutes;
      return '${minutes}m';
    }
  }

  /// Get assignee names as comma-separated string
  String getAssigneesString() {
    if (userIds.isNotEmpty) {
      return userIds.map((u) => u.name).join(', ');
    }
    return userNames.join(', ');
  }

  /// Get first assignee initial for avatar
  String getFirstAssigneeInitial() {
    if (userIds.isNotEmpty) {
      return userIds.first.name[0].toUpperCase();
    }
    if (userNames.isNotEmpty) return userNames.first[0].toUpperCase();
    return '?';
  }

  @override
  String toString() {
    return 'TaskDetailsModel(id: $id, name: $name, stage: $stageName, users: $userNames, progress: $progressPercentage%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskDetailsModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Task Stage Model (User Example #2)
class TaskStage {
  final int id;
  final String name;
  final int? sequence;

  TaskStage({
    required this.id,
    required this.name,
    this.sequence,
  });

  factory TaskStage.fromJson(Map<String, dynamic> json) {
    return TaskStage(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sequence: json['sequence'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sequence': sequence,
    };
  }
}

/// Activity/Chatter Model
class TaskActivity {
  final int id;
  final String body;
  final DateTime date;
  final int authorId;
  final String authorName;
  final String messageType;
  final String subtypeName;
  final String? stageOldValue;
  final String? stageNewValue;
  final String? trackingDesc;
  final bool isInternalNote;
  final bool isTaskCreated;
  final List<TaskAssignee>? attachmentIds;

  TaskActivity({
    required this.id,
    required this.body,
    required this.date,
    required this.authorId,
    required this.authorName,
    required this.messageType,
    this.subtypeName = '',
    this.stageOldValue,
    this.stageNewValue,
    this.trackingDesc,
    this.isInternalNote = false,
    this.isTaskCreated = false,
    this.attachmentIds,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> json) {
    String subName = '';
    if (json['subtype_id'] is List &&
        (json['subtype_id'] as List).length > 1) {
      subName = json['subtype_id'][1]?.toString() ?? '';
    } else if (json['subtype_name'] != null) {
      subName = json['subtype_name'].toString();
    }

    final bool isNote = subName.toLowerCase().contains('note') ||
        (json['is_internal_note'] == true);
    final bool isCreated = subName.toLowerCase().contains('created') ||
        (json['is_task_created'] == true) ||
        (json['body']?.toString().toLowerCase().contains('task created') ??
            false);

    DateTime parsedDate = DateTime.now();
    if (json['date'] != null) {
      final dateStr = json['date'].toString();
      if (dateStr.isNotEmpty) {
        if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
          parsedDate =
              DateTime.tryParse('${dateStr.replaceAll(' ', 'T')}Z')?.toLocal() ??
                  DateTime.now();
        } else {
          parsedDate =
              DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
        }
      }
    }

    return TaskActivity(
      id: json['id'] ?? 0,
      body: json['body'] ?? '',
      date: parsedDate,
      authorId: json['author_id'] is List
          ? (json['author_id'] as List).first
          : json['author_id'] is Map
              ? (json['author_id'] as Map)['id'] ?? 0
              : json['author_id'] ?? 0,
      authorName: json['author_name'] ??
          (json['author_id'] is List && (json['author_id'] as List).length > 1
              ? json['author_id'][1]
              : json['author_id'] is Map
                  ? (json['author_id'] as Map)['name'] ?? 'Public user'
                  : 'Public user'),
      messageType: json['message_type'] ?? 'comment',
      subtypeName: subName,
      stageOldValue: json['stage_old_value']?.toString(),
      stageNewValue: json['stage_new_value']?.toString(),
      trackingDesc: json['tracking_desc']?.toString(),
      isInternalNote: isNote,
      isTaskCreated: isCreated,
      attachmentIds: json['attachment_ids'] != null
          ? (json['attachment_ids'] as List)
              .map<TaskAssignee>((x) => TaskAssignee.fromJson(x))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'date': date.toIso8601String(),
      'author_id': authorId,
      'author_name': authorName,
      'message_type': messageType,
      'subtype_name': subtypeName,
      'stage_old_value': stageOldValue,
      'stage_new_value': stageNewValue,
      'tracking_desc': trackingDesc,
      'is_internal_note': isInternalNote,
      'is_task_created': isTaskCreated,
      'attachment_ids': attachmentIds,
    };
  }

  /// Get author initial for avatar
  String getAuthorInitial() {
    return authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
  }

  /// Check if this is a stage change notification
  bool isStageChange() {
    return messageType == 'notification' &&
        body.toLowerCase().contains('stage');
  }

  /// Get clean body text (strip HTML)
  String getCleanBody() {
    return FormatUtils.cleanHtml(body);
  }
}

/// Planned Activity Model (mail.activity)
class TaskPlannedActivity {
  final int id;
  final String summary;
  final String note;
  final int activityTypeId;
  final String activityTypeName;
  final String dateDeadline;
  final int userId;
  final String userName;
  final String state; // 'today', 'planned', 'overdue'

  TaskPlannedActivity({
    required this.id,
    required this.summary,
    required this.note,
    required this.activityTypeId,
    required this.activityTypeName,
    required this.dateDeadline,
    required this.userId,
    required this.userName,
    required this.state,
  });

  factory TaskPlannedActivity.fromJson(Map<String, dynamic> json) {
    int actTypeId = 0;
    String actTypeName = 'Activity';
    if (json['activity_type_id'] is List &&
        (json['activity_type_id'] as List).isNotEmpty) {
      actTypeId = json['activity_type_id'][0] is int
          ? json['activity_type_id'][0]
          : int.tryParse(json['activity_type_id'][0].toString()) ?? 0;
      if ((json['activity_type_id'] as List).length > 1) {
        actTypeName = json['activity_type_id'][1].toString();
      }
    }

    int uId = 0;
    String uName = '';
    if (json['user_id'] is List && (json['user_id'] as List).isNotEmpty) {
      uId = json['user_id'][0] is int
          ? json['user_id'][0]
          : int.tryParse(json['user_id'][0].toString()) ?? 0;
      if ((json['user_id'] as List).length > 1) {
        uName = json['user_id'][1].toString();
      }
    }

    return TaskPlannedActivity(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      summary: json['summary']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      activityTypeId: actTypeId,
      activityTypeName: actTypeName,
      dateDeadline: json['date_deadline']?.toString() ?? '',
      userId: uId,
      userName: uName,
      state: json['state']?.toString() ?? 'planned',
    );
  }

  String get cleanNote => FormatUtils.cleanHtml(note);
}

/// Timesheet Model
class TaskTimesheet {
  final int id;
  final String date;
  final int employeeId;
  final String employeeName;
  final String description;
  final double unitAmount;
  final String duration;

  TaskTimesheet({
    required this.id,
    required this.date,
    required this.employeeId,
    required this.employeeName,
    required this.description,
    required this.unitAmount,
    required this.duration,
  });

  factory TaskTimesheet.fromJson(Map<String, dynamic> json) {
    return TaskTimesheet(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      employeeId: json['employee_id'] is List
          ? (json['employee_id'] as List).first
          : json['employee_id'] is Map
              ? (json['employee_id'] as Map)['id'] ?? 0
              : json['employee_id'] ?? 0,
      employeeName: json['employee_name'] ??
          (json['employee_id'] is List &&
                  (json['employee_id'] as List).length > 1
              ? json['employee_id'][1]
              : json['employee_id'] is Map
                  ? (json['employee_id'] as Map)['name'] ?? 'Unknown'
                  : 'Unknown'),
      description: json['description'] ?? '',
      unitAmount: (json['unit_amount'] ?? 0.0).toDouble(),
      duration: json['duration'] ?? '00:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'description': description,
      'unit_amount': unitAmount,
      'duration': duration,
    };
  }
}

/// Subtask Model
class Subtask {
  final int id;
  final String name;
  final int stageId;
  final String stageName;
  final List<TaskAssignee> userIds;
  final DateTime? deadline;

  Subtask({
    required this.id,
    required this.name,
    required this.stageId,
    required this.stageName,
    required this.userIds,
    this.deadline,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      stageId: json['stage_id'] is List
          ? (json['stage_id'] as List).first
          : json['stage_id'] ?? 0,
      stageName: json['stage_name'] ??
          (json['stage_id'] is List && (json['stage_id'] as List).length > 1
              ? json['stage_id'][1]
              : 'Unknown'),
      userIds: json['user_ids'] != null
          ? (json['user_ids'] as List)
              .map<TaskAssignee>((x) => TaskAssignee.fromJson(x))
              .toList()
          : [],
      deadline:
          json['deadline'] != null ? DateTime.tryParse(json['deadline']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stage_id': stageId,
      'stage_name': stageName,
      'user_ids': userIds.map((u) => u.toJson()).toList(),
      'deadline': deadline?.toIso8601String(),
    };
  }

  /// Get assignees as comma-separated string
  String getAssigneesString() {
    return userIds.map((u) => u.name).join(', ');
  }
}

/// Task Assignee Model (User Example #8/9)
class TaskAssignee {
  final int id;
  final String name;

  TaskAssignee({
    required this.id,
    required this.name,
  });

  factory TaskAssignee.fromJson(dynamic json) {
    if (json is List && json.length > 1) {
      return TaskAssignee(id: json[0], name: json[1].toString());
    }
    if (json is Map) {
      return TaskAssignee(
        id: json['id'] is int
            ? json['id']
            : (int.tryParse(json['id'].toString()) ?? 0),
        name: json['name'] ?? '',
      );
    }
    // Handle integer ID case (API sometimes returns [1,2,3])
    if (json is int) {
      return TaskAssignee(id: json, name: 'User $json');
    }
    return TaskAssignee(id: 0, name: 'Unknown');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

enum TaskAttachmentType { image, video, audio, document, other }

class TaskAttachment {
  final int id;
  final String name;
  final String? mimetype;
  final int fileSize;
  final DateTime? createDate;
  final String? createUserName;

  TaskAttachment({
    required this.id,
    required this.name,
    this.mimetype,
    this.fileSize = 0,
    this.createDate,
    this.createUserName,
  });

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    String? author;
    if (json['create_uid'] is List && (json['create_uid'] as List).length > 1) {
      author = json['create_uid'][1].toString();
    } else if (json['create_uid'] is Map) {
      author = json['create_uid']['name']?.toString();
    }

    return TaskAttachment(
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id'].toString()) ?? 0),
      name: json['name']?.toString() ?? 'Unnamed Attachment',
      mimetype: json['mimetype']?.toString(),
      fileSize: json['file_size'] is int
          ? json['file_size']
          : (int.tryParse(json['file_size']?.toString() ?? '0') ?? 0),
      createDate: json['create_date'] != null
          ? DateTime.tryParse(json['create_date'].toString())
          : null,
      createUserName: author,
    );
  }

  TaskAttachmentType get type {
    final lowerName = name.toLowerCase();
    final lowerMime = (mimetype ?? '').toLowerCase();

    if (lowerMime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.svg') ||
        lowerName.endsWith('.bmp')) {
      return TaskAttachmentType.image;
    }

    if (lowerMime.startsWith('video/') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.avi') ||
        lowerName.endsWith('.mkv') ||
        lowerName.endsWith('.webm')) {
      return TaskAttachmentType.video;
    }

    if (lowerMime.startsWith('audio/') ||
        lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.wav') ||
        lowerName.endsWith('.m4a') ||
        lowerName.endsWith('.aac') ||
        lowerName.endsWith('.ogg') ||
        lowerName.endsWith('.flac')) {
      return TaskAttachmentType.audio;
    }

    if (lowerMime.contains('pdf') ||
        lowerMime.contains('document') ||
        lowerMime.contains('sheet') ||
        lowerMime.contains('presentation') ||
        lowerMime.contains('text') ||
        lowerName.endsWith('.pdf') ||
        lowerName.endsWith('.doc') ||
        lowerName.endsWith('.docx') ||
        lowerName.endsWith('.xls') ||
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.ppt') ||
        lowerName.endsWith('.pptx') ||
        lowerName.endsWith('.txt') ||
        lowerName.endsWith('.csv')) {
      return TaskAttachmentType.document;
    }

    return TaskAttachmentType.other;
  }

  String get formattedSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
