import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pi_task_watch/controllers/task_controller.dart';
import 'package:pi_task_watch/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pi_task_watch/models/task_model.dart';
import 'package:pi_task_watch/models/task_details_model.dart';
import 'package:pi_task_watch/widgets/add_task_dialog.dart';
import 'task_detail_screen.dart';

class MyTaskListScreen extends StatefulWidget {
  static const String routeName = '/my-task-list';
  const MyTaskListScreen({super.key});

  @override
  State<MyTaskListScreen> createState() => _MyTaskListScreenState();
}

class _MyTaskListScreenState extends State<MyTaskListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<TaskModel> _tasks = [];
  List<TaskModel> _filteredTasks = [];
  bool _isLoading = true;
  String _sortBy = 'startTime';
  late FilterOptions _filterOptions;
  String _searchQuery = '';
  final Map<String, Set<String>> _uniqueValuesCache = {};
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
        _applyFilters();
      });
    });
  }

  Set<String> _getUniqueValues(
    String key,
    String? Function(TaskModel) selector,
  ) {
    if (!_uniqueValuesCache.containsKey(key)) {
      _uniqueValuesCache[key] = _tasks
          .where((task) => selector(task) != null)
          .map((task) => selector(task)!)
          .toSet();
    }
    return _uniqueValuesCache[key]!;
  }

  Set<String> _getUniqueProjects() {
    return _getUniqueValues('projects', (task) => task.projectName);
  }

  Set<String> _getUniqueStages() {
    return _getUniqueValues('stages', (task) => task.stageName);
  }

  String formatDateWithOrdinal(DateTime date) {
    final day = date.day;
    String suffix;

    if (day >= 11 && day <= 13) {
      suffix = 'th';
    } else {
      switch (day % 10) {
        case 1:
          suffix = 'st';
          break;
        case 2:
          suffix = 'nd';
          break;
        case 3:
          suffix = 'rd';
          break;
        default:
          suffix = 'th';
          break;
      }
    }

    return '$day$suffix ${DateFormat('MMM yyyy').format(date)}';
  }

  @override
  void initState() {
    super.initState();
    _filterOptions = FilterOptions(
      startDate: DateTime.now(),
      endDate: DateTime.now(),
    );
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final fetchedTasks = await Get.find<TaskController>().getTaskList(
        projectId: null,
      );
      setState(() {
        _tasks = fetchedTasks;
      });
    } catch (e) {
      setState(() {});
    }
    _applyFilters();
    setState(() {
      _isLoading = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredTasks = _tasks.where((task) {
        if (!_filterOptions.isWithinTimeRange(task)) {
          return false;
        }

        if (_filterOptions.projectName != null &&
            task.projectName != _filterOptions.projectName) {
          return false;
        }

        if (_filterOptions.stageName != null &&
            task.stageName != _filterOptions.stageName) {
          return false;
        }

        if (!_filterOptions.showOverdueTasks && task.isOverdue()) {
          return false;
        }

        return true;
      }).toList();

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        _filteredTasks = _filteredTasks.where((task) {
          return task.name.toLowerCase().contains(query) ||
              (task.projectName?.toLowerCase().contains(query) ?? false) ||
              (task.stageName?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      _sortTasks();
    });
  }

  void _showFilterDialog() {
    var tempFilterOptions = FilterOptions(
      startDate: _filterOptions.startDate,
      endDate: _filterOptions.endDate,
      startTime: _filterOptions.startTime,
      endTime: _filterOptions.endTime,
      projectName: _filterOptions.projectName,
      stageName: _filterOptions.stageName,
      showOverdueTasks: _filterOptions.showOverdueTasks,
      showCompletedTasks: _filterOptions.showCompletedTasks,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 320,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterDialogHeader(dialogContext),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateRangeSection(
                            tempFilterOptions,
                            setDialogState,
                          ),
                          if (_getUniqueProjects().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildDropdownSection(
                              label: 'Project',
                              value: tempFilterOptions.projectName,
                              items: _getUniqueProjects(),
                              onChanged: (value) => setDialogState(() {
                                tempFilterOptions.projectName = value;
                              }),
                            ),
                          ],
                          if (_getUniqueStages().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildDropdownSection(
                              label: 'Stage',
                              value: tempFilterOptions.stageName,
                              items: _getUniqueStages(),
                              onChanged: (value) => setDialogState(() {
                                tempFilterOptions.stageName = value;
                              }),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildTimeRangeSection(
                            tempFilterOptions,
                            setDialogState,
                          ),
                          const SizedBox(height: 16),
                          _buildOverdueSwitch(
                            tempFilterOptions,
                            setDialogState,
                          ),
                          const SizedBox(height: 8),
                          _buildCompletedTasksSwitch(
                            tempFilterOptions,
                            setDialogState,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  _buildFilterDialogActions(
                    tempFilterOptions,
                    dialogContext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDialogHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.filter_list_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Filter Tasks',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSection({
    required String label,
    required String? value,
    required Set<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                elevation: 4,
                borderRadius: BorderRadius.circular(16),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      'All',
                      style: GoogleFonts.inter(color: Colors.grey.shade500),
                    ),
                  ),
                  ...items.map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDialogActions(
    FilterOptions tempOptions,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _filterOptions = FilterOptions(
                    startDate: DateTime.now(),
                    endDate: DateTime.now(),
                  );
                  _applyFilters();
                });
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Reset All',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _filterOptions = tempOptions;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Show Results',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection(
    FilterOptions options,
    StateSetter setDialogState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final range = await _selectDateRange(context, options);
            if (range != null) {
              setDialogState(() {
                options.startDate = range.start;
                options.endDate = range.end;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 18, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    options.startDate != null
                        ? '${DateFormat('dd/MM/yyyy').format(options.startDate!)} - ${options.endDate != null ? DateFormat('dd/MM/yyyy').format(options.endDate!) : 'Now'}'
                        : 'Select date range',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: options.startDate != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                if (options.startDate != null)
                  GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        options.startDate = null;
                        options.endDate = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 12, color: Colors.grey[600]),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSection(
    FilterOptions options,
    StateSetter setDialogState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time Range',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTimePicker(
                label: 'Start',
                time: options.startTime,
                onTimeSelected: (time) {
                  setDialogState(() {
                    options.startTime = time;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimePicker(
                label: 'End',
                time: options.endTime,
                onTimeSelected: (time) {
                  setDialogState(() {
                    options.endTime = time;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? time,
    required ValueChanged<TimeOfDay?> onTimeSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
        );
        onTimeSelected(selectedTime);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                time != null ? time.format(context) : label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: time != null ? Colors.black87 : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueSwitch(
    FilterOptions options,
    StateSetter setDialogState,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      activeColor: AppTheme.primary,
      title: Text(
        'Show Overdue Tasks',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
      ),
      value: options.showOverdueTasks,
      onChanged: (value) {
        setDialogState(() {
          options.showOverdueTasks = value;
        });
      },
    );
  }

  Widget _buildCompletedTasksSwitch(
    FilterOptions options,
    StateSetter setDialogState,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      activeColor: AppTheme.primary,
      title: Text(
        'Show Completed Tasks',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
      ),
      value: options.showCompletedTasks,
      onChanged: (value) {
        setDialogState(() {
          options.showCompletedTasks = value;
        });
      },
    );
  }

  Future<DateTimeRange?> _selectDateRange(
    BuildContext context,
    FilterOptions options,
  ) async {
    try {
      final now = DateTime.now();
      final firstDate = DateTime(2020);
      final lastDate = DateTime(2025, 12, 31);

      DateTimeRange initialRange;
      if (options.startDate != null) {
        final start = options.startDate!;
        final end = options.endDate ?? start;
        initialRange = DateTimeRange(
          start: start.isBefore(firstDate) ? firstDate : start,
          end: end.isAfter(lastDate) ? lastDate : end,
        );
      } else {
        initialRange = DateTimeRange(start: now, end: now);
      }

      return await showDateRangePicker(
        context: context,
        firstDate: firstDate,
        lastDate: lastDate,
        initialDateRange: initialRange,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              appBarTheme: Theme.of(context).appBarTheme.copyWith(
                    backgroundColor: Theme.of(context).primaryColor,
                    iconTheme: const IconThemeData(color: Colors.white),
                    titleTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
            ),
            child: child!,
          );
        },
      );
    } catch (e) {
      debugPrint('Error selecting date range: $e');
      return null;
    }
  }

  void _sortTasks() {
    switch (_sortBy) {
      case 'startTime':
        _filteredTasks.sort((a, b) {
          final aDate = a.getStartDateTime();
          final bDate = b.getStartDateTime();
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });
        break;
      case 'endTime':
        _filteredTasks.sort((a, b) {
          final aDate = a.getEndDateTime();
          final bDate = b.getEndDateTime();
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });
        break;
      case 'priority':
        _filteredTasks.sort((a, b) {
          if (a.isOverdue() && !b.isOverdue()) return -1;
          if (!a.isOverdue() && b.isOverdue()) return 1;

          if (a.hasNegativeRemainingTime() && !b.hasNegativeRemainingTime()) {
            return -1;
          }
          if (!a.hasNegativeRemainingTime() && b.hasNegativeRemainingTime()) {
            return 1;
          }

          final aPercentage = a.getTimeUsedPercentage();
          final bPercentage = b.getTimeUsedPercentage();
          return bPercentage.compareTo(aPercentage);
        });
        break;
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.sort_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sort Tasks',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildSortOption(
              icon: Icons.access_time_rounded,
              title: 'Sort by Start Time',
              value: 'startTime',
            ),
            _buildSortOption(
              icon: Icons.timer_off_rounded,
              title: 'Sort by End Time',
              value: 'endTime',
            ),
            _buildSortOption(
              icon: Icons.priority_high_rounded,
              title: 'Sort by Priority',
              value: 'priority',
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildSortOption({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final bool isSelected = _sortBy == value;

    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
        ),
      ),
      trailing: isSelected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_rounded,
                color: Theme.of(context).primaryColor,
                size: 16,
              ),
            )
          : null,
      onTap: () {
        setState(() {
          _sortBy = value;
          _sortTasks();
        });
        Navigator.pop(context);
      },
    );
  }

  Color _getTaskStatusColor(TaskModel task) {
    // Check for overdue tasks based on end date
    if (task.isOverdue()) return Colors.red.shade400;
    // Check negative remaining time (allocated time exceeded)
    if (task.getRemainingTimeDuration()?.isNegative ?? false) {
      return Colors.orange.shade400;
    }
    return Colors.green.shade400;
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 90) {
      return Colors.red.shade400;
    } else if (percentage >= 75) {
      return Colors.orange.shade400;
    } else if (percentage > 0) {
      return Colors.blue.shade400;
    }
    return Colors.grey.shade400;
  }

  Widget _buildTaskCard(TaskModel task) {
    final percentageUsed = task.getTimeUsedPercentage() * 100;
    final progressColor = _getProgressColor(percentageUsed);
    final isNegativeTime = task.hasNegativeRemainingTime();

    // Format date times
    final startDateTime = task.getStartDateTime();
    final endDateTime = task.getEndDateTime();
    final startDateFormatted = startDateTime != null
        ? DateFormat('MMM dd, hh:mm a').format(startDateTime)
        : 'N/A';
    final endDateFormatted = endDateTime != null
        ? DateFormat('MMM dd, hh:mm a').format(endDateTime)
        : 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(task),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: _getTaskStatusColor(task), width: 4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Eye button to view task details fullscreen
                      Tooltip(
                        message: 'View task details fullscreen',
                        child: InkWell(
                          onTap: () {
                            // Pass TaskDetailsModel instead of TaskModel
                            Get.toNamed(
                              TaskDetailScreen.routeName,
                              arguments: TaskDetailsModel(
                                id: task.id,
                                name: task.name,
                                projectId: task.projectId,
                                projectName: task.projectName,
                                stageId: task.stageId ?? 0,
                                stageName: task.stageName,
                                dateDeadline: task.getEndDateTime(),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.visibility_rounded,
                              size: 14,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                      // Task name with flexible width
                      Expanded(
                        flex: 3,
                        child: Text(
                          task.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.projectName != null) ...[
                        const SizedBox(width: 4),
                        // Project name with constrained width
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              task.projectName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      // Edit task button
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          final updated = await showDialog<TaskModel>(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) => AddTaskDialog(
                              initialProjectId: task.projectId,
                              initialTask: task,
                            ),
                          );
                          if (updated != null) {
                            _loadTasks();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Combined date time line
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$startDateFormatted to $endDateFormatted',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Percentage display on the left
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        child: Text(
                          '${percentageUsed.toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: progressColor,
                          ),
                        ),
                      ),
                      // Progress bar
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: task.getTimeUsedPercentage(),
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: progressColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Refactored time information section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Allocated time section
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Allocated: ${task.getFormattedAllocatedTime()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Remaining time section with improved styling
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isNegativeTime
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isNegativeTime
                                ? Colors.red.shade200
                                : Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isNegativeTime ? Icons.alarm_off : Icons.alarm_on,
                              size: 12,
                              color: isNegativeTime
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isNegativeTime
                                  ? 'Over: ${task.getFormattedRemainingTime().replaceAll('-', '')}'
                                  : '${task.getFormattedRemainingTime()} left',
                              style: TextStyle(
                                fontSize: 11,
                                color: isNegativeTime
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.editorialGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(constraints),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildSearchField(),
                  ),
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState()
                        : RefreshIndicator(
                            onRefresh: _loadTasks,
                            color: AppTheme.primary,
                            backgroundColor: Colors.white,
                            child: _filteredTasks.isEmpty
                                ? _buildEmptyState()
                                : _buildTaskList(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BoxConstraints constraints) {
    return Container(
      decoration: AppTheme.glassDecoration(
        borderRadius: 0,
        elevated: false,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.task_alt,
                size: 20,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _filterOptions.startDate != null
                      ? formatDateWithOrdinal(_filterOptions.startDate!)
                      : 'All Tasks',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildHeaderActions(),
            ],
          ),
          if (_hasActiveFilters())
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: _buildActiveFilterChips()),
            ),
        ],
      ),
    );
  }

  void _showAddTaskDialog() async {
    final result = await showDialog<TaskModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AddTaskDialog(),
    );

    if (result != null) {
      _loadTasks();
    }
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          icon: Icons.add_rounded,
          color: Theme.of(context).primaryColor,
          onTap: _showAddTaskDialog,
          withBackground: true,
        ),
        const SizedBox(width: 6),
        _buildIconButton(
          icon: Icons.filter_alt_rounded,
          color: _hasActiveFilters()
              ? Theme.of(context).primaryColor
              : Colors.grey[700],
          onTap: _showFilterDialog,
          withBackground: true,
          isActive: _hasActiveFilters(),
        ),
        const SizedBox(width: 6),
        _buildIconButton(
          icon: Icons.sort_rounded,
          color: Colors.grey[700],
          onTap: _showSortBottomSheet,
          withBackground: true,
        ),
        const SizedBox(width: 6),
        _buildIconButton(
          icon: Icons.close_rounded,
          color: Colors.grey[700],
          onTap: () => Navigator.of(context).pop(),
          withBackground: true,
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color? color,
    required VoidCallback onTap,
    bool withBackground = false,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: withBackground
                ? isActive
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.grey[100]
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: withBackground
                ? Border.all(
                    color: isActive
                        ? Theme.of(context).primaryColor.withOpacity(0.3)
                        : Colors.grey[300]!,
                    width: 1,
                  )
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? Theme.of(context).primaryColor : color,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search tasks...',
          hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.clear, size: 18, color: Colors.grey[400]),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        style: GoogleFonts.inter(fontSize: 14),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildTaskList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _filteredTasks.length,
      itemBuilder: (context, index) {
        final task = _filteredTasks[index];
        return KeyedSubtree(
          key: ValueKey(task.id),
          child: _buildTaskCard(task),
        );
      },
    );
  }

  bool _hasActiveFilters() {
    return _filterOptions.projectName != null ||
        _filterOptions.stageName != null ||
        !_filterOptions.showOverdueTasks ||
        (_filterOptions.startDate != null &&
            !DateUtils.isSameDay(_filterOptions.startDate, DateTime.now()));
  }

  List<Widget> _buildActiveFilterChips() {
    final List<Widget> chips = [];

    if (_filterOptions.startDate != null) {
      final startDate = DateFormat(
        'dd/MM/yyyy',
      ).format(_filterOptions.startDate!);
      final endDate = _filterOptions.endDate != null
          ? DateFormat('dd/MM/yyyy').format(_filterOptions.endDate!)
          : startDate;

      chips.add(
        _buildFilterChip(
          label: startDate == endDate
              ? 'Date: $startDate'
              : 'Date: $startDate - $endDate',
          onDeleted: () {
            setState(() {
              _filterOptions.startDate = null;
              _filterOptions.endDate = null;
              _applyFilters();
            });
          },
        ),
      );
    }

    if (_filterOptions.projectName != null) {
      chips.add(
        _buildFilterChip(
          label: 'Project: ${_filterOptions.projectName}',
          onDeleted: () {
            setState(() {
              _filterOptions.projectName = null;
              _applyFilters();
            });
          },
        ),
      );
    }

    if (_filterOptions.stageName != null) {
      chips.add(
        _buildFilterChip(
          label: 'Stage: ${_filterOptions.stageName}',
          onDeleted: () {
            setState(() {
              _filterOptions.stageName = null;
              _applyFilters();
            });
          },
        ),
      );
    }

    if (!_filterOptions.showOverdueTasks) {
      chips.add(
        _buildFilterChip(
          label: 'Hide Overdue',
          onDeleted: () {
            setState(() {
              _filterOptions.showOverdueTasks = true;
              _applyFilters();
            });
          },
        ),
      );
    }

    return chips;
  }

  Widget _buildFilterChip({required String label, VoidCallback? onDeleted}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
        ),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onDeleted,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading tasks...',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No tasks match the filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                if (_hasActiveFilters()) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterOptions = FilterOptions(
                          startDate: DateTime.now(),
                          endDate: DateTime.now(),
                        );
                        _applyFilters();
                      });
                    },
                    child: const Text('Clear Filters'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FilterOptions {
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? projectName;
  String? stageName;
  bool showOverdueTasks;
  bool showCompletedTasks;

  FilterOptions({
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.projectName,
    this.stageName,
    this.showOverdueTasks = true,
    this.showCompletedTasks = false,
  });

  bool isWithinTimeRange(TaskModel task) {
    final taskStartDateTime = task.getStartDateTime();
    final taskEndDateTime = task.getEndDateTime();

    // Only include tasks with both null start AND end dates when no date filter is applied
    if (taskStartDateTime == null && taskEndDateTime == null) {
      return startDate == null;
    }

    // If we're not filtering by date, show all tasks
    if (startDate == null) {
      return true;
    }

    // Create filter date range (just dates without time)
    final filterStartDate = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );

    final filterEndDate = endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day)
        : filterStartDate;

    // Handle case when only end date is available
    if (taskStartDateTime == null && taskEndDateTime != null) {
      final taskEndDate = DateTime(
        taskEndDateTime.year,
        taskEndDateTime.month,
        taskEndDateTime.day,
      );

      // Include the task if:
      // 1. Task end date is within the filter range OR
      // 2. Task end date is in the future (based on filter end date)
      if (taskEndDate.compareTo(filterStartDate) >= 0 &&
          taskEndDate.compareTo(filterEndDate) <= 0) {
        return true;
      }

      // If the task end date is in the future and we want to show future tasks
      if (taskEndDate.isAfter(DateTime.now())) {
        return true;
      }
    }
    // Handle case when only start date is available
    else if (taskStartDateTime != null && taskEndDateTime == null) {
      final taskStartDate = DateTime(
        taskStartDateTime.year,
        taskStartDateTime.month,
        taskStartDateTime.day,
      );

      // Check if the task start date is within filter range
      if (taskStartDate.compareTo(filterStartDate) >= 0 &&
          taskStartDate.compareTo(filterEndDate) <= 0) {
        return true;
      }
    }
    // Standard case: both start and end dates exist
    else if (taskStartDateTime != null && taskEndDateTime != null) {
      final taskStartDate = DateTime(
        taskStartDateTime.year,
        taskStartDateTime.month,
        taskStartDateTime.day,
      );

      final taskEndDate = DateTime(
        taskEndDateTime.year,
        taskEndDateTime.month,
        taskEndDateTime.day,
      );

      if (filterEndDate.isBefore(filterStartDate)) {
        return false;
      }

      bool isWithinRange = (!taskStartDate.isBefore(filterStartDate) &&
              !taskStartDate.isAfter(filterEndDate)) ||
          (!taskEndDate.isBefore(filterStartDate) &&
              !taskEndDate.isAfter(filterEndDate)) ||
          (taskStartDate.isBefore(filterStartDate) &&
              taskEndDate.isAfter(filterEndDate));

      if (!isWithinRange) return false;

      if (startTime != null &&
          taskStartDate.isAtSameMomentAs(filterStartDate)) {
        final taskTimeMinutes =
            taskStartDateTime.hour * 60 + taskStartDateTime.minute;
        final startTimeMinutes = startTime!.hour * 60 + startTime!.minute;
        if (taskTimeMinutes < startTimeMinutes) return false;
      }

      if (endTime != null && taskEndDate.isAtSameMomentAs(filterEndDate)) {
        final taskTimeMinutes =
            taskEndDateTime.hour * 60 + taskEndDateTime.minute;
        final endTimeMinutes = endTime!.hour * 60 + endTime!.minute;
        if (taskTimeMinutes > endTimeMinutes) return false;
      }

      return true;
    }

    return false;
  }
}
