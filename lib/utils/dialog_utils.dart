import 'package:pi_task_watch/exports.dart';

/// Utility class to show standardized dialogs throughout the app
class DialogUtils {
  /// Shows a dialog with standardized styling and layout
  ///
  /// Parameters:
  /// - [context]: The build context
  /// - [title]: Title displayed in the header
  /// - [content]: Widget to display in the scrollable content area
  /// - [actions]: List of action widgets (typically buttons)
  /// - [barrierDismissible]: Whether tapping outside the dialog dismisses it
  /// - [titleColor]: Background color of the header
  /// - [compact]: Whether to create a more compact dialog
  /// - [canOutsideDismiss]: Whether to allow dismissal by clicking outside and show close button
  static Future<T?> showAppDialog<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    bool barrierDismissible = true,
    Color? titleColor,
    bool compact = true, // Default to compact
    bool canOutsideDismiss = true, // Default to allowing outside dismissal
  }) {
    final dialog = _AppDialog(
      title: title,
      content: content,
      actions: actions,
      titleColor: titleColor ?? Colors.pink.shade400,
      compact: compact,
      canOutsideDismiss: canOutsideDismiss,
    );

    // Use Get dialog if app uses GetX, otherwise use native showDialog
    if (Get.isRegistered<GetMaterialController>()) {
      return Get.dialog<T>(
        dialog,
        barrierDismissible: barrierDismissible && canOutsideDismiss,
      );
    } else {
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible && canOutsideDismiss,
        builder: (BuildContext context) => dialog,
      );
    }
  }

  /// Shows a confirmation dialog with "Cancel" and "Confirm" buttons
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    Color? titleColor,
    bool canOutsideDismiss = true,
  }) async {
    final result = await showAppDialog<bool>(
      context: context,
      title: title,
      titleColor: titleColor,
      content: Text(message),
      canOutsideDismiss: canOutsideDismiss,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: titleColor ?? Colors.pink.shade400,
          ),
          child: Text(confirmText),
        ),
      ],
    );

    return result ?? false;
  }

  /// Shows a simple dialog with just an "OK" button
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    String okText = 'OK',
    Color? titleColor,
    bool canOutsideDismiss = true,
  }) {
    return showAppDialog(
      context: context,
      title: title,
      titleColor: titleColor,
      content: Text(message),
      canOutsideDismiss: canOutsideDismiss,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: titleColor ?? Colors.pink.shade400,
          ),
          child: Text(okText),
        ),
      ],
    );
  }
}

/// Internal widget representing the app's standard dialog layout
class _AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final Color titleColor;
  final bool compact;
  final bool canOutsideDismiss;

  const _AppDialog({
    required this.title,
    required this.content,
    this.actions,
    required this.titleColor,
    this.compact = true,
    this.canOutsideDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the width based on screen size and compact flag
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth =
        compact
            ? screenWidth *
                0.85 // More compact width
            : screenWidth * 0.9; // Standard width

    // Get more compact paddings when in compact mode
    final EdgeInsets headerPadding =
        compact
            ? EdgeInsets.symmetric(vertical: 12, horizontal: 16)
            : EdgeInsets.symmetric(vertical: 16, horizontal: 24);

    final EdgeInsets contentPadding =
        compact
            ? EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16,
            ) // Increased bottom padding to accommodate buttons
            : EdgeInsets.fromLTRB(24, 16, 24, 16);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 20 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          // maxHeight:
          //     MediaQuery.of(context).size.height * (compact ? 0.9 : 0.10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with optional close button
            Container(
              padding: headerPadding,
              decoration: BoxDecoration(
                color: titleColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 16 : 18,
                      ),
                    ),
                  ),
                  // Close button that appears when outside dismissal is allowed
                  if (canOutsideDismiss)
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content - now includes the buttons when needed
            Flexible(
              child: SingleChildScrollView(
                child: Padding(padding: contentPadding, child: content),
              ),
            ),

            // Actions - only render if explicitly provided
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildActionWidgets(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionWidgets() {
    if (actions == null || actions!.isEmpty) return [];

    List<Widget> actionWidgets = [];
    for (int i = 0; i < actions!.length; i++) {
      actionWidgets.add(actions![i]);

      // Add spacing between buttons
      if (i < actions!.length - 1) {
        actionWidgets.add(const SizedBox(width: 8));
      }
    }

    return actionWidgets;
  }
}
