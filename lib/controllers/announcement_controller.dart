import 'dart:async';
import 'package:pi_task_watch/exports.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/widgets/announcement_widgets.dart';
import 'package:pi_task_watch/utils/dialog_utils.dart';

class AnnouncementController extends GetxController {
  final RxList<AnnouncementModel> announcements = <AnnouncementModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCreating = false.obs;
  Timer? _refreshTimer;
  final RxSet<int> _shownBirthdayPopupIds = <int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAnnouncements();
    // Auto-refresh announcements every 30 seconds in background
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isLoading.value && !isCreating.value) {
        fetchAnnouncements();
      }
    });
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }

  Future<void> fetchAnnouncements() async {
    try {
      isLoading.value = true;
      final response = await OdooRpcApiManager.searchRead(
        model: 'hr.announcement',
        domain: [], // Retrieve all announcements
        order: 'create_date desc',
      );

      if (response.isSuccess && response.data != null) {
        final records = response.data!;
        announcements.value = records
            .map((json) => AnnouncementModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();

        // Check for active approved birthday announcement to auto-popup instantly
        _checkAndShowBirthdayPopup();
      } else {
        debugPrint('==================================================');
        debugPrint('⚠️ ODOO API WARNING: FAILED TO FETCH ANNOUNCEMENTS');
        debugPrint('Response Message: ${response.message}');
        if (response.message.toLowerCase().contains('session expired') ||
            response.message.toLowerCase().contains('not authenticated')) {
          debugPrint('👉 REASON: Odoo session has expired or is invalid!');
          debugPrint('👉 ACTION: Please log out of the Taskwatch app and log back in to renew your session.');
        }
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
