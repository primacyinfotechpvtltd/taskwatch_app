import 'package:pi_task_watch/managers/api_manager.dart';

import 'package:pi_task_watch/models/models.dart';

class ApiService {
  Future<bool> sendSessionScreenshot({required SessionModel session}) async {
    final apiResponse = await ApiManager.postRequest(
      showLog: true,
      endPoint: "taskwatch",
      data: session.toJsonForAPi(),
    );

    final responseData = apiResponse.body['taskwatch_id'];

    return true;
  }
}

// 9
