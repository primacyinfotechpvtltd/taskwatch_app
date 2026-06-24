import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/theme/app_theme.dart';

class LogoCaptionWidget extends StatelessWidget {
  final double imageWidth;
  final double imageHeight;
  final TextStyle? captionStyle;
  final double zoomPercentage;

  const LogoCaptionWidget({
    super.key,
    this.imageWidth = 80,
    this.imageHeight = 80,
    this.captionStyle,
    this.zoomPercentage = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final scaledImageWidth = imageWidth * zoomPercentage;
    final scaledImageHeight = imageHeight * zoomPercentage;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: 1.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logo-transparent.png',
            width: scaledImageWidth,
            height: scaledImageHeight,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 8 * zoomPercentage),
          Text(
            'PI Task Watch',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22 * zoomPercentage,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
