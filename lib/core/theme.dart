import 'package:flutter/material.dart';

/// A dizájn színtokenjei (Kékláng design artifact).
abstract final class AppColors {
  static const bg = Color(0xFF080A0F);
  static const surface1 = Color(0xFF10141C);
  static const surface2 = Color(0xFF171C27);
  static const line = Color(0x14FFFFFF);
  static const text = Color(0xFFEDF0F6);
  static const muted = Color(0xFF97A1B5);
  static const accent = Color(0xFF5CCBFF);
  static const onAccent = Color(0xFF04141C);
  static const warn = Color(0xFFFFB454);
  static const track = Color(0xFF1B212E);
  static const navBg = Color(0xFF0C1017);
  static const toggleOff = Color(0xFF2A3140);
}

abstract final class AppFonts {
  static const sans = 'Bricolage';
  static const mono = 'PlexMono';
}

/// A Bricolage változtatható betűtípus, ezért a vastagságot a `wght`
/// tengelyen is be kell állítani.
TextStyle sans(double size, {FontWeight weight = FontWeight.w500, Color? color, double? letterSpacing, double? height}) {
  return TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color ?? AppColors.text,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color? color, double? letterSpacing, double? height}) {
  return TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.text,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.warn,
    error: AppColors.warn,
    onSurface: AppColors.text,
    surfaceContainerHigh: AppColors.surface2,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: AppFonts.sans,
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.accent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface2,
      contentTextStyle: sans(14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: sans(18, weight: FontWeight.w700),
      contentTextStyle: sans(14, color: AppColors.muted),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
