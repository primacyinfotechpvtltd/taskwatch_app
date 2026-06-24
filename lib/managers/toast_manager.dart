import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ToastManager {
  static void showSuccess(String message) {
    final context = Get.context!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(String message) {
    final context = Get.context!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showInfo(String message) {
    final context = Get.context!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showWarning(String message) {
    final context = Get.context!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

void showToast(String message, {bool? idSuccess}) {
  if (idSuccess == null) {
    ToastManager.showInfo(message);
  } else if (idSuccess) {
    ToastManager.showSuccess(message);
  } else if (!idSuccess) {
    ToastManager.showError(message);
  }
}
