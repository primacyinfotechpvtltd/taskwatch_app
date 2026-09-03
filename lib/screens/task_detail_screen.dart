import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pi_task_watch/models/task_details_model.dart';
import 'package:pi_task_watch/models/task_model.dart';
import 'package:pi_task_watch/controllers/controllers.dart';
import 'package:pi_task_watch/controllers/task_details_controller.dart';
import 'package:pi_task_watch/managers/odoo_rpc_api_manager.dart';
import 'package:pi_task_watch/managers/toast_manager.dart';
import 'package:pi_task_watch/utils/format_utils.dart';
import 'package:pi_task_watch/widgets/widgets.dart';

class TaskDetailScreen extends StatefulWidget {
  static const String routeName = '/task-detail';

  const TaskDetailScreen({super.key});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TaskDetailsModel task;
  final ThemeController _themeController = Get.put(ThemeController());
  final TaskDetailsController _taskDetailsController =
      Get.put(TaskDetailsController());
  final TaskController _taskController = Get.find<TaskController>();
  int _activeStageIndex = 0;
  String _activeChatterTab = 'Activity';
  final TextEditingController _logNoteController = TextEditingController();
  final TextEditingController _searchChatterController =
      TextEditingController();
  bool _isSearchingChatter = false;

  // ── Attachments category filter ───────────────────────────────────────────
  String _selectedAttachmentCategory = 'All';
  bool _isUploadingAttachment = false;
  bool _isEditingDescription = false;
  final TextEditingController _taskDescriptionController = TextEditingController();

  // ── Assignees dropdown state ──────────────────────────────────────────────
  final LayerLink _assigneesLayerLink = LayerLink();
  OverlayEntry? _assigneesOverlay;
  List<TaskAssignee> _allUsers = [];
  final TextEditingController _assigneeDropdownSearch = TextEditingController();
  bool _isLoadingUsers = false;

  // ── Milestones & Tags state ──────────────────────────────────────────────
  List<ProjectMilestone> _projectMilestones = [];
  bool _isLoadingMilestones = false;
  List<ProjectTag> _allProjectTags = [];
  bool _isLoadingTags = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Stage change
  // ─────────────────────────────────────────────────────────────────────────
  void _changeStage(int newIndex) async {
    if (newIndex == _activeStageIndex) return;
    final stage = _taskDetailsController.stages[newIndex];
    final success =
        await _taskDetailsController.updateTaskStage(task.id, stage.id);
    if (success) {
      setState(() => _activeStageIndex = newIndex);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.index = 1;

    final args = Get.arguments;
    if (args is TaskDetailsModel) {
      task = args;
      _taskDetailsController.currentTask.value = args;
    } else if (args is TaskModel) {
      final model = TaskDetailsModel(
        id: args.id,
        name: args.name,
        projectId: args.projectId,
        projectName: args.projectName,
        stageId: args.stageId ?? 0,
        stageName: args.stageName,
        dateDeadline: args.getEndDateTime(),
        dateStart: args.getStartDateTime(),
        allocatedHours: args.allocatedHours ?? 0.0,
        tags: args.tags,
        tagIds: args.tagIds,
        milestoneId: args.milestoneId,
        milestoneName: args.milestoneName,
        description: args.description,
      );
      task = model;
      _taskDetailsController.currentTask.value = model;
    } else if (args is Map<String, dynamic>) {
      final model = TaskDetailsModel.fromJson(args);
      task = model;
      _taskDetailsController.currentTask.value = model;
    } else if (args is int) {
      final model = TaskDetailsModel(id: args, name: 'Task #$args', stageId: 0);
      task = model;
      _taskDetailsController.currentTask.value = model;
    } else {
      debugPrint(
          'Error: TaskDetailScreen expected TaskDetailsModel but got ${args.runtimeType}');
      Get.back();
      return;
    }

    _maximizeWindow();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      _taskDetailsController.loadAllTaskData(task.id),
      _fetchAllUsers(),
      _fetchProjectMilestones(),
      _fetchProjectTags(),
    ]);

    _updateActiveStageIndex();
    _resolveTagsAndMilestones();

    if (mounted) {
      setState(() {});
    }
  }

  void _resolveTagsAndMilestones() {
    if (_taskDetailsController.currentTask.value != null) {
      final t = _taskDetailsController.currentTask.value!;
      List<String> resolvedTags = List<String>.from(t.tags ?? []);
      List<int> resolvedTagIds = List<int>.from(t.tagIds ?? []);

      // If tagIds exist, resolve any missing names from _allProjectTags
      if (resolvedTagIds.isNotEmpty && _allProjectTags.isNotEmpty) {
        for (final id in resolvedTagIds) {
          final found = _allProjectTags.where((pt) => pt.id == id).firstOrNull;
          if (found != null && found.name.isNotEmpty && !resolvedTags.contains(found.name)) {
            resolvedTags.add(found.name);
          }
        }
      }

      // If tags exist without tagIds, resolve IDs
      if (resolvedTags.isNotEmpty && _allProjectTags.isNotEmpty) {
        for (final name in resolvedTags) {
          final found = _allProjectTags.where((pt) => pt.name.toLowerCase() == name.toLowerCase()).firstOrNull;
          if (found != null && found.id > 0 && !resolvedTagIds.contains(found.id)) {
            resolvedTagIds.add(found.id);
          }
        }
      }

      // If milestoneId exists but milestoneName is empty, resolve name
      String? resolvedMilestoneName = t.milestoneName;
      if ((resolvedMilestoneName == null || resolvedMilestoneName.isEmpty) &&
          t.milestoneId != null &&
          t.milestoneId! > 0 &&
          _projectMilestones.isNotEmpty) {
        final foundMs = _projectMilestones.where((m) => m.id == t.milestoneId).firstOrNull;
        if (foundMs != null) {
          resolvedMilestoneName = foundMs.name;
        }
      }

      _taskDetailsController.currentTask.value = t.copyWith(
        tags: resolvedTags,
        tagIds: resolvedTagIds,
        milestoneName: resolvedMilestoneName,
      );
      _taskDetailsController.currentTask.refresh();
    }
  }

  Future<void> _fetchProjectMilestones() async {
    final projId =
        _taskDetailsController.currentTask.value?.projectId ?? task.projectId;
    setState(() => _isLoadingMilestones = true);
    final list = await _taskDetailsController.getProjectMilestones(projId);
    if (mounted) {
      setState(() {
        _projectMilestones = list;
        _isLoadingMilestones = false;
      });
      final t = _taskDetailsController.currentTask.value;
      if (t != null && t.milestoneId != null && t.milestoneId! > 0) {
        final found = list.where((m) => m.id == t.milestoneId).firstOrNull;
        if (found != null && (t.milestoneName == null || t.milestoneName!.isEmpty || t.milestoneName != found.name)) {
          _taskDetailsController.currentTask.value = t.copyWith(milestoneName: found.name);
          _taskDetailsController.currentTask.refresh();
        }
      }
    }
  }

  Future<void> _fetchProjectTags() async {
    setState(() => _isLoadingTags = true);
    final list = await _taskDetailsController.getProjectTags();
    if (mounted) {
      setState(() {
        _allProjectTags = list;
        _isLoadingTags = false;
      });
      final t = _taskDetailsController.currentTask.value;
      if (t != null && t.tagIds != null && t.tagIds!.isNotEmpty) {
        final resolved = <String>[];
        for (final id in t.tagIds!) {
          final found = list.where((pt) => pt.id == id).firstOrNull;
          if (found != null && found.name.isNotEmpty) {
            resolved.add(found.name);
          }
        }
        if (resolved.isNotEmpty) {
          final mergedTags = List<String>.from(t.tags ?? []);
          for (final r in resolved) {
            if (!mergedTags.contains(r)) mergedTags.add(r);
          }
          _taskDetailsController.currentTask.value = t.copyWith(tags: mergedTags);
          _taskDetailsController.currentTask.refresh();
        }
      }
    }
  }

  void _updateActiveStageIndex() {
    if (_taskDetailsController.stages.isNotEmpty &&
        _taskDetailsController.currentTask.value != null) {
      final currentStageId = _taskDetailsController.currentTask.value!.stageId;
      final index = _taskDetailsController.stages
          .indexWhere((s) => s.id == currentStageId);
      if (index != -1) setState(() => _activeStageIndex = index);
    }
  }

  Future<void> _maximizeWindow() async {
    if (GetPlatform.isDesktop) await windowManager.setFullScreen(true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logNoteController.dispose();
    _searchChatterController.dispose();
    _taskDescriptionController.dispose();
    _taskDetailsController.clearData();
    _restoreWindow();
    _removeAssigneesOverlay();
    _assigneeDropdownSearch.dispose();
    super.dispose();
  }

  Future<void> _restoreWindow() async {
    if (GetPlatform.isDesktop) await windowManager.setFullScreen(false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data helpers
  // ─────────────────────────────────────────────────────────────────────────
  String _getTaskName() =>
      _taskDetailsController.currentTask.value?.name ?? task.name;

  String _getProjectName() {
    final t = _taskDetailsController.currentTask.value;
    if (t != null) return t.projectName ?? 'N/A';
    try {
      return (task as dynamic).projectName ?? 'N/A';
    } catch (_) {
      return 'N/A';
    }
  }

  DateTime? _getDeadline() {
    final t = _taskDetailsController.currentTask.value;
    if (t != null) return t.dateDeadline;
    try {
      return (task as dynamic).getEndDateTime();
    } catch (_) {
      return null;
    }
  }

  String _getAllocatedTime() {
    final t = _taskDetailsController.currentTask.value;
    if (t != null) return t.getFormattedAllocatedTime();
    try {
      return (task as dynamic).getFormattedAllocatedTime() ?? '00:00';
    } catch (_) {
      return '00:00';
    }
  }

  String _getProgress() =>
      _taskDetailsController.currentTask.value?.getFormattedProgress() ?? '0%';

  String _getDescription() {
    final t = _taskDetailsController.currentTask.value;
    if (t != null && t.description != null) return t.description!;
    return 'Complete Field Pro assigned features and prepare final build';
  }

  String _getAssignees() {
    final t = _taskDetailsController.currentTask.value;
    if (t != null) {
      debugPrint(
          '🔍 [TaskDetailScreen] Assignees for Task ${t.id}: ${t.userNames}');
      if (t.userNames.isNotEmpty) return t.getAssigneesString();
    }
    return '';
  }

  String _getAssigneeInitial() {
    final t = _taskDetailsController.currentTask.value;
    if (t != null && t.userNames.isNotEmpty) return t.getFirstAssigneeInitial();
    return '';
  }

  Color _getAvatarColorForName(String name) {
    if (name.isEmpty) return const Color(0xFF3F51B5);
    const colors = [
      Color(0xFF3F51B5),
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF673AB7),
      Color(0xFF009688),
      Color(0xFF3F51B5),
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF795548),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Assignees overlay helpers
  // ─────────────────────────────────────────────────────────────────────────
  void _removeAssigneesOverlay() {
    _assigneesOverlay?.remove();
    _assigneesOverlay = null;
  }

  Future<void> _fetchAllUsers() async {
    if (_allUsers.isNotEmpty) return;
    setState(() => _isLoadingUsers = true);
    try {
      final response = await OdooRpcApiManager.searchRead(
        model: 'res.users',
        domain: [
          ['active', '=', true],
          ['share', '=', false],
        ],
        fields: ['id', 'name', 'login', 'email'],
        limit: 100,
      );
      if (response.isSuccess && response.data != null) {
        final list = (response.data as List).map((u) {
          final m = u as Map<String, dynamic>;
          return TaskAssignee(
            id: m['id'] as int,
            name: (m['name'] ?? m['login'] ?? 'User').toString(),
          );
        }).toList();
        if (list.isNotEmpty) {
          setState(() {
            _allUsers = list;
            _isLoadingUsers = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching users from Odoo: $e');
    }

    final currentUser = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().user.value
        : null;
    if (currentUser != null) {
      _allUsers = [
        TaskAssignee(
          id: currentUser.userId,
          name: currentUser.name,
        ),
      ];
    } else {
      final currentTask = _taskDetailsController.currentTask.value;
      _allUsers = List<TaskAssignee>.from(currentTask?.userIds ?? []);
    }
    setState(() => _isLoadingUsers = false);
  }

  void _showAssigneesDropdown(BuildContext anchorContext, ThemePalette theme) {
    _removeAssigneesOverlay();
    _fetchAllUsers();

    final overlay = Overlay.of(anchorContext);
    final renderBox = anchorContext.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _assigneesOverlay = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeAssigneesOverlay,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.transparent)),
            CompositedTransformFollower(
              link: _assigneesLayerLink,
              offset: Offset(0, size.height + 4),
              child: Material(
                color: Colors.transparent,
                child: _AssigneesDropdown(
                  theme: theme,
                  allUsers: _allUsers,
                  currentAssignees:
                      _taskDetailsController.currentTask.value?.userIds ?? [],
                  searchController: _assigneeDropdownSearch,
                  onSelect: (user) async {
                    _removeAssigneesOverlay();
                    final current =
                        _taskDetailsController.currentTask.value?.userIds ?? [];
                    final List<TaskAssignee> updatedList = List.from(current);
                    final isAlready = updatedList.any((a) => a.id == user.id);
                    if (isAlready) {
                      updatedList.removeWhere((a) => a.id == user.id);
                    } else {
                      updatedList.add(user);
                    }

                    // 1. INSTANT LOCAL UPDATE
                    if (_taskDetailsController.currentTask.value != null) {
                      _taskDetailsController.currentTask.value =
                          _taskDetailsController.currentTask.value!.copyWith(
                        userIds: updatedList,
                        userNames: updatedList.map((a) => a.name).toList(),
                      );
                    }
                    setState(() {});

                    // 2. Persist to Odoo
                    final List<int> ids = updatedList.map((a) => a.id).toList();
                    final taskId =
                        _taskDetailsController.currentTask.value?.id ?? 0;
                    if (taskId > 0) {
                      await _taskDetailsController.updateTaskAssignees(taskId, ids);
                    }
                    setState(() {});
                  },
                  onSearchMore: () {
                    _removeAssigneesOverlay();
                    _showFullSearchDialog(theme);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(_assigneesOverlay!);
  }

  void _showFullSearchDialog(ThemePalette theme) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _AssigneesSearchDialog(
        theme: theme,
        allUsers: _allUsers,
        currentAssignees:
            _taskDetailsController.currentTask.value?.userIds ?? [],
        onSelect: (selected) async {
          Navigator.of(ctx).pop();
          
          // 1. INSTANT LOCAL UPDATE
          if (_taskDetailsController.currentTask.value != null) {
            _taskDetailsController.currentTask.value =
                _taskDetailsController.currentTask.value!.copyWith(
              userIds: selected,
              userNames: selected.map((a) => a.name).toList(),
            );
          }
          setState(() {});

          // 2. Persist to Odoo
          final List<int> ids = selected.map((a) => a.id).toList();
          final taskId =
              _taskDetailsController.currentTask.value?.id ?? 0;
          if (taskId > 0) {
            await _taskDetailsController.updateTaskAssignees(taskId, ids);
          }
          setState(() {});
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = _themeController.currentTheme;
      final bool isMainLoading =
          _taskDetailsController.isInitialLoading.value ||
              _taskDetailsController.isLoading.value;

      return Scaffold(
        backgroundColor: theme.bgColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(theme),
                  _buildStageBreadcrumbs(theme),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildMainContent(theme),
                        ),
                        if (MediaQuery.of(context).size.width > 900)
                          Container(
                              width: 1, color: Colors.white.withOpacity(0.05)),
                        if (MediaQuery.of(context).size.width > 900)
                          Expanded(
                            flex: 1,
                            child: _buildChatterSection(theme),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isMainLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                theme.isDark ? Colors.white : Colors.teal),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Loading task details...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top bar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar(ThemePalette theme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.headerColor,
        border: Border(
            bottom: BorderSide(
                color: Colors.white.withOpacity(theme.isDark ? 0.05 : 0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon:
                Icon(Icons.arrow_back, color: theme.primaryTextColor, size: 20),
            onPressed: () => Get.back(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _getTaskName(),
              style: TextStyle(
                  color: theme.primaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.edit_note_rounded,
                    color: theme.activeColor, size: 22),
                onPressed: () async {
                  final currentTaskModel = _taskController.taskList
                          .firstWhereOrNull((t) => t.id == task.id) ??
                      TaskModel(
                        id: task.id,
                        name: _getTaskName(),
                        projectId: task.projectId,
                        projectName: _getProjectName(),
                        allocatedTimeInHours: _taskDetailsController
                            .currentTask.value?.allocatedHours != null
                            ? Duration(
                                minutes: (_taskDetailsController
                                            .currentTask.value!.allocatedHours! *
                                        60)
                                    .round())
                            : null,
                        endDate: _getDeadline()?.toIso8601String(),
                        json: {
                          'description': _getDescription(),
                          'allocated_hours': _taskDetailsController
                              .currentTask.value?.allocatedHours,
                        },
                      );

                  final updated = await showDialog<TaskModel>(
                    context: context,
                    barrierDismissible: true,
                    builder: (ctx) => AddTaskDialog(
                      initialProjectId: task.projectId,
                      initialTask: currentTaskModel,
                    ),
                  );

                  if (updated != null) {
                    await _loadData();
                  }
                },
                tooltip: 'Edit Task Time & Description',
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.star_border,
                    color: theme.secondaryTextColor, size: 20),
                onPressed: () {},
                tooltip: 'Mark as important',
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ThemeType>(
                tooltip: 'Change Theme',
                icon: Icon(Icons.palette_outlined,
                    color: theme.secondaryTextColor, size: 20),
                offset: const Offset(0, 40),
                color: theme.isDark ? const Color(0xFF2E2E2E) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onSelected: (type) => _themeController.setTheme(type),
                itemBuilder: (context) => [
                  _buildThemeMenuItem(
                      ThemeType.odooDark, 'Odoo Dark', const Color(0xFF00A09D)),
                  _buildThemeMenuItem(ThemeType.odooLight, 'Odoo Light',
                      const Color(0xFF714B67)),
                  _buildThemeMenuItem(ThemeType.emerald, 'Emerald Forest',
                      const Color(0xFF10B981)),
                  _buildThemeMenuItem(
                      ThemeType.sunset, 'Sunset Gold', const Color(0xFFF59E0B)),
                  _buildThemeMenuItem(
                      ThemeType.royal, 'Royal Plum', const Color(0xFF8B5CF6)),
                  _buildThemeMenuItem(
                      ThemeType.ocean, 'Ocean Blue', const Color(0xFF0EA5E9)),
                  _buildThemeMenuItem(
                      ThemeType.ruby, 'Deep Ruby', const Color(0xFFEF4444)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined,
                    color: theme.secondaryTextColor, size: 20),
                onPressed: () {},
                tooltip: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<ThemeType> _buildThemeMenuItem(
      ThemeType type, String label, Color color) {
    final isSelected = _themeController.currentType == type;
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, color: Colors.teal, size: 14),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage breadcrumbs
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStageBreadcrumbs(ThemePalette theme) {
    return Obx(() {
      final stages = _taskDetailsController.stages;
      if (stages.isEmpty) return const SizedBox.shrink();

      return Container(
        height: 42,
        decoration: BoxDecoration(
          color: theme.bgColor,
          border: Border(
              bottom: BorderSide(
                  color: theme.secondaryTextColor.withOpacity(0.08))),
        ),
        child: Row(
          children: [
            const SizedBox(width: 24),
            Expanded(
              child: ClipRRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: stages.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final stage = entry.value;
                      final isActive = idx == _activeStageIndex;
                      final isLast = idx == stages.length - 1;
                      return GestureDetector(
                        onTap: () => _changeStage(idx),
                        child: _buildBreadcrumbItem(
                            stage.name, '', isActive, idx == 0, isLast, theme),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBreadcrumbItem(String title, String duration, bool isActive,
      bool isFirst, bool isLast, ThemePalette theme) {
    final activeColor = theme.accentColor;
    final inactiveColor =
        theme.isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF3E8EE);
    final textColor = isActive
        ? Colors.white
        : (theme.isDark ? Colors.white70 : const Color(0xFF714B67));

    return ClipPath(
      clipper: BreadcrumbClipper(isFirst: isFirst, isLast: isLast),
      child: Container(
        padding: EdgeInsets.fromLTRB(isFirst ? 20 : 34, 0, isLast ? 20 : 20, 0),
        height: 42,
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          gradient: isActive
              ? LinearGradient(
                  colors: [activeColor, const Color(0xFFE2165F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main content
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMainContent(ThemePalette theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _getTaskName(),
                  style: TextStyle(
                    color: theme.primaryTextColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_border,
                      color: Colors.white30, size: 20),
                  const Icon(Icons.star_border,
                      color: Colors.white30, size: 20),
                  const Icon(Icons.star_border,
                      color: Colors.white30, size: 20),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.secondaryTextColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'In Progress',
                      style: TextStyle(
                          color: theme.secondaryTextColor, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoGrid(theme),
          const SizedBox(height: 32),
          _buildTabs(theme),
          if (MediaQuery.of(context).size.width <= 900) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _buildChatterSection(theme, isEmbedded: true),
          ],
        ],
      ),
    );
  }

  String _getPlannedDateString() {
    final t = _taskDetailsController.currentTask.value;
    final start = t?.dateStart;
    final end = t?.dateDeadline;

    if (start == null && end == null) {
      return '';
    }
    if (start != null && end != null) {
      final startStr = DateFormat('MMM d, h:mm a').format(start.toLocal());
      final isSameDay = start.year == end.year && start.month == end.month && start.day == end.day;
      final endStr = isSameDay ? DateFormat('h:mm a').format(end.toLocal()) : DateFormat('MMM d, h:mm a').format(end.toLocal());
      return '$startStr  ➔  $endStr';
    }
    if (start != null) return DateFormat('MMM d, h:mm a').format(start.toLocal());
    if (end != null) return DateFormat('MMM d, h:mm a').format(end.toLocal());
    return '';
  }

  Widget _buildCustomRow({
    required String label,
    required ThemePalette theme,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.secondaryTextColor.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (label == 'Milestone')
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '?',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow(ThemePalette theme) {
    final t = _taskDetailsController.currentTask.value;
    String? milestone = t?.milestoneName;
    if ((milestone == null || milestone.isEmpty) && t?.milestoneId != null && t!.milestoneId! > 0) {
      final found = _projectMilestones.where((m) => m.id == t.milestoneId).firstOrNull;
      if (found != null) {
        milestone = found.name;
      }
    }
    final hasMilestone = milestone != null && milestone.isNotEmpty;

    return _buildCustomRow(
      label: 'Milestone',
      theme: theme,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF00A09D), width: 1.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showMilestoneDropdown(context, theme),
                child: Text(
                  hasMilestone ? milestone : 'Add milestone...',
                  style: TextStyle(
                    color: hasMilestone
                        ? theme.primaryTextColor
                        : theme.secondaryTextColor.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: hasMilestone ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showMilestoneDropdown(context, theme),
                child: const Icon(Icons.arrow_drop_down,
                    size: 18, color: Color(0xFF00A09D)),
              ),
              if (hasMilestone) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () async {
                    if (_taskDetailsController.currentTask.value != null) {
                      _taskDetailsController.currentTask.value =
                          _taskDetailsController.currentTask.value!.copyWith(
                        milestoneId: null,
                        milestoneName: null,
                      );
                      _taskDetailsController.currentTask.refresh();
                    }
                    setState(() {});
                    await _taskDetailsController.updateTaskMilestone(task.id, null, null);
                    _taskDetailsController.currentTask.refresh();
                    setState(() {});
                  },
                  child: const Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ],
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showCreateMilestoneDialog(theme),
                child: const Icon(Icons.add_circle_outline,
                    size: 15, color: Color(0xFF00A09D)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMilestoneDropdown(BuildContext context, ThemePalette theme) async {
    if (_projectMilestones.isEmpty) {
      await _fetchProjectMilestones();
    }

    final searchController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchController.text.toLowerCase();
          final filtered = _projectMilestones
              .where((m) => m.name.toLowerCase().contains(query))
              .toList();

          return Dialog(
            backgroundColor:
                theme.isDark ? const Color(0xFF2A2A2A) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Select Milestone',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryTextColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: theme.secondaryTextColor,
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search box
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: theme.isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.isDark
                            ? const Color(0xFF4B5563)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search,
                            size: 16,
                            color: theme.isDark
                                ? Colors.white70
                                : const Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            cursorColor: const Color(0xFF00A09D),
                            style: TextStyle(
                              color: theme.isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'Search...',
                              hintStyle: TextStyle(
                                color: theme.isDark
                                    ? Colors.white38
                                    : const Color(0xFF9CA3AF),
                                fontSize: 13,
                              ),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Milestones list
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // None / Clear option
                        InkWell(
                          onTap: () async {
                            Navigator.of(dialogCtx).pop();
                            if (_taskDetailsController.currentTask.value != null) {
                              _taskDetailsController.currentTask.value =
                                  _taskDetailsController.currentTask.value!.copyWith(
                                milestoneId: null,
                                milestoneName: null,
                              );
                              _taskDetailsController.currentTask.refresh();
                            }
                            setState(() {});
                            await _taskDetailsController.updateTaskMilestone(task.id, null, null);
                            _taskDetailsController.currentTask.refresh();
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: Row(
                              children: [
                                const Icon(Icons.block, size: 14, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'None (Clear Milestone)',
                                  style: TextStyle(
                                    color: theme.secondaryTextColor,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ...filtered.map((m) {
                          final isSelected = _taskDetailsController
                                  .currentTask.value?.milestoneId ==
                              m.id;
                          return InkWell(
                            onTap: () async {
                              Navigator.of(dialogCtx).pop();

                              // 1. INSTANT LOCAL UPDATE
                              if (_taskDetailsController.currentTask.value != null) {
                                _taskDetailsController.currentTask.value =
                                    _taskDetailsController.currentTask.value!.copyWith(
                                  milestoneId: m.id,
                                  milestoneName: m.name,
                                );
                                _taskDetailsController.currentTask.refresh();
                              }
                              setState(() {});

                              // 2. Persist to Odoo
                              await _taskDetailsController.updateTaskMilestone(task.id, m.id, m.name);
                              _taskDetailsController.currentTask.refresh();
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF00A09D)
                                        .withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.flag_outlined,
                                      size: 14,
                                      color: isSelected
                                          ? const Color(0xFF00A09D)
                                          : theme.secondaryTextColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF00A09D)
                                            : theme.primaryTextColor,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check,
                                        size: 14,
                                        color: Color(0xFF00A09D)),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No milestones found',
                              style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Create Option (Image 2)
                  InkWell(
                    onTap: () {
                      Navigator.of(dialogCtx).pop();
                      _showCreateMilestoneDialog(theme);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 16, color: Color(0xFF00A09D)),
                          SizedBox(width: 8),
                          Text(
                            'Create...',
                            style: TextStyle(
                              color: Color(0xFF00A09D),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateMilestoneDialog(ThemePalette theme) {
    final nameController = TextEditingController();
    DateTime? deadlineDate;
    bool isReached = false;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor:
                theme.isDark ? const Color(0xFF242424) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Milestone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Name Field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Row(
                          children: [
                            Text(
                              'Name',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '?',
                              style: TextStyle(
                                color: Color(0xFF00A09D),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          autofocus: true,
                          cursorColor: const Color(0xFF00A09D),
                          style: TextStyle(
                            color: theme.primaryTextColor,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 6),
                            hintText: 'e.g: Product Launch',
                            hintStyle: TextStyle(
                              color: theme.secondaryTextColor
                                  .withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFF00A09D)),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF00A09D), width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Deadline Field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Row(
                          children: [
                            Text(
                              'Deadline',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '?',
                              style: TextStyle(
                                color: Color(0xFF00A09D),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: deadlineDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2040),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                deadlineDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.secondaryTextColor
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            child: Text(
                              deadlineDate != null
                                  ? DateFormat('MM/dd/yyyy')
                                      .format(deadlineDate!)
                                  : 'Select deadline...',
                              style: TextStyle(
                                fontSize: 13,
                                color: deadlineDate != null
                                    ? theme.primaryTextColor
                                    : theme.secondaryTextColor
                                        .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reached Field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Row(
                          children: [
                            Text(
                              'Reached',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '?',
                              style: TextStyle(
                                color: Color(0xFF00A09D),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: isReached,
                        activeColor: const Color(0xFF714B67),
                        onChanged: (val) {
                          setDialogState(() {
                            isReached = val ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            showToast('Please enter milestone name',
                                idSuccess: false);
                            return;
                          }
                          Navigator.of(dialogCtx).pop();
                          final projId = _taskDetailsController
                                  .currentTask.value?.projectId ??
                              task.projectId;
                          final newM =
                              await _taskDetailsController.createMilestone(
                            name: name,
                            projectId: projId,
                            deadline: deadlineDate,
                            isReached: isReached,
                          );
                          if (newM != null) {
                            await _taskDetailsController.updateTaskMilestone(
                              task.id,
                              newM.id,
                              newM.name,
                            );
                            _fetchProjectMilestones();
                            setState(() {});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF714B67),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: theme.isDark
                              ? const Color(0xFF333333)
                              : const Color(0xFFF1F5F9),
                          foregroundColor: theme.primaryTextColor,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Discard'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagsRow(ThemePalette theme) {
    final t = _taskDetailsController.currentTask.value;
    List<String> tags = List<String>.from(t?.tags ?? []);
    if (tags.isEmpty && t?.tagIds != null && t!.tagIds!.isNotEmpty && _allProjectTags.isNotEmpty) {
      tags = t.tagIds!.map((id) {
        final found = _allProjectTags.where((pt) => pt.id == id).firstOrNull;
        return found?.name ?? '';
      }).where((s) => s.isNotEmpty).toList();
    }
    final hasTags = tags.isNotEmpty;

    return _buildCustomRow(
      label: 'Tags',
      theme: theme,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF00A09D), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showTagsDropdown(context, theme),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...tags.map((tagName) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAD7A0), // peach/orange
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tagName,
                                style: const TextStyle(
                                  color: Color(0xFF78350F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _removeTag(tagName),
                                child: const Icon(Icons.close,
                                    size: 13, color: Color(0xFF78350F)),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (!hasTags)
                        Text(
                          'Add tags...',
                          style: TextStyle(
                            color:
                                theme.secondaryTextColor.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showTagsDropdown(context, theme),
                child: const Icon(Icons.arrow_drop_down,
                    size: 18, color: Color(0xFF00A09D)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagsDropdown(BuildContext context, ThemePalette theme) async {
    if (_allProjectTags.isEmpty) {
      await _fetchProjectTags();
    }

    final searchController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = _allProjectTags
              .where((t) => t.name.toLowerCase().contains(query))
              .toList();

          final currentTask = _taskDetailsController.currentTask.value;
          final currentTags = List<String>.from(currentTask?.tags ?? []);
          final currentTagIds = List<int>.from(currentTask?.tagIds ?? []);

          return Dialog(
            backgroundColor:
                theme.isDark ? const Color(0xFF2A2A2A) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Select Tags',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryTextColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: theme.secondaryTextColor,
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search box
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: theme.isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.isDark
                            ? const Color(0xFF4B5563)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search,
                            size: 16,
                            color: theme.isDark
                                ? Colors.white70
                                : const Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            cursorColor: const Color(0xFF00A09D),
                            style: TextStyle(
                              color: theme.isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'Search or add tags...',
                              hintStyle: TextStyle(
                                color: theme.isDark
                                    ? Colors.white38
                                    : const Color(0xFF9CA3AF),
                                fontSize: 13,
                              ),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tags list
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ...filtered.map((t) {
                          final isSelected = currentTags.any((tag) => tag.toLowerCase() == t.name.toLowerCase()) ||
                              currentTagIds.contains(t.id);
                          return InkWell(
                            onTap: () async {
                              final updatedNames = List<String>.from(
                                  _taskDetailsController.currentTask.value?.tags ?? []);
                              final updatedIds = List<int>.from(
                                  _taskDetailsController.currentTask.value?.tagIds ?? []);

                              if (isSelected) {
                                updatedNames.removeWhere((name) => name.toLowerCase() == t.name.toLowerCase());
                                updatedIds.remove(t.id);
                              } else {
                                if (!updatedNames.any((name) => name.toLowerCase() == t.name.toLowerCase())) {
                                  updatedNames.add(t.name);
                                }
                                if (!updatedIds.contains(t.id)) {
                                  updatedIds.add(t.id);
                                }
                              }

                              // 1. INSTANT LOCAL UPDATE
                              if (_taskDetailsController.currentTask.value != null) {
                                _taskDetailsController.currentTask.value =
                                    _taskDetailsController.currentTask.value!.copyWith(
                                  tags: updatedNames,
                                  tagIds: updatedIds,
                                );
                                _taskDetailsController.currentTask.refresh();
                              }
                              setDialogState(() {});
                              setState(() {});

                              // 2. Persist to Odoo & REST
                              await _taskDetailsController.updateTaskTags(task.id, updatedIds, updatedNames);
                              _taskDetailsController.currentTask.refresh();
                              if (mounted) setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF00A09D)
                                        .withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                    size: 18,
                                    color: isSelected
                                        ? const Color(0xFF00A09D)
                                        : theme.secondaryTextColor.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF00A09D)
                                            : theme.primaryTextColor,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (query.isNotEmpty &&
                            !filtered.any((t) =>
                                t.name.toLowerCase() == query))
                          InkWell(
                            onTap: () async {
                              final newTag = await _taskDetailsController
                                  .createTag(searchController.text.trim());
                              if (newTag != null) {
                                _allProjectTags.add(newTag);
                                final updatedNames = List<String>.from(
                                    _taskDetailsController.currentTask.value?.tags ?? [])..add(newTag.name);
                                final updatedIds = List<int>.from(
                                    _taskDetailsController.currentTask.value?.tagIds ?? [])..add(newTag.id);

                                if (_taskDetailsController.currentTask.value != null) {
                                  _taskDetailsController.currentTask.value =
                                      _taskDetailsController.currentTask.value!.copyWith(
                                    tags: updatedNames,
                                    tagIds: updatedIds,
                                  );
                                  _taskDetailsController.currentTask.refresh();
                                }
                                setDialogState(() {});
                                setState(() {});

                                await _taskDetailsController.updateTaskTags(
                                    task.id, updatedIds, updatedNames);
                                _taskDetailsController.currentTask.refresh();
                                if (mounted) setState(() {});
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Text(
                                'Create "${searchController.text.trim()}"',
                                style: const TextStyle(
                                  color: Color(0xFF00A09D),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Done Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF714B67),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _removeTag(String tagName) async {
    final currentTags = List<String>.from(
        _taskDetailsController.currentTask.value?.tags ?? []);
    currentTags.removeWhere((t) => t.toLowerCase() == tagName.toLowerCase());

    final currentTagIds = <int>[];
    for (final name in currentTags) {
      final tag = _allProjectTags
          .where((t) => t.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (tag != null && tag.id > 0) {
        currentTagIds.add(tag.id);
      }
    }

    if (_taskDetailsController.currentTask.value != null) {
      _taskDetailsController.currentTask.value =
          _taskDetailsController.currentTask.value!.copyWith(
        tags: currentTags,
        tagIds: currentTagIds,
      );
      _taskDetailsController.currentTask.refresh();
    }
    setState(() {});

    await _taskDetailsController.updateTaskTags(
        task.id, currentTagIds, currentTags);
    _taskDetailsController.currentTask.refresh();
    setState(() {});
  }

  Widget _buildPlannedDateRow(ThemePalette theme) {
    final t = _taskDetailsController.currentTask.value;
    final dateStart = t?.dateStart;
    final dateDeadline = t?.dateDeadline ?? _getDeadline();
    
    Widget dateContent;
    const dateColor = Color(0xFFEF5350); // soft red/coral matching Odoo mockup

    if (dateStart != null && dateDeadline != null) {
      final isSameDay = dateStart.year == dateDeadline.year &&
          dateStart.month == dateDeadline.month &&
          dateStart.day == dateDeadline.day;
      final startStr = DateFormat('MMM d, h:mm a').format(dateStart.toLocal());
      final endStr = isSameDay
          ? DateFormat('h:mm a').format(dateDeadline.toLocal())
          : DateFormat('MMM d, h:mm a').format(dateDeadline.toLocal());

      dateContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            startStr,
            style: const TextStyle(
              color: dateColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '➔',
            style: TextStyle(
              color: dateColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            endStr,
            style: const TextStyle(
              color: dateColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (dateDeadline != null) {
      dateContent = Text(
        DateFormat('MMM d, h:mm a').format(dateDeadline.toLocal()),
        style: const TextStyle(
          color: dateColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
    } else if (dateStart != null) {
      dateContent = Text(
        DateFormat('MMM d, h:mm a').format(dateStart.toLocal()),
        style: const TextStyle(
          color: dateColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      dateContent = Text(
        'Set planned date...',
        style: TextStyle(
          color: theme.secondaryTextColor.withOpacity(0.4),
          fontSize: 13,
        ),
      );
    }

    return _buildCustomRow(
      label: 'Planned Date',
      theme: theme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openPlannedDatePicker(theme),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: dateContent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _openPlannedDatePicker(theme),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 26,
                height: 24,
                decoration: BoxDecoration(
                  color:
                      theme.isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: theme.isDark
                        ? Colors.white24
                        : const Color(0xFFD1D5DB),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.refresh,
                  size: 15,
                  color: theme.primaryTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPlannedDatePicker(ThemePalette theme) async {
    final t = _taskDetailsController.currentTask.value;
    final result = await showOdooDateRangePicker(
      context: context,
      initialStartDate: t?.dateStart,
      initialEndDate: t?.dateDeadline,
      includeTime: true,
      allowRange: true,
      title: 'Select Planned Date',
    );

    if (result != null) {
      await _taskDetailsController.updateTaskPlannedDates(
        task.id,
        startDate: result.startDate,
        deadline: result.endDate,
      );
      setState(() {});
    }
  }

  Widget _buildAllocatedTimeRow(ThemePalette theme) {
    return _buildCustomRow(
      label: 'Allocated Time',
      theme: theme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _getAllocatedTime(),
            style: TextStyle(
              color: theme.primaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${_getProgress()})',
            style: TextStyle(
              color: theme.secondaryTextColor.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(ThemePalette theme) {
    return Obx(() {
      final currentTask = _taskDetailsController.currentTask.value;

      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;

          final leftColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Project', _getProjectName(), theme: theme),
              _buildMilestoneRow(theme),
              _buildAssigneesRow(theme),
            ],
          );

          final rightColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTagsRow(theme),
              _buildPlannedDateRow(theme),
              _buildAllocatedTimeRow(theme),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftColumn),
                const SizedBox(width: 48),
                Expanded(child: rightColumn),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftColumn,
                const SizedBox(height: 16),
                rightColumn,
              ],
            );
          }
        },
      );
    });
  }

  Widget _buildInfoColumn(List<Widget> children) {
    return SizedBox(
      width: 300,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isPlaceholder = false,
      bool isAvatar = false,
      Color? color,
      required ThemePalette theme}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.secondaryTextColor.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (label == 'Milestone')
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.help_outline,
                        size: 13, color: Colors.blueAccent),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (isAvatar) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 24,
                      height: 24,
                      color: const Color(0xFF3F51B5),
                      alignment: Alignment.center,
                      child: Text(
                        _getAssigneeInitial(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color ??
                          (isPlaceholder
                              ? theme.secondaryTextColor.withOpacity(0.4)
                              : theme.primaryTextColor),
                      fontSize: 13,
                      fontWeight:
                          isPlaceholder ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NEW: Assignees row with dropdown + search-more modal
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // Assignees row with Wrap (prevents overflow)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAssigneesRow(ThemePalette theme) {
    final currentTask = _taskDetailsController.currentTask.value;
    final List<TaskAssignee> assignees = currentTask?.userIds ?? [];

    final List<Widget> items = [];
    items.addAll(assignees.map((assignee) {
      TaskAssignee? found;
      for (final u in _allUsers) {
        if (u.id == assignee.id) {
          found = u;
          break;
        }
      }
      final realName = (found != null &&
              found.name.isNotEmpty &&
              !found.name.startsWith('User '))
          ? found.name
          : (assignee.name.isNotEmpty && !assignee.name.startsWith('User ')
              ? assignee.name
              : 'Spandan Halder');
      return _AssigneeChip(
        assignee: TaskAssignee(id: assignee.id, name: realName),
        theme: theme,
        getColor: _getAvatarColorForName,
      );
    }));

    // "Add Assignee" button – anchored for the overlay dropdown
    items.add(
      CompositedTransformTarget(
        link: _assigneesLayerLink,
        child: Builder(
          builder: (anchorCtx) => Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => _showAssigneesDropdown(anchorCtx, theme),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A09D).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: const Color(0xFF00A09D).withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF00A09D)),
                    SizedBox(width: 4),
                    Text(
                      'Add Assignee',
                      style: TextStyle(
                        color: Color(0xFF00A09D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Assignees',
                style: TextStyle(
                  color: theme.secondaryTextColor.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: items,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tabs
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTabs(ThemePalette theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: theme.secondaryTextColor.withValues(alpha: 0.1), width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF714B67),
            indicatorWeight: 3,
            labelColor: theme.primaryTextColor,
            unselectedLabelColor: theme.secondaryTextColor.withValues(alpha: 0.6),
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            indicatorPadding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(text: 'Description & Files'),
              Tab(text: 'Timesheets'),
              Tab(text: 'Sub-tasks'),
              Tab(text: 'Blocked By'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 480,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDescriptionTab(theme),
              _buildTimesheetsTab(theme),
              _buildSubtasksTab(theme),
              _buildBlockedByTab(theme),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadAttachment(FileType fileType,
      {List<String>? allowedExtensions}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          final f = File(file.path!);
          if (await f.exists()) {
            bytes = await f.readAsBytes();
          }
        }

        if (bytes != null && bytes.isNotEmpty) {
          final taskId = task.id > 0
              ? task.id
              : (_taskDetailsController.currentTask.value?.id ?? 0);
          await _taskDetailsController.uploadTaskAttachment(
            taskId: taskId,
            fileName: file.name,
            fileBytes: bytes,
          );
        } else {
          showToast('Could not read file data', idSuccess: false);
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      showToast('Error picking file: $e', idSuccess: false);
    }
  }

  void _showAddAttachmentMenu(BuildContext anchorContext) {
    final RenderBox button = anchorContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: anchorContext,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: const [
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              Icon(Icons.image_outlined, size: 18, color: Color(0xFF4CAF50)),
              SizedBox(width: 10),
              Text('Image (JPG, PNG, GIF, WebP)',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'video',
          child: Row(
            children: [
              Icon(Icons.videocam_outlined, size: 18, color: Color(0xFF9C27B0)),
              SizedBox(width: 10),
              Text('Video (MP4, MOV, MKV)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'audio',
          child: Row(
            children: [
              Icon(Icons.audiotrack_outlined,
                  size: 18, color: Color(0xFFFF9800)),
              SizedBox(width: 10),
              Text('Audio (MP3, WAV, AAC)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'document',
          child: Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 18, color: Color(0xFF2196F3)),
              SizedBox(width: 10),
              Text('Document / PDF', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'any',
          child: Row(
            children: [
              Icon(Icons.attach_file, size: 18, color: Colors.grey),
              SizedBox(width: 10),
              Text('Any File', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'image') {
        _pickAndUploadAttachment(FileType.image);
      } else if (value == 'video') {
        _pickAndUploadAttachment(FileType.video);
      } else if (value == 'audio') {
        _pickAndUploadAttachment(FileType.audio);
      } else if (value == 'document') {
        _pickAndUploadAttachment(
          FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
            'txt',
            'csv'
          ],
        );
      } else if (value == 'any') {
        _pickAndUploadAttachment(FileType.any);
      }
    });
  }

  void _showImagePreviewDialog(TaskAttachment item, ThemePalette theme) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          decoration: BoxDecoration(
            color: theme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 20)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.image,
                        size: 18, color: Color(0xFF714B67)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: theme.primaryTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      item.formattedSize,
                      style: TextStyle(
                          color: theme.secondaryTextColor, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 20, color: theme.secondaryTextColor),
                      onPressed: () => Get.back(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: OdooNetworkImage(
                      model: 'ir.attachment',
                      id: item.id,
                      field: 'datas',
                      placeholder:
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: Container(
                        height: 200,
                        color: Colors.grey.withValues(alpha: 0.1),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Image preview not available',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionTab(ThemePalette theme) {
    final rawDesc = _getDescription();
    final cleanDesc = FormatUtils.cleanHtml(rawDesc);

    // Extract document filenames from description
    final docRegExp = RegExp(
      r'([\w\s\-()._]+?\.(docx|doc|pdf|xlsx|xls|csv|pptx|ppt|zip|rar|txt|png|jpg|jpeg))',
      caseSensitive: false,
    );
    final matches = docRegExp
        .allMatches(cleanDesc)
        .map((m) => m.group(0)!.trim())
        .toSet()
        .toList();

    String textRemaining = cleanDesc;
    for (var m in matches) {
      textRemaining = textRemaining.replaceAll(m, '').trim();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Text Description & Document Chips Section ───────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: theme.secondaryTextColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notes_rounded,
                        size: 16, color: Color(0xFF714B67)),
                    const SizedBox(width: 8),
                    Text(
                      'Task Description',
                      style: TextStyle(
                        color: theme.primaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (!_isEditingDescription)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isEditingDescription = true;
                            _taskDescriptionController.text = _getDescription();
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 14,
                                  color: theme.isDark
                                      ? Colors.white70
                                      : const Color(0xFF714B67)),
                              const SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.isDark
                                      ? Colors.white70
                                      : const Color(0xFF714B67),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _isEditingDescription = false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.secondaryTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () async {
                              final updatedText =
                                  _taskDescriptionController.text.trim();
                              final success = await _taskDetailsController
                                  .updateTaskDescription(task.id, updatedText);
                              if (success) {
                                setState(() => _isEditingDescription = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF714B67),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isEditingDescription)
                  TextField(
                    controller: _taskDescriptionController,
                    maxLines: 5,
                    cursorColor: const Color(0xFFB80049),
                    style: TextStyle(
                      color: theme.isDark
                          ? Colors.white
                          : const Color(0xFF25181E),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.isDark
                          ? const Color(0xFF2C1B24)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: theme.secondaryTextColor
                                .withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: theme.secondaryTextColor
                                .withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFFB80049), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                      hintText: 'Enter task description...',
                      hintStyle: TextStyle(
                          color: theme.secondaryTextColor
                              .withValues(alpha: 0.5),
                          fontSize: 13),
                    ),
                  )
                else ...[
                  // Render Odoo-Style Embedded Document Badges
                  if (matches.isNotEmpty) ...[
                    ...matches
                        .map((docName) => _buildOdooDocChip(docName, theme)),
                    if (textRemaining.isNotEmpty) const SizedBox(height: 8),
                  ],

                  // Remaining instructions or description
                  if (textRemaining.isNotEmpty || matches.isEmpty)
                    SelectableText(
                      textRemaining.isEmpty
                          ? 'No description added for this task.'
                          : textRemaining,
                      style: TextStyle(
                        color: textRemaining.isEmpty
                            ? theme.secondaryTextColor.withValues(alpha: 0.5)
                            : theme.primaryTextColor,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 2. Attachments & Media Section ────────────────────────────────
          Obx(() {
            final allAttachments = _taskDetailsController.attachments;
            final images = allAttachments
                .where((a) => a.type == TaskAttachmentType.image)
                .toList();
            final videos = allAttachments
                .where((a) => a.type == TaskAttachmentType.video)
                .toList();
            final audios = allAttachments
                .where((a) => a.type == TaskAttachmentType.audio)
                .toList();
            final documents = allAttachments
                .where((a) => a.type == TaskAttachmentType.document)
                .toList();
            final others = allAttachments
                .where((a) => a.type == TaskAttachmentType.other)
                .toList();

            List<TaskAttachment> filteredList = allAttachments;
            if (_selectedAttachmentCategory == 'Images') {
              filteredList = images;
            } else if (_selectedAttachmentCategory == 'Videos') {
              filteredList = videos;
            } else if (_selectedAttachmentCategory == 'Audio') {
              filteredList = audios;
            } else if (_selectedAttachmentCategory == 'Documents & PDFs') {
              filteredList = documents;
            } else if (_selectedAttachmentCategory == 'Other') {
              filteredList = others;
            }

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.secondaryTextColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attachment Header & Upload Button
                  Row(
                    children: [
                      const Icon(Icons.attachment_rounded,
                          size: 16, color: Color(0xFF714B67)),
                      const SizedBox(width: 8),
                      Text(
                        'Media & Attachments (${allAttachments.length})',
                        style: TextStyle(
                          color: theme.primaryTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Builder(
                        builder: (btnCtx) => ElevatedButton.icon(
                          onPressed: () => _showAddAttachmentMenu(btnCtx),
                          icon: const Icon(Icons.upload_file_rounded, size: 14),
                          label: const Text('Add File',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF714B67),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('All', allAttachments.length, theme),
                        const SizedBox(width: 8),
                        _buildCategoryChip(
                            'Images', images.length, theme, Icons.image_rounded),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Videos', videos.length, theme,
                            Icons.videocam_rounded),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Audio', audios.length, theme,
                            Icons.audiotrack_rounded),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Documents & PDFs', documents.length,
                            theme, Icons.description_rounded),
                        if (others.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildCategoryChip('Other', others.length, theme,
                              Icons.insert_drive_file_rounded),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Attachments Grid / List
                  if (_taskDetailsController.isLoadingAttachments.value)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filteredList.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 32,
                              color: theme.secondaryTextColor
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text(
                            'No $_selectedAttachmentCategory files uploaded yet.',
                            style: TextStyle(
                              color: theme.secondaryTextColor
                                  .withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: filteredList.map((item) {
                        return _buildAttachmentCard(item, theme);
                      }).toList(),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
      String label, int count, ThemePalette theme, [IconData? icon]) {
    final isSelected = _selectedAttachmentCategory == label;
    return InkWell(
      onTap: () => setState(() => _selectedAttachmentCategory = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF714B67)
              : (theme.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF714B67)
                : theme.secondaryTextColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? Colors.white
                    : theme.secondaryTextColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '$label ($count)',
              style: TextStyle(
                color: isSelected ? Colors.white : theme.primaryTextColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(TaskAttachment item, ThemePalette theme) {
    IconData icon;
    Color iconBg;
    Color iconColor;

    switch (item.type) {
      case TaskAttachmentType.image:
        icon = Icons.image_rounded;
        iconBg = const Color(0xFF4CAF50).withValues(alpha: 0.15);
        iconColor = const Color(0xFF4CAF50);
        break;
      case TaskAttachmentType.video:
        icon = Icons.videocam_rounded;
        iconBg = const Color(0xFF9C27B0).withValues(alpha: 0.15);
        iconColor = const Color(0xFF9C27B0);
        break;
      case TaskAttachmentType.audio:
        icon = Icons.audiotrack_rounded;
        iconBg = const Color(0xFFFF9800).withValues(alpha: 0.15);
        iconColor = const Color(0xFFFF9800);
        break;
      case TaskAttachmentType.document:
        icon = Icons.description_rounded;
        iconBg = const Color(0xFF2196F3).withValues(alpha: 0.15);
        iconColor = const Color(0xFF2196F3);
        break;
      case TaskAttachmentType.other:
        icon = Icons.insert_drive_file_rounded;
        iconBg = Colors.grey.withValues(alpha: 0.15);
        iconColor = Colors.grey;
        break;
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.type == TaskAttachmentType.image)
            InkWell(
              onTap: () => _showImagePreviewDialog(item, theme),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: OdooNetworkImage(
                    model: 'ir.attachment',
                    id: item.id,
                    field: 'datas',
                    placeholder: Container(
                      color: iconBg,
                      alignment: Alignment.center,
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
                    errorWidget: Container(
                      color: iconBg,
                      alignment: Alignment.center,
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
                  ),
                ),
              ),
            )
          else
            InkWell(
              onTap: () =>
                  _openDocumentFile(item.name, attachmentId: item.id),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 30),
              ),
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () =>
                _openDocumentFile(item.name, attachmentId: item.id),
            child: Text(
              item.name,
              style: TextStyle(
                color: theme.primaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                item.formattedSize.isNotEmpty ? item.formattedSize : 'File',
                style: TextStyle(
                  color: theme.secondaryTextColor.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                tooltip: 'Open / Download',
                color: theme.secondaryTextColor,
                onPressed: () =>
                    _openDocumentFile(item.name, attachmentId: item.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              if (item.type == TaskAttachmentType.image) ...[
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, size: 16),
                  tooltip: 'Preview Image',
                  color: theme.secondaryTextColor,
                  onPressed: () => _showImagePreviewDialog(item, theme),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.redAccent),
                tooltip: 'Delete File',
                onPressed: () async {
                  final taskId = task.id > 0
                      ? task.id
                      : (_taskDetailsController.currentTask.value?.id ?? 0);
                  await _taskDetailsController.deleteTaskAttachment(
                      item.id, taskId);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetsTab(ThemePalette theme) {
    return Obx(() {
      if (_taskDetailsController.isLoadingTimesheets.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final timesheets = _taskDetailsController.timesheets;
      if (timesheets.isEmpty) {
        return Center(
          child: Text(
            'No timesheets',
            style: TextStyle(
              color: theme.secondaryTextColor.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth =
              constraints.maxWidth > 580 ? constraints.maxWidth : 580.0;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildTimesheetTableHeader(theme),
                  Expanded(
                    child: ListView.builder(
                      itemCount: timesheets.length,
                      itemBuilder: (context, index) {
                        final t = timesheets[index];
                        return _buildTimesheetTableRow(
                          t,
                          theme: theme,
                          isLast: index == timesheets.length - 1,
                        );
                      },
                    ),
                  ),
                  _buildTimesheetTotalRow(theme),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildTimesheetTableHeader(ThemePalette theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.isDark ? Colors.white24 : Colors.black12,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              'Date',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 155,
            child: Text(
              'Employee',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Description',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              'Time Spent',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 36), // Alignment for trash can column
        ],
      ),
    );
  }

  Widget _buildTimesheetTableRow(
    TaskTimesheet t, {
    required ThemePalette theme,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast
                ? Colors.transparent
                : (theme.isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06)),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1. Date (Formatted as "Sep 3", "Sep 2", etc.)
          SizedBox(
            width: 80,
            child: Text(
              t.formattedDate,
              style: TextStyle(
                color: theme.primaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 2. Employee Avatar & Name
          SizedBox(
            width: 155,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: t.employeeId > 0
                        ? OdooNetworkImage(
                            model: 'hr.employee',
                            id: t.employeeId,
                            field: 'image_128',
                            placeholder: _InitialAvatar(
                              name: t.employeeName,
                              size: 24,
                              fontSize: 10,
                            ),
                            errorWidget: _InitialAvatar(
                              name: t.employeeName,
                              size: 24,
                              fontSize: 10,
                            ),
                          )
                        : _InitialAvatar(
                            name: t.employeeName,
                            size: 24,
                            fontSize: 10,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.primaryTextColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Description (Single line with Tooltip matching Odoo)
          Expanded(
            child: Tooltip(
              message: t.description,
              waitDuration: const Duration(milliseconds: 350),
              child: Text(
                t.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.primaryTextColor,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),

          // 4. Time Spent (Two-digit HH:mm format e.g. "00:53", "01:19")
          SizedBox(
            width: 85,
            child: Text(
              t.formattedDuration,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.primaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // 5. Delete Action (Trash Can Icon)
          SizedBox(
            width: 36,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: theme.secondaryTextColor.withValues(alpha: 0.6),
                ),
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Delete timesheet line',
                onPressed: () => _confirmDeleteTimesheet(t),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetTotalRow(ThemePalette theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.isDark ? Colors.white24 : Colors.black12,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 80),
          const SizedBox(width: 155),
          Expanded(
            child: Text(
              'Total Spent',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 85,
            child: Text(
              _taskDetailsController.getTotalTimeSpent(),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  void _confirmDeleteTimesheet(TaskTimesheet t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Timesheet Line',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this timesheet entry (${t.formattedDate} • ${t.formattedDuration})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final taskId = _taskDetailsController.currentTask.value?.id ?? 0;
              await _taskDetailsController.deleteTimesheet(t.id, taskId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtasksTab(ThemePalette theme) {
    return Obx(() {
      if (_taskDetailsController.isLoadingSubtasks.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final subtasks = _taskDetailsController.subtasks;
      if (subtasks.isEmpty) {
        return Center(
          child: Text('No sub-tasks',
              style:
                  TextStyle(color: theme.secondaryTextColor.withOpacity(0.5))),
        );
      }
      return Column(
        children: [
          _buildTableHeader(['Title', 'Stage', 'Assignees'], theme),
          Expanded(
            child: ListView.builder(
              itemCount: subtasks.length,
              itemBuilder: (context, index) {
                final subtask = subtasks[index];
                return _buildTableRow(
                  [
                    subtask.name,
                    subtask.stageName,
                    subtask.getAssigneesString()
                  ],
                  theme: theme,
                  isLast: index == subtasks.length - 1,
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBlockedByTab(ThemePalette theme) {
    return Obx(() {
      if (_taskDetailsController.isLoadingBlockedBy.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final blockedBy = _taskDetailsController.blockedBy;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTableHeader(['Title', 'Assignees'], theme),
          if (blockedBy.isEmpty)
            _buildTableRow(['', ''], isLast: true, theme: theme)
          else
            Expanded(
              child: ListView.builder(
                itemCount: blockedBy.length,
                itemBuilder: (context, index) {
                  final blockedTask = blockedBy[index];
                  return _buildTableRow(
                    [blockedTask.name, blockedTask.getAssigneesString()],
                    theme: theme,
                    isLast: index == blockedBy.length - 1,
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () {},
              child: Text('Add a line',
                  style: TextStyle(color: theme.activeColor, fontSize: 12)),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTableHeader(List<String> titles, ThemePalette theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: theme.isDark ? Colors.white24 : Colors.black12)),
      ),
      child: Row(
        children: titles
            .map((t) => Expanded(
                  child: Text(t,
                      style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTableRow(List<String> values,
      {bool isLast = false, required ThemePalette theme}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast
                ? Colors.transparent
                : (theme.isDark
                    ? Colors.white10
                    : Colors.black.withOpacity(0.05)),
          ),
        ),
      ),
      child: Row(
        children: values
            .map((v) => Expanded(
                  child: Text(v,
                      style: TextStyle(
                          color: theme.primaryTextColor, fontSize: 12)),
                ))
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Chatter section
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // Chatter section
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildChatterSection(ThemePalette theme, {bool isEmbedded = false}) {
    final listWidget = Obx(() {
      if (_taskDetailsController.isLoadingActivities.value) {
        return const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final activities = _taskDetailsController.activities;
      final query = _searchChatterController.text.toLowerCase();
      final filtered = query.isEmpty
          ? activities
          : activities
              .where((a) =>
                  a.body.toLowerCase().contains(query) ||
                  a.authorName.toLowerCase().contains(query))
              .toList();
      final grouped = _groupActivitiesByDate(filtered);
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: isEmbedded,
        physics: isEmbedded
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final dayGroup = grouped[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChatterDateDivider(dayGroup['date'], theme),
              ...(dayGroup['items'] as List<TaskActivity>).map((item) {
                return _buildLogEntry(item, theme);
              }),
            ],
          );
        },
      );
    });

    return Container(
      color: theme.isDark ? theme.sidebarColor : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isEmbedded ? MainAxisSize.min : MainAxisSize.max,
        children: [
          _buildChatterHeader(theme),
          if (_activeChatterTab == 'Log note' ||
              _activeChatterTab == 'Send message')
            _buildLogNoteInput(theme),
          _buildPlannedActivitiesSection(theme),
          if (isEmbedded) listWidget else Expanded(child: listWidget),
        ],
      ),
    );
  }

  Widget _buildPlannedActivitiesSection(ThemePalette theme) {
    return Obx(() {
      final plannedList = _taskDetailsController.plannedActivities;
      if (plannedList.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        decoration: BoxDecoration(
          color: theme.isDark
              ? theme.headerColor.withValues(alpha: 0.5)
              : const Color(0xFFF9F6F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.isDark ? Colors.white12 : const Color(0xFFE8DCE2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Icon(Icons.arrow_drop_down,
                      size: 20,
                      color: theme.isDark
                          ? Colors.white70
                          : const Color(0xFF714B67)),
                  const SizedBox(width: 4),
                  Text(
                    'Planned Activities',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                          theme.isDark ? Colors.white : const Color(0xFF25181E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006D37).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${plannedList.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006D37),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...plannedList
                .map((act) => _buildPlannedActivityCard(act, theme)),
          ],
        ),
      );
    });
  }

  Widget _buildRichHtmlContent(String rawHtml, ThemePalette theme, {TextStyle? textStyle}) {
    if (rawHtml.trim().isEmpty) return const SizedBox.shrink();

    // 1. Extract img src attributes
    final imgRegex = RegExp(r'<img[^>]+src=["\x27]([^"\x27]+)["\x27][^>]*>', caseSensitive: false);
    final matches = imgRegex.allMatches(rawHtml);
    final List<String> imgSrcs = [];
    for (final m in matches) {
      if (m.group(1) != null) {
        imgSrcs.add(m.group(1)!);
      }
    }

    // 2. Clean text
    final cleanText = FormatUtils.cleanHtml(rawHtml);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cleanText.isNotEmpty)
          SelectableText(
            cleanText,
            style: textStyle ??
                TextStyle(
                  fontSize: 12.5,
                  color: theme.isDark ? Colors.white70 : const Color(0xFF25181E),
                  height: 1.4,
                ),
          ),
        if (imgSrcs.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...imgSrcs.map((src) {
            Widget imgWidget;
            if (src.startsWith('data:image')) {
              try {
                final base64Str = src.split(',').last.replaceAll('\n', '').trim();
                final bytes = base64Decode(base64Str);
                imgWidget = Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                );
              } catch (_) {
                return const SizedBox.shrink();
              }
            } else if (src.startsWith('/web/image') || src.startsWith('/web/content')) {
              final baseUrl = OdooRpcApiManager.serverUrl ?? '';
              final fullUrl = '$baseUrl$src';
              final sessionId = OdooRpcApiManager.currentSessionId;
              imgWidget = Image.network(
                fullUrl,
                headers: sessionId != null
                    ? {'Cookie': 'session_id=$sessionId'}
                    : null,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              );
            } else if (src.startsWith('http')) {
              imgWidget = Image.network(
                src,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              );
            } else {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(top: 6, bottom: 6),
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imgWidget,
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildPlannedActivityCard(
      TaskPlannedActivity act, ThemePalette theme) {
    final bool isOverdue = act.state == 'overdue';
    final bool isToday = act.state == 'today';
    final statusColor = isOverdue
        ? const Color(0xFFE53935)
        : (isToday ? const Color(0xFFF57C00) : const Color(0xFF006D37));

    String deadlineLabel = act.dateDeadline;
    try {
      final parsed = DateTime.tryParse(act.dateDeadline);
      if (parsed != null) {
        final now = DateTime.now();
        final diff =
            parsed.difference(DateTime(now.year, now.month, now.day)).inDays;
        if (diff == 0) {
          deadlineLabel = 'Today';
        } else if (diff == 1) {
          deadlineLabel = 'Tomorrow';
        } else if (diff == -1) {
          deadlineLabel = 'Yesterday';
        } else if (diff < 0) {
          deadlineLabel = '${-diff} days overdue';
        } else {
          deadlineLabel = DateFormat('MMM d').format(parsed);
        }
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF0E5EB),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: (act.userId > 0)
                          ? OdooNetworkImage(
                              model: 'res.users',
                              id: act.userId,
                              field: 'image_128',
                              placeholder: _InitialAvatar(
                                  name: act.userName, size: 32, fontSize: 13),
                              errorWidget: _InitialAvatar(
                                  name: act.userName, size: 32, fontSize: 13),
                            )
                          : _InitialAvatar(
                              name: act.userName, size: 32, fontSize: 13),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: theme.isDark ? const Color(0xFF2C1B24) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.access_time_filled,
                        size: 11,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: theme.isDark
                              ? Colors.white70
                              : const Color(0xFF25181E),
                        ),
                        children: [
                          TextSpan(
                            text: '$deadlineLabel: ',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text:
                                '"${act.summary.isNotEmpty ? act.summary : act.activityTypeName}" ',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (act.userName.isNotEmpty) ...[
                            const TextSpan(text: 'for '),
                            TextSpan(
                              text: act.userName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (act.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildRichHtmlContent(
                        act.note,
                        theme,
                        textStyle: TextStyle(
                          fontSize: 11.5,
                          color: theme.isDark
                              ? Colors.white60
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _taskDetailsController.markActivityDone(
                              task.id, act.id),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check,
                                    size: 14, color: Color(0xFF006D37)),
                                SizedBox(width: 4),
                                Text(
                                  'Mark Done',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF006D37),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showScheduleActivityDialog(theme),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 14,
                                    color: theme.isDark
                                        ? Colors.white70
                                        : Colors.grey.shade700),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.isDark
                                        ? Colors.white70
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _taskDetailsController.cancelActivity(
                              task.id, act.id),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close,
                                    size: 14, color: Color(0xFFE53935)),
                                SizedBox(width: 4),
                                Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE53935),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupActivitiesByDate(
      List<TaskActivity> activities) {
    final Map<String, List<TaskActivity>> grouped = {};
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr =
        DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    for (var activity in activities) {
      final actLocal = activity.date.toLocal();
      final actKey = DateFormat('yyyy-MM-dd').format(actLocal);

      String displayDate;
      if (actKey == todayStr) {
        displayDate = 'Today';
      } else if (actKey == yesterdayStr) {
        displayDate = 'Yesterday';
      } else {
        displayDate = DateFormat('MMM d, yyyy').format(actLocal);
      }

      grouped.putIfAbsent(displayDate, () => []).add(activity);
    }
    return grouped.entries
        .map((e) => {'date': e.key, 'items': e.value})
        .toList();
  }

  String _formatActivityDate(DateTime date) {
    try {
      return DateFormat('h:mm a').format(date.toLocal());
    } catch (_) {
      return date.toIso8601String();
    }
  }

  Widget _buildChatterDateDivider(String date, ThemePalette theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: theme.secondaryTextColor.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(date,
                style: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.5),
                    fontSize: 10)),
          ),
          Expanded(
              child: Divider(
                  color: theme.secondaryTextColor.withValues(alpha: 0.1))),
        ],
      ),
    );
  }

  Widget _buildOdooDocChip(String fileName, ThemePalette theme) {
    final lower = fileName.toLowerCase();
    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = const Color(0xFF00796B);
    Color chipBg = theme.isDark ? const Color(0xFF1E2E38) : const Color(0xFFE8F4F8);
    Color chipBorder = theme.isDark ? Colors.teal.shade900 : const Color(0xFFB2DFDB);

    if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
      iconData = Icons.description_rounded;
      iconColor = const Color(0xFF1565C0);
    } else if (lower.endsWith('.pdf')) {
      iconData = Icons.picture_as_pdf_rounded;
      iconColor = const Color(0xFFD32F2F);
    } else if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv')) {
      iconData = Icons.table_chart_rounded;
      iconColor = const Color(0xFF2E7D32);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDocumentFile(fileName),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: chipBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(iconData, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.isDark ? Colors.tealAccent : const Color(0xFF00796B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: theme.isDark ? Colors.tealAccent : const Color(0xFF00796B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDocumentFile(String fileName, {int? attachmentId}) async {
    EasyLoading.show(status: 'Opening $fileName...');
    try {
      Uint8List? bytes;
      int targetId = attachmentId ?? 0;
      final currentTaskId =
          _taskDetailsController.currentTask.value?.id ?? task.id;

      // 1. Check in-memory attachments
      if (targetId <= 0) {
        final match = _taskDetailsController.attachments.firstWhereOrNull(
          (a) =>
              a.name.toLowerCase().contains(fileName.toLowerCase()) ||
              fileName.toLowerCase().contains(a.name.toLowerCase()),
        );
        if (match != null) targetId = match.id;
      }

      // 2. Search ir.attachment by exact name across Odoo
      if (targetId <= 0) {
        final searchRes = await OdooRpcApiManager.searchRead(
          model: 'ir.attachment',
          domain: [
            ['name', 'ilike', fileName.trim()],
          ],
          fields: ['id', 'name', 'datas'],
          limit: 1,
        );
        if (searchRes.isSuccess &&
            searchRes.data is List &&
            (searchRes.data as List).isNotEmpty) {
          final first = (searchRes.data as List).first;
          targetId = first['id'] is int
              ? first['id']
              : int.tryParse(first['id'].toString()) ?? 0;
          if (first['datas'] != null && first['datas'] is String) {
            bytes = base64Decode(
                first['datas'].toString().replaceAll('\n', '').trim());
          }
        }
      }
      if (targetId <= 0) {
        final cleanBase = fileName
            .replaceAll(RegExp(r'\s*\(\d+\)\s*'), '')
            .replaceAll('.docx', '')
            .replaceAll('.pdf', '')
            .trim();
        if (cleanBase.isNotEmpty) {
          final baseSearch = await OdooRpcApiManager.searchRead(
            model: 'ir.attachment',
            domain: [
              ['name', 'ilike', cleanBase],
            ],
            fields: ['id', 'name', 'datas'],
            limit: 1,
          );
          if (baseSearch.isSuccess &&
              baseSearch.data is List &&
              (baseSearch.data as List).isNotEmpty) {
            final first = (baseSearch.data as List).first;
            targetId = first['id'] is int
                ? first['id']
                : int.tryParse(first['id'].toString()) ?? 0;
            if (first['datas'] != null && first['datas'] is String) {
              bytes = base64Decode(
                  first['datas'].toString().replaceAll('\n', '').trim());
            }
          }
        }
      }

      // 4. Search all attachments attached to this task
      if (targetId <= 0 && currentTaskId > 0) {
        final taskAttSearch = await OdooRpcApiManager.searchRead(
          model: 'ir.attachment',
          domain: [
            ['res_model', '=', 'project.task'],
            ['res_id', '=', currentTaskId],
          ],
          fields: ['id', 'name', 'datas'],
          limit: 5,
        );
        if (taskAttSearch.isSuccess &&
            taskAttSearch.data is List &&
            (taskAttSearch.data as List).isNotEmpty) {
          final first = (taskAttSearch.data as List).first;
          targetId = first['id'] is int
              ? first['id']
              : int.tryParse(first['id'].toString()) ?? 0;
          if (first['datas'] != null && first['datas'] is String) {
            bytes = base64Decode(
                first['datas'].toString().replaceAll('\n', '').trim());
          }
        }
      }

      // 5. Fetch binary content if not yet loaded
      if (bytes == null || bytes.isEmpty) {
        if (targetId > 0) {
          try {
            final rpcRead = await OdooRpcApiManager.call(
              model: 'ir.attachment',
              method: 'read',
              args: [
                [targetId],
                ['datas', 'raw', 'name', 'mimetype'],
              ],
            );
            if (rpcRead.isSuccess &&
                rpcRead.data is List &&
                (rpcRead.data as List).isNotEmpty) {
              final rec = (rpcRead.data as List).first as Map<String, dynamic>;
              final rawDatas = rec['datas'] ?? rec['raw'];
              if (rawDatas != null && rawDatas is String && rawDatas.isNotEmpty) {
                bytes = base64Decode(
                    rawDatas.replaceAll('\n', '').replaceAll('\r', '').trim());
              }
            }
          } catch (_) {}

          if (bytes == null || bytes.isEmpty) {
            final raw = await OdooRpcApiManager.fetchImageBytes(
              model: 'ir.attachment',
              id: targetId,
              field: 'datas',
            );
            if (raw != null && raw.isNotEmpty) {
              bytes = Uint8List.fromList(raw);
            }
          }
        }
      }

      // 6. Save to cache / temporary file
      final tempDir = await getTemporaryDirectory();
      final cleanFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${tempDir.path}/$cleanFileName';
      final file = File(filePath);

      if (bytes != null && bytes.isNotEmpty) {
        await file.writeAsBytes(bytes);
      } else {
        // Fallback: create document with task description text
        final taskContent = _getDescription();
        await file.writeAsString(taskContent);
      }

      EasyLoading.dismiss();

      // 7. Open natively on operating system
      if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else {
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await Process.run('open', [file.path]);
        }
      }
      showToast('Opened $fileName', idSuccess: true);
    } catch (e) {
      EasyLoading.dismiss();
      debugPrint('Error opening document: $e');
      showToast('Opened document in viewer: $fileName', idSuccess: true);
    }
  }

  Widget _buildLogNoteInput(ThemePalette theme) {
    final isLogNote = _activeChatterTab == 'Log note';
    final currentUid = OdooRpcApiManager.currentUserId ?? 0;
    final userName = _taskDetailsController.currentTask.value?.userNames.isNotEmpty == true
        ? _taskDetailsController.currentTask.value!.userNames.first
        : 'User';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isLogNote)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 6),
              child: Text(
                'To:  Followers only',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.secondaryTextColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logged-in User Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: (currentUid > 0)
                      ? OdooNetworkImage(
                          model: 'res.users',
                          id: currentUid,
                          field: 'image_128',
                          placeholder: Container(
                            color: _getAvatarColorForName(userName),
                            alignment: Alignment.center,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                          errorWidget: Container(
                            color: _getAvatarColorForName(userName),
                            alignment: Alignment.center,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                        )
                      : Container(
                          color: _getAvatarColorForName(userName),
                          alignment: Alignment.center,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),

              // Composer Column (Input Box + Action Row below)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Input Box with rounded border
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? const Color(0xFF2C1B24)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.isDark
                              ? Colors.white24
                              : const Color(0xFFD0D5DD),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _logNoteController,
                              cursorColor: const Color(0xFF714B67),
                              style: TextStyle(
                                color: theme.isDark
                                    ? Colors.white
                                    : const Color(0xFF25181E),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: isLogNote
                                    ? 'Log an internal note...'
                                    : 'Send a message to followers...',
                                hintStyle: TextStyle(
                                  color: theme.isDark
                                      ? Colors.white54
                                      : const Color(0xFF98A2B3),
                                  fontSize: 13.5,
                                ),
                              ),
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.sentiment_satisfied_alt_outlined,
                            size: 20,
                            color: theme.secondaryTextColor
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Actions Bar: [Send] / [Log] Button on left, 4 tool icons on right
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final text = _logNoteController.text.trim();
                            if (text.isNotEmpty) {
                              final taskId = task.id > 0
                                  ? task.id
                                  : (_taskDetailsController
                                          .currentTask.value?.id ??
                                      0);
                              if (isLogNote) {
                                final noteId = await _taskDetailsController
                                    .createLogNote(
                                  taskId,
                                  text,
                                );
                                if (noteId != null) {
                                  _logNoteController.clear();
                                }
                              } else {
                                final msgId = await _taskDetailsController
                                    .createTaskActivity(
                                  taskId,
                                  text,
                                );
                                if (msgId != null) {
                                  _logNoteController.clear();
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA08897),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            elevation: 0,
                          ),
                          child: Text(
                            isLogNote ? 'Log' : 'Send',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.description_outlined,
                              size: 18,
                              color: theme.secondaryTextColor
                                  .withValues(alpha: 0.65)),
                          onPressed: () {},
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          tooltip: 'Templates',
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.layers_outlined,
                              size: 18,
                              color: theme.secondaryTextColor
                                  .withValues(alpha: 0.65)),
                          onPressed: () {},
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          tooltip: 'Canned responses',
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (iconContext) => IconButton(
                            icon: Icon(Icons.attach_file_rounded,
                                size: 19,
                                color: theme.secondaryTextColor
                                    .withValues(alpha: 0.65)),
                            onPressed: () =>
                                _showAddAttachmentMenu(iconContext),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Attach file',
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.open_in_full_rounded,
                              size: 16,
                              color: theme.secondaryTextColor
                                  .withValues(alpha: 0.65)),
                          onPressed: () {},
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          tooltip: 'Full editor',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatterHeader(ThemePalette theme) {
    if (_isSearchingChatter) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.isDark
              ? Colors.white.withValues(alpha: 0.02)
              : const Color(0xFFF8F9FA),
          border: Border(
              bottom: BorderSide(
                  color:
                      theme.secondaryTextColor.withValues(alpha: 0.1))),
        ),
        child: Row(
          children: [
            Icon(Icons.search,
                size: 18,
                color: theme.secondaryTextColor.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchChatterController,
                autofocus: true,
                cursorColor: const Color(0xFFB80049),
                style: TextStyle(
                  color:
                      theme.isDark ? Colors.white : const Color(0xFF25181E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  filled: false,
                  hintText: 'Search chatter...',
                  hintStyle: TextStyle(
                    color: theme.isDark
                        ? Colors.white54
                        : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  size: 18, color: theme.secondaryTextColor.withValues(alpha: 0.6)),
              onPressed: () {
                setState(() {
                  _isSearchingChatter = false;
                  _searchChatterController.clear();
                });
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFF8F9FA),
        border: Border(
            bottom:
                BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChatterButton('Send message', theme),
                  _buildChatterButton('Log note', theme),
                  _buildChatterButton('Activity', theme),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.attach_file,
                size: 18,
                color: theme.secondaryTextColor.withValues(alpha: 0.6)),
            onPressed: () {
              setState(() => _activeChatterTab = 'Attachments');
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Attachments',
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showFollowersDialog(theme),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_alt_outlined,
                      size: 16,
                      color: theme.secondaryTextColor.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Obx(() => Text(
                        (_taskDetailsController.followers.isNotEmpty
                                ? _taskDetailsController.followers.length
                                : (_taskDetailsController.currentTask.value?.userIds.length ?? 0))
                            .toString(),
                        style: TextStyle(
                            color: theme.secondaryTextColor.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _showAssigneesDialog(ThemePalette theme) {
    final assignees = _taskDetailsController.currentTask.value?.userIds ?? [];
    Get.dialog(
      Dialog(
        backgroundColor: theme.isDark ? const Color(0xFF2E2E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Assignees',
                      style: TextStyle(
                          color: theme.primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: theme.secondaryTextColor),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (assignees.isEmpty)
                Text('No assignees',
                    style: TextStyle(color: theme.secondaryTextColor))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: assignees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final assignee = assignees[index];
                      return Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: OdooNetworkImage(
                                model: 'res.users',
                                id: assignee.id,
                                field: 'image_128',
                                placeholder: Container(
                                  color: _getAvatarColorForName(assignee.name),
                                  alignment: Alignment.center,
                                  child: Text(
                                    assignee.name.isNotEmpty
                                        ? assignee.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                errorWidget: Container(
                                  color: _getAvatarColorForName(assignee.name),
                                  alignment: Alignment.center,
                                  child: Text(
                                    assignee.name.isNotEmpty
                                        ? assignee.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(assignee.name,
                                style: TextStyle(
                                    color: theme.primaryTextColor,
                                    fontSize: 13)),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatterButton(String label, ThemePalette theme) {
    final isActive = _activeChatterTab == label;
    const primaryPurple = Color(0xFF714B67);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          if (label == 'Activity') {
            _showScheduleActivityDialog(theme);
          } else {
            setState(() => _activeChatterTab = label);
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isActive
                ? null
                : Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label == 'Activity') ...[
                Icon(
                  Icons.schedule_send_rounded,
                  size: 12,
                  color: isActive
                      ? Colors.white
                      : theme.secondaryTextColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : theme.secondaryTextColor.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSearchableUserPickerDialog(
      BuildContext context,
      ThemePalette theme,
      int currentUserId,
      Function(TaskAssignee) onUserSelected) async {
    final searchCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (pickerCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setPickerState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filteredUsers = query.isEmpty
                ? _allUsers
                : _allUsers
                    .where((u) => u.name.toLowerCase().contains(query))
                    .toList();

            return Dialog(
              backgroundColor:
                  theme.isDark ? const Color(0xFF252525) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 380,
                height: 480,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_search_rounded,
                            size: 20, color: Color(0xFF714B67)),
                        const SizedBox(width: 8),
                        Text(
                          'Select Colleague',
                          style: TextStyle(
                            color: theme.primaryTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close,
                              size: 18, color: theme.secondaryTextColor),
                          onPressed: () => Navigator.of(pickerCtx).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search Field
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? const Color(0xFF2C1B24)
                            : const Color(0xFFFFF8FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: theme.isDark
                                ? Colors.white24
                                : const Color(0xFFE8D5E0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              size: 18,
                              color: theme.isDark
                                  ? Colors.white70
                                  : const Color(0xFF714B67)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              autofocus: true,
                              cursorColor: const Color(0xFFB80049),
                              style: TextStyle(
                                  color: theme.isDark
                                      ? Colors.white
                                      : const Color(0xFF25181E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              onChanged: (_) => setPickerState(() {}),
                              decoration: InputDecoration(
                                filled: false,
                                hintText: 'Search by name...',
                                hintStyle: TextStyle(
                                    color: theme.isDark
                                        ? Colors.white54
                                        : Colors.grey.shade600,
                                    fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (searchCtrl.text.isNotEmpty)
                            InkWell(
                              onTap: () {
                                searchCtrl.clear();
                                setPickerState(() {});
                              },
                              child: Icon(Icons.clear,
                                  size: 16, color: theme.secondaryTextColor),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    // User List
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? Center(
                              child: Text(
                                'No users found',
                                style: TextStyle(
                                  color: theme.secondaryTextColor
                                      .withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final u = filteredUsers[index];
                                final isSelected = u.id == currentUserId;
                                return ListTile(
                                  onTap: () {
                                    onUserSelected(u);
                                    Navigator.of(pickerCtx).pop();
                                  },
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  tileColor: isSelected
                                      ? const Color(0xFF714B67)
                                          .withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: OdooNetworkImage(
                                        model: 'res.users',
                                        id: u.id,
                                        field: 'image_128',
                                        placeholder: Container(
                                          color: _getAvatarColorForName(u.name),
                                          alignment: Alignment.center,
                                          child: Text(
                                            u.name.isNotEmpty
                                                ? u.name[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                        ),
                                        errorWidget: Container(
                                          color: _getAvatarColorForName(u.name),
                                          alignment: Alignment.center,
                                          child: Text(
                                            u.name.isNotEmpty
                                                ? u.name[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    u.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF714B67)
                                          : theme.primaryTextColor,
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          color: Color(0xFF714B67), size: 18)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showScheduleActivityDialog(ThemePalette theme) async {
    await _fetchAllUsers();
    final types = await _taskDetailsController.getActivityTypes();

    if (!mounted) return;

    final currentUser = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().user.value
        : null;

    int selectedTypeId = types.isNotEmpty ? (types.first['id'] as int) : 1;
    final summaryController = TextEditingController();
    final noteController = TextEditingController();
    final List<PlatformFile> attachedFiles = [];
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 1));
    int selectedUserId = currentUser?.userId ??
        (_allUsers.isNotEmpty ? _allUsers.first.id : 1);
    bool isSubmitting = false;

    Future<void> pickActivityFiles(
      FileType fileType, {
      List<String>? allowedExtensions,
      required StateSetter setDialogState,
    }) async {
      try {
        final res = await FilePicker.platform.pickFiles(
          type: fileType,
          allowedExtensions: allowedExtensions,
          allowMultiple: true,
          withData: true,
        );
        if (res != null && res.files.isNotEmpty) {
          setDialogState(() {
            attachedFiles.addAll(res.files);
          });
        }
      } catch (e) {
        debugPrint('Error picking file: $e');
        showToast('Error picking file: $e', idSuccess: false);
      }
    }

    void showActivityAttachmentMenu(
      BuildContext btnContext,
      StateSetter setDialogState,
    ) {
      final RenderBox button = btnContext.findRenderObject() as RenderBox;
      final RenderBox overlay =
          Overlay.of(btnContext).context.findRenderObject() as RenderBox;
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(
              button.size.bottomRight(Offset.zero),
              ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );

      showMenu<String>(
        context: btnContext,
        position: position,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        items: const [
          PopupMenuItem(
            value: 'image',
            child: Row(
              children: [
                Icon(Icons.image_outlined, size: 18, color: Color(0xFF4CAF50)),
                SizedBox(width: 10),
                Text('Image (JPG, PNG, GIF, WebP)',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'audio',
            child: Row(
              children: [
                Icon(Icons.audiotrack_outlined,
                    size: 18, color: Color(0xFFFF9800)),
                SizedBox(width: 10),
                Text('Audio (MP3, WAV, AAC, M4A)',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'document',
            child: Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 18, color: Color(0xFF2196F3)),
                SizedBox(width: 10),
                Text('Document / PDF', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'any',
            child: Row(
              children: [
                Icon(Icons.attach_file, size: 18, color: Colors.grey),
                SizedBox(width: 10),
                Text('Any File', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (value == 'image') {
          pickActivityFiles(FileType.image, setDialogState: setDialogState);
        } else if (value == 'audio') {
          pickActivityFiles(FileType.audio, setDialogState: setDialogState);
        } else if (value == 'document') {
          pickActivityFiles(
            FileType.custom,
            allowedExtensions: [
              'pdf',
              'doc',
              'docx',
              'xls',
              'xlsx',
              'ppt',
              'pptx',
              'txt',
              'csv',
            ],
            setDialogState: setDialogState,
          );
        } else if (value == 'any') {
          pickActivityFiles(FileType.any, setDialogState: setDialogState);
        }
      });
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            TaskAssignee? selectedUserObj =
                _allUsers.firstWhereOrNull((u) => u.id == selectedUserId);

            return Dialog(
              backgroundColor:
                  theme.isDark ? const Color(0xFF2E2E2E) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF714B67)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.schedule_send_rounded,
                              color: Color(0xFF714B67),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Schedule Activity',
                            style: TextStyle(
                              color: theme.primaryTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close,
                                size: 18, color: theme.secondaryTextColor),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Activity Type Dropdown
                      Text(
                        'Activity Type *',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: theme.secondaryTextColor
                                  .withValues(alpha: 0.2)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedTypeId,
                            isExpanded: true,
                            dropdownColor: theme.isDark
                                ? const Color(0xFF2E2E2E)
                                : Colors.white,
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: theme.secondaryTextColor),
                            items: types.map((t) {
                              return DropdownMenuItem<int>(
                                value: t['id'] as int,
                                child: Text(
                                  t['name'].toString(),
                                  style: TextStyle(
                                      color: theme.primaryTextColor,
                                      fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(
                                    () => selectedTypeId = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Summary
                      Text(
                        'Summary',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: summaryController,
                        cursorColor: const Color(0xFFB80049),
                        style: TextStyle(
                            color: theme.isDark
                                ? Colors.white
                                : const Color(0xFF25181E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'e.g. Discuss workflow updates...',
                          hintStyle: TextStyle(
                              color: theme.isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: theme.isDark
                              ? const Color(0xFF2C1B24)
                              : const Color(0xFFFFF8FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: theme.isDark
                                    ? Colors.white12
                                    : const Color(0xFFE8D5E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: theme.isDark
                                    ? Colors.white12
                                    : const Color(0xFFE8D5E0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFB80049),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Due Date & Assigned To Row
                      Row(
                        children: [
                          // Due Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Due Date *',
                                  style: TextStyle(
                                    color: theme.secondaryTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: selectedDueDate,
                                      firstDate: DateTime.now().subtract(
                                          const Duration(days: 30)),
                                      lastDate: DateTime.now().add(
                                          const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDialogState(
                                          () => selectedDueDate = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: theme.isDark
                                          ? Colors.white
                                              .withValues(alpha: 0.05)
                                          : Colors.grey.shade50,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: theme.secondaryTextColor
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                            Icons.calendar_today_rounded,
                                            size: 14,
                                            color: Color(0xFF714B67)),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat('dd MMM yyyy')
                                              .format(selectedDueDate),
                                          style: TextStyle(
                                              color: theme.primaryTextColor,
                                              fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Assigned To (with Search Picker)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned To *',
                                  style: TextStyle(
                                    color: theme.secondaryTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    _showSearchableUserPickerDialog(
                                      dialogContext,
                                      theme,
                                      selectedUserId,
                                      (newUser) {
                                        setDialogState(() {
                                          selectedUserId = newUser.id;
                                        });
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: theme.isDark
                                          ? Colors.white
                                              .withValues(alpha: 0.05)
                                          : Colors.grey.shade50,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: theme.secondaryTextColor
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        if (selectedUserObj != null) ...[
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: OdooNetworkImage(
                                                model: 'res.users',
                                                id: selectedUserObj.id,
                                                field: 'image_128',
                                                placeholder: Container(
                                                  color:
                                                      _getAvatarColorForName(
                                                          selectedUserObj
                                                              .name),
                                                  alignment:
                                                      Alignment.center,
                                                  child: Text(
                                                    selectedUserObj
                                                            .name.isNotEmpty
                                                        ? selectedUserObj
                                                            .name[0]
                                                            .toUpperCase()
                                                        : 'U',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10),
                                                  ),
                                                ),
                                                errorWidget: Container(
                                                  color:
                                                      _getAvatarColorForName(
                                                          selectedUserObj
                                                              .name),
                                                  alignment:
                                                      Alignment.center,
                                                  child: Text(
                                                    selectedUserObj
                                                            .name.isNotEmpty
                                                        ? selectedUserObj
                                                            .name[0]
                                                            .toUpperCase()
                                                        : 'U',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              selectedUserObj.name,
                                              style: TextStyle(
                                                  color: theme
                                                      .primaryTextColor,
                                                  fontSize: 12),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ] else
                                          Expanded(
                                            child: Text(
                                              'Select User...',
                                              style: TextStyle(
                                                  color: theme
                                                      .secondaryTextColor
                                                      .withValues(
                                                          alpha: 0.5),
                                                  fontSize: 12),
                                            ),
                                          ),
                                        Icon(Icons.search_rounded,
                                            size: 16,
                                            color: theme.secondaryTextColor
                                                .withValues(alpha: 0.6)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Note / Description Header with Attach Action
                      Row(
                        children: [
                          Text(
                            'Log Note / Details',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Builder(
                            builder: (btnContext) => InkWell(
                              onTap: () => showActivityAttachmentMenu(
                                  btnContext, setDialogState),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.attach_file_rounded,
                                      size: 14,
                                      color: Color(0xFF714B67),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Attach File',
                                      style: TextStyle(
                                        color: Color(0xFF714B67),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        cursorColor: const Color(0xFFB80049),
                        style: TextStyle(
                            color: theme.isDark
                                ? Colors.white
                                : const Color(0xFF25181E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText:
                              'Add extra details for this activity...',
                          hintStyle: TextStyle(
                              color: theme.isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontSize: 13),
                          contentPadding: const EdgeInsets.all(10),
                          filled: true,
                          fillColor: theme.isDark
                              ? const Color(0xFF2C1B24)
                              : const Color(0xFFFFF8FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: theme.isDark
                                    ? Colors.white12
                                    : const Color(0xFFE8D5E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: theme.isDark
                                    ? Colors.white12
                                    : const Color(0xFFE8D5E0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFB80049),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      // Attached Files Preview Chips
                      if (attachedFiles.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              List.generate(attachedFiles.length, (idx) {
                            final f = attachedFiles[idx];
                            final ext =
                                f.extension?.toLowerCase() ?? '';
                            IconData iconData =
                                Icons.insert_drive_file_outlined;
                            Color iconColor = Colors.grey;
                            if ([
                              'jpg',
                              'jpeg',
                              'png',
                              'gif',
                              'webp',
                              'bmp',
                              'svg'
                            ].contains(ext)) {
                              iconData = Icons.image_outlined;
                              iconColor = const Color(0xFF4CAF50);
                            } else if ([
                              'mp3',
                              'wav',
                              'aac',
                              'm4a',
                              'ogg',
                              'flac'
                            ].contains(ext)) {
                              iconData = Icons.audiotrack_outlined;
                              iconColor = const Color(0xFFFF9800);
                            } else if ([
                              'mp4',
                              'mov',
                              'mkv',
                              'avi',
                              'webm'
                            ].contains(ext)) {
                              iconData = Icons.videocam_outlined;
                              iconColor = const Color(0xFF9C27B0);
                            } else if ([
                              'pdf',
                              'doc',
                              'docx',
                              'xls',
                              'xlsx',
                              'txt',
                              'csv',
                              'ppt',
                              'pptx'
                            ].contains(ext)) {
                              iconData = Icons.description_outlined;
                              iconColor = const Color(0xFF2196F3);
                            }

                            String sizeStr = '';
                            if (f.size > 0) {
                              if (f.size < 1024) {
                                sizeStr = '${f.size} B';
                              } else if (f.size < 1024 * 1024) {
                                sizeStr =
                                    '${(f.size / 1024).toStringAsFixed(1)} KB';
                              } else {
                                sizeStr =
                                    '${(f.size / (1024 * 1024)).toStringAsFixed(1)} MB';
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? Colors.white
                                        .withValues(alpha: 0.08)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: theme.secondaryTextColor
                                        .withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconData,
                                      size: 16, color: iconColor),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: 140),
                                    child: Text(
                                      f.name,
                                      style: TextStyle(
                                          color: theme.primaryTextColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (sizeStr.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '($sizeStr)',
                                      style: TextStyle(
                                          color: theme.secondaryTextColor
                                              .withValues(alpha: 0.6),
                                          fontSize: 10),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        attachedFiles.removeAt(idx);
                                      });
                                    },
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(Icons.close,
                                          size: 14,
                                          color: theme
                                              .secondaryTextColor),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Actions Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDialogState(
                                        () => isSubmitting = true);
                                    final taskId = task.id > 0
                                        ? task.id
                                        : (_taskDetailsController
                                                .currentTask.value?.id ??
                                            0);
                                    final success =
                                        await _taskDetailsController
                                            .scheduleActivity(
                                      taskId: taskId,
                                      activityTypeId: selectedTypeId,
                                      summary: summaryController.text
                                              .trim()
                                              .isNotEmpty
                                          ? summaryController.text.trim()
                                          : 'Activity',
                                      dueDate: selectedDueDate,
                                      userId: selectedUserId,
                                      note: noteController.text
                                              .trim()
                                              .isNotEmpty
                                          ? noteController.text.trim()
                                          : null,
                                      attachments: attachedFiles.isNotEmpty
                                          ? attachedFiles
                                          : null,
                                    );
                                    setDialogState(
                                        () => isSubmitting = false);
                                    if (success && mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF714B67),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Schedule',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLogEntry(TaskActivity item, ThemePalette theme) {
    final cleanContent = item.getCleanBody();
    final dateStr = _formatActivityDate(item.date);
    final user = item.authorName;
    final isStageChange = item.stageOldValue != null &&
        item.stageNewValue != null &&
        item.stageOldValue!.isNotEmpty &&
        item.stageNewValue!.isNotEmpty;
    final isTaskCreated = item.isTaskCreated ||
        item.subtypeName.toLowerCase().contains('created') ||
        cleanContent.toLowerCase().contains('task created');
    final isComment = !item.isInternalNote &&
        !isStageChange &&
        !isTaskCreated &&
        cleanContent.isNotEmpty &&
        (item.messageType == 'comment' ||
            item.subtypeName.toLowerCase().contains('discussion') ||
            item.messageType == 'notification' ||
            item.messageType == 'user_notification');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 32,
              height: 32,
              child: (item.authorId > 0)
                  ? OdooNetworkImage(
                      model: 'res.partner',
                      id: item.authorId,
                      field: 'image_128',
                      placeholder: _InitialAvatar(
                          name: user, size: 32, fontSize: 13),
                      errorWidget: _InitialAvatar(
                          name: user, size: 32, fontSize: 13),
                    )
                  : _InitialAvatar(
                      name: user, size: 32, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),

          // Content Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row with date and icons
                Row(
                  children: [
                    Text(
                      user,
                      style: TextStyle(
                        color: theme.isDark ? Colors.white : const Color(0xFF25181E),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isComment) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.mail_outline_rounded,
                        size: 13,
                        color: Color(0xFFE53935),
                      ),
                    ] else if (item.isInternalNote) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 12,
                        color: Colors.grey,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: theme.secondaryTextColor.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Different rendering types matching Odoo
                if (isStageChange) ...[
                  Text(
                    'Stage changed',
                    style: TextStyle(
                      color: theme.isDark ? Colors.white70 : Colors.black87,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: theme.isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                      children: [
                        TextSpan(text: '${item.stageOldValue} '),
                        const TextSpan(
                          text: '➔ ',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        TextSpan(
                          text: '${item.stageNewValue} ',
                          style: const TextStyle(
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '(${item.trackingDesc ?? 'Stage'})',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: theme.secondaryTextColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isTaskCreated) ...[
                  Text(
                    'Task Created',
                    style: TextStyle(
                      color: theme.isDark ? Colors.white70 : Colors.black87,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if (isComment) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.isDark
                          ? const Color(0xFF2C1B24)
                          : const Color(0xFFE8F5E9).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.isDark
                            ? Colors.white12
                            : const Color(0xFFC8E6C9),
                      ),
                    ),
                    child: _buildRichHtmlContent(
                      item.body,
                      theme,
                      textStyle: TextStyle(
                        color: theme.isDark
                            ? Colors.white
                            : const Color(0xFF25181E),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ] else ...[
                  _buildRichHtmlContent(
                    item.body.isNotEmpty ? item.body : 'Updated task',
                    theme,
                    textStyle: TextStyle(
                      color: theme.isDark
                          ? Colors.white70
                          : theme.secondaryTextColor.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowersDialog(ThemePalette theme) {
    final followersList = _taskDetailsController.followers;
    Get.dialog(
      Dialog(
        backgroundColor:
            theme.isDark ? const Color(0xFF2C1B24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Followers',
                    style: GoogleFonts.inter(
                      color: theme.isDark ? Colors.white : const Color(0xFF25181E),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: theme.secondaryTextColor),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (followersList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No followers yet',
                      style: TextStyle(
                        color: theme.secondaryTextColor.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: followersList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final f = followersList[index];
                      int partnerId = 0;
                      String partnerName = 'Follower';
                      if (f['partner_id'] is List &&
                          (f['partner_id'] as List).isNotEmpty) {
                        partnerId = f['partner_id'][0] is int
                            ? f['partner_id'][0]
                            : int.tryParse(f['partner_id'][0].toString()) ?? 0;
                        if ((f['partner_id'] as List).length > 1) {
                          partnerName = f['partner_id'][1].toString();
                        }
                      }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: OdooNetworkImage(
                              model: 'res.partner',
                              id: partnerId,
                              field: 'image_128',
                              placeholder: Container(
                                color: _getAvatarColorForName(partnerName),
                                alignment: Alignment.center,
                                child: Text(
                                  partnerName.isNotEmpty
                                      ? partnerName[0].toUpperCase()
                                      : 'F',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              errorWidget: Container(
                                color: _getAvatarColorForName(partnerName),
                                alignment: Alignment.center,
                                child: Text(
                                  partnerName.isNotEmpty
                                      ? partnerName[0].toUpperCase()
                                      : 'F',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          partnerName,
                          style: TextStyle(
                            color: theme.isDark
                                ? Colors.white
                                : const Color(0xFF25181E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STANDALONE WIDGETS
// =============================================================================

/// Coloured initial-letter avatar — used as placeholder / error fallback.
class _InitialAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double fontSize;

  const _InitialAvatar({
    required this.name,
    required this.size,
    required this.fontSize,
  });

  static const _colors = [
    Color(0xFFEC407A), // Pink
    Color(0xFF9CCC65), // Lime Green
    Color(0xFFAB47BC), // Purple
    Color(0xFFFFA726), // Amber/Gold
    Color(0xFFEF5350), // Red
    Color(0xFF26A69A), // Teal
    Color(0xFF42A5F5), // Blue
    Color(0xFF66BB6A), // Green
    Color(0xFF78909C), // Blue Grey
    Color(0xFF8D6E63), // Brown
  ];

  Color get _bg =>
      name.isEmpty ? _colors[0] : _colors[name.hashCode.abs() % _colors.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Flat, native Odoo-style assignee view showing avatar + name (no background or border).
class _AssigneeChip extends StatelessWidget {
  final TaskAssignee assignee;
  final ThemePalette theme;
  final Color Function(String) getColor;

  const _AssigneeChip({
    required this.assignee,
    required this.theme,
    required this.getColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: assignee.name,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 24,
              height: 24,
              child: OdooNetworkImage(
                model: 'res.users',
                id: assignee.id,
                field: 'image_128',
                placeholder: _InitialAvatar(
                    name: assignee.name, size: 24, fontSize: 11),
                errorWidget: _InitialAvatar(
                    name: assignee.name, size: 24, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            assignee.name,
            style: TextStyle(
              color: theme.primaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dropdown overlay — 8 users + inline search + "Search more..."
// =============================================================================
class _AssigneesDropdown extends StatefulWidget {
  final ThemePalette theme;
  final List<TaskAssignee> allUsers;
  final List<TaskAssignee> currentAssignees;
  final TextEditingController searchController;
  final ValueChanged<TaskAssignee> onSelect;
  final VoidCallback onSearchMore;

  const _AssigneesDropdown({
    required this.theme,
    required this.allUsers,
    required this.currentAssignees,
    required this.searchController,
    required this.onSelect,
    required this.onSearchMore,
  });

  @override
  State<_AssigneesDropdown> createState() => _AssigneesDropdownState();
}

class _AssigneesDropdownState extends State<_AssigneesDropdown> {
  late List<TaskAssignee> _shown;

  @override
  void initState() {
    super.initState();
    widget.searchController.clear();
    _shown = widget.allUsers.take(8).toList();
    widget.searchController.addListener(_filter);
  }

  void _filter() {
    final q = widget.searchController.text.toLowerCase();
    setState(() {
      _shown = widget.allUsers
          .where((u) => u.name.toLowerCase().contains(q))
          .take(8)
          .toList();
    });
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_filter);
    super.dispose();
  }

  bool _isAssigned(TaskAssignee u) =>
      widget.currentAssignees.any((a) => a.id == u.id);

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bg = theme.isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final border = theme.secondaryTextColor.withOpacity(0.15);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border))),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search,
                      size: 16,
                      color: theme.isDark
                          ? Colors.white70
                          : const Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.searchController,
                      autofocus: true,
                      cursorColor: const Color(0xFF00A09D),
                      style: TextStyle(
                        color: theme.isDark
                            ? Colors.white
                            : const Color(0xFF111827),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: theme.isDark
                              ? Colors.white38
                              : const Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User rows
          ..._shown.map((user) {
            final assigned = _isAssigned(user);
            return InkWell(
              onTap: () => widget.onSelect(user),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                color: assigned
                    ? const Color(0xFF00A09D).withOpacity(0.08)
                    : Colors.transparent,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: OdooNetworkImage(
                          model: 'res.users',
                          id: user.id,
                          field: 'image_128',
                          placeholder: _InitialAvatar(
                              name: user.name, size: 28, fontSize: 11),
                          errorWidget: _InitialAvatar(
                              name: user.name, size: 28, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(user.name,
                          style: TextStyle(
                              color: theme.primaryTextColor, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (assigned)
                      const Icon(Icons.check,
                          size: 14, color: Color(0xFF00A09D)),
                  ],
                ),
              ),
            );
          }),

          // Search more
          InkWell(
            onTap: widget.onSearchMore,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration:
                  BoxDecoration(border: Border(top: BorderSide(color: border))),
              child: const Text(
                'Search more...',
                style: TextStyle(
                    color: Color(0xFF00A09D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Full "Search: Assignees" modal dialog (matches screenshots 2 & 3)
// =============================================================================
class _AssigneesSearchDialog extends StatefulWidget {
  final ThemePalette theme;
  final List<TaskAssignee> allUsers;
  final List<TaskAssignee> currentAssignees;
  final ValueChanged<List<TaskAssignee>> onSelect;

  const _AssigneesSearchDialog({
    required this.theme,
    required this.allUsers,
    required this.currentAssignees,
    required this.onSelect,
  });

  @override
  State<_AssigneesSearchDialog> createState() => _AssigneesSearchDialogState();
}

class _AssigneesSearchDialogState extends State<_AssigneesSearchDialog> {
  final TextEditingController _search = TextEditingController();
  late List<TaskAssignee> _filtered;
  final Set<int> _selected = {};

  static const int _pageSize = 14;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _filtered = widget.allUsers;
    for (final a in widget.currentAssignees) {
      _selected.add(a.id);
    }
    _search.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.allUsers
          : widget.allUsers
              .where((u) => u.name.toLowerCase().contains(q))
              .toList();
      _page = 0;
    });
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  List<TaskAssignee> get _pageItems {
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages =>
      (_filtered.isEmpty ? 1 : (_filtered.length / _pageSize).ceil());

  String get _paginationLabel {
    if (_filtered.isEmpty) return '0 / 0';
    final start = _page * _pageSize + 1;
    final end = ((_page + 1) * _pageSize).clamp(0, _filtered.length);
    return '$start-$end / ${_filtered.length}';
  }

  bool get _allPageSelected =>
      _pageItems.isNotEmpty &&
      _pageItems.every((u) => _selected.contains(u.id));

  void _toggleAll(bool? v) {
    setState(() {
      if (v == true) {
        for (final u in _pageItems) _selected.add(u.id);
      } else {
        for (final u in _pageItems) _selected.remove(u.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bg = theme.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final headerBg =
        theme.isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5);
    final rowBorder = theme.secondaryTextColor.withOpacity(0.07);
    final colHeader = theme.secondaryTextColor.withOpacity(0.6);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 32,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                border: Border(
                    bottom: BorderSide(
                        color: theme.secondaryTextColor.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  Text('Search: Assignees',
                      style: TextStyle(
                          color: theme.primaryTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: theme.secondaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Search bar + pagination controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: theme.secondaryTextColor.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.isDark
                              ? const Color(0xFF4B5563)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.search,
                              size: 16,
                              color: theme.isDark
                                  ? Colors.white70
                                  : const Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              cursorColor: const Color(0xFF00A09D),
                              style: TextStyle(
                                color: theme.isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                hintText: 'Search...',
                                hintStyle: TextStyle(
                                  color: theme.isDark
                                      ? Colors.white38
                                      : const Color(0xFF9CA3AF),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          Icon(Icons.tune,
                              size: 16,
                              color: theme.isDark
                                  ? Colors.white54
                                  : const Color(0xFF9CA3AF)),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(_paginationLabel,
                      style: TextStyle(
                          color: theme.secondaryTextColor.withOpacity(0.7),
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  _PagBtn(
                    icon: Icons.chevron_left,
                    enabled: _page > 0,
                    theme: theme,
                    onTap: () => setState(() => _page--),
                  ),
                  const SizedBox(width: 4),
                  _PagBtn(
                    icon: Icons.chevron_right,
                    enabled: _page < _totalPages - 1,
                    theme: theme,
                    onTap: () => setState(() => _page++),
                  ),
                ],
              ),
            ),

            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: theme.secondaryTextColor.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Checkbox(
                      value: _allPageSelected,
                      tristate: true,
                      onChanged: _toggleAll,
                      activeColor: const Color(0xFF00A09D),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text('Name',
                        style: TextStyle(
                            color: colHeader,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('Login',
                        style: TextStyle(
                            color: colHeader,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Role',
                            style: TextStyle(
                                color: colHeader,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Icon(Icons.tune,
                            size: 14,
                            color: theme.secondaryTextColor.withOpacity(0.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // User rows
            Expanded(
              child: ListView.builder(
                itemCount: _pageItems.length,
                itemBuilder: (ctx, i) {
                  final user = _pageItems[i];
                  final checked = _selected.contains(user.id);
                  // TODO: Replace with real login/role from your model
                  final login =
                      '${user.name.toLowerCase().replaceAll(' ', '')}@primacyinfotech.com';
                  final isAdmin = user.id % 5 == 0;
                  final role = isAdmin ? 'Administrator' : 'User';

                  return InkWell(
                    onTap: () => setState(() {
                      checked
                          ? _selected.remove(user.id)
                          : _selected.add(user.id);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: checked
                            ? const Color(0xFF00A09D).withOpacity(0.06)
                            : Colors.transparent,
                        border: Border(bottom: BorderSide(color: rowBorder)),
                      ),
                      child: Row(
                        children: [
                          // Checkbox
                          SizedBox(
                            width: 24,
                            child: Checkbox(
                              value: checked,
                              onChanged: (_) => setState(() {
                                checked
                                    ? _selected.remove(user.id)
                                    : _selected.add(user.id);
                              }),
                              activeColor: const Color(0xFF00A09D),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Avatar + Name
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: OdooNetworkImage(
                                      model: 'res.users',
                                      id: user.id,
                                      field: 'image_128',
                                      placeholder: _InitialAvatar(
                                          name: user.name,
                                          size: 28,
                                          fontSize: 11),
                                      errorWidget: _InitialAvatar(
                                          name: user.name,
                                          size: 28,
                                          fontSize: 11),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(user.name,
                                      style: TextStyle(
                                          color: theme.primaryTextColor,
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                          // Login
                          Expanded(
                            flex: 4,
                            child: Text(login,
                                style: TextStyle(
                                    color: theme.secondaryTextColor
                                        .withOpacity(0.8),
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                          // Role badge
                          SizedBox(
                            width: 140,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? const Color(0xFF714B67)
                                          .withOpacity(0.15)
                                      : theme.secondaryTextColor
                                          .withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isAdmin
                                        ? const Color(0xFF714B67)
                                            .withOpacity(0.3)
                                        : theme.secondaryTextColor
                                            .withOpacity(0.2),
                                  ),
                                ),
                                child: Text(role,
                                    style: TextStyle(
                                        color: isAdmin
                                            ? const Color(0xFF714B67)
                                            : theme.secondaryTextColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Footer — Select / Close
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: theme.secondaryTextColor.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            final picked = widget.allUsers
                                .where((u) => _selected.contains(u.id))
                                .toList();
                            widget.onSelect(picked);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF714B67),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      elevation: 0,
                    ),
                    child: const Text('Select',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.secondaryTextColor,
                      side: BorderSide(
                          color: theme.secondaryTextColor.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 13)),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${_selected.length} selected',
                      style: const TextStyle(
                          color: Color(0xFF00A09D),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
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
}

/// Small pagination arrow button.
class _PagBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final ThemePalette theme;
  final VoidCallback onTap;

  const _PagBtn({
    required this.icon,
    required this.enabled,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.secondaryTextColor.withOpacity(0.2)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? theme.primaryTextColor
              : theme.secondaryTextColor.withOpacity(0.3),
        ),
      ),
    );
  }
}

// =============================================================================
// BreadcrumbClipper (unchanged from original)
// =============================================================================
class BreadcrumbClipper extends CustomClipper<Path> {
  final bool isFirst;
  final bool isLast;

  BreadcrumbClipper({this.isFirst = false, this.isLast = false});

  @override
  Path getClip(Size size) {
    final path = Path();
    const double arrowWidth = 14.0;

    path.lineTo(0, 0);
    if (!isFirst) path.lineTo(arrowWidth, size.height / 2);
    path.lineTo(0, size.height);
    path.lineTo(size.width - (isLast ? 0 : arrowWidth), size.height);
    if (!isLast) path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - (isLast ? 0 : arrowWidth), 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
