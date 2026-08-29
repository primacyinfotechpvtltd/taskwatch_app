import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pi_task_watch/controllers/auth_controller.dart';
import 'package:pi_task_watch/controllers/project_controller.dart';
import 'package:pi_task_watch/controllers/task_controller.dart';
import 'package:pi_task_watch/models/project_model.dart';
import 'package:pi_task_watch/models/task_model.dart';
import 'package:pi_task_watch/theme/app_theme.dart';
import 'package:pi_task_watch/widgets/compact_text_field.dart';
import 'package:pi_task_watch/widgets/odoo_network_image.dart';
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

  DateTime? _selectedDeadline;
  bool _isLoadingProjects = true;
  bool _isLoadingTasks = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
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
    _descriptionController.text = task.description ?? '';
    if (task.allocatedHours != null && task.allocatedHours! > 0) {
      _hoursController.text = task.allocatedHours! % 1 == 0
          ? task.allocatedHours!.toInt().toString()
          : task.allocatedHours!.toStringAsFixed(1);
    } else {
      _hoursController.text = '';
    }
    _selectedDeadline = task.getEndDateTime();
  }

  void _resetFields() {
    _taskNameController.clear();
    _descriptionController.clear();
    _hoursController.clear();
    _selectedDeadline = null;
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

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initialDate = _selectedDeadline ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDeadline = picked);
    }
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

    double? allocatedHours;
    if (_hoursController.text.trim().isNotEmpty) {
      allocatedHours = double.tryParse(_hoursController.text.trim());
    }

    setState(() => _isSubmitting = true);

    try {
      if (_dialogMode == TaskDialogMode.editExisting && _selectedTask != null) {
        // Update existing task
        final success = await _taskController.updateTask(
          taskId: _selectedTask!.id,
          name: taskName,
          description: _descriptionController.text.trim(),
          deadline: _selectedDeadline,
          allocatedHours: allocatedHours,
        );

        if (success && mounted) {
          final updatedTask = _taskController.taskList
              .firstWhereOrNull((t) => t.id == _selectedTask!.id);
          Navigator.of(context).pop(updatedTask ?? _selectedTask);
        }
      } else {
        // Create new task strictly assigned to the current user
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
      // Error handled inside taskController
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authController.user.value;
    final userName = currentUser?.name ?? 'Current User';
    final userEmail = currentUser?.email ?? '';
    final userId = currentUser?.userId ?? 0;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
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

                          // If in Edit Existing mode, show task selector dropdown
                          if (_dialogMode == TaskDialogMode.editExisting) ...[
                            _buildFieldLabel('Select Existing Task in Project *'),
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
                            const SizedBox(height: 12),
                            _buildExistingTaskInfoBanner(),
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
                                    'No existing tasks found for you in this project. Creating a new task.',
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
                        _dialogMode == TaskDialogMode.editExisting
                            ? 'Task Title'
                            : 'Task Title *',
                      ),
                      const SizedBox(height: 6),
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

                      // Assignee: Locked to Logged-in User (Self-assignment only)
                      _buildFieldLabel('Assignee'),
                      const SizedBox(height: 6),
                      _buildSelfAssigneeCard(
                        userId: userId,
                        name: userName,
                        email: userEmail,
                      ),
                      const SizedBox(height: 16),

                      // Deadline & Allocated Hours Row (Editable)
                      Row(
                        children: [
                          // Deadline
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Deadline'),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _pickDeadline,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                          color: AppTheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedDeadline != null
                                                ? DateFormat('dd MMM yyyy')
                                                    .format(_selectedDeadline!)
                                                : 'Set deadline',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _selectedDeadline != null
                                                  ? Colors.black87
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                        if (_selectedDeadline != null)
                                          GestureDetector(
                                            onTap: () {
                                              setState(
                                                () => _selectedDeadline = null,
                                              );
                                            },
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Allocated Hours
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Allocated Time (Hours)'),
                                const SizedBox(height: 6),
                                CompactTextField(
                                  controller: _hoursController,
                                  hintText: 'e.g. 2.5',
                                  prefixIcon: Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description (Editable)
                      _buildFieldLabel('Task Description & Notes'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _descriptionController,
                          maxLines: 4,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.black87,
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

  Widget _buildExistingTaskInfoBanner() {
    if (_selectedTask == null) return const SizedBox.shrink();

    final allocated = _selectedTask!.getFormattedAllocatedTime();
    final used = _selectedTask!.getUsedTime();
    final usedStr = used != null ? '${used.inHours}h ${used.inMinutes % 60}m' : '0h';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Current: Allocated $allocated | Used $usedStr. You can adjust the time & description below.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.primary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

  Widget _buildSelfAssigneeCard({
    required int userId,
    required String name,
    required String email,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF00A09D).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF00A09D).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 32,
              height: 32,
              child: userId > 0
                  ? OdooNetworkImage(
                      model: 'res.users',
                      id: userId,
                      field: 'image_128',
                      placeholder: _buildInitialAvatar(name),
                      errorWidget: _buildInitialAvatar(name),
                    )
                  : _buildInitialAvatar(name),
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
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A09D).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'You (Self)',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00A09D),
                        ),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Tooltip(
            message:
                'Tasks created by you are automatically and strictly assigned to your account only.',
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return Container(
      color: AppTheme.primary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
