import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class XmColors {
  static const primary = Color(0xFF3B82F6);
  static const primarySoft = Color(0xFFE8F0FE);
  static const conflict = Color(0xFFF59A23);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF22A06B);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF8A8A8A);
  static const border = Color(0xFFEBEBEB);
  static const bgMuted = Color(0xFFF5F5F5);

  static const work = Color(0xFF3B82F6);
  static const family = Color(0xFFF59A23);
  static const document = Color(0xFFE5484D);
  static const birthday = Color(0xFFE879A9);
  static const study = Color(0xFF22A06B);
  static const health = Color(0xFF8B5CF6);

  static Color domain(String d) {
    switch (d) {
      case 'work':
        return work;
      case 'family':
        return family;
      case 'document':
        return document;
      case 'birthday':
        return birthday;
      case 'study':
        return study;
      case 'health':
        return health;
      default:
        return primary;
    }
  }
}

ThemeData buildXmTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: XmColors.primary, brightness: Brightness.light),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    textTheme: GoogleFonts.notoSansScTextTheme(base.textTheme).apply(
      bodyColor: XmColors.text,
      displayColor: XmColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: XmColors.text,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
