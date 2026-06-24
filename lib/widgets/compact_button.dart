import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/theme/app_theme.dart';

class CompactButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final double elevation;
  final bool isOutlined;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;

  const CompactButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.height = 44, // Slightly increased for better tap target
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 16.0, // Increased for premium feel
    this.iconSize = 18,
    this.fontSize = 14,
    this.fontWeight = FontWeight.bold, // Bolder for high-end look
    this.elevation = 0,
    this.isOutlined = false,
    this.fullWidth = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // Use AppTheme.primary as default
    final effectiveBackgroundColor = backgroundColor ?? AppTheme.primary;
    final effectiveForegroundColor = foregroundColor ??
        (isOutlined ? effectiveBackgroundColor : Colors.white);

    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 20);

    Widget buttonWidget;
    if (isOutlined) {
      buttonWidget = OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveForegroundColor,
          side: BorderSide(color: effectiveBackgroundColor, width: 1.5),
          elevation: elevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: effectivePadding,
        ),
        child: _buildButtonContent(),
      );
    } else {
      buttonWidget = ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveForegroundColor,
          elevation: elevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: effectivePadding,
        ),
        child: _buildButtonContent(),
      );
    }

    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: buttonWidget,
    );
  }

  Widget _buildButtonContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: 0.2, // Subtle elegance
          ),
        ),
      ],
    );
  }
}
