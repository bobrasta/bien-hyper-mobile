import 'package:flutter/material.dart';

/// BioTrack v3 design tokens — dark-theme static defaults.
/// Adaptive per-theme values live in AppPalette.
class AppColors {
  AppColors._();

  // ── Dark surfaces ──────────────────────────────────────────
  static const Color bg          = Color(0xFF0E1622); // canvas
  static const Color surface1    = Color(0xFF162133); // cards, panels
  static const Color surface2    = Color(0xFF1B273B); // inset / secondary
  static const Color surface3    = Color(0xFF1F2D41); // inputs, nested
  static const Color sidebarBg   = Color(0xFF0A1119);
  static const Color topbarBg    = Color(0xFF0E1622);

  // ── Dark borders ──────────────────────────────────────────
  static const Color border      = Color(0xFF243042);
  static const Color borderStrong= Color(0xFF324158);
  static const Color divider     = Color(0xFF1C2840);

  // ── Dark text ─────────────────────────────────────────────
  static const Color text        = Color(0xFFEAF0F7);
  static const Color textMute    = Color(0xFF9DA9BB);
  static const Color textDim     = Color(0xFF6B7888);

  // ── Brand — dark values (primary = blue) ──────────────────
  // `teal` kept as an alias for backward compat — now maps to brand blue.
  static const Color teal        = Color(0xFF5AA6E8);
  static const Color tealSoft    = Color(0x2A5AA6E8);
  static const Color tealGlow    = Color(0x505AA6E8);

  static const Color blue        = Color(0xFF5AA6E8); // dark brand blue
  static const Color blueSoft    = Color(0x2A5AA6E8);
  static const Color blueStrong  = Color(0xFF7FBCF0); // hover / blue700 dark

  static const Color green       = Color(0xFF3FC06E); // success / positive
  static const Color greenSoft   = Color(0x2A3FC06E);

  static const Color amber       = Color(0xFFECC05A); // warning
  static const Color amberSoft   = Color(0x29ECC05A);

  static const Color coral       = Color(0xFFF0726F); // critical / error
  static const Color coralSoft   = Color(0x29F0726F);

  static const Color violet      = Color(0xFF9D7CFB);
  static const Color violetSoft  = Color(0x289D7CFB);

  // ── Radii ─────────────────────────────────────────────────
  static const double rSm = 6;
  static const double rMd = 10;
  static const double rLg = 14;
  static const double rXl = 18;

  // ── Gradient presets ──────────────────────────────────────
  static const LinearGradient avatarGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [blue, violet],
  );
  static const LinearGradient avatarTealGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [teal, Color(0xFF2F7FC2)],
  );
  static const LinearGradient avatarAmberGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [amber, Color(0xFFB8900A)],
  );
  static const LinearGradient avatarCoralGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [coral, Color(0xFFB83A38)],
  );
  static const LinearGradient avatarVioletGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [violet, Color(0xFF6B4EC8)],
  );

  static Color withAlpha(Color c, double opacity) =>
      c.withValues(alpha: opacity);
}
