import 'package:pi_task_watch/exports.dart';

/// Controller for managing tasks and their related data
/// Handles all API interactions for task management including:
/// - Task details retrieval
/// - Stage management
/// - Activities/Chatter
/// - Timesheets
/// - Subtasks
/// - Dependencies
class TaskDetailsController extends GetxController {
  // Observable state management
  final Rx<TaskDetailsModel?> currentTask = Rx<TaskDetailsModel?>(null);
  final RxList<TaskStage> stages = <TaskStage>[].obs;
  final RxList<TaskActivity> activities = <TaskActivity>[].obs;
  final RxList<TaskTimesheet> timesheets = <TaskTimesheet>[].obs;
  final RxList<Subtask> subtasks = <Subtask>[].obs;
  final RxList<Subtask> blockedBy = <Subtask>[].obs;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingStages = false.obs;
  final RxBool isLoadingActivities = false.obs;
  final RxBool isLoadingTimesheets = false.obs;
  final RxBool isLoadingSubtasks = false.obs;
  final RxBool isLoadingBlockedBy = false.obs;
  final RxBool isInitialLoading = false.obs;

  // Error handling
  final RxString errorMessage = ''.obs;

  /// Handle API errors consistently
  void _handleError(dynamic error, String context) {
    print('Error in $context: $error');
    errorMessage.value = 'Failed to $context. Please try again.';
    // Get.snackbar(
    //   'Error',
    //   errorMessage.value,
    //   snackPosition: SnackPosition.BOTTOM,
    //   duration: const Duration(seconds: 3),
    // );
  }

  /// 1. Get Task Details
  Future<TaskDetailsModel?> getTaskDetails(int taskId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await ApiManager.getRequest(
        endPoint: 'tasks/$taskId',
      );

      if (response.isSuccess) {
        currentTask.value = TaskDetailsModel.fromJson(response.data);
        return currentTask.value;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'load task details');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// 2. Get Task Stages
  Future<List<TaskStage>> getTaskStages(int taskId) async {
    try {
      isLoadingStages.value = true;
      errorMessage.value = '';

      final response = await ApiManager.getRequest(
        endPoint: 'tasks/$taskId/stages',
      );

      if (response.isSuccess) {
        stages.value =
            (response.data as List).map((x) => TaskStage.fromJson(x)).toList();
        return stages;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'load task stages');
      return [];
    } finally {
      isLoadingStages.value = false;
    }
  }

  /// 3. Update Task Stage
  Future<bool> updateTaskStage(int taskId, int stageId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await ApiManager.postRequest(
        endPoint: 'tasks/$taskId/stage',
        data: {'stage_id': stageId},
      );

      if (response.isSuccess) {
        if (currentTask.value != null) {
          await getTaskDetails(taskId);
        }

        // Get.snackbar(
        //   'Success',
        //   'Stage updated successfully',
        //   snackPosition: SnackPosition.BOTTOM,
        //   duration: const Duration(seconds: 2),
        // );

        return true;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'update task stage');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 4. Get Task Activities (Chatter)
  Future<List<TaskActivity>> getTaskActivities(int taskId) async {
    try {
      isLoadingActivities.value = true;
      errorMessage.value = '';

      final response = await ApiManager.getRequest(
        endPoint: 'tasks/$taskId/activities',
      );

      if (response.isSuccess) {
        activities.value = (response.data as List)
            .map((x) => TaskActivity.fromJson(x))
            .toList();
        return activities;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'load task activities');
      return [];
    } finally {
      isLoadingActivities.value = false;
    }
  }

  /// 5. Create Task Activity (Post Message)
  Future<int?> createTaskActivity(int taskId, String body) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await ApiManager.postRequest(
        endPoint: 'tasks/$taskId/activity',
        data: {'body': body},
      );

      if (response.isSuccess) {
        await getTaskActivities(taskId);

        // Get.snackbar(
        //   'Success',
        //   'Message posted successfully',
        //   snackPosition: SnackPosition.BOTTOM,
        //   duration: const Duration(seconds: 2),
        // );

        return response.body['id'];
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'post message');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// 6. Create Log Note
  Future<int?> createLogNote(int taskId, String body) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await ApiManager.postRequest(
        endPoint: 'tasks/$taskId/notes',
        data: {'body': body},
      );

      if (response.isSuccess) {
        await getTaskActivities(taskId);

        // Get.snackbar(
        //   'Success',
        //   'Note logged successfully',
        //   snackPosition: SnackPosition.BOTTOM,
        //   duration: const Duration(seconds: 2),
        // );

        return response.body['id'];
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'log note');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// 7. Get Task Timesheets
  Future<List<TaskTimesheet>> getTaskTimesheets(int taskId) async {
    try {
      isLoadingTimesheets.value = true;
      errorMessage.value = '';

      final response = await ApiManager.getRequest(
        endPoint: 'tasks/$taskId/timesheets',
      );

      if (response.isSuccess) {
        timesheets.value = (response.data as List)
            .map((x) => TaskTimesheet.fromJson(x))
            .toList();
        return timesheets;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'load timesheets');
      return [];
    } finally {
      isLoadingTimesheets.value = false;
    }
  }

  /// 8. Get Task Subtasks
  Future<List<Subtask>> getSubtasks(int taskId) async {
    try {
      isLoadingSubtasks.value = true;
      errorMessage.value = '';

      final response = await ApiManager.getRequest(
        endPoint: 'tasks/$taskId/subtasks',
      );

      if (response.isSuccess) {
        subtasks.value =
            (response.data as List).map((x) => Subtask.fromJson(x)).toList();
        return subtasks;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'load subtasks');
      return [];
    } finally {
      isLoadingSubtasks.value = false;
    }
  }

  /// 9. Get Blocked By Tasks
  Future<List<Subtask>> getBlockedBy(int taskId) async {
    try {
      isLoadingBlockedBy.value = true;
      errorMessage.value = '';

      final response = await ApiManager.getRequest(
        endPoint: 'tasks/$taskId/blocked-by',
      );

      if (response.isSuccess) {
        blockedBy.value =
            (response.data as List).map((x) => Subtask.fromJson(x)).toList();
        return blockedBy;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'load blocked by tasks');
      return [];
    } finally {
      isLoadingBlockedBy.value = false;
    }
  }

  /// Comprehensive method to load all task data at once
  Future<void> loadAllTaskData(int taskId) async {
    try {
      isInitialLoading.value = true;
      await Future.wait([
        getTaskDetails(taskId),
        getTaskStages(taskId),
        getTaskActivities(taskId),
        getTaskTimesheets(taskId),
        getSubtasks(taskId),
        getBlockedBy(taskId),
      ]);
    } finally {
      isInitialLoading.value = false;
    }
  }

  /// Refresh current task data
  Future<void> refreshTaskData() async {
    if (currentTask.value != null) {
      await loadAllTaskData(currentTask.value!.id);
    }
  }

  /// Calculate total time spent from timesheets or pre-calculated usedTime
  String getTotalTimeSpent() {
    if (currentTask.value?.usedTime != null) {
      return currentTask.value!.usedTime!;
    }

    if (timesheets.isEmpty) return '00:00';

    double totalHours = 0;
    for (var timesheet in timesheets) {
      totalHours += timesheet.unitAmount;
    }

    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).round();

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Clear all data (useful when navigating away)
  void clearData() {
    currentTask.value = null;
    stages.clear();
    activities.clear();
    timesheets.clear();
    subtasks.clear();
    blockedBy.clear();
    errorMessage.value = '';
  }

  @override
  void onClose() {
    clearData();
    super.onClose();
  }
}
