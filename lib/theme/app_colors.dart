import 'package:flutter/material.dart';

/// Hypermed design tokens — ported from the gwgps Fleet Command design
/// system (see gwgps-app/public/css/fleet-command.css + theme-overrides.css).
/// Dark-theme static defaults; adaptive per-theme values live in AppPalette.
class AppColors {
  AppColors._();

  // ── Dark surfaces ──────────────────────────────────────────
  static const Color bg          = Color(0xFF08090B); // canvas
  static const Color surface1    = Color(0xFF111418); // cards, panels (panel-solid)
  static const Color surface2    = Color(0xFF1B1F27); // inset / secondary
  static const Color surface3    = Color(0xFF20242D); // inputs, nested
  static const Color sidebarBg   = Color(0xFF08090B);
  static const Color topbarBg    = Color(0xFF08090B);

  // ── Dark borders ──────────────────────────────────────────
  static const Color border      = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const Color borderStrong= Color(0x29FFFFFF); // rgba(255,255,255,.16)
  static const Color divider     = Color(0x14FFFFFF);

  // ── Dark text ─────────────────────────────────────────────
  static const Color text        = Color(0xFFF3F5F7);
  static const Color textMute    = Color(0xFFA3ABB4); // gwgps --text-dim (1st tier)
  static const Color textDim     = Color(0xFF6A727B); // gwgps --text-mute (2nd tier)

  // ── Brand — accent green (gwgps --accent) ──────────────────
  // `teal`/`blue` kept as aliases for backward compat across existing screens
  // — both now map to the brand accent green, not the old blue.
  static const Color teal        = Color(0xFF22C55E);
  static const Color tealSoft    = Color(0x2422C55E);
  static const Color tealGlow    = Color(0x5922C55E);

  static const Color blue        = Color(0xFF22C55E); // brand accent (was blue)
  static const Color blueSoft    = Color(0x2422C55E);
  static const Color blueStrong  = Color(0xFF4ADE80); // hover / lighter accent

  static const Color green       = Color(0xFF22C55E); // success — same as accent in gwgps
  static const Color greenSoft   = Color(0x2422C55E);

  static const Color amber       = Color(0xFFF59E0B); // warning (gwgps --warn)
  static const Color amberSoft   = Color(0x24F59E0B);

  static const Color coral       = Color(0xFFF04438); // critical (gwgps --danger)
  static const Color coralSoft   = Color(0x24F04438);

  static const Color violet      = Color(0xFFA78BFA); // gwgps --violet
  static const Color violetSoft  = Color(0x29A78BFA);

  static const Color info        = Color(0xFF38BDF8); // gwgps --info

  // ── Radii (gwgps --r-sm/md/lg/xl) ───────────────────────────
  static const double rSm = 10;
  static const double rMd = 14;
  static const double rLg = 18;
  static const double rXl = 24;

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
