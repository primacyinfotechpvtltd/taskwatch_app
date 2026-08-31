import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pi_task_watch/controllers/auth_controller.dart';
import 'package:pi_task_watch/controllers/project_controller.dart';
import 'package:pi_task_watch/controllers/task_controller.dart';
import 'package:pi_task_watch/managers/api_manager.dart';
import 'package:pi_task_watch/managers/odoo_rpc_api_manager.dart';
import 'package:pi_task_watch/models/project_model.dart';
import 'package:pi_task_watch/models/task_details_model.dart';
import 'package:pi_task_watch/models/task_model.dart';
import 'package:pi_task_watch/screens/task_detail_screen.dart';
import 'package:pi_task_watch/theme/app_theme.dart';
import 'package:pi_task_watch/utils/duration_utils.dart';
import 'package:pi_task_watch/utils/format_utils.dart';
import 'package:pi_task_watch/widgets/compact_text_field.dart';
import 'package:pi_task_watch/widgets/searchable_dropdown.dart';

enum TaskDialogMode { createNew, editExisting }

class AddTaskDialog extends StatefulWidget {
  final int? initialProjectId;
  final TaskModel? initialTask;

  const AddTaskDialog({
    super.key,
    this.initialProjectId,
    this.initialTask,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final ProjectController _projectController = Get.find<ProjectController>();
  final TaskController _taskController = Get.find<TaskController>();
  final AuthController _authController = Get.find<AuthController>();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _projectSearchController = TextEditingController();
  final TextEditingController _taskSearchController = TextEditingController();

  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;

  List<TaskModel> _projectTasks = [];
  TaskModel? _selectedTask;
  TaskDialogMode _dialogMode = TaskDialogMode.createNew;

  DateTime? _selectedStartDate;
  DateTime? _selectedDeadline;
  String _displayedAllocatedTime = '00:00';

  // "Assigned By" state (The person in Odoo who assigned/created this task)
  int? _assignedById;
  int? _assignedByEmployeeId;
  int? _assignedByPartnerId;
  String _assignedByName = '';
  String _assignedByEmail = '';
  String? _assignedByAvatarBase64;
  String? _assignedByAvatarUrl;

  // Logged-in user avatar state
  String? _loggedInUserAvatarBase64;
  String? _loggedInUserAvatarUrl;

  bool _isLoadingProjects = true;
  bool _isLoadingTasks = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchLoggedInUserAvatar();
    _loadProjects();
  }

  Future<void> _fetchLoggedInUserAvatar() async {
    final currentUser = _authController.user.value;
    if (currentUser == null) return;
    final uid = currentUser.userId;

    if (currentUser.imageUrl != null && currentUser.imageUrl!.isNotEmpty) {
      if (currentUser.imageUrl!.startsWith('http')) {
        setState(() => _loggedInUserAvatarUrl = currentUser.imageUrl);
      } else {
        setState(() => _loggedInUserAvatarBase64 = currentUser.imageUrl);
      }
    }

    if (uid <= 0) return;

    // 1. Fetch from res.users
    try {
      final userRes = await OdooRpcApiManager.searchRead(
        model: 'res.users',
        domain: [
          ['id', '=', uid]
        ],
        fields: ['id', 'image_128', 'avatar_128', 'image_512', 'image_1920', 'partner_id'],
        limit: 1,
      );
      if (userRes.isSuccess &&
          userRes.data is List &&
          (userRes.data as List).isNotEmpty &&
          mounted) {
        final uData = (userRes.data as List).first as Map<String, dynamic>;
        for (final f in ['image_128', 'avatar_128', 'image_512', 'image_1920']) {
          final val = uData[f];
          if (val is String && val.trim().isNotEmpty && val.trim() != 'false') {
            setState(() => _loggedInUserAvatarBase64 = val.trim());
            return;
          }
        }
      }
    } catch (_) {}

    // 2. Fetch from hr.employee
    try {
      final empRes = await OdooRpcApiManager.searchRead(
        model: 'hr.employee',
        domain: [
          ['user_id', '=', uid]
        ],
        fields: ['id', 'image_128', 'avatar_128', 'image_512', 'image_1920'],
        limit: 1,
      );
      if (empRes.isSuccess &&
          empRes.data is List &&
          (empRes.data as List).isNotEmpty &&
          mounted) {
        final eData = (empRes.data as List).first as Map<String, dynamic>;
        for (final f in ['image_128', 'avatar_128', 'image_512', 'image_1920']) {
          final val = eData[f];
          if (val is String && val.trim().isNotEmpty && val.trim() != 'false') {
            setState(() => _loggedInUserAvatarBase64 = val.trim());
            return;
          }
        }
      }
    } catch (_) {}

    // 3. Fallback via fetchImageBytes
    try {
      final bytes = await OdooRpcApiManager.fetchImageBytes(
        model: 'res.users',
        id: uid,
        field: 'image_128',
      );
      if (bytes != null && bytes.isNotEmpty && mounted) {
        setState(() => _loggedInUserAvatarBase64 = base64Encode(bytes));
      }
    } catch (_) {}
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoadingProjects = true);
    try {
      final projects = await _projectController.getAllProject();
      if (!mounted) return;

      setState(() {
        _projects = projects;
        final targetProjectId =
            widget.initialTask?.projectId ?? widget.initialProjectId;
        if (targetProjectId != null) {
          _selectedProject = _projects.firstWhereOrNull(
            (p) => p.id == targetProjectId,
          );
        }
        if (_selectedProject == null && _projects.isNotEmpty) {
          _selectedProject = _projects.first;
        }
      });

      if (_selectedProject != null) {
        await _loadTasksForProject(_selectedProject!.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _projects = []);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProjects = false);
      }
    }
  }

  Future<void> _loadTasksForProject(int projectId) async {
    if (!mounted) return;
    setState(() => _isLoadingTasks = true);

    try {
      final tasks = await _taskController.getTaskList(projectId: projectId);
      if (!mounted) return;

      setState(() {
        _projectTasks = tasks;
        if (widget.initialTask != null &&
            _projectTasks.any((t) => t.id == widget.initialTask!.id)) {
          _selectedTask = _projectTasks.firstWhere(
            (t) => t.id == widget.initialTask!.id,
          );
          _dialogMode = TaskDialogMode.editExisting;
          _populateFieldsFromTask(_selectedTask!);
        } else if (_projectTasks.isNotEmpty) {
          _selectedTask = _projectTasks.first;
          _dialogMode = TaskDialogMode.editExisting;
          _populateFieldsFromTask(_selectedTask!);
        } else {
          _selectedTask = null;
          _dialogMode = TaskDialogMode.createNew;
          _resetFields();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _projectTasks = [];
          _selectedTask = null;
          _dialogMode = TaskDialogMode.createNew;
          _resetFields();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
      }
    }
  }

  void _populateFieldsFromTask(TaskModel task) {
    _taskNameController.text = task.name;
    _descriptionController.text = FormatUtils.cleanHtml(task.description);
    _selectedStartDate = task.getStartDateTime();
    _selectedDeadline = task.getEndDateTime();

    final formattedTime = task.getFormattedAllocatedTime();
    _displayedAllocatedTime = formattedTime.isNotEmpty ? formattedTime : '00:00';
    _hoursController.text = _displayedAllocatedTime;

    // 1. Initial resolution of "Assigned By" from task model getters
    _assignedById = task.createUid;
    _assignedByName = task.createUserName ?? '';
    _assignedByEmail = '';
    _assignedByAvatarBase64 = null;
    _assignedByAvatarUrl = null;
    _assignedByEmployeeId = null;
    _assignedByPartnerId = null;

    if (_assignedById != null && _assignedById! > 0) {
      _fetchUserEmail(_assignedById!);
    } else if (_assignedByName.isNotEmpty) {
      _fetchUserByName(_assignedByName);
    }

    // 2. Enrich task data asynchronously from both REST API and Odoo RPC
    _fetchFullTaskDetails(task.id);
  }

  Future<void> _fetchFullTaskDetails(int taskId) async {
    // 1. Try REST API endpoint 'tasks/$taskId'
    try {
      final apiRes = await ApiManager.getRequest(endPoint: 'tasks/$taskId');
      if (apiRes.isSuccess && apiRes.data != null && mounted) {
        final m = apiRes.data is Map ? Map<String, dynamic>.from(apiRes.data) : null;
        if (m != null) {
          if (m['description'] != null &&
              m['description'] != false) {
            final desc = m['description'].toString();
            if (desc.isNotEmpty && desc != 'false') {
              final clean = FormatUtils.cleanHtml(desc);
              setState(() => _descriptionController.text = clean);
            }
          }

          if (m['create_uid'] != null && m['create_uid'] != false) {
            if (m['create_uid'] is List && (m['create_uid'] as List).isNotEmpty) {
              final uid = (m['create_uid'] as List)[0] is int
                  ? (m['create_uid'] as List)[0]
                  : int.tryParse((m['create_uid'] as List)[0].toString());
              final uName = (m['create_uid'] as List).length > 1
                  ? (m['create_uid'] as List)[1].toString()
                  : '';
              if (uid != null && uid > 0) _assignedById = uid;
              if (uName.isNotEmpty && uName != 'false') {
                setState(() => _assignedByName = uName);
              }
            } else if (m['create_uid'] is Map) {
              final uid = m['create_uid']['id'] is int
                  ? m['create_uid']['id']
                  : int.tryParse(m['create_uid']['id'].toString());
              final uName = (m['create_uid']['name'] ??
                      m['create_uid']['display_name'])
                  ?.toString();
              if (uid != null && uid > 0) _assignedById = uid;
              if (uName != null && uName.isNotEmpty && uName != 'false') {
                setState(() => _assignedByName = uName);
              }
            }
          }

          if (_assignedByName.isEmpty) {
            final possibleName = (m['created_by'] ??
                    m['create_user_name'] ??
                    m['assigned_by'] ??
                    m['author_name'])
                ?.toString();
            if (possibleName != null &&
                possibleName.isNotEmpty &&
                possibleName != 'false') {
              setState(() => _assignedByName = possibleName);
            }
          }

          // Image URL if provided by REST API
          final img = m['image_url'] ?? m['avatar_url'] ?? m['created_by_image'];
          if (img is String && img.isNotEmpty && img.startsWith('http')) {
            setState(() => _assignedByAvatarUrl = img);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting task details from API: $e');
    }

    // 2. Try Odoo RPC searchRead
    try {
      final res = await OdooRpcApiManager.searchRead(
        model: 'project.task',
        domain: [
          ['id', '=', taskId]
        ],
        fields: [
          'id',
          'name',
          'description',
          'user_ids',
          'create_uid',
          'create_date',
          'date_start',
          'date_deadline',
          'allocated_hours',
        ],
        limit: 1,
      );

      if (res.isSuccess &&
          res.data is List &&
          (res.data as List).isNotEmpty &&
          mounted) {
        final data = (res.data as List).first as Map<String, dynamic>;

        // Update description
        if (data['description'] != null && data['description'] != false) {
          final desc = data['description'].toString();
          if (desc.isNotEmpty && desc != 'false') {
            final clean = FormatUtils.cleanHtml(desc);
            setState(() => _descriptionController.text = clean);
          }
        }

        // Update dates
        if (data['date_start'] != null && data['date_start'] != false) {
          final start = DateTime.tryParse(data['date_start'].toString());
          if (start != null) {
            setState(() => _selectedStartDate = start.toLocal());
          }
        }
        if (data['date_deadline'] != null && data['date_deadline'] != false) {
          final deadline =
              DateTime.tryParse(data['date_deadline'].toString());
          if (deadline != null) {
            setState(() => _selectedDeadline = deadline.toLocal());
          }
        }

        // Update allocated hours
        if (data['allocated_hours'] is num) {
          final hours = (data['allocated_hours'] as num).toDouble();
          final duration = Duration(minutes: (hours * 60).round());
          final formatted = DurationUtils.formatDuration(duration);
          setState(() {
            _displayedAllocatedTime = formatted;
            _hoursController.text = formatted;
          });
        }

        // Update "Assigned By" (create_uid)
        if (data['create_uid'] != null && data['create_uid'] != false) {
          if (data['create_uid'] is List &&
              (data['create_uid'] as List).isNotEmpty) {
            final uid = (data['create_uid'] as List)[0] is int
                ? (data['create_uid'] as List)[0]
                : int.tryParse((data['create_uid'] as List)[0].toString());
            final uName = (data['create_uid'] as List).length > 1
                ? (data['create_uid'] as List)[1].toString()
                : '';
            setState(() {
              if (uid != null) _assignedById = uid;
              if (uName.isNotEmpty && uName != 'false') {
                _assignedByName = uName;
              }
            });
            if (uid != null && uid > 0) {
              _fetchUserEmail(uid);
            }
          } else if (data['create_uid'] is int) {
            setState(() {
              _assignedById = data['create_uid'];
            });
            _fetchUserEmail(data['create_uid']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching full task details from Odoo: $e');
    }

    // 3. If still empty, query mail.message (chatter) for the initial task creation author
    if (_assignedByName.isEmpty || _assignedById == null) {
      try {
        final msgRes = await OdooRpcApiManager.searchRead(
          model: 'mail.message',
          domain: [
            ['model', '=', 'project.task'],
            ['res_id', '=', taskId],
          ],
          fields: ['author_id', 'date', 'body', 'subtype_id'],
          order: 'date asc, id asc',
          limit: 1,
        );

        if (msgRes.isSuccess &&
            msgRes.data is List &&
            (msgRes.data as List).isNotEmpty &&
            mounted) {
          final firstMsg =
              (msgRes.data as List).first as Map<String, dynamic>;
          final author = firstMsg['author_id'];
          if (author is List && author.isNotEmpty) {
            final uid = author[0] is int
                ? author[0]
                : int.tryParse(author[0].toString());
            final uName = author.length > 1 ? author[1].toString() : '';
            setState(() {
              if (uid != null) _assignedById = uid;
              if (uName.isNotEmpty && uName != 'false') {
                _assignedByName = uName;
              }
            });
            if (uid != null && uid > 0) {
              _fetchUserEmail(uid);
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting mail.message author: $e');
      }
    }

    // 4. If still empty, query activities from REST API
    if (_assignedByName.isEmpty) {
      try {
        final actRes =
            await ApiManager.getRequest(endPoint: 'tasks/$taskId/activities');
        if (actRes.isSuccess &&
            actRes.data is List &&
            (actRes.data as List).isNotEmpty &&
            mounted) {
          final firstAct = (actRes.data as List).first;
          if (firstAct is Map && firstAct['author_name'] != null) {
            final uName = firstAct['author_name'].toString();
            if (uName.isNotEmpty && uName != 'false') {
              setState(() {
                _assignedByName = uName;
                if (firstAct['author_id'] != null) {
                  _assignedById = firstAct['author_id'] is int
                      ? firstAct['author_id']
                      : int.tryParse(firstAct['author_id'].toString());
                }
              });
              if (_assignedById != null && _assignedById! > 0) {
                _fetchUserEmail(_assignedById!);
              }
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchUserByName(String name) async {
    if (name.isEmpty) return;
    try {
      final userRes = await OdooRpcApiManager.searchRead(
        model: 'res.users',
        domain: [
          ['name', 'ilike', name.trim()]
        ],
        fields: [
          'id',
          'name',
          'display_name',
          'email',
          'login',
          'image_128',
          'image_1920',
          'avatar_128',
          'partner_id'
        ],
        limit: 1,
      );
      if (userRes.isSuccess &&
          userRes.data is List &&
          (userRes.data as List).isNotEmpty &&
          mounted) {
        final userData = (userRes.data as List).first as Map<String, dynamic>;
        final uid = userData['id'] is int
            ? userData['id']
            : int.tryParse(userData['id'].toString());
        if (uid != null && uid > 0) {
          _fetchUserEmail(uid);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUserEmail(int userId) async {
    try {
      // 1. Fetch user record from res.users
      final userRes = await OdooRpcApiManager.searchRead(
        model: 'res.users',
        domain: [
          ['id', '=', userId]
        ],
        fields: [
          'id',
          'name',
          'display_name',
          'email',
          'login',
          'image_128',
          'image_1920',
          'avatar_128',
          'image_512',
          'partner_id',
        ],
        limit: 1,
      );

      if (userRes.isSuccess &&
          userRes.data is List &&
          (userRes.data as List).isNotEmpty &&
          mounted) {
        final userData =
            (userRes.data as List).first as Map<String, dynamic>;

        final resolvedName = (userData['name'] ??
                userData['display_name'] ??
                userData['login'])
            ?.toString()
            .trim();
        final resolvedEmail =
            (userData['email'] ?? userData['login'])?.toString().trim();

        int? partnerId;
        if (userData['partner_id'] is List &&
            (userData['partner_id'] as List).isNotEmpty) {
          final p = (userData['partner_id'] as List)[0];
          partnerId = p is int ? p : int.tryParse(p.toString());
        }

        String? avatarBase64;
        for (final field in ['image_128', 'avatar_128', 'image_512', 'image_1920']) {
          final val = userData[field];
          if (val is String &&
              val.trim().isNotEmpty &&
              val.trim() != 'false') {
            avatarBase64 = val.trim();
            break;
          }
        }

        setState(() {
          if (resolvedName != null &&
              resolvedName.isNotEmpty &&
              resolvedName != 'false') {
            _assignedByName = resolvedName;
          }
          if (resolvedEmail != null &&
              resolvedEmail.isNotEmpty &&
              resolvedEmail.contains('@')) {
            _assignedByEmail = resolvedEmail;
          }
          if (avatarBase64 != null) {
            _assignedByAvatarBase64 = avatarBase64;
          }
          if (partnerId != null) {
            _assignedByPartnerId = partnerId;
          }
        });
      }

      // 2. Query hr.employee by user_id
      try {
        final empDomain = userId > 0
            ? [
                ['user_id', '=', userId]
              ]
            : [
                ['name', 'ilike', _assignedByName]
              ];

        final empRes = await OdooRpcApiManager.searchRead(
          model: 'hr.employee',
          domain: empDomain,
          fields: [
            'id',
            'name',
            'work_email',
            'image_128',
            'avatar_128',
            'image_512',
            'image_1920',
          ],
          limit: 1,
        );

        if (empRes.isSuccess &&
            empRes.data is List &&
            (empRes.data as List).isNotEmpty &&
            mounted) {
          final empData = (empRes.data as List).first as Map<String, dynamic>;
          final empId = empData['id'] is int
              ? empData['id']
              : int.tryParse(empData['id'].toString());
          if (empId != null) {
            setState(() => _assignedByEmployeeId = empId);
          }
          if (_assignedByAvatarBase64 == null) {
            for (final field in ['image_128', 'avatar_128', 'image_512', 'image_1920']) {
              final val = empData[field];
              if (val is String &&
                  val.trim().isNotEmpty &&
                  val.trim() != 'false') {
                setState(() => _assignedByAvatarBase64 = val.trim());
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching employee record for user $userId: $e');
      }

      // 3. Query res.partner by partner_id or name
      if (_assignedByAvatarBase64 == null) {
        try {
          final partDomain = (_assignedByPartnerId != null && _assignedByPartnerId! > 0)
              ? [
                  ['id', '=', _assignedByPartnerId!]
                ]
              : [
                  ['name', 'ilike', _assignedByName]
                ];

          final partRes = await OdooRpcApiManager.searchRead(
            model: 'res.partner',
            domain: partDomain,
            fields: [
              'id',
              'name',
              'image_128',
              'avatar_128',
              'image_512',
              'image_1920',
            ],
            limit: 1,
          );

          if (partRes.isSuccess &&
              partRes.data is List &&
              (partRes.data as List).isNotEmpty &&
              mounted) {
            final pData = (partRes.data as List).first as Map<String, dynamic>;
            for (final field in ['image_128', 'avatar_128', 'image_512', 'image_1920']) {
              final val = pData[field];
              if (val is String &&
                  val.trim().isNotEmpty &&
                  val.trim() != 'false') {
                setState(() => _assignedByAvatarBase64 = val.trim());
                break;
              }
            }
          }
        } catch (_) {}
      }

      // 4. Also try fetchImageBytes if still null
      if (_assignedByAvatarBase64 == null && userId > 0) {
        try {
          final bytes = await OdooRpcApiManager.fetchImageBytes(
            model: 'res.users',
            id: userId,
            field: 'image_128',
          );
          if (bytes != null && bytes.isNotEmpty && mounted) {
            setState(() => _assignedByAvatarBase64 = base64Encode(bytes));
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error in _fetchUserEmail: $e');
    }
  }

  void _resetFields() {
    _taskNameController.clear();
    _descriptionController.clear();
    _hoursController.clear();
    _displayedAllocatedTime = '00:00';
    _selectedStartDate = null;
    _selectedDeadline = null;
    _assignedById = null;
    _assignedByEmployeeId = null;
    _assignedByPartnerId = null;
    _assignedByName = '';
    _assignedByEmail = '';
    _assignedByAvatarBase64 = null;
    _assignedByAvatarUrl = null;
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _descriptionController.dispose();
    _hoursController.dispose();
    _projectSearchController.dispose();
    _taskSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initialDate = _selectedStartDate ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null && mounted) {
      final initialTime = TimeOfDay.fromDateTime(_selectedStartDate ?? now);
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );

      setState(() {
        if (pickedTime != null) {
          _selectedStartDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        } else {
          _selectedStartDate = pickedDate;
        }
      });
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initialDate = _selectedDeadline ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null && mounted) {
      final initialTime = TimeOfDay.fromDateTime(_selectedDeadline ?? now);
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );

      setState(() {
        if (pickedTime != null) {
          _selectedDeadline = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        } else {
          _selectedDeadline = pickedDate;
        }
      });
    }
  }

  void _openFullScreenTaskDetail() {
    if (_selectedTask == null) return;
    Get.toNamed(
      TaskDetailScreen.routeName,
      arguments: TaskDetailsModel(
        id: _selectedTask!.id,
        name: _taskNameController.text.trim().isNotEmpty
            ? _taskNameController.text.trim()
            : _selectedTask!.name,
        projectId: _selectedTask!.projectId ?? _selectedProject?.id,
        projectName: _selectedTask!.projectName ?? _selectedProject?.name,
        stageId: _selectedTask!.stageId ?? 0,
        stageName: _selectedTask!.stageName,
        dateDeadline: _selectedDeadline,
        dateStart: _selectedStartDate,
        description: _descriptionController.text.trim(),
        allocatedHours: _selectedTask!.allocatedHours ?? 0.0,
      ),
    );
  }

  double? _parseAllocatedHoursInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final h = double.tryParse(parts[0]) ?? 0;
        final m = double.tryParse(parts[1]) ?? 0;
        return h + (m / 60.0);
      }
    }

    return double.tryParse(trimmed);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_selectedProject == null) {
      Get.snackbar(
        'Required',
        'Please select a project',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    final taskName = _taskNameController.text.trim();
    if (taskName.isEmpty) {
      Get.snackbar(
        'Required',
        'Please enter a task title',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_dialogMode == TaskDialogMode.editExisting && _selectedTask != null) {
        // For existing tasks, only update description & notes (time & dates are fixed)
        final success = await _taskController.updateTask(
          taskId: _selectedTask!.id,
          description: _descriptionController.text.trim(),
        );

        if (success && mounted) {
          final updatedTask = _taskController.taskList
              .firstWhereOrNull((t) => t.id == _selectedTask!.id);
          Navigator.of(context).pop(updatedTask ?? _selectedTask);
        }
      } else {
        // Creating new task
        final allocatedHours = _parseAllocatedHoursInput(_hoursController.text);

        final createdTask = await _taskController.createTask(
          name: taskName,
          projectId: _selectedProject!.id,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          deadline: _selectedDeadline,
          allocatedHours: allocatedHours,
        );

        if (createdTask != null && mounted) {
          Navigator.of(context).pop(createdTask);
        }
      }
    } catch (e) {
      // Handled inside controller
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authController.user.value;
    final loggedInUserId = currentUser?.userId ?? 0;
    final loggedInUserName = currentUser?.name ?? 'Current User';
    final loggedInUserEmail = currentUser?.email ?? '';

    final bool isEditing = _dialogMode == TaskDialogMode.editExisting;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(),

            // Content Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project Selector
                      _buildFieldLabel('Project *'),
                      const SizedBox(height: 6),
                      if (_isLoadingProjects)
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'Loading projects...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        )
                      else
                        SearchableDropdown<ProjectModel>(
                          value: _selectedProject,
                          items: _projects,
                          hint: 'Select Project',
                          height: 42,
                          searchController: _projectSearchController,
                          itemToString: (project) => project.name,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedProject = val);
                              _loadTasksForProject(val.id);
                            }
                          },
                        ),
                      const SizedBox(height: 16),

                      // If project has existing tasks, show Mode Toggle (Edit Existing vs Create New)
                      if (_selectedProject != null) ...[
                        if (_isLoadingTasks)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else if (_projectTasks.isNotEmpty) ...[
                          _buildModeSelector(),
                          const SizedBox(height: 16),

                          // If in Edit Existing mode, show task selector dropdown & EYE button
                          if (isEditing) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFieldLabel('Select Existing Task in Project *'),
                                ),
                                if (_selectedTask != null) ...[
                                  Tooltip(
                                    message: 'View full task details fullscreen',
                                    child: InkWell(
                                      onTap: _openFullScreenTaskDetail,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: AppTheme.primary.withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.visibility_rounded,
                                          size: 15,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            SearchableDropdown<TaskModel>(
                              value: _selectedTask,
                              items: _projectTasks,
                              hint: 'Select Task to View/Edit',
                              height: 42,
                              searchController: _taskSearchController,
                              itemToString: (task) =>
                                  '${task.name} (${task.stageName ?? 'Stage'})',
                              onChanged: (task) {
                                if (task != null) {
                                  setState(() {
                                    _selectedTask = task;
                                    _populateFieldsFromTask(task);
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No existing tasks found in this project. Creating a new task.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],

                      // Task Title
                      _buildFieldLabel(
                        isEditing ? 'Task Title' : 'Task Title *',
                      ),
                      const SizedBox(height: 6),
                      if (isEditing)
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _taskNameController.text.isNotEmpty
                                      ? _taskNameController.text
                                      : (_selectedTask?.name ?? 'Task'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Tooltip(
                                message: 'Task title is fixed for existing tasks.',
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        CompactTextField(
                          controller: _taskNameController,
                          hintText: 'Enter task title...',
                          prefixIcon: Icon(
                            Icons.edit_note_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Assigned By Section (The person who assigned the task to you in Odoo)
                      _buildFieldLabel('Assigned By'),
                      const SizedBox(height: 6),
                      _buildAssignedByCard(
                        isEditing: isEditing,
                        loggedInUserId: loggedInUserId,
                        loggedInUserName: loggedInUserName,
                        loggedInUserEmail: loggedInUserEmail,
                        loggedInUserAvatarUrl: _loggedInUserAvatarUrl ?? currentUser?.imageUrl,
                        loggedInUserAvatarBase64: _loggedInUserAvatarBase64,
                      ),
                      const SizedBox(height: 16),

                      // Start Time & End Time (2 fields in a row) - Read-only / Locked for existing tasks
                      Row(
                        children: [
                          // Start Time
                          Expanded(
                            child: _buildTimePickerField(
                              label: 'Start Time',
                              icon: Icons.play_circle_outline_rounded,
                              dateTime: _selectedStartDate,
                              hintText: 'Set start time',
                              onTap: isEditing ? null : _pickStartDate,
                              onClear: isEditing
                                  ? null
                                  : () => setState(() => _selectedStartDate = null),
                              isReadOnly: isEditing,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // End Time / Deadline
                          Expanded(
                            child: _buildTimePickerField(
                              label: 'End Time',
                              icon: Icons.alarm_rounded,
                              dateTime: _selectedDeadline,
                              hintText: 'Set end time',
                              onTap: isEditing ? null : _pickDeadline,
                              onClear: isEditing
                                  ? null
                                  : () => setState(() => _selectedDeadline = null),
                              isReadOnly: isEditing,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Allocated Time (Erase '(Hours)' text, show '00:00') - Read-only / Locked for existing tasks
                      _buildFieldLabel('Allocated Time'),
                      const SizedBox(height: 6),
                      if (isEditing)
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _displayedAllocatedTime.isNotEmpty
                                      ? _displayedAllocatedTime
                                      : '00:00',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Tooltip(
                                message:
                                    'Allocated time is fixed for existing tasks and cannot be modified.',
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        CompactTextField(
                          controller: _hoursController,
                          hintText: '00:00 (e.g. 01:30 or 2.5)',
                          prefixIcon: Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Description & Notes (Editable for both existing and new tasks)
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldLabel('Task Description & Notes'),
                          ),
                          if (isEditing)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                'Editable',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: TextField(
                          controller: _descriptionController,
                          maxLines: 5,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Add or update description, details, and notes for this task...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required IconData icon,
    required DateTime? dateTime,
    required String hintText,
    required VoidCallback? onTap,
    required VoidCallback? onClear,
    bool isReadOnly = false,
  }) {
    final hasValue = dateTime != null;
    final formatted = hasValue
        ? DateFormat('dd MMM yyyy, hh:mm a').format(dateTime)
        : (isReadOnly ? 'Not set' : hintText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: isReadOnly ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isReadOnly ? Colors.grey.shade100 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isReadOnly ? Colors.grey.shade300 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isReadOnly ? Colors.grey.shade600 : AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          hasValue ? FontWeight.w600 : FontWeight.normal,
                      color: hasValue ? Colors.black87 : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isReadOnly)
                  Tooltip(
                    message:
                        '$label is fixed for existing tasks and cannot be modified.',
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  )
                else if (hasValue && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.close,
                        size: 15,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _dialogMode = TaskDialogMode.editExisting;
                  if (_selectedTask != null) {
                    _populateFieldsFromTask(_selectedTask!);
                  } else if (_projectTasks.isNotEmpty) {
                    _selectedTask = _projectTasks.first;
                    _populateFieldsFromTask(_selectedTask!);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _dialogMode == TaskDialogMode.editExisting
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _dialogMode == TaskDialogMode.editExisting
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: 16,
                      color: _dialogMode == TaskDialogMode.editExisting
                          ? AppTheme.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Existing Tasks (${_projectTasks.length})',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _dialogMode == TaskDialogMode.editExisting
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _dialogMode == TaskDialogMode.editExisting
                            ? AppTheme.primary
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _dialogMode = TaskDialogMode.createNew;
                  _resetFields();
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _dialogMode == TaskDialogMode.createNew
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _dialogMode == TaskDialogMode.createNew
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: _dialogMode == TaskDialogMode.createNew
                          ? AppTheme.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Create New Task',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _dialogMode == TaskDialogMode.createNew
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _dialogMode == TaskDialogMode.createNew
                            ? AppTheme.primary
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedByCard({
    required bool isEditing,
    required int loggedInUserId,
    required String loggedInUserName,
    required String loggedInUserEmail,
    String? loggedInUserAvatarUrl,
    String? loggedInUserAvatarBase64,
  }) {
    if (!isEditing) {
      // In Create New mode: You are creating & assigning this task
      return _buildPersonCard(
        userId: loggedInUserId,
        name: loggedInUserName,
        email: loggedInUserEmail,
        avatarBase64: loggedInUserAvatarBase64 ?? _loggedInUserAvatarBase64,
        avatarUrl: loggedInUserAvatarUrl ?? _loggedInUserAvatarUrl,
        badgeText: 'You (Self)',
        badgeColor: const Color(0xFF00A09D),
        subtitle: 'You are creating and assigning this task',
        tooltip: 'You created this task.',
      );
    }

    // In Edit Existing mode: check who assigned the task in Odoo (create_uid)
    final bool isSelfAssigned = (_assignedById != null &&
            _assignedById == loggedInUserId) ||
        (_assignedByName.isNotEmpty &&
            loggedInUserName.isNotEmpty &&
            _assignedByName.trim().toLowerCase() ==
                loggedInUserName.trim().toLowerCase());

    if (isSelfAssigned) {
      return _buildPersonCard(
        userId: loggedInUserId,
        name: loggedInUserName,
        email: loggedInUserEmail,
        avatarBase64: loggedInUserAvatarBase64 ?? _loggedInUserAvatarBase64,
        avatarUrl: loggedInUserAvatarUrl ?? _loggedInUserAvatarUrl,
        badgeText: 'You (Self)',
        badgeColor: const Color(0xFF00A09D),
        subtitle: loggedInUserEmail.isNotEmpty
            ? loggedInUserEmail
            : 'Created by you',
        tooltip: 'You created and assigned this task.',
      );
    }

    // Task was assigned by someone else in Odoo
    String assignerName = _assignedByName.trim();
    if (assignerName.isEmpty || assignerName == 'Assigned in Odoo') {
      if (_assignedById != null && _assignedById! > 0) {
        assignerName = 'User #$_assignedById';
      } else if (_selectedTask?.projectName != null &&
          _selectedTask!.projectName!.isNotEmpty) {
        assignerName = 'Project Lead (${_selectedTask!.projectName})';
      } else {
        assignerName = 'Odoo Manager';
      }
    }

    final assignerEmail = _assignedByEmail.trim();
    final assignerId = _assignedById ?? 0;

    return _buildPersonCard(
      userId: assignerId,
      name: assignerName,
      email: assignerEmail,
      avatarBase64: _assignedByAvatarBase64,
      avatarUrl: _assignedByAvatarUrl,
      badgeText: 'Assigned By',
      badgeColor: const Color(0xFF673AB7),
      subtitle: assignerEmail.isNotEmpty
          ? assignerEmail
          : 'Assigned this task to you in Odoo',
      tooltip: 'This task was assigned to you by $assignerName in Odoo.',
    );
  }

  Widget _buildPersonCard({
    required int userId,
    required String name,
    required String email,
    required String? avatarBase64,
    required String? avatarUrl,
    required String badgeText,
    required Color badgeColor,
    required String subtitle,
    required String tooltip,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 38,
              height: 38,
              child: _buildAvatarWidget(
                userId: userId,
                name: name,
                base64: avatarBase64,
                imageUrl: avatarUrl,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                badgeText == 'You (Self)'
                    ? Icons.person_outline_rounded
                    : Icons.person_pin_rounded,
                size: 14,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget({
    required int userId,
    required String name,
    required String? base64,
    required String? imageUrl,
    required Color color,
  }) {
    // 1. Direct base64 string (user photo from res.users, hr.employee, or res.partner)
    if (base64 != null && base64.isNotEmpty && base64 != 'false') {
      try {
        final clean = base64.replaceAll('\n', '').replaceAll('\r', '').trim();
        final bytes = base64Decode(clean);
        if (bytes.isNotEmpty) {
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildInitialAvatar(name, color: color),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error decoding base64 avatar: $e');
      }
    }

    // 2. Direct HTTP Image URL
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(name, color: color),
        ),
      );
    }

    // 3. Fallback: Initials Avatar Badge (e.g. 'SD' for Smritimay Debnath)
    return _buildInitialAvatar(name, color: color);
  }

  Color _getAvatarColorForName(String name) {
    if (name.isEmpty) return const Color(0xFF673AB7);
    const colors = [
      Color(0xFF673AB7),
      Color(0xFF00A09D),
      Color(0xFFE91E63),
      Color(0xFF2196F3),
      Color(0xFF9C27B0),
      Color(0xFF009688),
      Color(0xFFFF9800),
      Color(0xFF3F51B5),
      Color(0xFF4CAF50),
      Color(0xFF795548),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Widget _buildInitialAvatar(String name, {Color? color}) {
    String initial = 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      initial = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.trim().isNotEmpty) {
      initial = name.trim()[0].toUpperCase();
    }
    final avatarColor = color ?? _getAvatarColorForName(name);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: avatarColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: avatarColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _dialogMode == TaskDialogMode.editExisting
                  ? Icons.edit_note_rounded
                  : Icons.add_task_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _dialogMode == TaskDialogMode.editExisting
                ? 'Manage Task in Project'
                : 'Create New Task',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildFooter() {
    final isEditing = _dialogMode == TaskDialogMode.editExisting;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEditing ? Icons.save_rounded : Icons.add_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEditing ? 'Save Task Changes' : 'Create Task',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
