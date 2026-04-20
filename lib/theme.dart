import 'package:flutter/material.dart';

// ── Design tokens ─────────────────────────────────────────────
const _bgLight      = Color(0xFFF5F3EF);
const _bgDark       = Color(0xFF0E0E10);
const _surfaceLight = Color(0xFFFFFFFF);
const _surfaceDark  = Color(0xFF18181B);
const _surface2Lt   = Color(0xFFF0EDE8);
const _surface2Dk   = Color(0xFF222226);
const _borderLight  = Color(0xFFE7E4DE);
const _borderDark   = Color(0xFF2A2A30);
const _inkLight     = Color(0xFF18181B);
const _inkDark      = Color(0xFFF4F4F5);
const _subLight     = Color(0xFF6B6B73);
const _subDark      = Color(0xFFA1A1AA);
const _muteLight    = Color(0xFFA1A1A8);
const _muteDark     = Color(0xFF6B6B73);

// ── Radii ─────────────────────────────────────────────────────
const kCardRadius  = 20.0;
const kChipRadius  = 999.0;
const kInputRadius = 14.0;
const kSheetRadius = 28.0;

// ── Themes ────────────────────────────────────────────────────
ThemeData buildLightTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: _bgLight,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _inkLight,
    brightness: Brightness.light,
  ).copyWith(
    primary: _inkLight,
    onPrimary: _bgLight,
    surface: _surfaceLight,
    onSurface: _inkLight,
    onSurfaceVariant: _subLight,
    outline: _borderLight,
    outlineVariant: _borderLight,
    error: const Color(0xFFB91C1C),
    onError: Colors.white,
  ),
);

ThemeData buildDarkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: _bgDark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _inkDark,
    brightness: Brightness.dark,
  ).copyWith(
    primary: _inkDark,
    onPrimary: _bgDark,
    surface: _surfaceDark,
    onSurface: _inkDark,
    onSurfaceVariant: _subDark,
    outline: _borderDark,
    outlineVariant: _borderDark,
    error: const Color(0xFFB91C1C),
    onError: Colors.white,
  ),
);

// ── BuildContext extension ─────────────────────────────────────
extension AppTheme on BuildContext {
  bool   get isDark        => Theme.of(this).brightness == Brightness.dark;
  Color  get bgColor       => isDark ? _bgDark      : _bgLight;
  Color  get surfaceColor  => isDark ? _surfaceDark  : _surfaceLight;
  Color  get surface2Color => isDark ? _surface2Dk   : _surface2Lt;
  Color  get borderColor   => isDark ? _borderDark   : _borderLight;
  Color  get inkColor      => isDark ? _inkDark      : _inkLight;
  Color  get subColor      => isDark ? _subDark      : _subLight;
  Color  get muteColor     => isDark ? _muteDark     : _muteLight;
  Color  get accentColor   => inkColor; // mono theme — accent = ink
}
