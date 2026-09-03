import 'dart:async';
import 'package:pi_task_watch/exports.dart';
import 'package:intl/intl.dart';

class AnnouncementController extends GetxController {
  final RxList<AnnouncementModel> announcements = <AnnouncementModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCreating = false.obs;
  final RxBool isModuleAvailable = false.obs;
  Timer? _scheduledTimer;
  String _lastHitKey = '';
  final RxSet<int> _shownBirthdayPopupIds = <int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAnnouncements();
    _startThreeTimesDailyScheduler();
  }

  @override
  void onClose() {
    _scheduledTimer?.cancel();
    super.onClose();
  }

  void _startThreeTimesDailyScheduler() {
    _scheduledTimer?.cancel();
    // Check every 30 seconds if current local time matches 10:00 AM, 2:30 PM (14:30), or 7:30 PM (19:30)
    _scheduledTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      // 3 Scheduled hits per day:
      // 1) 10:00 AM
      // 2) 2:30 PM (14:30)
      // 3) 7:30 PM (19:30)
      bool isHitTime = false;
      String slot = '';

      if (currentHour == 10 && currentMinute == 0) {
        isHitTime = true;
        slot = '10:00';
      } else if (currentHour == 14 && currentMinute == 30) {
        isHitTime = true;
        slot = '14:30';
      } else if (currentHour == 19 && currentMinute == 30) {
        isHitTime = true;
        slot = '19:30';
      }

      if (isHitTime) {
        final hitKey = '${todayStr}_$slot';
        if (_lastHitKey != hitKey) {
          _lastHitKey = hitKey;
          debugPrint('ANNOUNCEMENT_SCHEDULED_HIT: Triggered daily hit at $slot on $todayStr');
          if (!isLoading.value && !isCreating.value) {
            fetchAnnouncements();
          }
        }
      }
    });
  }

  Future<void> fetchAnnouncements() async {
    try {
      isLoading.value = true;

      int? currentUserId;
      int? currentEmployeeId;
      int? currentDepartmentId;
      int? currentJobId;

      if (Get.isRegistered<AuthController>()) {
        final auth = Get.find<AuthController>();
        currentUserId = auth.user.value?.userId;
        currentEmployeeId = auth.employeeId;
      }

      // If employeeId or departmentId not yet resolved, query hr.employee
      if (currentUserId != null && (currentEmployeeId == null || currentDepartmentId == null)) {
        try {
          final empResp = await OdooRpcApiManager.searchRead(
            model: 'hr.employee',
            domain: [
              ['user_id', '=', currentUserId]
            ],
            fields: ['id', 'department_id', 'job_id'],
            limit: 1,
          );
          if (empResp.isSuccess && empResp.data != null && (empResp.data as List).isNotEmpty) {
            final emp = (empResp.data as List).first as Map;
            currentEmployeeId ??= emp['id'] is int ? emp['id'] as int : int.tryParse(emp['id'].toString());
            if (emp['department_id'] is List && (emp['department_id'] as List).isNotEmpty) {
              final firstVal = (emp['department_id'] as List).first;
              currentDepartmentId = firstVal is int ? firstVal : int.tryParse(firstVal.toString());
            } else if (emp['department_id'] is int) {
              currentDepartmentId = emp['department_id'] as int;
            }
            if (emp['job_id'] is List && (emp['job_id'] as List).isNotEmpty) {
              final firstVal = (emp['job_id'] as List).first;
              currentJobId = firstVal is int ? firstVal : int.tryParse(firstVal.toString());
            } else if (emp['job_id'] is int) {
              currentJobId = emp['job_id'] as int;
            }
            if (currentEmployeeId != null && Get.isRegistered<AuthController>()) {
              Get.find<AuthController>().employeeId = currentEmployeeId;
            }
          }
        } catch (e) {
          debugPrint('Error resolving current employee for announcements: $e');
        }
      }

      // 1. Try querying with full fields
      var response = await OdooRpcApiManager.searchRead(
        model: 'hr.announcement',
        domain: [],
        order: 'create_date desc',
      );

      // 2. Fallback with standard safe fields if first query fails
      if (!response.isSuccess) {
        response = await OdooRpcApiManager.searchRead(
          model: 'hr.announcement',
          domain: [],
          fields: [
            'id',
            'name',
            'announcement_reason',
            'announcement',
            'date_start',
            'date_end',
            'is_announcement',
            'is_birthday_announcement',
            'birthday_employee_id',
            'state',
            'announcement_type',
            'employee_ids',
            'department_ids',
            'job_ids',
            'user_ids',
            'create_uid',
            'create_date',
          ],
          order: 'create_date desc',
        );
      }

      // 3. Fallback with minimal fields
      if (!response.isSuccess) {
        response = await OdooRpcApiManager.searchRead(
          model: 'hr.announcement',
          domain: [],
          fields: [
            'id',
            'name',
            'announcement_reason',
            'date_start',
            'date_end',
            'state',
            'announcement_type',
            'employee_ids',
          ],
        );
      }

      if (response.isSuccess && response.data != null) {
        isModuleAvailable.value = true;
        final records = response.data as List;
        final allList = records
            .map((json) => AnnouncementModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();

        // Filter user-wise targeted announcements
        final filteredList = allList.where((a) => a.isVisibleToUser(
          currentUserId: currentUserId,
          currentEmployeeId: currentEmployeeId,
          currentDepartmentId: currentDepartmentId,
          currentJobId: currentJobId,
        )).toList();

        announcements.value = filteredList;
        debugPrint('ANNOUNCEMENT: Fetched ${allList.length} total, filtered ${filteredList.length} for user (UID: $currentUserId, EmpID: $currentEmployeeId, DeptID: $currentDepartmentId, JobID: $currentJobId)');

        // Check for active approved birthday announcement to auto-popup instantly
        _checkAndShowBirthdayPopup();
      } else {
        final err = response.message.toLowerCase();
        if (err.contains("doesn't exist") ||
            err.contains("not found") ||
            err.contains("cannot find") ||
            err.contains("model")) {
          isModuleAvailable.value = false;
        } else {
          // If network or permission error, keep module available if we previously had it
          if (announcements.isNotEmpty) {
            isModuleAvailable.value = true;
          }
        }
        debugPrint('==================================================');
        debugPrint('⚠️ ODOO API ANNOUNCEMENT STATUS: ${response.message}');
        debugPrint('==================================================');
      }
    } catch (e, stack) {
      debugPrint('ANNOUNCEMENT_ERROR: $e');
      debugPrint('ANNOUNCEMENT_STACKTRACE: $stack');
    } finally {
      isLoading.value = false;
    }
  }

  void _checkAndShowBirthdayPopup() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    for (var a in announcements) {
      // 1. Must be approved
      if (a.state != 'approved') continue;

      // 2. Must be a birthday announcement
      if (!a.isBirthdayAnnouncement) continue;

      // 3. Must not have been shown in this session
      if (_shownBirthdayPopupIds.contains(a.id)) continue;

      // 4. Must be active today
      try {
        final start = DateTime.parse(a.dateStart);
        final end = DateTime.parse(a.dateEnd).add(const Duration(days: 1));
        if (now.isAfter(start) && now.isBefore(end)) {
          // Mark as shown
          _shownBirthdayPopupIds.add(a.id);

          // Show the popup instantly
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Get.context != null) {
              DialogUtils.showAppDialog(
                context: Get.context!,
                title: 'Announcement Details',
                content: AnnouncementDetailDialog(announcement: a),
              );
            }
          });
          break; // Show only one auto-popup at a time
        }
      } catch (e) {
        debugPrint('Error parsing dates for auto-popup: $e');
      }
    }
  }

  Future<bool> createAnnouncement({
    required String title,
    required String content,
    required DateTime startDate,
    required DateTime endDate,
    required bool isAnnouncement,
  }) async {
    try {
      isCreating.value = true;

      final formatter = DateFormat('yyyy-MM-dd');
      final values = {
        'announcement_reason': title,
        'announcement': content.isNotEmpty ? content : '<p></p>',
        'date_start': formatter.format(startDate),
        'date_end': formatter.format(endDate),
        'is_announcement': isAnnouncement,
      };

      // 1. Create announcement
      final createResponse = await OdooRpcApiManager.create(
        model: 'hr.announcement',
        values: values,
      );

      if (!createResponse.isSuccess || createResponse.data == null) {
        showToast(createResponse.message.isNotEmpty ? createResponse.message : 'Failed to create announcement', idSuccess: false);
        return false;
      }

      final int newId = createResponse.data as int;

      // 2. Submit for approval
      final submitResponse = await OdooRpcApiManager.call(
        model: 'hr.announcement',
        method: 'action_sent_announcement',
        args: [[newId]],
      );

      if (!submitResponse.isSuccess) {
        showToast('Announcement created as draft. Failed to submit for approval.', idSuccess: false);
        fetchAnnouncements();
        return true;
      }

      // 3. Approve announcement (auto-approve)
      final approveResponse = await OdooRpcApiManager.call(
        model: 'hr.announcement',
        method: 'action_approve_announcement',
        args: [[newId]],
      );

      if (!approveResponse.isSuccess) {
        showToast('Announcement submitted for approval successfully.', idSuccess: true);
      } else {
        showToast('Announcement created and approved successfully.', idSuccess: true);
      }

      // Refresh list
      fetchAnnouncements();
      return true;
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      showToast('Error occurred while creating announcement: $e', idSuccess: false);
      return false;
    } finally {
      isCreating.value = false;
    }
  }
}
