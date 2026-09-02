import 'package:intl/intl.dart';
import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/models/idle_time_data.dart';
import 'package:pi_task_watch/models/timesheet_model.dart';

class TimesheetController extends GetxController {
  RxList<TimesheetModel> timesheetList = <TimesheetModel>[].obs;

  Future<List<TimesheetModel>> getAllTimesheet({required DateTime date}) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final apiResponse = await ApiManager.getRequest(
      endPoint: "timesheets",
      queryParameters: {"date": formattedDate},
    );

    final result = apiResponse.body['timesheets'];

    final rawItems = result == null
        ? <TimesheetModel>[]
        : (result as List).map((e) => TimesheetModel.fromJson(e)).toList();

    // Deduplicate by timesheetId
    final uniqueList = <TimesheetModel>[];
    final seenIds = <int>{};
    for (final item in rawItems) {
      if (item.timesheetId > 0) {
        if (!seenIds.contains(item.timesheetId)) {
          seenIds.add(item.timesheetId);
          uniqueList.add(item);
        }
      } else {
        uniqueList.add(item);
      }
    }

    timesheetList.value = uniqueList;

    return uniqueList;
  }

  //

  Future<int?> updateSyncTimesheet({
    required StartWorkModel startWorkData,
  }) async {
    //
    final apiResponse = await ApiManager.postRequest(
      endPoint: "timesheets",
      data: startWorkData.toCustomJson(),
    );
    final result = int.tryParse("${apiResponse.body['timesheet_id']}");
    return result;
    //
  }

  //
  Future<bool> updateSyncIdle({required IdleTimeData idleData}) async {
    try {
      //LogUtils.i('📤 [IDLE SYNC] Sending idle time data to API:');
      //LogUtils.i('📤 [IDLE SYNC] Full JSON: ${jsonEncode(idleData.toJson())}');
      //LogUtils.i('📤 [IDLE SYNC] Note field: "${idleData.note}"');
      //LogUtils.i('📤 [IDLE SYNC] Idle type: ${idleData.idleType}');
      
      final response = await ApiManager.postRequest(
        endPoint: "taskwatch_idle",
        data: idleData.toJson(),
      );
      
      //LogUtils.i('📥 [IDLE SYNC] API Response: ${response.isSuccess}');
      //LogUtils.i('📥 [IDLE SYNC] Response body: ${jsonEncode(response.body)}');
      
      return response.isSuccess;
    } catch (e) {
      //LogUtils.e('❌ [IDLE SYNC] Error sending idle time data', e);
      return false;
    }
  }

  //
}
