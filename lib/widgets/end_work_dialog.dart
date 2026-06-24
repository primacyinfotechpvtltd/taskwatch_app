import 'package:pi_task_watch/exports.dart';
import 'package:google_fonts/google_fonts.dart';

class EndWorkDialog extends StatefulWidget {
  final Function(EndWorkResult result) onStop;
  final Duration trackedDuration;
  final ProjectModel? project;
  final TaskModel? task;

  const EndWorkDialog({
    super.key,
    required this.onStop,
    required this.trackedDuration,
    this.project,
    this.task,
  });

  /// Shows the dialog using DialogUtils
  static Future<void> show({
    required BuildContext context,
    required Function(EndWorkResult) onStop,
    required Duration trackedDuration,
    ProjectModel? project,
    TaskModel? task,
  }) {
    return DialogUtils.showAppDialog(
      context: context,
      title: 'Stop Tracking',
      compact: true,
      content: EndWorkDialog(
        onStop: onStop,
        trackedDuration: trackedDuration,
        project: project,
        task: task,
      ),
    );
  }

  @override
  State<EndWorkDialog> createState() => _EndWorkDialogState();
}

class _EndWorkDialogState extends State<EndWorkDialog> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    _notesController.text =
        Get.find<TrackerController>().startWorkData.value?.notes ?? '';
    super.initState();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show tracking summary
        if (widget.project != null && widget.task != null)
          if (1 == 2)
            Card(
              elevation: 1,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      Icons.folder_outlined,
                      widget.project!.name,
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(Icons.task_alt, widget.task!.name),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      Icons.timer,
                      'Time tracked: ${FormatUtils.formatDuration(widget.trackedDuration)}',
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 12),

        // Notes field
        Text(
          'Notes *',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.surfaceContainer,
            border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'What did you accomplish?',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              isDense: true,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            style: GoogleFonts.inter(fontSize: 12),
            maxLines: 4,
          ),
        ),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                final result = EndWorkResult(
                  notes: _notesController.text,
                  endTime: DateTime.now(),
                  duration: widget.trackedDuration,
                );
                widget.onStop(result);
                Navigator.of(context).pop();
              },
              child: const Text('Stop Tracking'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
