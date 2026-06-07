import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_palette.dart';

/// Three-way theme mode: light, dark, and neutral (cool-tinted surfaces).
enum AppThemeMode { light, dark, neutral }

class AppTheme {
  AppTheme._();

  // ── Dark theme ─────────────────────────────────────────────────────────────

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  // ── Light theme ────────────────────────────────────────────────────────────

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  // ── Neutral theme ──────────────────────────────────────────────────────────

  static ThemeData neutral() => _build(AppPalette.neutral, Brightness.light);

  // ── Shared builder ─────────────────────────────────────────────────────────

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      bodyMedium: GoogleFonts.inter(color: p.text,     fontSize: 13),
      bodySmall:  GoogleFonts.inter(color: p.textMute, fontSize: 11.5),
    );

    final onPrimary = p.isDark ? const Color(0xFF0A1119) : Colors.white;

    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      colorScheme: brightness == Brightness.dark
          ? ColorScheme.dark(
              surface:     p.bg,
              primary:     p.blue,
              secondary:   p.statusWarning,
              error:       p.statusCritical,
              onPrimary:   onPrimary,
              onSecondary: p.bg,
              onSurface:   p.text,
            )
          : ColorScheme.light(
              surface:     p.bg,
              primary:     p.blue,
              secondary:   p.statusWarning,
              error:       p.statusCritical,
              onPrimary:   onPrimary,
              onSecondary: p.bg,
              onSurface:   p.text,
            ),
      textTheme: textTheme,
      dividerColor: p.divider,
      cardTheme: CardThemeData(
        color: p.surface1,
        elevation: p.isDark ? 0 : 1,
        shadowColor: p.isDark ? Colors.transparent : const Color(0x14000000),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppColors.rLg)),
          side: BorderSide(color: p.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.blue, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: p.textDim, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(p.border),
        radius: const Radius.circular(999),
      ),
      extensions: [p],
    );
  }

  // ── Typography helpers ─────────────────────────────────────────────────────
  // Colors below use AppColors dark-mode defaults. Widgets that need
  // theme-aware text colors should read from context.pal instead.

  static TextStyle get monoSm => GoogleFonts.jetBrainsMono(
    fontSize: 11.5, color: AppColors.textMute, letterSpacing: -0.01,
  );
  static TextStyle get monoXs => GoogleFonts.jetBrainsMono(
    fontSize: 10.5, color: AppColors.textDim, letterSpacing: 0.04,
  );
  static TextStyle get labelCaps => GoogleFonts.inter(
    fontSize: 10.5, color: AppColors.textDim, fontWeight: FontWeight.w500,
    letterSpacing: 0.13, height: 1,
  );
  static TextStyle get kpiValue => GoogleFonts.inter(
    fontSize: 30, fontWeight: FontWeight.w700,
    letterSpacing: -0.02, height: 1,
    fontFeatures: [const FontFeature.tabularFigures()],
  );
  static TextStyle get pageTitle => GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.01,
  );
  static TextStyle get cardTitle => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.005,
  );
  static TextStyle get bodyStrong => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w500,
  );
  static TextStyle get bodySm => GoogleFonts.inter(fontSize: 12.5);
  static TextStyle get bodySub => GoogleFonts.inter(
    fontSize: 11.5, color: AppColors.textMute,
  );
}
