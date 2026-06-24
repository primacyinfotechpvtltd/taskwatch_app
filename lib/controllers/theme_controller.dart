import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { odooDark, odooLight, emerald, sunset, royal, ocean, ruby }

class ThemePalette {
  final Color bgColor;
  final Color headerColor;
  final Color activeColor;
  final Color accentColor;
  final Color sidebarColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color avatarColor;
  final bool isDark;

  ThemePalette({
    required this.bgColor,
    required this.headerColor,
    required this.activeColor,
    required this.accentColor,
    required this.sidebarColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.avatarColor,
    required this.isDark,
  });

  static ThemePalette getTheme(ThemeType type) {
    switch (type) {
      case ThemeType.odooDark:
        return ThemePalette(
          bgColor: const Color(0xFF14141E),
          headerColor: const Color(0xFF1C1C28),
          activeColor: const Color(0xFF00A09D),
          accentColor: const Color(0xFF00A09D),
          sidebarColor: const Color(0xFF181824),
          primaryTextColor: Colors.white,
          secondaryTextColor: const Color(0xFF9494A1),
          avatarColor: const Color(0xFF00A09D),
          isDark: true,
        );
      case ThemeType.odooLight:
        return ThemePalette(
          bgColor: const Color(0xFFF8F9FA),
          headerColor: const Color(0xFF714B67),
          activeColor: const Color(0xFF00A09D),
          accentColor: const Color(0xFF714B67),
          sidebarColor: const Color(0xFFE9ECEF),
          primaryTextColor: Colors.black87,
          secondaryTextColor: Colors.black54,
          avatarColor: const Color(0xFF714B67),
          isDark: false,
        );
      case ThemeType.emerald:
        return ThemePalette(
          bgColor: const Color(0xFF064E3B),
          headerColor: const Color(0xFF065F46),
          activeColor: const Color(0xFF10B981),
          accentColor: const Color(0xFF34D399),
          sidebarColor: const Color(0xFF064E3B),
          primaryTextColor: Colors.white,
          secondaryTextColor: Colors.white70,
          avatarColor: const Color(0xFF10B981),
          isDark: true,
        );
      case ThemeType.sunset:
        return ThemePalette(
          bgColor: const Color(0xFF451A03),
          headerColor: const Color(0xFF78350F),
          activeColor: const Color(0xFFF59E0B),
          accentColor: const Color(0xFFFBBF24),
          sidebarColor: const Color(0xFF451A03),
          primaryTextColor: Colors.white,
          secondaryTextColor: Colors.white70,
          avatarColor: const Color(0xFFF59E0B),
          isDark: true,
        );
      case ThemeType.royal:
        return ThemePalette(
          bgColor: const Color(0xFF2E1065),
          headerColor: const Color(0xFF4C1D95),
          activeColor: const Color(0xFF8B5CF6),
          accentColor: const Color(0xFFA78BFA),
          sidebarColor: const Color(0xFF2E1065),
          primaryTextColor: Colors.white,
          secondaryTextColor: Colors.white70,
          avatarColor: const Color(0xFF8B5CF6),
          isDark: true,
        );
      case ThemeType.ocean:
        return ThemePalette(
          bgColor: const Color(0xFF0C4A6E),
          headerColor: const Color(0xFF075985),
          activeColor: const Color(0xFF0EA5E9),
          accentColor: const Color(0xFF38BDF8),
          sidebarColor: const Color(0xFF0C4A6E),
          primaryTextColor: Colors.white,
          secondaryTextColor: Colors.white70,
          avatarColor: const Color(0xFF0EA5E9),
          isDark: true,
        );
      case ThemeType.ruby:
        return ThemePalette(
          bgColor: const Color(0xFF450A0A),
          headerColor: const Color(0xFF7F1D1D),
          activeColor: const Color(0xFFEF4444),
          accentColor: const Color(0xFFF87171),
          sidebarColor: const Color(0xFF450A0A),
          primaryTextColor: Colors.white,
          secondaryTextColor: Colors.white70,
          avatarColor: const Color(0xFFEF4444),
          isDark: true,
        );
    }
  }
}

class ThemeController extends GetxController {
  static const String _keyTheme = 'app_theme_type';

  final _currentType = ThemeType.odooDark.obs;
  ThemeType get currentType => _currentType.value;

  final _themeData = ThemePalette.getTheme(ThemeType.odooDark).obs;
  ThemePalette get currentTheme => _themeData.value;

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyTheme) ?? ThemeType.odooDark.index;
    setTheme(ThemeType.values[index]);
  }

  void setTheme(ThemeType type) async {
    _currentType.value = type;
    _themeData.value = ThemePalette.getTheme(type);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTheme, type.index);
  }
}
