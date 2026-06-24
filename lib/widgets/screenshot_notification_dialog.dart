import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/theme/app_theme.dart';

class ScreenshotNotificationDialog extends StatefulWidget {
  const ScreenshotNotificationDialog({super.key});

  @override
  State<ScreenshotNotificationDialog> createState() =>
      _ScreenshotNotificationDialogState();
}

class _ScreenshotNotificationDialogState
    extends State<ScreenshotNotificationDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoDismiss();
  }

  void _startAutoDismiss() {
    // Auto-dismiss after 3 seconds
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.glassDecoration(
          borderRadius: 32,
          color: Colors.white.withOpacity(0.95),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon with animated-like presence
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.secondary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 40,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              'Capture Success',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            // Message
            Text(
              'Your work activity snapshot has been securely recorded to the cloud.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Auto-dismiss indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Auto-closing in 3s',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
