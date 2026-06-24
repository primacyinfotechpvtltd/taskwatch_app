import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pi_task_watch/models/task_details_model.dart';
import 'package:pi_task_watch/controllers/controllers.dart';
import 'package:pi_task_watch/controllers/task_details_controller.dart';
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
  int _activeStageIndex = 0;
  String _activeChatterTab = 'Activity';
  final TextEditingController _logNoteController = TextEditingController();
  final TextEditingController _searchChatterController =
      TextEditingController();
  bool _isSearchingChatter = false;

  // ── Assignees dropdown state ──────────────────────────────────────────────
  final LayerLink _assigneesLayerLink = LayerLink();
  OverlayEntry? _assigneesOverlay;
  List<TaskAssignee> _allUsers = [];
  final TextEditingController _assigneeDropdownSearch = TextEditingController();
  bool _isLoadingUsers = false;

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
    await _taskDetailsController.loadAllTaskData(task.id);
    _updateActiveStageIndex();
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
    // TODO: replace with your real API call:
    // _allUsers = await _taskDetailsController.fetchAllUsers();
    final currentTask = _taskDetailsController.currentTask.value;
    _allUsers = List<TaskAssignee>.from(currentTask?.userIds ?? []);
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
                  onSelect: (user) {
                    _removeAssigneesOverlay();
                    // TODO: call API to add/remove assignee
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
        onSelect: (selected) {
          // TODO: call API to persist updated assignees
          Navigator.of(ctx).pop();
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
    const activeColor = Color(0xFF00A09D);
    final inactiveColor =
        theme.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0);
    final textColor = isActive ? Colors.white : theme.secondaryTextColor;

    return ClipPath(
      clipper: BreadcrumbClipper(isFirst: isFirst, isLast: isLast),
      child: Container(
        padding: EdgeInsets.fromLTRB(isFirst ? 20 : 34, 0, isLast ? 20 : 20, 0),
        height: 42,
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          gradient: isActive
              ? const LinearGradient(
                  colors: [activeColor, Color(0xFF00807E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
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
        ],
      ),
    );
  }

  String _getPlannedDateString() {
    final t = _taskDetailsController.currentTask.value;
    final start = t?.dateStart;
    final end = t?.dateDeadline;

    if (start == null && end == null) {
      return 'May 25, 10:30 AM  →  11:00 AM'; // Exact mockup fallback
    }
    if (start != null && end != null) {
      final startStr = DateFormat('MMM d, h:mm a').format(start);
      final isSameDay = start.year == end.year && start.month == end.month && start.day == end.day;
      final endStr = isSameDay ? DateFormat('h:mm a').format(end) : DateFormat('MMM d, h:mm a').format(end);
      return '$startStr  →  $endStr';
    }
    if (start != null) return DateFormat('MMM d, h:mm a').format(start);
    return DateFormat('MMM d, h:mm a').format(end!);
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
    return _buildCustomRow(
      label: 'Milestone',
      theme: theme,
      child: Text(
        'e.g. Product Launch',
        style: TextStyle(
          color: theme.secondaryTextColor.withOpacity(0.4),
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildPlannedDateRow(ThemePalette theme) {
    final dateStr = _getPlannedDateString();
    
    return _buildCustomRow(
      label: 'Planned Date',
      theme: theme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              dateStr,
              style: const TextStyle(
                color: Color(0xFFEF5350), // soft red/pink matching mockup
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.secondaryTextColor.withOpacity(0.15),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.sync,
              size: 14,
              color: theme.secondaryTextColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
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
            _buildInfoRow('Tags', '', theme: theme),
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
  Widget _buildAssigneesRow(ThemePalette theme) {
    final currentTask = _taskDetailsController.currentTask.value;
    final List<TaskAssignee> assignees = currentTask?.userIds ?? [];

    final List<Widget> items = [];
    items.addAll(assignees.map((assignee) => _AssigneeChip(
          assignee: assignee,
          theme: theme,
          getColor: _getAvatarColorForName,
        )));

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
                  color: const Color(0xFF00A09D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: const Color(0xFF00A09D).withOpacity(0.25)),
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

    // Group items into rows of exactly 3 with equal width using Expanded
    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 3) {
      final List<Widget> rowItems = [];
      for (int j = 0; j < 3; j++) {
        if (i + j < items.length) {
          rowItems.add(Expanded(child: items[i + j]));
        } else {
          rowItems.add(const Expanded(child: SizedBox()));
        }
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 3 < items.length ? 12.0 : 0.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: rowItems,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.only(top: 4), // Align vertically with first row
              child: Text(
                'Assignees',
                style: TextStyle(
                  color: theme.secondaryTextColor.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
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
                  color: theme.secondaryTextColor.withOpacity(0.1), width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF714B67),
            indicatorWeight: 3,
            labelColor: theme.primaryTextColor,
            unselectedLabelColor: theme.secondaryTextColor.withOpacity(0.6),
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            indicatorPadding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(text: 'Description'),
              Tab(text: 'Timesheets'),
              Tab(text: 'Sub-tasks'),
              Tab(text: 'Blocked By'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 400,
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

  Widget _buildDescriptionTab(ThemePalette theme) {
    final cleanDesc = FormatUtils.cleanHtml(_getDescription());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.isDark ? Colors.white10 : Colors.black12,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: SelectableText(
          cleanDesc.isEmpty ? 'No description available.' : cleanDesc,
          style: TextStyle(
              color: theme.primaryTextColor, fontSize: 13, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildTimesheetsTab(ThemePalette theme) {
    return Obx(() {
      if (_taskDetailsController.isLoadingTimesheets.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final timesheets = _taskDetailsController.timesheets;
      return Column(
        children: [
          _buildTableHeader(
              ['Date', 'Employee', 'Description', 'Time Spent'], theme),
          Expanded(
            child: timesheets.isEmpty
                ? Center(
                    child: Text('No timesheets',
                        style: TextStyle(
                            color: theme.secondaryTextColor.withOpacity(0.5))))
                : ListView.builder(
                    itemCount: timesheets.length,
                    itemBuilder: (context, index) {
                      final t = timesheets[index];
                      return _buildTableRow(
                        [t.date, t.employeeName, t.description, t.duration],
                        theme: theme,
                        isLast: index == timesheets.length - 1,
                      );
                    },
                  ),
          ),
          const Divider(color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Total Spent: ',
                    style: TextStyle(
                        color: theme.secondaryTextColor, fontSize: 12)),
                Text(
                  _taskDetailsController.getTotalTimeSpent(),
                  style: TextStyle(
                    color: theme.primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
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
              onTap: () {
                // TODO: Implement add blocked by task dialog
              },
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
  Widget _buildChatterSection(ThemePalette theme) {
    return Container(
      color: theme.isDark ? theme.sidebarColor : Colors.white,
      child: Column(
        children: [
          _buildChatterHeader(theme),
          if (_activeChatterTab == 'Log note') _buildLogNoteInput(theme),
          Expanded(
            child: Obx(() {
              if (_taskDetailsController.isLoadingActivities.value) {
                return const Center(child: CircularProgressIndicator());
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
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final dayGroup = grouped[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChatterDateDivider(dayGroup['date'], theme),
                      ...(dayGroup['items'] as List<TaskActivity>).map((item) {
                        return _buildLogEntry(
                          _formatActivityDate(item.date),
                          item.authorName,
                          item.body,
                          theme: theme,
                          isStageChange: item.messageType == 'notification',
                          color: item.messageType == 'notification'
                              ? Colors.blueAccent
                              : null,
                        );
                      }),
                    ],
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupActivitiesByDate(
      List<TaskActivity> activities) {
    final Map<String, List<TaskActivity>> grouped = {};
    for (var activity in activities) {
      final dateKey = DateFormat('MMM d, yyyy').format(activity.date.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(activity);
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
              child: Divider(color: theme.secondaryTextColor.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(date,
                style: TextStyle(
                    color: theme.secondaryTextColor.withOpacity(0.5),
                    fontSize: 10)),
          ),
          Expanded(
              child: Divider(color: theme.secondaryTextColor.withOpacity(0.1))),
        ],
      ),
    );
  }

  Widget _buildLogNoteInput(ThemePalette theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.isDark ? theme.headerColor : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _logNoteController,
            style: TextStyle(color: theme.primaryTextColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: _activeChatterTab == 'Log note'
                  ? 'Log an internal note...'
                  : 'Send a message...',
              hintStyle: TextStyle(
                  color: theme.secondaryTextColor.withOpacity(0.3),
                  fontSize: 13),
              border: InputBorder.none,
            ),
            maxLines: 4,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.attach_file,
                    size: 18, color: theme.secondaryTextColor.withOpacity(0.6)),
                const SizedBox(width: 16),
                Icon(Icons.emoji_emotions_outlined,
                    size: 18, color: theme.secondaryTextColor.withOpacity(0.6)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    if (_logNoteController.text.isNotEmpty) {
                      final noteId = await _taskDetailsController.createLogNote(
                        task.id,
                        _logNoteController.text,
                      );
                      if (noteId != null) _logNoteController.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF714B67),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                  child: Text(
                    _activeChatterTab == 'Log note' ? 'Log' : 'Send',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
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
              ? Colors.white.withOpacity(0.02)
              : const Color(0xFFF8F9FA),
          border: Border(
              bottom:
                  BorderSide(color: theme.secondaryTextColor.withOpacity(0.1))),
        ),
        child: Row(
          children: [
            Icon(Icons.search,
                size: 18, color: theme.secondaryTextColor.withOpacity(0.6)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchChatterController,
                autofocus: true,
                style: TextStyle(color: theme.primaryTextColor, fontSize: 13),
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search chatter...',
                  hintStyle: TextStyle(
                      color: theme.secondaryTextColor.withOpacity(0.3),
                      fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  size: 18, color: theme.secondaryTextColor.withOpacity(0.6)),
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
            ? Colors.white.withOpacity(0.02)
            : const Color(0xFFF8F9FA),
        border: Border(
            bottom:
                BorderSide(color: theme.secondaryTextColor.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildChatterButton('Send message', theme),
                _buildChatterButton('Log note', theme),
                _buildChatterButton('Activity', theme),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.search,
                size: 18, color: theme.secondaryTextColor.withOpacity(0.6)),
            onPressed: () => setState(() => _isSearchingChatter = true),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.person_add_outlined,
                size: 18, color: theme.secondaryTextColor.withOpacity(0.6)),
            onPressed: () => _showAssigneesDialog(theme),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          Text(
            (_taskDetailsController.currentTask.value?.userIds.length ?? 0)
                .toString(),
            style: TextStyle(
                color: theme.secondaryTextColor.withOpacity(0.6), fontSize: 12),
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
                                    style: TextStyle(
                                        color: theme.primaryTextColor,
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
                                    style: TextStyle(
                                        color: theme.primaryTextColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => setState(() => _activeChatterTab = label),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isActive
                ? null
                : Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive
                  ? Colors.white
                  : theme.secondaryTextColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogEntry(String date, String user, String content,
      {required ThemePalette theme, bool isStageChange = false, Color? color}) {
    final cleanContent = FormatUtils.cleanHtml(content);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 32,
              height: 32,
              color: theme.avatarColor.withOpacity(0.2),
              alignment: Alignment.center,
              child: Text(
                user.isNotEmpty ? user[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: theme.primaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(user,
                        style: TextStyle(
                            color: theme.primaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    Text(date,
                        style: TextStyle(
                            color: theme.secondaryTextColor.withOpacity(0.4),
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  cleanContent,
                  style: TextStyle(
                    color: isStageChange
                        ? const Color(0xFF00A09D)
                        : theme.secondaryTextColor.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight:
                        isStageChange ? FontWeight.w500 : FontWeight.normal,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border))),
            child: Row(
              children: [
                Icon(Icons.search,
                    size: 16, color: theme.secondaryTextColor.withOpacity(0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.searchController,
                    autofocus: true,
                    style:
                        TextStyle(color: theme.primaryTextColor, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                          color: theme.secondaryTextColor.withOpacity(0.35),
                          fontSize: 13),
                    ),
                  ),
                ),
              ],
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
                            ? Colors.white.withOpacity(0.05)
                            : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: theme.secondaryTextColor.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.search,
                              size: 16,
                              color: theme.secondaryTextColor.withOpacity(0.5)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              style: TextStyle(
                                  color: theme.primaryTextColor, fontSize: 13),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                hintText: 'Search...',
                                hintStyle: TextStyle(
                                    color: theme.secondaryTextColor
                                        .withOpacity(0.4),
                                    fontSize: 13),
                              ),
                            ),
                          ),
                          Icon(Icons.tune,
                              size: 16,
                              color: theme.secondaryTextColor.withOpacity(0.5)),
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
