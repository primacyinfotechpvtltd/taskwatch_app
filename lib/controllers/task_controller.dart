import 'package:intl/intl.dart';
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

  void clearCache() {
    _taskList.clear();
    taskStages.clear();
    taskActivities.clear();
    taskSubtasks.clear();
    taskBlockedBy.clear();
    taskTimesheets.clear();
    currentTask.value = null;
  }

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

  /// Create a new task strictly assigned to the currently logged in user
  Future<TaskModel?> createTask({
    required String name,
    required int projectId,
    String? description,
    DateTime? startDate,
    DateTime? deadline,
    double? allocatedHours,
  }) async {
    try {
      _isLoading.value = true;

      // Ensure logged in user is assigned
      final authController = Get.find<AuthController>();
      final currentUser = authController.user.value;
      if (currentUser == null) {
        showToast('Please log in to create a task', idSuccess: false);
        return null;
      }

      final int userId = currentUser.userId;
      final Map<String, dynamic> values = {
        'name': name.trim(),
        'project_id': projectId,
        // Strictly assign ONLY the logged-in user
        'user_ids': [
          [6, 0, [userId]]
        ],
      };

      if (description != null && description.trim().isNotEmpty) {
        values['description'] = description.trim();
      }

      if (deadline != null) {
        values['date_deadline'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(deadline.toUtc());
      }

      if (allocatedHours != null && allocatedHours > 0) {
        values['allocated_hours'] = allocatedHours;
      }

      // If startDate is also provided (double data / range mode), try with planned_date_begin
      if (startDate != null) {
        values['planned_date_begin'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate.toUtc());
      }

      // Try creating via OdooRpcApiManager
      var odooResponse = await OdooRpcApiManager.create(
        model: 'project.task',
        values: values,
      );

      // If failed due to planned_date_begin not existing in standard Odoo, retry with date_deadline only
      if (!odooResponse.isSuccess &&
          values.containsKey('planned_date_begin') &&
          (odooResponse.message.contains('planned_date_begin') || odooResponse.message.contains('Invalid field'))) {
        values.remove('planned_date_begin');
        odooResponse = await OdooRpcApiManager.create(
          model: 'project.task',
          values: values,
        );
      }

      if (odooResponse.isSuccess && odooResponse.data != null) {
        final int taskId = odooResponse.data as int;
        showToast('Task created successfully', idSuccess: true);
        await getTaskList(projectId: null);
        return _taskList.firstWhereOrNull((t) => t.id == taskId);
      } else {
        // Fallback: try via REST API if RPC is not enabled
        final restResponse = await ApiManager.postRequest(
          endPoint: 'tasks',
          data: {
            'name': name.trim(),
            'project_id': projectId,
            'user_id': userId,
            'user_ids': [userId],
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            if (startDate != null)
              'start_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate),
            if (deadline != null) ...{
              'date_deadline': DateFormat('yyyy-MM-dd HH:mm:ss').format(deadline),
              'end_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(deadline),
            },
            if (allocatedHours != null && allocatedHours > 0)
              'allocated_hours': allocatedHours,
          },
        );

        if (restResponse.isSuccess) {
          showToast('Task created successfully', idSuccess: true);
          await getTaskList(projectId: null);
          return _taskList.isNotEmpty ? _taskList.first : null;
        }

        final errMsg = odooResponse.message.isNotEmpty
            ? odooResponse.message
            : (restResponse.message.isNotEmpty
                ? restResponse.message
                : 'Failed to create task');
        showToast(errMsg, idSuccess: false);
        return null;
      }
    } catch (e) {
      print("Error creating task: $e");
      showToast('Error creating task: $e', idSuccess: false);
      return null;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Update an existing task's description, allocated hours, deadline, and/or name
  Future<bool> updateTask({
    required int taskId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? deadline,
    double? allocatedHours,
  }) async {
    try {
      _isLoading.value = true;

      final Map<String, dynamic> values = {};
      if (name != null && name.trim().isNotEmpty) {
        values['name'] = name.trim();
      }
      if (description != null) {
        values['description'] = description.trim();
      }
      if (deadline != null) {
        values['date_deadline'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(deadline.toUtc());
      }
      if (startDate != null) {
        values['planned_date_begin'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate.toUtc());
      }
      if (allocatedHours != null) {
        values['allocated_hours'] = allocatedHours;
      }

      if (values.isEmpty) return true;

      // Try via OdooRpcApiManager.write
      var odooResponse = await OdooRpcApiManager.write(
        model: 'project.task',
        ids: [taskId],
        values: values,
      );

      if (!odooResponse.isSuccess &&
          values.containsKey('planned_date_begin') &&
          (odooResponse.message.contains('planned_date_begin') || odooResponse.message.contains('Invalid field'))) {
        values.remove('planned_date_begin');
        odooResponse = await OdooRpcApiManager.write(
          model: 'project.task',
          ids: [taskId],
          values: values,
        );
      }

      if (odooResponse.isSuccess) {
        showToast('Task updated successfully', idSuccess: true);
        await getTaskList(projectId: null);
        return true;
      } else {
        // Fallback: try REST API
        final restResponse = await ApiManager.postRequest(
          endPoint: 'tasks/$taskId',
          data: values,
        );

        if (restResponse.isSuccess) {
          showToast('Task updated successfully', idSuccess: true);
          await getTaskList(projectId: null);
          return true;
        }

        final errMsg = odooResponse.message.isNotEmpty
            ? odooResponse.message
            : (restResponse.message.isNotEmpty
                ? restResponse.message
                : 'Failed to update task');
        showToast(errMsg, idSuccess: false);
        return false;
      }
    } catch (e) {
      print("Error updating task: $e");
      showToast('Error updating task: $e', idSuccess: false);
      return false;
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
