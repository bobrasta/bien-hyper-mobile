import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_palette.dart';

/// Theme mode: light, dark, neutral (cool-tinted surfaces), fundify
/// (sky-blue canvas, mint sidebar, lime accent), and aurora (warm cream/gold
/// canvas — the app's default identity as of the 2026-08-27 HR redesign).
enum AppThemeMode { light, dark, neutral, fundify, aurora }

/// Global theme-mode notifier — toggled by the top-bar button or Settings.
/// Lives here (not main.dart) so the static typography helpers below can
/// read the active palette without needing a BuildContext. Defaults to
/// [AppThemeMode.aurora] — the user asked for the warm-gradient look to be
/// the system's identity, not an opt-in extra alongside the older themes.
final themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.aurora);

/// App-wide text-size preference, applied as a MediaQuery text-scale
/// multiplier in main.dart (on top of the device's own scale, so OS
/// accessibility settings still apply). 'medium' is the default — the same
/// bump the app shipped with before this became user-adjustable.
enum TextSizePref {
  small(1.0), medium(1.1), large(1.2);
  const TextSizePref(this.scale);
  final double scale;
}

/// Global text-size notifier — toggled from Settings → Preferences.
/// Same "lives in memory only, not persisted across restarts" behavior as
/// [themeNotifier] above — consistent, not accidental.
final textSizeNotifier = ValueNotifier<TextSizePref>(TextSizePref.medium);

class AppTheme {
  AppTheme._();

  /// The palette matching the current [themeNotifier] value — lets static
  /// TextStyle getters below stay theme-correct without a BuildContext.
  static AppPalette get pal => switch (themeNotifier.value) {
    AppThemeMode.dark    => AppPalette.dark,
    AppThemeMode.light   => AppPalette.light,
    AppThemeMode.neutral => AppPalette.neutral,
    AppThemeMode.fundify => AppPalette.fundify,
    AppThemeMode.aurora  => AppPalette.aurora,
  };

  // ── Dark theme ─────────────────────────────────────────────────────────────

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  // ── Light theme ────────────────────────────────────────────────────────────

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  // ── Neutral theme ──────────────────────────────────────────────────────────

  static ThemeData neutral() => _build(AppPalette.neutral, Brightness.light);

  // ── Fundify theme ──────────────────────────────────────────────────────────

  static ThemeData fundify() => _build(AppPalette.fundify, Brightness.light);

  // ── Aurora theme ───────────────────────────────────────────────────────────

  static ThemeData aurora() => _build(AppPalette.aurora, Brightness.light);

  // ── Shared builder ─────────────────────────────────────────────────────────

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();

    final textTheme = base.textTheme.apply(
      fontFamily: 'TildaSans',
      bodyColor: p.text,
      displayColor: p.text,
    ).copyWith(
      bodyMedium: TextStyle(fontFamily: 'TildaSans', color: p.text,     fontSize: 13),
      bodySmall:  TextStyle(fontFamily: 'TildaSans', color: p.textMute, fontSize: 11.5),
    );

    // Every pre-existing theme keeps its exact original onPrimary (dark
    // near-black on isDark, white otherwise) — do not derive this from
    // p.blue's luminance app-wide, since that would also silently repaint
    // light/neutral (whose green primary already reads as "light" under
    // Flutter's own brightness estimate, same as aurora's gold does) and
    // break the "pre-existing themes render byte-identical" rule from the
    // earlier Fundify port. Aurora's gold genuinely needs dark text — white
    // barely contrasts on it — so it gets its own branch instead.
    final onPrimary = switch (themeNotifier.value) {
      _ when p.isDark        => const Color(0xFF0A1119),
      AppThemeMode.aurora    => const Color(0xFF1C1712),
      _                      => Colors.white,
    };

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
  // Colors below track the active theme via [pal] (resolved from the global
  // [themeNotifier], not BuildContext) — they stay correct in light/dark/
  // neutral without every call site needing its own .copyWith(color: ...).

  static TextStyle get monoSm => GoogleFonts.jetBrainsMono(
    fontSize: 11.5, color: pal.textMute, letterSpacing: -0.01,
  );
  static TextStyle get monoXs => GoogleFonts.jetBrainsMono(
    fontSize: 10.5, color: pal.textDim, letterSpacing: 0.04,
  );
  static TextStyle get labelCaps => TextStyle(
    fontFamily: 'TildaSans',
    fontSize: 10.5, color: pal.textDim, fontWeight: FontWeight.w500,
    letterSpacing: 0.13, height: 1,
  );
  static TextStyle get kpiValue => const TextStyle(
    fontFamily: 'TildaSans',
    fontSize: 30, fontWeight: FontWeight.w700,
    letterSpacing: -0.02, height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static TextStyle get pageTitle => const TextStyle(
    fontFamily: 'TildaSans',
    fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.01,
  );
  static TextStyle get cardTitle => const TextStyle(
    fontFamily: 'TildaSans',
    fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.005,
  );
  static TextStyle get bodyStrong => const TextStyle(
    fontFamily: 'TildaSans',
    fontSize: 13, fontWeight: FontWeight.w500,
  );
  static TextStyle get bodySm => const TextStyle(fontFamily: 'TildaSans', fontSize: 12.5);
  static TextStyle get bodySub => TextStyle(
    fontFamily: 'TildaSans',
    fontSize: 11.5, color: pal.textMute,
  );
}
