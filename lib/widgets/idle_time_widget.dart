import 'dart:async';
import 'package:pi_task_watch/exports.dart';
import 'package:flutter/foundation.dart';
import 'package:pi_task_watch/models/idle_time_data.dart';
import 'package:pi_task_watch/controllers/timesheet_controller.dart';
import 'package:pi_task_watch/models/timesheet_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/widgets/compact_text_field.dart';
import 'package:pi_task_watch/theme/app_theme.dart';

class IdleTimeWidget extends StatefulWidget {
  final int idleTime;
  final VoidCallback? onError;
  final String? initialNote;

  const IdleTimeWidget({
    super.key,
    required this.idleTime,
    this.onError,
    this.initialNote,
  });

  @override
  State<IdleTimeWidget> createState() => _IdleTimeWidgetState();
}

class _IdleTimeWidgetState extends State<IdleTimeWidget> {
  IdleMode? _selectedMode;
  late final TextEditingController _noteController;
  final TextEditingController _projectSearchController =
      TextEditingController();
  final TextEditingController _employeeSearchController =
      TextEditingController();
  final TextEditingController _taskSearchController = TextEditingController();

  late int _currentIdleTime;
  Timer? _timer;

  // Selection state
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;

  List<TaskModel> _tasks = [];
  TaskModel? _selectedTask;

  List<UserModel> _employees = [];
  List<UserModel> _selectedEmployees = [];

  bool _isLoadingData = false;
  bool _isLoadingTasks = false;
  String? _errorMessage;

  final TrackerController _trackerController = Get.find<TrackerController>();
  final TaskController _taskController = Get.find<TaskController>();

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote ?? '');

    _currentIdleTime = widget.idleTime;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentIdleTime++;
        });
      }
    });

    _fetchProjects();
    // Employees are now fetched when "Discussion" is clicked
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noteController.dispose();
    _projectSearchController.dispose();
    _employeeSearchController.dispose();
    _taskSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoadingData = true);
    try {
      if (kDebugMode) print('📋 [PROJECTS] Fetching projects...');
      final projectController = Get.find<ProjectController>();
      await projectController.getAllProject();

      if (kDebugMode) {
        print(
            '📋 [PROJECTS] Raw project list count: ${projectController.projectList.length}');
        print(
            '📋 [PROJECTS] Project list data: ${projectController.projectList.map((p) => '${p.id}: ${p.name}').toList()}');
      }

      setState(() {
        final uniqueProjects = <int, ProjectModel>{};
        for (var p in projectController.projectList) {
          uniqueProjects[p.id] = p;
        }
        _projects = uniqueProjects.values.toList();

        if (kDebugMode) {
          print('📋 [PROJECTS] Unique projects count: ${_projects.length}');
          print(
              '📋 [PROJECTS] Projects available: ${_projects.map((p) => '${p.id}: ${p.name}').toList()}');
        }

        final currentProjectId =
            _trackerController.startWorkData.value?.project.id;
        if (currentProjectId != null && _projects.isNotEmpty) {
          _selectedProject = _projects.firstWhere(
            (p) => p.id == currentProjectId,
            orElse: () => _projects.first,
          );
        } else if (_projects.isNotEmpty) {
          _selectedProject = _projects.first;
        }

        if (_selectedProject != null) {
          _fetchTasksForProject(
            _selectedProject!.id,
            initialTaskId: _trackerController.startWorkData.value?.task.id,
          );
        }

        _isLoadingData = false;
      });
    } catch (e) {
      if (kDebugMode) print('🚨 [PROJECTS] Error fetching projects: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load projects. Please restart the app.';
      });
    }
  }

  Future<void> _fetchEmployees() async {
    // Skip if already loading or already have data
    if (_isLoadingData || _employees.isNotEmpty) return;

    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      print("👥 [EMPLOYEES] Fetching employees...");
      print("👥 [EMPLOYEES] Server URL: ${AppConstant.apiServerUrl}");
      final hasSession = OdooRpcApiManager.currentSessionId?.isNotEmpty == true;
      print("👥 [EMPLOYEES] Active Session: ${hasSession ? 'YES' : 'NO'}");

      // Try fetching with all needed fields first
      final response = await OdooRpcApiManager.searchRead(
        model: 'hr.employee',
        fields: ["id", "name", "work_email"],
        order: "id desc",
        showLog: true,
      );

      List<Map<String, dynamic>> rawRecords = [];

      if (response.isSuccess && response.data != null) {
        rawRecords = response.data!;
        print(
            "👥 [EMPLOYEES] Primary fetch success: ${rawRecords.length} records");
      } else {
        // Fallback: Try with minimum fields if primary fetch failed (e.g. AccessError on work_email)
        print("👥 [EMPLOYEES] Primary fetch failed: ${response.message}");
        print("👥 [EMPLOYEES] Retrying with minimum fields...");

        final fallbackResponse = await OdooRpcApiManager.searchRead(
          model: 'hr.employee',
          fields: ["id", "name"],
          order: "id desc",
          showLog: true,
        );

        if (fallbackResponse.isSuccess && fallbackResponse.data != null) {
          rawRecords = fallbackResponse.data!;
          print(
              "👥 [EMPLOYEES] Fallback fetch success: ${rawRecords.length} records");
        } else {
          // Both failed
          throw Exception("Server Error: ${fallbackResponse.message}");
        }
      }

      final List<UserModel> fetchedEmployees = rawRecords.map((e) {
        return UserModel(
          userId: (e['id'] as num).toInt(),
          name: e['name']?.toString() ?? 'Unknown',
          email: e['work_email']?.toString() ?? '',
          token: '',
          imageUrl: null,
          json: Map<String, dynamic>.from(e),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _employees = fetchedEmployees;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      print('🚨 [EMPLOYEES] Error: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _errorMessage = "Unable to load employees: $e";
        });
      }
    }
  }

  Future<void> _fetchTasksForProject(int projectId,
      {int? initialTaskId}) async {
    setState(() => _isLoadingTasks = true);
    try {
      if (kDebugMode) {
        print(
            '📋 [TASKS] Fetching tasks for project ID: $projectId, Initial Task ID: $initialTaskId');
      }

      final tasks = await _taskController.getTaskList(projectId: projectId);

      if (kDebugMode) {
        print('📋 [TASKS] Found ${tasks.length} tasks');
        print(
            '📋 [TASKS] Tasks: ${tasks.map((t) => '${t.id}: ${t.name}').toList()}');
      }

      setState(() {
        _tasks = tasks;
        if (initialTaskId != null) {
          // Find the task with matching ID, or default to the first one if not found
          TaskModel? found;
          for (var t in tasks) {
            if (t.id == initialTaskId) {
              found = t;
              break;
            }
          }
          _selectedTask = found ?? (tasks.isNotEmpty ? tasks.first : null);
        } else {
          _selectedTask = tasks.isNotEmpty ? tasks.first : null;
        }
        _isLoadingTasks = false;

        // Fetch description ONLY if:
        // 1. It's NOT the task we started with (user manually changed project/task)
        // 2. AND the note is currently empty
        if (_selectedTask != null) {
          final currentNote = _noteController.text.trim();
          final isInitialTask =
              initialTaskId != null && _selectedTask!.id == initialTaskId;

          if (!isInitialTask && currentNote.isEmpty) {
            _fetchLastDescriptionForTask(_selectedTask!.id);
          }
        }
      });
    } catch (e) {
      if (kDebugMode) print('🚨 [TASKS] Error fetching tasks: $e');
      setState(() {
        _tasks = [];
        _selectedTask = null;
        _isLoadingTasks = false;
      });
    }
  }

  Future<void> _fetchLastDescriptionForTask(int taskId) async {
    try {
      if (!Get.isRegistered<TimesheetController>()) {
        Get.put(TimesheetController());
      }
      final timesheetController = Get.find<TimesheetController>();
      final now = DateTime.now();
      final tList = await timesheetController.getAllTimesheet(date: now);

      // Filter for matching task ID
      final matchingTimesheets =
          tList.where((t) => t.taskId == taskId).toList();

      if (matchingTimesheets.isEmpty) return;

      // Sort by timesheetId descending to get the latest
      matchingTimesheets.sort((a, b) => b.timesheetId.compareTo(a.timesheetId));

      TimesheetModel? bestMatch;

      // Try to find one where description != taskName (user entered custom note)
      // Iterate through the sorted list (latest first)
      for (final t in matchingTimesheets) {
        if (t.description != t.taskName) {
          bestMatch = t;
          break;
        }
      }

      // If no custom note found, fall back to the absolute latest entry
      final match = bestMatch ?? matchingTimesheets.first;

      if (mounted) {
        setState(() {
          // Only pre-fill if it's NOT just the task name
          if (match.description != match.taskName &&
              match.description.isNotEmpty) {
            _noteController.text = match.description;
          } else {
            _noteController.text = ''; // Clear if it's just the task name
          }
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching last description: $e');
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _handleSubmit() {
    if (_selectedMode == null) {
      setState(() => _errorMessage = 'Please select an option');
      return;
    }

    if (_selectedMode == IdleMode.meeting && _selectedProject == null) {
      setState(() => _errorMessage = 'Please select a project');
      return;
    }

    if (_selectedMode == IdleMode.meeting && _selectedTask == null) {
      setState(() => _errorMessage = 'Please select a task');
      return;
    }

    if (_selectedMode == IdleMode.thinking &&
        _noteController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Please enter what you are thinking about');
      return;
    }

    if (_selectedMode == IdleMode.discussion && _selectedProject == null) {
      setState(() => _errorMessage = 'Please select a project');
      return;
    }

    if (_selectedMode == IdleMode.discussion && _selectedTask == null) {
      setState(() => _errorMessage = 'Please select a task');
      return;
    }

    if (_selectedMode == IdleMode.discussion && _selectedEmployees.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one employee');
      return;
    }

    if (_selectedMode == IdleMode.keep && _selectedProject == null) {
      setState(() => _errorMessage = 'Please select a project');
      return;
    }

    if (_selectedMode == IdleMode.keep && _selectedTask == null) {
      setState(() => _errorMessage = 'Please select a task');
      return;
    }

    if (_selectedMode == IdleMode.remove && _selectedProject == null) {
      setState(() => _errorMessage = 'Please select a project');
      return;
    }

    if (_selectedMode == IdleMode.remove && _selectedTask == null) {
      setState(() => _errorMessage = 'Please select a task');
      return;
    }

    // Validate note for all modes
    final noteText = _noteController.text.trim();

    if (noteText.isEmpty) {
      setState(() => _errorMessage = 'Please enter a note');
      return;
    }

    String note = "";
    bool keepTime = true;
    bool wasDeducted = false;

    switch (_selectedMode!) {
      case IdleMode.meeting:
        note = noteText;
        break;
      case IdleMode.thinking:
        note = noteText;
        break;
      case IdleMode.discussion:
        note = noteText;
        break;
      case IdleMode.keep:
        note = noteText;
        wasDeducted = false;
        keepTime = true;
        break;
      case IdleMode.remove:
        note = noteText;
        wasDeducted = true;
        keepTime = false;
        break;
    }

    final now = DateTime.now();
    final startTime = now.subtract(Duration(seconds: _currentIdleTime));

    // Convert mode to string for idleType
    String? idleTypeString;
    String? meetingProjectName;
    String? discussionWithNames;

    switch (_selectedMode!) {
      case IdleMode.meeting:
        idleTypeString = 'meeting';
        meetingProjectName = _selectedProject?.name;
        break;
      case IdleMode.thinking:
        idleTypeString = 'thinking';
        break;
      case IdleMode.discussion:
        idleTypeString = 'discussion';
        discussionWithNames = _selectedEmployees.map((e) => e.name).join(", ");
        break;
      case IdleMode.keep:
        idleTypeString = 'keep';
        break;
      case IdleMode.remove:
        idleTypeString = 'remove';
        break;
    }

    // Check for project or task mismatch to determine timesheetId
    final startWork = _trackerController.startWorkData.value;
    final originalProjectId = startWork?.project.id;
    final originalTaskId = startWork?.task.id;

    dynamic timesheetId = startWork?.timesheetId ?? 0;

    // If project or task changed from what was previously selected, send blank timesheetId
    if (_selectedProject?.id != originalProjectId ||
        _selectedTask?.id != originalTaskId) {
      if (kDebugMode) {
        print(
            '🔄 [SUBMIT] Project/Task mismatch detected. Sending blank timesheetId.');
        print(
            '🔄 [SUBMIT] Original: P$originalProjectId, T$originalTaskId | New: P${_selectedProject?.id}, T${_selectedTask?.id}');
      }
      timesheetId = "";
    }

    Navigator.of(context).pop(
      IdleTimeData(
        mode: _selectedMode,
        timesheetId: timesheetId,
        keepTime: keepTime,
        idleSeconds: _currentIdleTime,
        note: note,
        projectId: _selectedProject?.id ??
            _trackerController.startWorkData.value?.project.id,
        taskId: _selectedTask?.id ??
            _trackerController.startWorkData.value?.task.id,
        projectName: _selectedProject?.name ??
            _trackerController.startWorkData.value?.project.name,
        taskName: _selectedTask?.name ??
            _trackerController.startWorkData.value?.task.name,
        idleType: idleTypeString,
        meetingProject: meetingProjectName,
        discussionWith: discussionWithNames,
        employeeIds: _selectedMode == IdleMode.discussion &&
                _selectedEmployees.isNotEmpty
            ? _selectedEmployees.map((e) => e.userId).toList()
            : null,
        breakTime:
            FormatUtils.formatDuration(Duration(seconds: _currentIdleTime)),
        startTime: startTime.toIso8601String(),
        endTime: now.toIso8601String(),
        duration:
            FormatUtils.formatDuration(Duration(seconds: _currentIdleTime)),
        durationInMinutes: (_currentIdleTime / 60).ceil(),
        wasDeducted: wasDeducted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTimerDisplay(),
        const SizedBox(height: 24),
        _buildOptionsGrid(),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _buildDetailsArea(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildFooter(),
      ],
    );
  }

  Widget _buildTimerDisplay() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE68A).withOpacity(0.2), // Light Amber
              borderRadius: BorderRadius.circular(30),
              border:
                  Border.all(color: const Color(0xFFFDE68A).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined,
                    color: Color(0xFFB45309), size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_currentIdleTime),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Action Required',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildOptionCard(
          mode: IdleMode.meeting,
          icon: Icons.groups_outlined,
          label: 'Meeting',
          color: Colors.blue,
        ),
        _buildOptionCard(
          mode: IdleMode.thinking,
          icon: Icons.psychology_outlined,
          label: 'Thinking',
          color: Colors.purple,
        ),
        _buildOptionCard(
          mode: IdleMode.discussion,
          icon: Icons.forum_outlined,
          label: 'Discussion',
          color: Colors.teal,
        ),
        _buildOptionCard(
          mode: IdleMode.keep,
          icon: Icons.play_arrow_outlined,
          label: 'Keep',
          color: Colors.green,
        ),
        _buildOptionCard(
          mode: IdleMode.remove,
          icon: Icons.close_outlined,
          label: 'Remove',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IdleMode mode,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      onTap: () {
        if (kDebugMode) print("🖱️ Option selected: $label");
        setState(() {
          _selectedMode = mode;
          _errorMessage = null;
        });

        // Trigger specific fetch if Discussion is selected and list is empty
        if (mode == IdleMode.discussion) {
          _fetchEmployees();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsArea() {
    if (_selectedMode == null) return const SizedBox.shrink();
    if (_isLoadingData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    switch (_selectedMode!) {
      case IdleMode.meeting:
        return _buildMeetingDetails();
      case IdleMode.thinking:
        return _buildThinkingDetails();
      case IdleMode.discussion:
        return _buildDiscussionDetails();
      case IdleMode.keep:
        return _buildKeepDetails();
      case IdleMode.remove:
        return _buildRemoveDetails();
    }
  }

  Widget _buildMeetingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Project',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SearchableDropdown<ProjectModel>(
          value: _selectedProject,
          items: _projects,
          hint: 'Select Project',
          searchController: _projectSearchController,
          itemToString: (p) => p.name,
          onChanged: (val) {
            setState(() {
              _selectedProject = val;
              _selectedTask = null; // Reset task on project change
            });
            if (val != null) {
              _fetchTasksForProject(val.id);
            }
          },
          height: 48,
        ),
        const SizedBox(height: 16),

        // Task selection
        if (_isLoadingTasks)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_tasks.isEmpty && _selectedProject != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No tasks found for this project',
                    style: GoogleFonts.inter(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (_tasks.isNotEmpty) ...[
          Text(
            'Related Task',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SearchableDropdown<TaskModel>(
            value: _selectedTask,
            items: _tasks,
            hint: 'Select Task',
            searchController: _taskSearchController,
            itemToString: (t) => t.name,
            onChanged: (val) {
              setState(() => _selectedTask = val);
              if (val != null && _noteController.text.trim().isEmpty) {
                _fetchLastDescriptionForTask(val.id);
              }
            },
            height: 48,
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Add a Note',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        CompactTextField(
          controller: _noteController,
          hintText: 'Enter meeting details...',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildKeepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Project',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SearchableDropdown<ProjectModel>(
          value: _selectedProject,
          items: _projects,
          hint: 'Select Project',
          searchController: _projectSearchController,
          itemToString: (p) => p.name,
          onChanged: (val) {
            setState(() {
              _selectedProject = val;
              _selectedTask = null;
            });
            if (val != null) {
              _fetchTasksForProject(val.id);
            }
          },
          height: 48,
        ),
        const SizedBox(height: 16),

        // Task selection
        if (_isLoadingTasks)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_tasks.isEmpty && _selectedProject != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No tasks found for this project',
                    style: GoogleFonts.inter(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (_tasks.isNotEmpty) ...[
          Text(
            'Related Task',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SearchableDropdown<TaskModel>(
            value: _selectedTask,
            items: _tasks,
            hint: 'Select Task',
            searchController: _taskSearchController,
            itemToString: (t) => t.name,
            onChanged: (val) {
              setState(() => _selectedTask = val);
              if (val != null && _noteController.text.trim().isEmpty) {
                _fetchLastDescriptionForTask(val.id);
              }
            },
            height: 48,
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Add a Note',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        CompactTextField(
          controller: _noteController,
          hintText: 'Add details about this time...',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildThinkingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are you thinking about?',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        CompactTextField(
          controller: _noteController,
          hintText: 'Share your thoughts...',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildDiscussionDetails() {
    final query = _employeeSearchController.text.toLowerCase();
    final filteredEmployees = _employees.where((e) {
      return e.name.toLowerCase().contains(query) ||
          e.email.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Project',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SearchableDropdown<ProjectModel>(
          value: _selectedProject,
          items: _projects,
          hint: 'Select Project',
          searchController: _projectSearchController,
          itemToString: (p) => p.name,
          onChanged: (val) {
            setState(() {
              _selectedProject = val;
              _selectedTask = null;
            });
            if (val != null) {
              _fetchTasksForProject(val.id);
            }
          },
          height: 48,
        ),
        const SizedBox(height: 16),

        // Task selection area
        _buildTaskSelectionArea(),
        const SizedBox(height: 16),

        // Employee selection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Discussed with',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  if (_selectedEmployees.length == _employees.length) {
                    _selectedEmployees.clear();
                  } else {
                    _selectedEmployees = List.from(_employees);
                  }
                });
              },
              child: Text(
                _selectedEmployees.length == _employees.length
                    ? 'Clear All'
                    : 'Select All',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Horizontal list of selected chips
        if (_selectedEmployees.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedEmployees.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final emp = _selectedEmployees[index];
                return Chip(
                  label: Text(
                    emp.name,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  deleteIcon: const Icon(Icons.close,
                      size: 14, color: AppTheme.primary),
                  onDeleted: () =>
                      setState(() => _selectedEmployees.remove(emp)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        CompactTextField(
          controller: _employeeSearchController,
          hintText: 'Search employee...',
          prefixIcon: const Icon(Icons.search, size: 18),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        Container(
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade100),
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.shade50.withOpacity(0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: filteredEmployees.isEmpty
              ? Center(
                  child: Text(
                    'No employees found',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = filteredEmployees[index];
                    final isSelected = _selectedEmployees
                        .any((e) => e.userId == employee.userId);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedEmployees.removeWhere(
                                (e) => e.userId == employee.userId);
                          } else {
                            _selectedEmployees.add(employee);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withOpacity(0.05)
                              : Colors.transparent,
                          border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                color: isSelected ? AppTheme.primary : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : Colors.black87,
                                    ),
                                  ),
                                  if (employee.email.isNotEmpty)
                                    Text(
                                      employee.email,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Text(
          'Add a Note',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        CompactTextField(
          controller: _noteController,
          hintText: 'Enter discussion details...',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildTaskSelectionArea() {
    if (_isLoadingTasks) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_tasks.isEmpty && _selectedProject != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No tasks found for this project',
                style: GoogleFonts.inter(
                  color: Colors.orange.shade700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_tasks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related Task',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SearchableDropdown<TaskModel>(
            value: _selectedTask,
            items: _tasks,
            hint: 'Select Task',
            searchController: _taskSearchController,
            itemToString: (t) => t.name,
            onChanged: (val) {
              setState(() => _selectedTask = val);
              if (val != null && _noteController.text.trim().isEmpty) {
                _fetchLastDescriptionForTask(val.id);
              }
            },
            height: 48,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRemoveDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Project',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SearchableDropdown<ProjectModel>(
          value: _selectedProject,
          items: _projects,
          hint: 'Select Project',
          searchController: _projectSearchController,
          itemToString: (p) => p.name,
          onChanged: (val) {
            setState(() {
              _selectedProject = val;
              _selectedTask = null;
            });
            if (val != null) {
              _fetchTasksForProject(val.id);
            }
          },
          height: 48,
        ),
        const SizedBox(height: 16),

        // Task selection area
        _buildTaskSelectionArea(),
        const SizedBox(height: 16),

        Text(
          'Reason for Removal',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        CompactTextField(
          controller: _noteController,
          hintText: 'Enter reason for removing time...',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSimpleMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message, style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: const Text('Confirm',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
