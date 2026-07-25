import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pi_task_watch/exports.dart';

/// Checks Screen Recording permission on macOS and opens a dialog + System Settings if needed.
Future<void> checkAndPromptScreenRecordingPermission(BuildContext context) async {
  if (!GetPlatform.isMacOS) return;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.security_rounded, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Screen Recording Permission',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PI Task Watch needs Screen Recording permission on macOS to capture work screenshots while time tracking.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Setup:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1. Click "Open System Settings" below\n'
                  '2. Turn ON Screen Recording for PI Task Watch\n'
                  '3. If already ON, click "-" to remove it, then add it again',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Later',
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            // Open macOS Privacy & Security -> Screen Recording settings page directly
            final Uri url = Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture');
            try {
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            } catch (_) {}
          },
          icon: const Icon(Icons.settings, size: 16),
          label: Text(
            'Open System Settings',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
