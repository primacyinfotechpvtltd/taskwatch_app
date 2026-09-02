import 'package:pi_task_watch/exports.dart';

import 'package:pi_task_watch/controllers/timesheet_controller.dart';
import 'package:pi_task_watch/models/task_details_model.dart';
import 'package:pi_task_watch/models/timesheet_model.dart';
import 'package:pi_task_watch/screens/task_detail_screen.dart';

import 'package:google_fonts/google_fonts.dart';

class StartTrackerForm extends StatefulWidget {
  final TaskModel? task;
  const StartTrackerForm({super.key, this.task});

  @override
  State<StartTrackerForm> createState() => _StartTrackerFormState();
}

class _StartTrackerFormState extends State<StartTrackerForm> {
  final ProjectController _projectController = Get.find<ProjectController>();
  final TaskController _taskController = Get.find<TaskController>();

  bool _isSubmitting = false;
  bool _isInitializing = true;
  bool _isLoadingProjects = false;
  bool _isLoadingTasks = false;

  int? selectedProjectId;
  String? selectedProjectName;
  int? selectedTaskId;
  String? selectedTaskName;
  List<ProjectModel> projects = [];
  List<TaskModel> tasks = [];

  final TextEditingController _noteController = TextEditingController();

  DateTime? _lastClickTime;
  late VoidCallback _textControllerListener;

  @override
  void initState() {
    super.initState();
    _textControllerListener = () {
      if (mounted) setState(() {});
    };
    _noteController.addListener(_textControllerListener);
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (!mounted) return;

    setState(() => _isInitializing = true);

    try {
      if (widget.task != null) {
        selectedTaskId = widget.task!.id;
        selectedTaskName = widget.task!.name;
        selectedProjectId = widget.task!.projectId;
        await fetch();
      }
      await _loadProjects();
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;

    setState(() => _isLoadingProjects = true);

    try {
      projects = await _projectController.getAllProject();
      if (!mounted) return;

      if (selectedProjectId != null && selectedProjectName == null) {
        final project = projects.firstWhereOrNull(
          (p) => p.id == selectedProjectId,
        );
        if (project != null) {
          selectedProjectName = project.name;
        }
      }

      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        projects = [];
      });
      Get.snackbar(
        'Error',
        'Failed to load projects. Please try again.',
        backgroundColor: Colors.red[100],
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingProjects = false);
      }
    }
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() => _isLoadingTasks = true);

    try {
      tasks = await _taskController.getTaskList(projectId: selectedProjectId);

      if (!mounted) return;

      if (selectedTaskId != null) {
        final taskExists = tasks.any((t) => t.id == selectedTaskId);
        if (!taskExists) {
          selectedTaskId = null;
          selectedTaskName = null;
          exitingTimesheet = null;
        } else {
          if (selectedTaskName == null) {
            final task = tasks.firstWhere((t) => t.id == selectedTaskId);
            selectedTaskName = task.name;
          }
          _checkAndSetExistingTimesheet(selectedTaskId!);
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        tasks = [];
      });
      Get.snackbar(
        'Error',
        'Failed to load tasks. Please try again.',
        backgroundColor: Colors.red[100],
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
      }
    }
  }

  void _checkAndSetExistingTimesheet(int taskId) {
    try {
      final tList = Get.find<TimesheetController>().timesheetList;
      for (final t in tList) {
        if (t.taskId != null && t.taskId == taskId) {
          exitingTimesheet = t;
          if (_noteController.text.trim().isEmpty && t.description.isNotEmpty) {
            _noteController.text = t.description;
          }
          break;
        }
      }
    } catch (_) {}
  }

  void _startTracking() async {
    final now = DateTime.now();
    if (_lastClickTime != null &&
        now.difference(_lastClickTime!).inMilliseconds < 1000) {
      return;
    }
    _lastClickTime = now;

    if (_isSubmitting ||
        _isInitializing ||
        _isLoadingProjects ||
        _isLoadingTasks) {
      return;
    }

    if (selectedTaskId == null) {
      Get.snackbar('Error', 'Please select a task');
      return;
    }

    if (_noteController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please add notes about your work');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final selectedTaskModel = tasks.firstWhereOrNull(
        (task) => task.id == selectedTaskId,
      );

      if (selectedTaskModel == null) {
        Get.snackbar('Error', 'Selected task not found. Please try again.');
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      final projectModel = projects.firstWhereOrNull(
        (project) => project.id == selectedTaskModel.projectId,
      );

      if (projectModel == null) {
        Get.snackbar(
          'Error',
          'Project not found for the selected task. Please try again.',
        );
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      final trackerData = StartWorkResult(
        task: selectedTaskModel,
        project: projectModel,
        notes: _noteController.text.trim(),
        startTime: DateTime.now(),
        timesheet: exitingTimesheet,
      );

      Get.back(result: trackerData);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to start tracking. Please try again.',
        backgroundColor: Colors.red[100],
      );
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  TimesheetModel? exitingTimesheet;

  Future<void> fetch() async {
    final taskId = widget.task?.id ?? selectedTaskId;
    if (taskId == null) return;

    try {
      final now = DateTime.now();
      final tList = await Get.find<TimesheetController>().getAllTimesheet(
        date: now,
      );

      for (final t in tList) {
        if (t.taskId != null && t.taskId == taskId) {
          exitingTimesheet = t;
          if (_noteController.text.trim().isEmpty && t.description.isNotEmpty) {
            _noteController.text = t.description;
          }
          break;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {}
  }

  @override
  void dispose() {
    _noteController.removeListener(_textControllerListener);
    _noteController.dispose();
    super.dispose();
  }

  bool get _isLoading =>
      _isInitializing || _isLoadingProjects || _isLoadingTasks;

  bool get _canSubmit {
    return !_isLoading &&
        !_isSubmitting &&
        selectedTaskId != null &&
        _noteController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      );
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      constraints: const BoxConstraints(maxWidth: 350),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            'Project',
            selectedProjectName ?? 'No project',
            Icons.folder_open_rounded,
            _isLoadingProjects,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Task',
            selectedTaskName ?? 'No task',
            Icons.assignment_rounded,
            _isLoadingTasks,
            onViewDetails: selectedTaskId != null
                ? () {
                    final selectedTaskModel = tasks.firstWhereOrNull(
                      (task) => task.id == selectedTaskId,
                    ) ?? widget.task;
                    if (selectedTaskModel != null) {
                      Get.toNamed(
                        TaskDetailScreen.routeName,
                        arguments: TaskDetailsModel(
                          id: selectedTaskModel.id,
                          name: selectedTaskModel.name,
                          projectId: selectedTaskModel.projectId ?? selectedProjectId,
                          projectName: selectedTaskModel.projectName ?? selectedProjectName,
                          stageId: selectedTaskModel.stageId ?? 0,
                          stageName: selectedTaskModel.stageName,
                          dateDeadline: selectedTaskModel.getEndDateTime(),
                          dateStart: selectedTaskModel.getStartDateTime(),
                          allocatedHours: selectedTaskModel.allocatedHours ?? 0.0,
                          tags: selectedTaskModel.tags,
                          tagIds: selectedTaskModel.tagIds,
                          milestoneId: selectedTaskModel.milestoneId,
                          milestoneName: selectedTaskModel.milestoneName,
                          description: selectedTaskModel.description,
                        ),
                      );
                    }
                  }
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            'Notes *',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF25181E),
            ),
          ),
          const SizedBox(height: 8),
          CompactTextField(
            controller: _noteController,
            hintText: 'What are you working on?',
            maxLines: 4,
            autogrow: false,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    (_isSubmitting || _isLoading) ? null : () => Get.back(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _canSubmit ? _startTracking : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Start'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    bool isLoading, {
    VoidCallback? onViewDetails,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                isLoading
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        value,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF25181E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
          if (onViewDetails != null && !isLoading) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'View task details fullscreen',
              child: InkWell(
                onTap: onViewDetails,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.visibility_rounded,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
