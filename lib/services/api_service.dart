import 'package:pi_task_watch/managers/api_manager.dart';
import 'package:pi_task_watch/models/models.dart';
import 'package:pi_task_watch/utils/log_utils.dart';

class ApiService {
  Future<bool> sendSessionScreenshot({required SessionModel session}) async {
    try {
      final apiResponse = await ApiManager.postRequest(
        showLog: true,
        endPoint: "taskwatch",
        data: session.toJsonForAPi(),
      );

      // Check HTTP status code first
      if (!apiResponse.isSuccessStatusCode) {
        LogUtils.e(
          '[ApiService] Session upload failed — HTTP ${apiResponse.statusCode}',
        );
        return false;
      }

      // Check response body is valid
      if (apiResponse.body == null) {
        LogUtils.e('[ApiService] Session upload failed — null response body');
        return false;
      }

      final dynamic taskwatchId = apiResponse.body['taskwatch_id'];
      LogUtils.i('[ApiService] Session uploaded OK, taskwatch_id=$taskwatchId');
      return true;
    } catch (e) {
      LogUtils.e('[ApiService] Exception uploading session: $e');
      return false;
    }
  }
}
