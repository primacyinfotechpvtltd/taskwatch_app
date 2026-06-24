import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/theme/app_theme.dart';

class CompactTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final int? maxLines;
  final double minHeight;
  final double maxHeight;
  final bool autogrow;
  final bool enabled;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry? margin;
  final void Function(String)? onChanged;

  const CompactTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.minHeight = 40,
    this.maxHeight = 120,
    this.autogrow = false,
    this.enabled = true,
    this.decoration,
    this.keyboardType,
    this.validator,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    this.margin,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        enabled: enabled,
        maxLines: obscureText ? 1 : (autogrow ? null : maxLines),
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF25181E),
        ),
        keyboardType: keyboardType,
        validator: validator,
        decoration: (decoration ?? const InputDecoration()).copyWith(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
          labelText: labelText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          isDense: true,
          isCollapsed: true,
          contentPadding: prefixIcon == null && suffixIcon == null
              ? contentPadding
              : const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
          ),
          filled: true,
          fillColor: AppTheme.surfaceContainer,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
