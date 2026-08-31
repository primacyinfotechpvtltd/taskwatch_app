import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/managers/odoo_rpc_api_manager.dart';

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
  final RxList<TaskPlannedActivity> plannedActivities =
      <TaskPlannedActivity>[].obs;
  final RxList<Map<String, dynamic>> followers = <Map<String, dynamic>>[].obs;
  final RxList<TaskTimesheet> timesheets = <TaskTimesheet>[].obs;
  final RxList<Subtask> subtasks = <Subtask>[].obs;
  final RxList<Subtask> blockedBy = <Subtask>[].obs;
  final RxList<TaskAttachment> attachments = <TaskAttachment>[].obs;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingStages = false.obs;
  final RxBool isLoadingActivities = false.obs;
  final RxBool isLoadingTimesheets = false.obs;
  final RxBool isLoadingSubtasks = false.obs;
  final RxBool isLoadingBlockedBy = false.obs;
  final RxBool isLoadingAttachments = false.obs;
  final RxBool isInitialLoading = false.obs;

  // Error handling
  final RxString errorMessage = ''.obs;

  /// Handle API errors consistently
  void _handleError(dynamic error, String context) {
    print('Error in $context: $error');
    errorMessage.value = 'Failed to $context. Please try again.';
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

  /// 4. Get Task Activities (Chatter Messages + Tracking Values + Planned Activities from Odoo)
  Future<List<TaskActivity>> getTaskActivities(int taskId) async {
    try {
      isLoadingActivities.value = true;
      errorMessage.value = '';

      // 1. Query Planned Activities from mail.activity
      try {
        final actRes = await OdooRpcApiManager.searchRead(
          model: 'mail.activity',
          domain: [
            ['res_model', '=', 'project.task'],
            ['res_id', '=', taskId],
          ],
          fields: [
            'id',
            'summary',
            'note',
            'activity_type_id',
            'date_deadline',
            'user_id',
            'state',
            'display_name',
          ],
          order: 'date_deadline asc, id asc',
        );

        if (actRes.isSuccess && actRes.data is List) {
          plannedActivities.value = (actRes.data as List)
              .map((x) => TaskPlannedActivity.fromJson(x))
              .toList();
        }
      } catch (e) {
        debugPrint('Error fetching planned activities: $e');
      }

      // Also fetch followers in parallel
      getTaskFollowers(taskId);

      // 2. Query Chatter Messages & Timeline from mail.message
      try {
        final msgRes = await OdooRpcApiManager.searchRead(
          model: 'mail.message',
          domain: [
            ['model', '=', 'project.task'],
            ['res_id', '=', taskId],
          ],
          fields: [
            'id',
            'body',
            'date',
            'author_id',
            'message_type',
            'subtype_id',
            'tracking_value_ids',
            'attachment_ids',
          ],
          order: 'date desc, id desc',
          limit: 100,
        );

        if (msgRes.isSuccess && msgRes.data is List && (msgRes.data as List).isNotEmpty) {
          final rawList = List<Map<String, dynamic>>.from(msgRes.data as List);

          // Collect all tracking IDs
          final allTrackingIds = <int>[];
          for (var m in rawList) {
            if (m['tracking_value_ids'] is List) {
              for (var t in m['tracking_value_ids']) {
                if (t is int) {
                  allTrackingIds.add(t);
                } else if (t is String) {
                  final parsed = int.tryParse(t);
                  if (parsed != null) allTrackingIds.add(parsed);
                }
              }
            }
          }

          final trackingMap = <int, Map<String, dynamic>>{};
          if (allTrackingIds.isNotEmpty) {
            try {
              final trackRes = await OdooRpcApiManager.searchRead(
                model: 'mail.tracking.value',
                domain: [
                  ['id', 'in', allTrackingIds]
                ],
                fields: [
                  'id',
                  'field_desc',
                  'old_value_char',
                  'new_value_char',
                  'field_name',
                  'old_value_integer',
                  'new_value_integer'
                ],
              );
              if (trackRes.isSuccess && trackRes.data is List) {
                for (var tr in trackRes.data as List) {
                  if (tr['id'] is int) {
                    trackingMap[tr['id']] = Map<String, dynamic>.from(tr);
                  }
                }
              }
            } catch (e) {
              debugPrint('Error loading tracking values: $e');
            }
          }

          // Build enriched TaskActivity list
          final enriched = <TaskActivity>[];
          for (var m in rawList) {
            String? stageOld;
            String? stageNew;
            String? trackDesc;

            if (m['tracking_value_ids'] is List) {
              for (var t in m['tracking_value_ids']) {
                final tId = t is int ? t : int.tryParse(t.toString());
                if (tId != null && trackingMap.containsKey(tId)) {
                  final tr = trackingMap[tId]!;
                  trackDesc = tr['field_desc']?.toString() ?? 'Stage';
                  stageOld = tr['old_value_char']?.toString() ??
                      tr['old_value_integer']?.toString() ??
                      '';
                  stageNew = tr['new_value_char']?.toString() ??
                      tr['new_value_integer']?.toString() ??
                      '';
                }
              }
            }

            final act = TaskActivity.fromJson({
              ...m,
              if (stageOld != null) 'stage_old_value': stageOld,
              if (stageNew != null) 'stage_new_value': stageNew,
              if (trackDesc != null) 'tracking_desc': trackDesc,
            });
            enriched.add(act);
          }

          activities.value = enriched;
          return activities;
        }
      } catch (e) {
        debugPrint('Error fetching chatter messages via RPC: $e');
      }

      // 3. Fallback to REST API if RPC returned empty or failed
      final response = await ApiManager.getRequest(
        endPoint: 'tasks/$taskId/activities',
      );

      if (response.isSuccess && response.data is List) {
        activities.value = (response.data as List)
            .map((x) => TaskActivity.fromJson(x))
            .toList();
        return activities;
      }
      return activities;
    } catch (e) {
      _handleError(e, 'load task activities');
      return activities;
    } finally {
      isLoadingActivities.value = false;
    }
  }

  /// Fetch task followers from mail.followers in Odoo
  Future<void> getTaskFollowers(int taskId) async {
    try {
      final res = await OdooRpcApiManager.searchRead(
        model: 'mail.followers',
        domain: [
          ['res_model', '=', 'project.task'],
          ['res_id', '=', taskId],
        ],
        fields: ['id', 'partner_id', 'is_active'],
      );
      if (res.isSuccess && res.data != null) {
        followers.value = List<Map<String, dynamic>>.from(res.data!);
      }
    } catch (e) {
      debugPrint('Error getting followers: $e');
    }
  }

  /// 5. Post Message to Followers (Send Message)
  Future<int?> createTaskActivity(int taskId, String body) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Direct Odoo message_post
      final rpcRes = await OdooRpcApiManager.call(
        model: 'project.task',
        method: 'message_post',
        args: [
          [taskId],
        ],
        kwargs: {
          'body': body,
          'message_type': 'comment',
          'subtype_xmlid': 'mail.mt_comment',
        },
      );

      if (rpcRes.isSuccess) {
        await getTaskActivities(taskId);
        showToast('Message sent to followers', idSuccess: true);
        return rpcRes.data is int ? rpcRes.data : 1;
      }

      // Fallback to API endpoint
      final response = await ApiManager.postRequest(
        endPoint: 'tasks/$taskId/activity',
        data: {'body': body},
      );

      if (response.isSuccess) {
        await getTaskActivities(taskId);
        showToast('Message sent', idSuccess: true);
        return response.body['id'];
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'send message');
      showToast('Failed to send message: $e', idSuccess: false);
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// 6. Create Log Note (Internal Note)
  Future<int?> createLogNote(int taskId, String body) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Direct Odoo message_post for internal note
      final rpcRes = await OdooRpcApiManager.call(
        model: 'project.task',
        method: 'message_post',
        args: [
          [taskId],
        ],
        kwargs: {
          'body': body,
          'message_type': 'comment',
          'subtype_xmlid': 'mail.mt_note',
        },
      );

      if (rpcRes.isSuccess) {
        await getTaskActivities(taskId);
        showToast('Internal note logged', idSuccess: true);
        return rpcRes.data is int ? rpcRes.data : 1;
      }

      // Fallback to API endpoint
      final response = await ApiManager.postRequest(
        endPoint: 'tasks/$taskId/notes',
        data: {'body': body},
      );

      if (response.isSuccess) {
        await getTaskActivities(taskId);
        showToast('Internal note logged', idSuccess: true);
        return response.body['id'];
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _handleError(e, 'log note');
      showToast('Failed to log note: $e', idSuccess: false);
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// 7. Mark Planned Activity as Done
  Future<bool> markActivityDone(int taskId, int activityId,
      [String? feedback]) async {
    try {
      isLoading.value = true;
      final rpcRes = await OdooRpcApiManager.call(
        model: 'mail.activity',
        method: 'action_feedback',
        args: [
          [activityId],
        ],
        kwargs: {
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        },
      );

      if (rpcRes.isSuccess) {
        await getTaskActivities(taskId);
        showToast('Activity marked as done', idSuccess: true);
        return true;
      } else {
        // Try fallback action_done
        final doneRes = await OdooRpcApiManager.call(
          model: 'mail.activity',
          method: 'action_done',
          args: [
            [activityId],
          ],
        );
        if (doneRes.isSuccess) {
          await getTaskActivities(taskId);
          showToast('Activity marked as done', idSuccess: true);
          return true;
        }
      }
      showToast('Failed to complete activity', idSuccess: false);
      return false;
    } catch (e) {
      showToast('Error completing activity: $e', idSuccess: false);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 8. Cancel / Delete Planned Activity
  Future<bool> cancelActivity(int taskId, int activityId) async {
    try {
      isLoading.value = true;
      final rpcRes = await OdooRpcApiManager.call(
        model: 'mail.activity',
        method: 'unlink',
        args: [
          [activityId],
        ],
      );

      if (rpcRes.isSuccess) {
        await getTaskActivities(taskId);
        showToast('Activity cancelled', idSuccess: true);
        return true;
      }
      showToast('Failed to cancel activity', idSuccess: false);
      return false;
    } catch (e) {
      showToast('Error cancelling activity: $e', idSuccess: false);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Cached res_model_id for project.task in ir.model
  int? _cachedTaskModelId;

  Future<int?> _getProjectTaskModelId() async {
    if (_cachedTaskModelId != null && _cachedTaskModelId! > 0) {
      return _cachedTaskModelId;
    }
    try {
      final res = await OdooRpcApiManager.searchRead(
        model: 'ir.model',
        domain: [
          ['model', '=', 'project.task']
        ],
        fields: ['id'],
        limit: 1,
      );
      if (res.isSuccess && res.data is List && (res.data as List).isNotEmpty) {
        final first = (res.data as List).first;
        _cachedTaskModelId = first['id'] is int
            ? first['id']
            : int.tryParse(first['id'].toString());
        if (_cachedTaskModelId != null && _cachedTaskModelId! > 0) {
          return _cachedTaskModelId;
        }
      }
    } catch (e) {
      debugPrint('Error getting ir.model for project.task: $e');
    }

    try {
      final actRes = await OdooRpcApiManager.searchRead(
        model: 'mail.activity',
        domain: [
          ['res_model', '=', 'project.task']
        ],
        fields: ['res_model_id'],
        limit: 1,
      );
      if (actRes.isSuccess &&
          actRes.data is List &&
          (actRes.data as List).isNotEmpty) {
        final first = (actRes.data as List).first;
        final rawModelId = first['res_model_id'];
        if (rawModelId is List && rawModelId.isNotEmpty) {
          _cachedTaskModelId = rawModelId[0] is int
              ? rawModelId[0]
              : int.tryParse(rawModelId[0].toString());
        } else if (rawModelId is int) {
          _cachedTaskModelId = rawModelId;
        }
        if (_cachedTaskModelId != null && _cachedTaskModelId! > 0) {
          return _cachedTaskModelId;
        }
      }
    } catch (e) {
      debugPrint('Error getting res_model_id from existing mail.activity: $e');
    }

    return null;
  }

  /// 6b. Schedule Odoo Activity (with inline image attachments embedded in activity note)
  Future<bool> scheduleActivity({
    required int taskId,
    required int activityTypeId,
    required String summary,
    required DateTime dueDate,
    required int userId,
    String? note,
    List<PlatformFile>? attachments,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final validTaskId = taskId > 0 ? taskId : (currentTask.value?.id ?? 0);
      if (validTaskId <= 0) {
        showToast('Invalid Task ID for activity', idSuccess: false);
        return false;
      }

      String effectiveNote = note?.trim() ?? '';
      
      // If user attached images to the activity, embed them directly in the activity note HTML
      if (attachments != null && attachments.isNotEmpty) {
        for (final att in attachments) {
          final ext = att.extension?.toLowerCase() ?? '';
          if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext) &&
              att.bytes != null &&
              att.bytes!.isNotEmpty) {
            final b64 = base64Encode(att.bytes!);
            final mime = ext == 'png'
                ? 'image/png'
                : (ext == 'webp' ? 'image/webp' : (ext == 'gif' ? 'image/gif' : 'image/jpeg'));
            if (effectiveNote.isNotEmpty) {
              effectiveNote += '<br/>';
            }
            effectiveNote += '<p><img src="data:$mime;base64,$b64" alt="${att.name}" /></p>';
          } else if (att.name.isNotEmpty) {
            if (effectiveNote.isNotEmpty) effectiveNote += '<br/>';
            effectiveNote += '<p>Attached: <b>${att.name}</b></p>';
          }
        }
      }

      final effectiveSummary = summary.trim();
      final effectiveBody = effectiveNote.isNotEmpty
          ? effectiveNote
          : (effectiveSummary.isNotEmpty ? effectiveSummary : 'Activity');
      final formattedDueDate = DateFormat('yyyy-MM-dd').format(dueDate);

      bool isSuccess = false;

      // 1. Try standard Odoo mail.thread method 'activity_schedule' on project.task
      try {
        final rpcScheduleRes = await OdooRpcApiManager.call(
          model: 'project.task',
          method: 'activity_schedule',
          args: [
            [validTaskId],
          ],
          kwargs: {
            'activity_type_id': activityTypeId,
            'summary': effectiveSummary,
            'date_deadline': formattedDueDate,
            'user_id': userId,
            'note': effectiveNote,
          },
        );

        if (rpcScheduleRes.isSuccess) {
          isSuccess = true;
        }
      } catch (e) {
        debugPrint('activity_schedule RPC call error: $e');
      }

      // 2. Try direct create on mail.activity if method call didn't succeed
      if (!isSuccess) {
        final taskModelId = await _getProjectTaskModelId();

        final Map<String, dynamic> values = {
          'res_model': 'project.task',
          if (taskModelId != null && taskModelId > 0)
            'res_model_id': taskModelId,
          'res_id': validTaskId,
          'activity_type_id': activityTypeId,
          'summary': effectiveSummary,
          'date_deadline': formattedDueDate,
          'user_id': userId,
          'note': effectiveNote,
          'body': effectiveBody,
        };

        final odooResponse = await OdooRpcApiManager.create(
          model: 'mail.activity',
          values: values,
        );

        if (odooResponse.isSuccess) {
          isSuccess = true;
        } else {
          // 3. Fallback to API endpoint
          final apiResponse = await ApiManager.postRequest(
            endPoint: 'tasks/$validTaskId/activity',
            data: values,
          );

          if (apiResponse.isSuccess) {
            isSuccess = true;
          } else {
            final errMsg = odooResponse.message.isNotEmpty
                ? odooResponse.message
                : (apiResponse.message.isNotEmpty
                    ? apiResponse.message
                    : 'Failed to schedule activity');
            showToast(errMsg, idSuccess: false);
            return false;
          }
        }
      }

      if (isSuccess) {
        await getTaskActivities(validTaskId);
        showToast('Activity scheduled successfully', idSuccess: true);
        return true;
      }

      return false;
    } catch (e) {
      _handleError(e, 'schedule activity');
      showToast('Error scheduling activity: $e', idSuccess: false);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update Task Description in Odoo project.task
  Future<bool> updateTaskDescription(int taskId, String newDescription) async {
    try {
      isLoading.value = true;
      final validTaskId = taskId > 0 ? taskId : (currentTask.value?.id ?? 0);
      if (validTaskId <= 0) return false;

      final res = await OdooRpcApiManager.write(
        model: 'project.task',
        ids: [validTaskId],
        values: {
          'description': newDescription,
        },
      );

      if (res.isSuccess) {
        if (currentTask.value != null) {
          currentTask.value =
              currentTask.value!.copyWith(description: newDescription);
        }
        showToast('Description updated', idSuccess: true);
        return true;
      } else {
        showToast('Failed to update description: ${res.message}',
            idSuccess: false);
        return false;
      }
    } catch (e) {
      showToast('Error updating description: $e', idSuccess: false);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Helper to upload multiple files as ir.attachment in Odoo
  Future<List<int>> uploadMultipleTaskAttachments({
    required int taskId,
    required List<PlatformFile> files,
  }) async {
    final List<int> uploadedIds = [];
    for (final file in files) {
      try {
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          final f = File(file.path!);
          if (await f.exists()) {
            bytes = await f.readAsBytes();
          }
        }
        if (bytes != null && bytes.isNotEmpty) {
          final base64Data = base64Encode(bytes);
          final res = await OdooRpcApiManager.create(
            model: 'ir.attachment',
            values: {
              'name': file.name,
              'datas': base64Data,
              'res_model': 'project.task',
              'res_id': taskId,
            },
          );
          if (res.isSuccess && res.data != null) {
            uploadedIds.add(res.data!);
          }
        }
      } catch (e) {
        debugPrint('Error uploading attachment ${file.name}: $e');
      }
    }
    return uploadedIds;
  }

  /// 6c. Get Activity Types
  Future<List<Map<String, dynamic>>> getActivityTypes() async {
    try {
      final response = await OdooRpcApiManager.searchRead(
        model: 'mail.activity.type',
        domain: [],
        fields: ['id', 'name', 'icon', 'category'],
        limit: 30,
      );

      if (response.isSuccess && response.data != null) {
        final list = List<Map<String, dynamic>>.from(response.data as List);
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Error loading activity types from Odoo: $e');
    }

    return [
      {'id': 1, 'name': 'Email'},
      {'id': 2, 'name': 'Call'},
      {'id': 3, 'name': 'Meeting'},
      {'id': 4, 'name': 'To-Do'},
      {'id': 5, 'name': 'Upload Document'},
      {'id': 6, 'name': 'Reminder'},
    ];
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

  /// 10. Load Task Attachments from Odoo ir.attachment
  Future<List<TaskAttachment>> getTaskAttachments(int taskId) async {
    try {
      isLoadingAttachments.value = true;
      final combined = <int, TaskAttachment>{};

      // Direct attachments on project.task (Description media & files only)
      final response = await OdooRpcApiManager.searchRead(
        model: 'ir.attachment',
        domain: [
          ['res_model', '=', 'project.task'],
          ['res_id', '=', taskId],
        ],
        fields: [
          'id',
          'name',
          'mimetype',
          'file_size',
          'create_date',
          'create_uid'
        ],
        limit: 100,
      );

      if (response.isSuccess && response.data is List) {
        for (var x in response.data as List) {
          final att = TaskAttachment.fromJson(x as Map<String, dynamic>);
          combined[att.id] = att;
        }
      }

      final list = combined.values.toList();
      attachments.value = list;
      return list;
    } catch (e) {
      debugPrint('Error loading task attachments: $e');
      return [];
    } finally {
      isLoadingAttachments.value = false;
    }
  }

  /// 11. Upload Task Attachment to Odoo ir.attachment
  Future<bool> uploadTaskAttachment({
    required int taskId,
    required String fileName,
    required Uint8List fileBytes,
    String? mimetype,
  }) async {
    try {
      isLoadingAttachments.value = true;
      final base64Data = base64Encode(fileBytes);
      final response = await OdooRpcApiManager.create(
        model: 'ir.attachment',
        values: {
          'name': fileName,
          'datas': base64Data,
          'res_model': 'project.task',
          'res_id': taskId,
          if (mimetype != null && mimetype.isNotEmpty) 'mimetype': mimetype,
        },
      );

      if (response.isSuccess) {
        await getTaskAttachments(taskId);
        showToast('Attachment uploaded successfully', idSuccess: true);
        return true;
      } else {
        final err = response.message.isNotEmpty
            ? response.message
            : 'Upload failed';
        showToast(err, idSuccess: false);
        return false;
      }
    } catch (e) {
      showToast('Error uploading attachment: $e', idSuccess: false);
      return false;
    } finally {
      isLoadingAttachments.value = false;
    }
  }

  /// 12. Delete Task Attachment from Odoo ir.attachment
  Future<bool> deleteTaskAttachment(int attachmentId, int taskId) async {
    try {
      isLoadingAttachments.value = true;
      final response = await OdooRpcApiManager.unlink(
        model: 'ir.attachment',
        ids: [attachmentId],
      );

      if (response.isSuccess) {
        attachments.removeWhere((a) => a.id == attachmentId);
        showToast('Attachment deleted', idSuccess: true);
        return true;
      } else {
        showToast('Failed to delete attachment: ${response.message}',
            idSuccess: false);
        return false;
      }
    } catch (e) {
      showToast('Error deleting attachment: $e', idSuccess: false);
      return false;
    } finally {
      isLoadingAttachments.value = false;
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
        getTaskAttachments(taskId),
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
    attachments.clear();
    errorMessage.value = '';
  }

  @override
  void onClose() {
    clearData();
    super.onClose();
  }
}
