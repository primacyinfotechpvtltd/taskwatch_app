import 'dart:convert';
import 'dart:io';
import 'package:pi_task_watch/rust/api/take_full_screenshot.dart';
import 'package:pi_task_watch/utils/confirmation_alert.dart';
import 'package:pi_task_watch/widgets/recent_activity_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/exports.dart';

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late TrackerController _trackerController;
  late AuthController _authController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _trackerController = Get.find<TrackerController>();
    _authController = Get.find<AuthController>();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.7) {
      return Colors.green.shade400;
    } else if (progress < 1.0) {
      return Colors.orange.shade400;
    } else {
      return Colors.red.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (Platform.isLinux &&
                    (Platform.environment['XDG_SESSION_TYPE'] == 'wayland' ||
                        Platform.environment['WAYLAND_DISPLAY'] != null))
                  //  _buildWaylandWarning(),
                  _buildDashboardSection(),
                _buildBottomSection()
              ],
            ),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Critical error in dashboard build: $e');
      debugPrint('Stack trace: $stackTrace');

      // Return a safe fallback UI
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: _buildErrorWidget(
              'Dashboard failed to load. Please restart the app.',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildWaylandWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.amber.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wayland Session Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontSize: 12,
                  ),
                ),
                const Text(
                  'Global window tracking and input monitoring are restricted on Wayland. For full functionality on Zorin OS, please switch to Xorg at login.',
                  style: TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 20, left: 12, right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildCounterSection(),
          const SizedBox(height: 16),
          _buildRunningTaskSection(),
        ],
      ),
    );
  }

  Widget _buildCounterSection() {
    return Obx(() {
      final duration = _trackerController.trackerDuration.value;
      final isRunning = _trackerController.isTracking.value;
      final breakDuration = _trackerController.totalBreakDuration.value;
      final isBreakOverLimit = breakDuration.inMinutes >= 60;

      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue =
              isRunning ? (0.9 + (_pulseController.value * 0.1)) : 1.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: pulseValue,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isRunning ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(duration),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _handleTrackingToggle,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (breakDuration.inSeconds > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBreakOverLimit
                        ? AppTheme.error.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBreakOverLimit
                            ? Icons.warning_amber_rounded
                            : Icons.coffee_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Break: ${_formatTimeHM(breakDuration)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: isBreakOverLimit
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      );
    });
  }

  Widget _buildRunningTaskSection() {
    return Container(
      decoration: AppTheme.glassDecoration(borderRadius: 20),
      child: Obx(() {
        final startWorkModel = _trackerController.startWorkData.value;

        if (startWorkModel == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    size: 28,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ready to start?',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a task and start tracking time',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return _buildActiveTaskContent(startWorkModel);
      }),
    );
  }

  Widget _buildActiveTaskContent(StartWorkModel startWorkModel) {
    try {
      final task = startWorkModel.task;
      final allocatedDuration =
          task.getAllocatedTimeDuration() ?? Duration.zero;
      final existingUsedTime = task.getUsedTime() ?? Duration.zero;
      final taskStartTime = startWorkModel.startTime;
      final taskNotes = startWorkModel.notes;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActiveTaskHeader(task, startWorkModel),
            const SizedBox(height: 16),
            _buildProgressBar(allocatedDuration, existingUsedTime),
            const SizedBox(height: 6),
            _buildTimeDetails(
              taskStartTime,
              allocatedDuration,
              existingUsedTime,
            ),
            if (taskNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildNotesSection(taskNotes),
            ],
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error building active task content: $e');
      debugPrint('Stack trace: $stackTrace');
      return _buildErrorWidget(
        'Error displaying task details. Please restart tracking.',
      );
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 24),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              try {
                _trackerController.stopWork(notes: "Error recovery stop");
              } catch (e) {
                debugPrint('Error during emergency stop: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Emergency Stop',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTaskHeader(TaskModel task, StartWorkModel startWorkModel) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  try {
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
                  } catch (e) {
                    debugPrint('Error navigating to task detail: $e');
                  }
                },
                child: Text(
                  task.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF25181E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.folder_open_rounded,
                    size: 12,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    startWorkModel.project.name,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.primary.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Obx(() {
          final taskStartAt = _trackerController.startWorkData.value?.startTime;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                taskStartAt != null
                    ? FormatUtils.formatTime(taskStartAt)
                    : '--:--',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Started',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildProgressBar(
    Duration allocatedDuration,
    Duration existingUsedTime,
  ) {
    return Obx(() {
      final currentSessionDuration =
          _trackerController.currentTimeEntryDuration.value;
      final initialDuration = _trackerController.initialTimeEntryDuration;
      final additionalMinutes =
          (currentSessionDuration.inMinutes - initialDuration.inMinutes)
              .clamp(0, 1000000);
      final additionalDuration = Duration(minutes: additionalMinutes);
      final totalUsedTime = Duration(
        minutes: existingUsedTime.inMinutes + additionalDuration.inMinutes,
      );
      final rawProgress = allocatedDuration.inMinutes > 0
          ? (totalUsedTime.inMinutes / allocatedDuration.inMinutes)
          : 0.0;
      final progressBarValue = rawProgress.clamp(0.0, 1.0);
      final progressColor = _getProgressColor(rawProgress);
      final displayPercentage =
          (rawProgress * 100).clamp(0.0, 100.0).toStringAsFixed(0);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Progress: $displayPercentage%",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF25181E),
                ),
              ),
              Text(
                "${_formatTimeHM(totalUsedTime)} / ${_formatTimeHM(allocatedDuration)}",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 8,
                    width: constraints.maxWidth * progressBarValue,
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: progressColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      );
    });
  }

  Widget _buildTimeDetails(
    DateTime? taskStartTime,
    Duration allocatedDuration,
    Duration existingUsedTime,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.pink.shade200),
      ),
      child: Row(
        children: [
          _buildCompactStatItem(
            icon: Icons.schedule_outlined,
            label: "Allocated",
            value: _formatTimeHM(allocatedDuration),
            color: Colors.pink.shade600,
          ),
          _buildCompactDivider(),
          _buildCompactStatItem(
            icon: Icons.hourglass_bottom_outlined,
            label: "Used",
            valueBuilder: () {
              final currentSessionDuration =
                  _trackerController.currentTimeEntryDuration.value;
              final initialDuration =
                  _trackerController.initialTimeEntryDuration;
              final additionalMinutes =
                  (currentSessionDuration.inMinutes - initialDuration.inMinutes)
                      .clamp(0, 1000000);
              final additionalDuration = Duration(minutes: additionalMinutes);
              final totalUsedTime = Duration(
                minutes:
                    existingUsedTime.inMinutes + additionalDuration.inMinutes,
              );
              return _formatTimeHM(totalUsedTime);
            },
            color: Colors.orange.shade600,
          ),
          _buildCompactDivider(),
          _buildCompactStatItem(
            icon: Icons.timer_outlined,
            label: "Remaining",
            valueBuilder: () {
              final currentSessionDuration =
                  _trackerController.currentTimeEntryDuration.value;
              final initialDuration =
                  _trackerController.initialTimeEntryDuration;
              final additionalMinutes =
                  (currentSessionDuration.inMinutes - initialDuration.inMinutes)
                      .clamp(0, 1000000);
              final additionalDuration = Duration(minutes: additionalMinutes);
              final totalUsedTime = Duration(
                minutes:
                    existingUsedTime.inMinutes + additionalDuration.inMinutes,
              );
              final isOverAllocated =
                  totalUsedTime.inMinutes > allocatedDuration.inMinutes;
              final displayTime = isOverAllocated
                  ? Duration(
                      minutes:
                          totalUsedTime.inMinutes - allocatedDuration.inMinutes,
                    )
                  : Duration(
                      minutes:
                          allocatedDuration.inMinutes - totalUsedTime.inMinutes,
                    );
              return isOverAllocated
                  ? "-${_formatTimeHM(displayTime)}"
                  : _formatTimeHM(displayTime);
            },
            color: Colors.green.shade600,
            isAlert: () {
              final currentSessionDuration =
                  _trackerController.currentTimeEntryDuration.value;
              final initialDuration =
                  _trackerController.initialTimeEntryDuration;
              final additionalMinutes =
                  (currentSessionDuration.inMinutes - initialDuration.inMinutes)
                      .clamp(0, 1000000);
              final additionalDuration = Duration(minutes: additionalMinutes);
              final totalUsedTime = Duration(
                minutes:
                    existingUsedTime.inMinutes + additionalDuration.inMinutes,
              );
              return totalUsedTime.inMinutes > allocatedDuration.inMinutes;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.primary.withOpacity(0.1),
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String label,
    String? value,
    Function? valueBuilder,
    required Color color,
    Function? isAlert,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          valueBuilder != null
              ? Obx(() {
                  final displayValue = valueBuilder();
                  final alert = isAlert?.call() ?? false;
                  return Text(
                    displayValue,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: alert ? AppTheme.error : const Color(0xFF25181E),
                      fontWeight: FontWeight.bold,
                    ),
                  );
                })
              : Text(
                  value!,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: const Color(0xFF25181E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String taskNotes) {
    final safeNotes = taskNotes.isEmpty ? 'Add task notes...' : taskNotes;

    return InkWell(
      onTap: () => _showEditNotesDialog(taskNotes),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note_rounded,
                size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                safeNotes,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: taskNotes.isEmpty
                      ? Colors.grey.shade500
                      : const Color(0xFF25181E),
                  fontStyle:
                      taskNotes.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(() {
      final user = _authController.user.value;
      final isTracking = _trackerController.isTracking.value;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (user != null) {
                      _showProfileDialog(context, user);
                    }
                  },
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white.withAlpha(77),
                    child: user?.userId != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: OdooNetworkImage(
                              model: 'res.users',
                              id: user!.userId,
                              field: 'image_128',
                              placeholder: const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.white,
                              ),
                              errorWidget: const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Guest User',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.email ?? "",
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isTracking
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isTracking
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTracking ? Colors.greenAccent : Colors.greenAccent,
                    boxShadow: isTracking
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 3,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  isTracking ? 'Active' : 'Stopped',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(isTracking ? 1 : 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              confirmationAlert(
                content: "Are you sure you want to logout?",
                onConfirm: () {
                  _authController.logout();
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.login, color: Colors.white, size: 14),
            ),
          ),
        ],
      );
    });
  }

  void _handleTrackingToggle() {
    try {
      final isTracking = _trackerController.isTracking.value;

      if (isTracking) {
        final startWorkData = _trackerController.startWorkData.value;
        if (startWorkData == null) {
          debugPrint(
            'Warning: Trying to stop tracking but no start work data found',
          );
          _showErrorDialog('No active task found to stop');
          return;
        }

        EndWorkDialog.show(
          context: context,
          trackedDuration: _trackerController.currentTimeEntryDuration.value,
          project: startWorkData.project,
          task: startWorkData.task,
          onStop: (EndWorkResult result) {
            try {
              _trackerController.stopWork(notes: result.notes);
            } catch (e) {
              debugPrint('Error stopping work: $e');
              _showErrorDialog('Failed to stop tracking. Please try again.');
            }
          },
        );
      } else {
        _showTaskSelectionDialog();
      }
    } catch (e, stackTrace) {
      debugPrint('Error in tracking toggle: $e');
      debugPrint('Stack trace: $stackTrace');
      _showErrorDialog(
        'An error occurred while toggling tracking. Please restart the app if this persists.',
      );
    }
  }

  void _showTaskSelectionDialog({TaskModel? exitingTask}) async {
    try {
      final isTracking = Get.find<TrackerController>().isTracking.value;
      if (isTracking) {
        debugPrint('Warning: Trying to start task but already tracking');
        return;
      }

      final TaskModel? task = exitingTask ?? await Get.to(MyTaskListScreen());
      if (task == null) {
        debugPrint('No task selected');
        return;
      }

      final StartWorkResult? result = await DialogUtils.showAppDialog(
        context: Get.context!,
        title: "Start work",
        content: StartTrackerForm(task: task),
      );

      if (result != null) {
        try {
          _trackerController.startWork(
            project: result.project,
            task: result.task,
            timesheet: result.timesheet,
            notes: result.notes,
          );
        } catch (e) {
          debugPrint('Error starting work: $e');
          _showErrorDialog(
            'Failed to start tracking. Please check your connection and try again.',
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error in task selection dialog: $e');
      debugPrint('Stack trace: $stackTrace');
      _showErrorDialog(
        'An error occurred while selecting task. Please try again.',
      );
    }
  }

  void _showErrorDialog(String message) {
    DialogUtils.showAppDialog(
      context: context,
      title: "Error",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditNotesDialog(String currentNotes) {
    try {
      final notesController = TextEditingController(text: currentNotes);

      DialogUtils.showAppDialog(
        context: context,
        title: "Edit Notes",
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                color: AppTheme.surfaceContainer,
              ),
              child: TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'Enter task notes...',
                  contentPadding: const EdgeInsets.all(12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                maxLines: 5,
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    try {
                      final newNotes = notesController.text.trim();
                      _trackerController.updateNotes(newNotes);
                      Navigator.pop(context);
                    } catch (e) {
                      debugPrint('Error updating notes: $e');
                      _showErrorDialog(
                        'Failed to update notes. Please try again.',
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error showing edit notes dialog: $e');
      debugPrint('Stack trace: $stackTrace');
      _showErrorDialog('Failed to open notes editor. Please try again.');
    }
  }

  String _formatDuration(Duration duration) {
    return FormatUtils.formatDuration(duration);
  }

  String _formatTimeHM(Duration duration) {
    return FormatUtils.formatTimeHM(duration);
  }

  Widget _buildBottomSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: _buildRecentTasksSection(),
    );
  }

  Widget _buildRecentTasksSection() {
    return RecentActivityWidget(handleStartTask: _showTaskSelectionDialog);
  }

  void _showProfileDialog(BuildContext context, UserModel user) {
    DialogUtils.showAppDialog(
      context: context,
      title: "User Profile",
      content: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: OdooNetworkImage(
                  model: 'res.users',
                  id: user.userId,
                  field: 'image_256',
                  placeholder: Container(
                    color: AppTheme.primary,
                    alignment: Alignment.center,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: AppTheme.primary,
                    alignment: Alignment.center,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF25181E),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              user.email,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            _buildProfileDetailItem(
              icon: Icons.person_outline,
              label: "User ID",
              value: user.userId.toString(),
            ),
            _buildProfileDetailItem(
              icon: Icons.dns_outlined,
              label: "Database",
              value: OdooRpcApiManager.authenticationState['database'] ?? 'N/A',
            ),
            _buildProfileDetailItem(
              icon: Icons.link_rounded,
              label: "Server URL",
              value:
                  OdooRpcApiManager.authenticationState['serverUrl'] ?? 'N/A',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  confirmationAlert(
                    content: "Are you sure you want to logout?",
                    onConfirm: () {
                      _authController.logout();
                    },
                  );
                },
                icon: const Icon(Icons.logout, size: 16, color: Colors.white),
                label: const Text(
                  "Logout",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary.withOpacity(0.7)),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF25181E),
            ),
          ),
        ],
      ),
    );
  }
}
