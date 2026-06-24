import 'package:pi_task_watch/exports.dart';

Future<bool> confirmationAlert({
  required String content,
  VoidCallback? onConfirm,
  bool showYesButton = true,
  bool showNoButton = true,
  String yesText = 'Yes',
  String noText = 'No',
  bool barrierDismissible = true,
}) async {
  final result = await showDialog(
    barrierDismissible: barrierDismissible,
    context: Get.context!,
    builder: (context) {
      return AlertDialog(
        insetPadding: EdgeInsets.all(15.0),
        scrollable: false,
        title: Text(
          "Confirmation Alert",
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 210.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                content,
                style: TextStyle(fontSize: 12.0, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        actions: [
          if (showYesButton)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(yesText),
            ),
          if (showNoButton)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(noText),
            ),
        ],
      );
    },
  );

  if (result == true) {
    if (onConfirm != null) onConfirm();
    return true;
  } else {
    return false;
  }
}
