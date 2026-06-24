import 'package:pi_task_watch/exports.dart';

class TaskController extends GetxController {
  final RxList<TaskModel> _taskList = <TaskModel>[].obs;
  List<TaskModel> get taskList => _taskList;

  final RxBool _isLoading = false.obs;
  RxBool get isLoading => _isLoading;

  final RxList<Map<String, dynamic>> taskStages = <Map<String, dynamic>>[].obs;
  List<Map<String, dynamic>> get stages => taskStages;

  final RxList<Map<String, dynamic>> taskActivities =
      <Map<String, dynamic>>[].obs;

  final RxList<Map<String, dynamic>> taskSubtasks =
      <Map<String, dynamic>>[].obs;
  List<Map<String, dynamic>> get subtasks => taskSubtasks;

  final RxList<Map<String, dynamic>> taskBlockedBy =
      <Map<String, dynamic>>[].obs;
  List<Map<String, dynamic>> get blockedBy => taskBlockedBy;

  final RxList<Map<String, dynamic>> taskTimesheets =
      <Map<String, dynamic>>[].obs;

  final Rxn<TaskModel> currentTask = Rxn<TaskModel>();

  Future<List<TaskModel>> getTaskList({required int? projectId}) async {
    try {
      _isLoading.value = true;
      final response = await ApiManager.getRequest(
        endPoint: projectId != null ? 'tasks?project_id=$projectId' : 'tasks',
      );
      if (response.isSuccess) {
        _taskList.value = (response.body['data'] as List)
            .map((e) => TaskModel.fromJson(e))
            .toList();
        return _taskList;
      }
      return [];
    } catch (e) {
      print("Error fetching task list: $e");
      return [];
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> getTaskDetails(int taskId) async {
    try {
      final response = await ApiManager.getRequest(endPoint: 'tasks/$taskId');
      if (response.isSuccess) {
        currentTask.value = TaskModel.fromJson(response.body['data']);
      }
    } catch (e) {
      print("Error fetching task details: $e");
    }
  }

  Future<void> getTaskStages(int taskId) async {
    try {
      print('🔍 Fetching stages for task ID: $taskId');
      final response =
          await ApiManager.getRequest(endPoint: 'tasks/$taskId/stages');
      print('📦 Stages API Response Status: ${response.statusCode}');

      // Only process if we get a successful response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('📦 Stages API Response Body: ${response.body}');
        print('✅ Success flag: ${response.body['success']}');

        if (response.body['success'] == true) {
          taskStages.value =
              List<Map<String, dynamic>>.from(response.body['data']);
          print('✅ Loaded ${taskStages.length} stages');
        } else {
          print('❌ API returned success=false');
        }
      } else {
        print('⚠️ API returned status code: ${response.statusCode}');
        print('⚠️ This endpoint may not be implemented yet');
      }
    } catch (e) {
      print('❌ Error fetching task stages: $e');
      // Don't clear existing data on error
    }
  }

  Future<bool> updateTaskStage(int taskId, int stageId) async {
    try {
      final response = await ApiManager.postRequest(
        endPoint: 'tasks/$taskId/stage',
        data: {'stage_id': stageId},
      );
      return response.body['success'] == true;
    } catch (e) {
      print('Error updating task stage: $e');
      return false;
    }
  }

  Future<void> getTaskActivities(int taskId) async {
    try {
      final response =
          await ApiManager.getRequest(endPoint: 'tasks/$taskId/activities');
      if (response.body['success'] == true) {
        taskActivities.value =
            List<Map<String, dynamic>>.from(response.body['data']);
      }
    } catch (e) {
      print('Error fetching task activities: $e');
    }
  }

  Future<bool> createTaskActivity(int taskId, String body) async {
    try {
      final response = await ApiManager.postRequest(
        endPoint: 'tasks/$taskId/activity',
        data: {'body': body},
      );
      if (response.body['success'] == true) {
        await getTaskActivities(taskId);
        return true;
      }
      return false;
    } catch (e) {
      print('Error creating task activity: $e');
      return false;
    }
  }

  Future<bool> createTaskNote(int taskId, String body) async {
    try {
      final response = await ApiManager.postRequest(
        endPoint: 'tasks/$taskId/notes',
        data: {'body': body},
      );
      if (response.body['success'] == true) {
        await getTaskActivities(taskId);
        return true;
      }
      return false;
    } catch (e) {
      print('Error creating log note: $e');
      return false;
    }
  }

  Future<void> getTaskTimesheets(int taskId) async {
    try {
      final response =
          await ApiManager.getRequest(endPoint: 'tasks/$taskId/timesheets');
      if (response.body['success'] == true) {
        taskTimesheets.value =
            List<Map<String, dynamic>>.from(response.body['data']);
      }
    } catch (e) {
      print('Error fetching task timesheets: $e');
    }
  }

  Future<void> getTaskSubtasks(int taskId) async {
    try {
      final response =
          await ApiManager.getRequest(endPoint: 'tasks/$taskId/subtasks');
      if (response.body['success'] == true) {
        taskSubtasks.value =
            List<Map<String, dynamic>>.from(response.body['data']);
      }
    } catch (e) {
      print('Error fetching task subtasks: $e');
    }
  }

  Future<void> getTaskBlockedBy(int taskId) async {
    try {
      final response =
          await ApiManager.getRequest(endPoint: 'tasks/$taskId/blocked-by');
      if (response.body['success'] == true) {
        taskBlockedBy.value =
            List<Map<String, dynamic>>.from(response.body['data']);
      }
    } catch (e) {
      print('Error fetching blocked by tasks: $e');
    }
  }

  // Aliases for convenience
  Future<void> getSubtasks(int taskId) => getTaskSubtasks(taskId);
  Future<void> getBlockedBy(int taskId) => getTaskBlockedBy(taskId);
}
