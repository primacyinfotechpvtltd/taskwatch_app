import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/controllers/discuss_controller.dart';

class EmployeeHierarchyData {
  final int id;
  final String name;
  final String? jobTitle;
  final String? departmentName;
  final int? departmentId;
  final int? managerId;
  final String? managerName;
  final String? workEmail;
  final String? workPhone;
  final String? mobilePhone;
  final int? userId;
  final List<int> childIds;
  final List<EmployeeHierarchyData> subordinates;

  EmployeeHierarchyData({
    required this.id,
    required this.name,
    this.jobTitle,
    this.departmentName,
    this.departmentId,
    this.managerId,
    this.managerName,
    this.workEmail,
    this.workPhone,
    this.mobilePhone,
    this.userId,
    this.childIds = const [],
    this.subordinates = const [],
  });

  factory EmployeeHierarchyData.fromJson(Map<String, dynamic> json) {
    int? depId;
    String? depName;
    if (json['department_id'] is List && (json['department_id'] as List).isNotEmpty) {
      depId = json['department_id'][0] as int?;
      depName = json['department_id'][1]?.toString();
    }

    int? mgrId;
    String? mgrName;
    if (json['parent_id'] is List && (json['parent_id'] as List).isNotEmpty) {
      mgrId = json['parent_id'][0] as int?;
      mgrName = json['parent_id'][1]?.toString();
    }

    int? uId;
    if (json['user_id'] is List && (json['user_id'] as List).isNotEmpty) {
      uId = json['user_id'][0] as int?;
    } else if (json['user_id'] is int) {
      uId = json['user_id'];
    }

    List<int> children = [];
    if (json['child_ids'] is List) {
      children = (json['child_ids'] as List).whereType<int>().toList();
    }

    return EmployeeHierarchyData(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Unknown Employee',
      jobTitle: json['job_title']?.toString(),
      departmentId: depId,
      departmentName: depName,
      managerId: mgrId,
      managerName: mgrName,
      workEmail: json['work_email']?.toString(),
      workPhone: json['work_phone']?.toString(),
      mobilePhone: json['mobile_phone']?.toString(),
      userId: uId,
      childIds: children,
    );
  }

  EmployeeHierarchyData copyWith({
    List<EmployeeHierarchyData>? subordinates,
  }) {
    return EmployeeHierarchyData(
      id: id,
      name: name,
      jobTitle: jobTitle,
      departmentId: departmentId,
      departmentName: departmentName,
      managerId: managerId,
      managerName: managerName,
      workEmail: workEmail,
      workPhone: workPhone,
      mobilePhone: mobilePhone,
      userId: userId,
      childIds: childIds,
      subordinates: subordinates ?? this.subordinates,
    );
  }
}

class UserProfileHierarchyDialog extends StatefulWidget {
  final int? userId;
  final int? partnerId;
  final int? employeeId;
  final String? initialName;
  final String? initialEmail;
  final String? initialRole;

  const UserProfileHierarchyDialog({
    super.key,
    this.userId,
    this.partnerId,
    this.employeeId,
    this.initialName,
    this.initialEmail,
    this.initialRole,
  });

  static Future<void> show(
    BuildContext context, {
    int? userId,
    int? partnerId,
    int? employeeId,
    String? initialName,
    String? initialEmail,
    String? initialRole,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UserProfileHierarchyDialog(
        userId: userId,
        partnerId: partnerId,
        employeeId: employeeId,
        initialName: initialName,
        initialEmail: initialEmail,
        initialRole: initialRole,
      ),
    );
  }

  @override
  State<UserProfileHierarchyDialog> createState() =>
      _UserProfileHierarchyDialogState();
}

class _UserProfileHierarchyDialogState
    extends State<UserProfileHierarchyDialog> {
  bool _isLoading = true;
  EmployeeHierarchyData? _employeeData;
  late int? _currentUserId;
  late int? _currentPartnerId;
  late int? _currentEmployeeId;
  late String _displayName;
  late String _displayEmail;
  late String? _displayRole;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userId;
    _currentPartnerId = widget.partnerId;
    _currentEmployeeId = widget.employeeId;
    _displayName = widget.initialName ?? 'User Profile';
    _displayEmail = widget.initialEmail ?? '';
    _displayRole = widget.initialRole;
    _fetchEmployeeHierarchy();
  }

  Future<void> _fetchEmployeeHierarchy() async {
    setState(() => _isLoading = true);

    try {
      // 1. Query hr.employee record
      List<dynamic> domain = [];
      if (_currentEmployeeId != null && _currentEmployeeId! > 0) {
        domain = [['id', '=', _currentEmployeeId]];
      } else if (_currentUserId != null && _currentUserId! > 0) {
        domain = [['user_id', '=', _currentUserId]];
      } else if (_currentPartnerId != null && _currentPartnerId! > 0) {
        domain = [['address_home_id', '=', _currentPartnerId]];
      }

      final fields = [
        'id',
        'name',
        'job_title',
        'department_id',
        'parent_id',
        'work_email',
        'work_phone',
        'mobile_phone',
        'user_id',
        'child_ids',
      ];

      var empRes = domain.isNotEmpty
          ? await OdooRpcApiManager.searchRead(
              model: 'hr.employee',
              domain: domain,
              fields: fields,
              limit: 1,
            )
          : null;

      // Fallback by work_email if empty
      if ((empRes == null || !empRes.isSuccess || empRes.data == null || empRes.data!.isEmpty) &&
          _displayEmail.isNotEmpty) {
        empRes = await OdooRpcApiManager.searchRead(
          model: 'hr.employee',
          domain: [['work_email', '=', _displayEmail]],
          fields: fields,
          limit: 1,
        );
      }

      // Fallback by name if still empty
      if ((empRes == null || !empRes.isSuccess || empRes.data == null || empRes.data!.isEmpty) &&
          _displayName.isNotEmpty &&
          _displayName != 'User Profile') {
        empRes = await OdooRpcApiManager.searchRead(
          model: 'hr.employee',
          domain: [['name', 'ilike', _displayName]],
          fields: fields,
          limit: 1,
        );
      }

      if (empRes != null && empRes.isSuccess && empRes.data != null && empRes.data!.isNotEmpty) {
        var emp = EmployeeHierarchyData.fromJson(
          Map<String, dynamic>.from(empRes.data!.first),
        );

        _displayName = emp.name;
        if (emp.workEmail != null && emp.workEmail!.isNotEmpty) {
          _displayEmail = emp.workEmail!;
        }
        if (emp.jobTitle != null && emp.jobTitle!.isNotEmpty) {
          _displayRole = emp.jobTitle;
        }
        if (emp.userId != null) {
          _currentUserId = emp.userId;
        }

        // Fetch subordinates if any
        if (emp.childIds.isNotEmpty) {
          try {
            final subRes = await OdooRpcApiManager.searchRead(
              model: 'hr.employee',
              domain: [
                ['id', 'in', emp.childIds],
              ],
              fields: ['id', 'name', 'job_title', 'work_email', 'user_id', 'department_id'],
              limit: 15,
            );
            if (subRes.isSuccess && subRes.data != null) {
              final subList = subRes.data!
                  .map((e) => EmployeeHierarchyData.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
              emp = emp.copyWith(subordinates: subList);
            }
          } catch (e) {
            debugPrint('SUBORDINATES_FETCH_ERROR: $e');
          }
        }

        _employeeData = emp;
      }
    } catch (e) {
      debugPrint('HIERARCHY_FETCH_ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEmployee(int empId, String name) {
    setState(() {
      _currentEmployeeId = empId;
      _currentUserId = null;
      _currentPartnerId = null;
      _displayName = name;
      _displayEmail = '';
      _displayRole = null;
    });
    _fetchEmployeeHierarchy();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().user.value
        : null;
    final isSelf = currentUser != null &&
        (_currentUserId == currentUser.userId ||
            (_displayEmail.isNotEmpty && _displayEmail == currentUser.email));

    final nameHash = _displayName.hashCode.abs();
    final avatarColors = [
      const Color(0xFFE2165F),
      const Color(0xFF006D37),
      const Color(0xFF0F52BA),
      const Color(0xFFD4AF37),
      const Color(0xFF8A2BE2),
      const Color(0xFFE65C00),
    ];
    final avatarColor = avatarColors[nameHash % avatarColors.length];

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          children: [
            // Header Bar with Close Button
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Employee Profile & Hierarchy',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF25181E),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile Header Card
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.25),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(44),
                              child: _currentUserId != null && _currentUserId! > 0
                                  ? OdooNetworkImage(
                                      model: 'res.users',
                                      id: _currentUserId!,
                                      field: 'image_256',
                                      placeholder: Container(
                                        color: avatarColor.withOpacity(0.15),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _displayName.isNotEmpty
                                              ? _displayName[0].toUpperCase()
                                              : 'U',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: avatarColor,
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      errorWidget: Container(
                                        color: avatarColor.withOpacity(0.15),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _displayName.isNotEmpty
                                              ? _displayName[0].toUpperCase()
                                              : 'U',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: avatarColor,
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  : (_currentPartnerId != null && _currentPartnerId! > 0
                                      ? OdooNetworkImage(
                                          model: 'res.partner',
                                          id: _currentPartnerId!,
                                          field: 'image_256',
                                          placeholder: Container(
                                            color: avatarColor.withOpacity(0.15),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _displayName.isNotEmpty
                                                  ? _displayName[0].toUpperCase()
                                                  : 'U',
                                              style: GoogleFonts.spaceGrotesk(
                                                color: avatarColor,
                                                fontSize: 34,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: avatarColor.withOpacity(0.15),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _displayName.isNotEmpty
                                                ? _displayName[0].toUpperCase()
                                                : 'U',
                                            style: GoogleFonts.spaceGrotesk(
                                              color: avatarColor,
                                              fontSize: 34,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _displayName,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF25181E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_displayRole != null && _displayRole!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF714B67).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _displayRole!,
                                style: const TextStyle(
                                  color: Color(0xFF714B67),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (_employeeData?.departmentName != null &&
                              _employeeData!.departmentName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _employeeData!.departmentName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        ),
                      )
                    else ...[
                      // Contact Information Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9FB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact Details',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_displayEmail.isNotEmpty)
                              _buildInfoRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: _displayEmail,
                                onAction: () {
                                  Clipboard.setData(ClipboardData(text: _displayEmail));
                                  showToast('Email copied to clipboard', idSuccess: true);
                                },
                                actionIcon: Icons.copy_rounded,
                              ),
                            if (_employeeData?.workPhone != null &&
                                _employeeData!.workPhone!.isNotEmpty)
                              _buildInfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Work Phone',
                                value: _employeeData!.workPhone!,
                                onAction: () => launchUrl(
                                    Uri.parse('tel:${_employeeData!.workPhone}')),
                                actionIcon: Icons.phone_forwarded_rounded,
                              ),
                            if (_employeeData?.mobilePhone != null &&
                                _employeeData!.mobilePhone!.isNotEmpty)
                              _buildInfoRow(
                                icon: Icons.phone_android_rounded,
                                label: 'Mobile',
                                value: _employeeData!.mobilePhone!,
                                onAction: () => launchUrl(
                                    Uri.parse('tel:${_employeeData!.mobilePhone}')),
                                actionIcon: Icons.phone_forwarded_rounded,
                              ),
                            if (_currentUserId != null && _currentUserId! > 0)
                              _buildInfoRow(
                                icon: Icons.fingerprint_rounded,
                                label: 'User ID',
                                value: _currentUserId.toString(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Reporting Hierarchy Tree
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_tree_rounded,
                                    size: 16, color: Color(0xFF714B67)),
                                const SizedBox(width: 6),
                                Text(
                                  'Organization Hierarchy',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF25181E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Manager Node
                            if (_employeeData?.managerId != null &&
                                _employeeData?.managerName != null) ...[
                              Text(
                                'REPORTS TO (MANAGER)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _navigateToEmployee(
                                  _employeeData!.managerId!,
                                  _employeeData!.managerName!,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E5F5).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF714B67).withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFF714B67).withOpacity(0.2),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: OdooNetworkImage(
                                            model: 'hr.employee',
                                            id: _employeeData!.managerId!,
                                            field: 'image_128',
                                            placeholder: Text(
                                              _employeeData!.managerName!.isNotEmpty
                                                  ? _employeeData!.managerName![0].toUpperCase()
                                                  : 'M',
                                              style: const TextStyle(
                                                color: Color(0xFF714B67),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _employeeData!.managerName!,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF25181E),
                                              ),
                                            ),
                                            const Text(
                                              'Reporting Manager',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF714B67),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded,
                                          size: 12, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Current User Node
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF714B67).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF714B67)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF714B67),
                                    child: Text(
                                      _displayName.isNotEmpty
                                          ? _displayName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$_displayName (Current)',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF714B67),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Subordinates Node
                            if (_employeeData != null &&
                                _employeeData!.subordinates.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                'DIRECT REPORTS (${_employeeData!.subordinates.length})',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...List.generate(_employeeData!.subordinates.length, (idx) {
                                final sub = _employeeData!.subordinates[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    onTap: () => _navigateToEmployee(sub.id, sub.name),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9F9FB),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor:
                                                avatarColors[idx % avatarColors.length]
                                                    .withOpacity(0.2),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: OdooNetworkImage(
                                                model: 'hr.employee',
                                                id: sub.id,
                                                field: 'image_128',
                                                placeholder: Text(
                                                  sub.name.isNotEmpty
                                                      ? sub.name[0].toUpperCase()
                                                      : 'E',
                                                  style: TextStyle(
                                                    color: avatarColors[idx % avatarColors.length],
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sub.name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                if (sub.jobTitle != null &&
                                                    sub.jobTitle!.isNotEmpty)
                                                  Text(
                                                    sub.jobTitle!,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_ios_rounded,
                                              size: 10, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (!isSelf &&
                      Get.isRegistered<DiscussController>() &&
                      (_currentPartnerId != null || _currentUserId != null)) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        final discuss = Get.find<DiscussController>();
                        final targetPartnerId = _currentPartnerId ??
                            _employeeData?.userId ??
                            _currentUserId;
                        if (targetPartnerId != null) {
                          discuss.startDirectChat(targetPartnerId, _displayName);
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 14, color: Colors.white),
                      label: Text(
                        'Direct Message',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF714B67),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onAction,
    IconData? actionIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onAction != null && actionIcon != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(actionIcon, size: 14, color: AppTheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
