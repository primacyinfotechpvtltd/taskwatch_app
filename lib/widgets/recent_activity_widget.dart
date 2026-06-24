import 'package:pi_task_watch/controllers/timesheet_controller.dart';
import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/models/timesheet_model.dart';

class RecentActivityWidget extends StatelessWidget {
  final void Function({TaskModel? exitingTask}) handleStartTask;

  const RecentActivityWidget({super.key, required this.handleStartTask});

  void _refreshTimesheets() {
    Get.find<TimesheetController>().getAllTimesheet(date: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 8),
          Obx(() {
            final timesheetList = Get.find<TimesheetController>().timesheetList;
            return Column(
              children: timesheetList.map((activity) {
                bool isWorking = false;
                final workingData =
                    Get.find<TrackerController>().startWorkData.value;
                if (activity.timesheetId == workingData?.timesheetId) {
                  isWorking = true;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildRecentTaskItem(
                    activity,
                    context,
                    isCurrentlyWorking: isWorking,
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule_outlined,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              "Today's Timesheets",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _refreshTimesheets,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.refresh, size: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTaskItem(
    TimesheetModel timesheet,
    BuildContext context, {
    bool isCurrentlyWorking = false,
  }) {
    return InkWell(
      onTap: () async {
        final taskList = await Get.find<TaskController>().getTaskList(
          projectId: timesheet.projectId,
        );
        TaskModel? selectedTask;
        if (timesheet.taskId != null) {
          for (final t in taskList) {
            if (t.id == timesheet.taskId) {
              selectedTask = t;
              break;
            }
          }
        }
        handleStartTask(exitingTask: selectedTask);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrentlyWorking ? Colors.pink.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrentlyWorking
                ? Colors.pink.shade200
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color:
                        isCurrentlyWorking ? Colors.blue.shade600 : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrentlyWorking ? Icons.play_arrow : Icons.check,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrentlyWorking) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timesheet.taskName ?? 'No task assigned',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        timesheet.projectName,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${timesheet.timeSpentDuration.inHours.toString().padLeft(2, '0')}:${(timesheet.timeSpentDuration.inMinutes % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (timesheet.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  timesheet.description,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
