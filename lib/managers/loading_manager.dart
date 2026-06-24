import 'package:flutter_easyloading/flutter_easyloading.dart';

class LoadingManager {
  static void startLoading() {
    EasyLoading.show(maskType: EasyLoadingMaskType.black);
  }

  static void dismissLoading() {
    EasyLoading.dismiss();
  }
}
