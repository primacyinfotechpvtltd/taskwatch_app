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
  final String state; // draft, to_approve, approved, rejected, cancel, expired
  final String author;
  final String createDate;

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
    required this.state,
    required this.author,
    required this.createDate,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    // Handle create_uid many2one
    final createUidVal = json['create_uid'];
    String authorName = 'System';
    if (createUidVal is List && createUidVal.length >= 2) {
      authorName = createUidVal[1].toString();
    }

    // Handle birthday_employee_id many2one
    final birthdayEmployeeVal = json['birthday_employee_id'];
    String birthdayEmployeeName = '';
    if (birthdayEmployeeVal is List && birthdayEmployeeVal.length >= 2) {
      birthdayEmployeeName = birthdayEmployeeVal[1].toString();
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
      state: safeString(json['state']).isNotEmpty ? safeString(json['state']) : 'draft',
      author: authorName,
      createDate: safeString(json['create_date']),
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
    };
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
