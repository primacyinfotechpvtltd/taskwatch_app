class AnnouncementModel {
  final int id;
  final String name; // Code/Sequence: e.g. GA0001
  final String title; // announcement_reason
  final String content; // announcement (HTML)
  final String dateStart;
  final String dateEnd;
  final bool isAnnouncement;
  final bool isBirthdayAnnouncement;
  final String birthdayEmployee;
  final int birthdayEmployeeId;
  final String state; // draft, to_approve, approved, rejected, cancel, expired
  final String author;
  final int createUid;
  final String createDate;
  final String announcementType; // general, employee, department, job_position
  final List<int> employeeIds;
  final List<int> departmentIds;
  final List<int> jobIds;
  final List<int> userIds;

  AnnouncementModel({
    required this.id,
    required this.name,
    required this.title,
    required this.content,
    required this.dateStart,
    required this.dateEnd,
    required this.isAnnouncement,
    required this.isBirthdayAnnouncement,
    required this.birthdayEmployee,
    this.birthdayEmployeeId = 0,
    required this.state,
    required this.author,
    this.createUid = 0,
    required this.createDate,
    this.announcementType = 'general',
    this.employeeIds = const [],
    this.departmentIds = const [],
    this.jobIds = const [],
    this.userIds = const [],
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    // Handle create_uid many2one or int
    final createUidVal = json['create_uid'];
    String authorName = 'System';
    int authorUid = 0;
    if (createUidVal is List && createUidVal.isNotEmpty) {
      if (createUidVal[0] is int) {
        authorUid = createUidVal[0] as int;
      } else {
        authorUid = int.tryParse(createUidVal[0].toString()) ?? 0;
      }
      if (createUidVal.length >= 2) {
        authorName = createUidVal[1].toString();
      }
    } else if (createUidVal is int) {
      authorUid = createUidVal;
    }

    // Handle birthday_employee_id many2one
    final birthdayEmployeeVal = json['birthday_employee_id'];
    String birthdayEmployeeName = '';
    int birthdayEmpId = 0;
    if (birthdayEmployeeVal is List && birthdayEmployeeVal.isNotEmpty) {
      if (birthdayEmployeeVal[0] is int) {
        birthdayEmpId = birthdayEmployeeVal[0] as int;
      } else {
        birthdayEmpId = int.tryParse(birthdayEmployeeVal[0].toString()) ?? 0;
      }
      if (birthdayEmployeeVal.length >= 2) {
        birthdayEmployeeName = birthdayEmployeeVal[1].toString();
      }
    } else if (birthdayEmployeeVal is int) {
      birthdayEmpId = birthdayEmployeeVal;
    }

    String safeString(dynamic value) {
      if (value == null || value == false) return '';
      return value.toString();
    }

    bool safeBool(dynamic value) {
      if (value == null || value == false) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    int safeInt(dynamic value) {
      if (value == null || value == false) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    List<int> safeIdList(dynamic val) {
      if (val == null || val == false) return [];
      if (val is List) {
        return val.map((e) {
          if (e is int) return e;
          if (e is List && e.isNotEmpty && e.first is int) return e.first as int;
          if (e is Map && e.containsKey('id')) return int.tryParse(e['id'].toString()) ?? 0;
          return int.tryParse(e.toString()) ?? 0;
        }).where((id) => id > 0).toList();
      }
      if (val is int && val > 0) return [val];
      return [];
    }

    final empIds = <int>{
      ...safeIdList(json['employee_ids']),
      ...safeIdList(json['announcement_employee_ids']),
      ...safeIdList(json['employee_id']),
    }.toList();

    final deptIds = <int>{
      ...safeIdList(json['department_ids']),
      ...safeIdList(json['department_id']),
    }.toList();

    final jIds = <int>{
      ...safeIdList(json['job_ids']),
      ...safeIdList(json['position_ids']),
      ...safeIdList(json['job_id']),
    }.toList();

    final uIds = <int>{
      ...safeIdList(json['user_ids']),
      ...safeIdList(json['user_id']),
    }.toList();

    return AnnouncementModel(
      id: safeInt(json['id']),
      name: safeString(json['name']),
      title: safeString(json['announcement_reason']),
      content: safeString(json['announcement']),
      dateStart: safeString(json['date_start']),
      dateEnd: safeString(json['date_end']),
      isAnnouncement: safeBool(json['is_announcement']),
      isBirthdayAnnouncement: safeBool(json['is_birthday_announcement']),
      birthdayEmployee: birthdayEmployeeName,
      birthdayEmployeeId: birthdayEmpId,
      state: safeString(json['state']).isNotEmpty ? safeString(json['state']) : 'draft',
      author: authorName,
      createUid: authorUid,
      createDate: safeString(json['create_date']),
      announcementType: safeString(json['announcement_type']),
      employeeIds: empIds,
      departmentIds: deptIds,
      jobIds: jIds,
      userIds: uIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'announcement_reason': title,
      'announcement': content,
      'date_start': dateStart,
      'date_end': dateEnd,
      'is_announcement': isAnnouncement,
      'is_birthday_announcement': isBirthdayAnnouncement,
      'birthday_employee': birthdayEmployee,
      'state': state,
      'author': author,
      'create_date': createDate,
      'announcement_type': announcementType,
      'employee_ids': employeeIds,
      'department_ids': departmentIds,
      'job_ids': jobIds,
      'user_ids': userIds,
    };
  }

  /// Determines if this announcement is targeted to the given user/employee/department
  bool isVisibleToUser({
    int? currentUserId,
    int? currentEmployeeId,
    int? currentDepartmentId,
    int? currentJobId,
  }) {
    // 1. Author can always see their own announcements
    if (currentUserId != null && createUid > 0 && currentUserId == createUid) {
      return true;
    }

    final type = announcementType.toLowerCase();

    // 2. Birthday announcement:
    if (isBirthdayAnnouncement) {
      return true;
    }

    // 3. General announcements (or no type specified / 'all')
    if (type.isEmpty || type == 'general' || type == 'all') {
      // If employee_ids is also specified, check if it's restricted
      if (employeeIds.isNotEmpty && currentEmployeeId != null) {
        return employeeIds.contains(currentEmployeeId);
      }
      return true;
    }

    // 4. Targeted by Employee:
    if (type == 'employee' || type == 'by_employee' || type == 'employees') {
      if (employeeIds.isEmpty && userIds.isEmpty) return true;
      if (currentEmployeeId != null && employeeIds.contains(currentEmployeeId)) {
        return true;
      }
      if (currentUserId != null && userIds.contains(currentUserId)) {
        return true;
      }
      return false;
    }

    // 5. Targeted by Department:
    if (type == 'department' || type == 'by_department') {
      if (departmentIds.isEmpty) return true;
      if (currentDepartmentId != null && departmentIds.contains(currentDepartmentId)) {
        return true;
      }
      return false;
    }

    // 6. Targeted by Job Position:
    if (type == 'job_position' || type == 'by_job' || type == 'job') {
      if (jobIds.isEmpty) return true;
      if (currentJobId != null && jobIds.contains(currentJobId)) {
        return true;
      }
      return false;
    }

    // 7. If employee_ids has entries and current user's employeeId doesn't match:
    if (employeeIds.isNotEmpty && currentEmployeeId != null) {
      return employeeIds.contains(currentEmployeeId);
    }

    return true;
  }

  // Get plain text content from HTML body
  String get plainContent {
    if (content.isEmpty) return '';
    // Basic regex to strip HTML tags for preview snippet
    final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return content.replaceAll(exp, '').trim();
  }

  bool get isVacationAnnouncement {
    final t = title.toLowerCase();
    final c = plainContent.toLowerCase();
    return t.contains('vacation') || t.contains('holiday') || t.contains('leave') || t.contains('trip') ||
           c.contains('vacation') || c.contains('holiday') || c.contains('leave') || c.contains('trip');
  }

  bool get isWarningAnnouncement {
    final t = title.toLowerCase();
    final c = plainContent.toLowerCase();
    return t.contains('warning') || t.contains('alert') || t.contains('critical') || t.contains('urgent') || t.contains('attention') ||
           c.contains('warning') || c.contains('alert') || c.contains('critical') || c.contains('urgent') || c.contains('attention');
  }
}
