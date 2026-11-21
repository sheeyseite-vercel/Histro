import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Parchment atlas palette.
class P {
  static const bg = Color(0xFFF6EFE2);
  static const ink = Color(0xFF2B2118);
  static const red = Color(0xFF8E1F1A);
  static const card = Color(0xFFFFFDF8);
  static const paper = Color(0xFFFBF7EE);
  static const line = Color(0xFFE2D6BD);
  static const tan = Color(0xFFD8C9AB);
  static const chip = Color(0xFFF1E8D4);
  static const sand = Color(0xFFEADFC8);
  static const muted = Color(0xFF6B5B4A);
}

TextStyle display(String lang, double size,
    {Color color = P.ink, FontWeight weight = FontWeight.w700, double? height}) {
  if (lang == 'ar') {
    return GoogleFonts.amiri(
        fontSize: size, color: color, fontWeight: weight, height: height ?? 1.35);
  }
  return GoogleFonts.cormorantGaramond(
      fontSize: size, color: color, fontWeight: weight, height: height ?? 1.1);
}

TextStyle body(String lang, double size,
    {Color color = P.ink, FontWeight weight = FontWeight.w400, double? height}) {
  if (lang == 'ar') {
    return GoogleFonts.notoNaskhArabic(
        fontSize: size, color: color, fontWeight: weight, height: height ?? 1.7);
  }
  return GoogleFonts.sourceSans3(
      fontSize: size, color: color, fontWeight: weight, height: height ?? 1.45);
}

ThemeData buildTheme(String lang) {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: P.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: P.red,
      brightness: Brightness.light,
    ).copyWith(primary: P.red, surface: P.bg),
  );
  final tt = lang == 'ar'
      ? GoogleFonts.notoNaskhArabicTextTheme(base.textTheme)
      : GoogleFonts.sourceSans3TextTheme(base.textTheme);
  return base.copyWith(
    textTheme: tt.apply(bodyColor: P.ink, displayColor: P.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: P.bg,
      foregroundColor: P.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
