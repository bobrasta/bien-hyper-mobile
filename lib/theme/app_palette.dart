import 'package:flutter/material.dart';

/// Adaptive colour tokens — all values that vary across light / dark / neutral.
/// Brand / accent colours that do NOT vary (e.g. violet for avatars) stay in AppColors.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.sidebarBg,
    required this.topbarBg,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.text,
    required this.textMute,
    required this.textDim,
    required this.blue,
    required this.blue700,
    required this.blue50,
    required this.green,
    required this.green50,
    required this.statusNormal,
    required this.statusInfo,
    required this.statusWarning,
    required this.statusCritical,
    required this.isDark,
  });

  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color sidebarBg;
  final Color topbarBg;
  final Color border;
  final Color borderStrong;
  final Color divider;
  final Color text;
  final Color textMute;
  final Color textDim;

  // Brand blues (primary actions, links, focus)
  final Color blue;
  final Color blue700;   // hover / pressed
  final Color blue50;    // selected rows, info tints

  // Brand greens (success, confirmations)
  final Color green;
  final Color green50;

  // Semantic status
  final Color statusNormal;
  final Color statusInfo;
  final Color statusWarning;
  final Color statusCritical;

  final bool isDark;

  // ── Dark ─────────────────────────────────────────────────────────────────────

  static const dark = AppPalette(
    isDark:         true,
    bg:             Color(0xFF0E1622),
    surface1:       Color(0xFF162133),
    surface2:       Color(0xFF1B273B),
    surface3:       Color(0xFF1F2D41),
    sidebarBg:      Color(0xFF0A1119),
    topbarBg:       Color(0xFF0E1622),
    border:         Color(0xFF243042),
    borderStrong:   Color(0xFF324158),
    divider:        Color(0xFF1C2840),
    text:           Color(0xFFEAF0F7),
    textMute:       Color(0xFF9DA9BB),
    textDim:        Color(0xFF6B7888),
    blue:           Color(0xFF5AA6E8),
    blue700:        Color(0xFF7FBCF0),
    blue50:         Color(0xFF18293D),
    green:          Color(0xFF3FC06E),
    green50:        Color(0xFF14301F),
    statusNormal:   Color(0xFF3FC06E),
    statusInfo:     Color(0xFF5AA6E8),
    statusWarning:  Color(0xFFECC05A),
    statusCritical: Color(0xFFF0726F),
  );

  // ── Light ────────────────────────────────────────────────────────────────────

  static const light = AppPalette(
    isDark:         false,
    bg:             Color(0xFFF6F8FB),
    surface1:       Color(0xFFFFFFFF),
    surface2:       Color(0xFFFBFCFE),
    surface3:       Color(0xFFF0F2F5),
    sidebarBg:      Color(0xFFFFFFFF),
    topbarBg:       Color(0xFFFFFFFF),
    border:         Color(0xFFE4E9F0),
    borderStrong:   Color(0xFFD2DAE5),
    divider:        Color(0xFFECF0F5),
    text:           Color(0xFF16202E),
    textMute:       Color(0xFF5A6678),
    textDim:        Color(0xFF8A95A6),
    blue:           Color(0xFF2F7FC2),
    blue700:        Color(0xFF225F92),
    blue50:         Color(0xFFEAF2FB),
    green:          Color(0xFF1F9E4D),
    green50:        Color(0xFFE8F6ED),
    statusNormal:   Color(0xFF1F9E4D),
    statusInfo:     Color(0xFF2F7FC2),
    statusWarning:  Color(0xFFE0A82E),
    statusCritical: Color(0xFFD64545),
  );

  // ── Neutral (color-rich, cool-tinted surfaces) ────────────────────────────────

  static const neutral = AppPalette(
    isDark:         false,
    bg:             Color(0xFFEAF1F4),
    surface1:       Color(0xFFFFFFFF),
    surface2:       Color(0xFFF2F7FA),
    surface3:       Color(0xFFE0EBF0),
    sidebarBg:      Color(0xFFFFFFFF),
    topbarBg:       Color(0xFFFFFFFF),
    border:         Color(0xFFD2E0E6),
    borderStrong:   Color(0xFFBBCDD6),
    divider:        Color(0xFFD8E6EC),
    text:           Color(0xFF14222C),
    textMute:       Color(0xFF51636E),
    textDim:        Color(0xFF8499A3),
    blue:           Color(0xFF1F7AD4),
    blue700:        Color(0xFF145EA8),
    blue50:         Color(0xFFDCEBFB),
    green:          Color(0xFF15A84F),
    green50:        Color(0xFFDBF3E2),
    statusNormal:   Color(0xFF15A84F),
    statusInfo:     Color(0xFF1F7AD4),
    statusWarning:  Color(0xFFEFB02E),
    statusCritical: Color(0xFFE0453F),
  );

  // ── Accessor ──────────────────────────────────────────────────────────────────

  static AppPalette of(BuildContext ctx) =>
      Theme.of(ctx).extension<AppPalette>() ?? dark;

  // ── ThemeExtension boilerplate ────────────────────────────────────────────────

  @override
  AppPalette copyWith({
    Color? bg, Color? surface1, Color? surface2, Color? surface3,
    Color? sidebarBg, Color? topbarBg,
    Color? border, Color? borderStrong, Color? divider,
    Color? text, Color? textMute, Color? textDim,
    Color? blue, Color? blue700, Color? blue50,
    Color? green, Color? green50,
    Color? statusNormal, Color? statusInfo, Color? statusWarning, Color? statusCritical,
    bool? isDark,
  }) => AppPalette(
    bg:             bg             ?? this.bg,
    surface1:       surface1       ?? this.surface1,
    surface2:       surface2       ?? this.surface2,
    surface3:       surface3       ?? this.surface3,
    sidebarBg:      sidebarBg      ?? this.sidebarBg,
    topbarBg:       topbarBg       ?? this.topbarBg,
    border:         border         ?? this.border,
    borderStrong:   borderStrong   ?? this.borderStrong,
    divider:        divider        ?? this.divider,
    text:           text           ?? this.text,
    textMute:       textMute       ?? this.textMute,
    textDim:        textDim        ?? this.textDim,
    blue:           blue           ?? this.blue,
    blue700:        blue700        ?? this.blue700,
    blue50:         blue50         ?? this.blue50,
    green:          green          ?? this.green,
    green50:        green50        ?? this.green50,
    statusNormal:   statusNormal   ?? this.statusNormal,
    statusInfo:     statusInfo     ?? this.statusInfo,
    statusWarning:  statusWarning  ?? this.statusWarning,
    statusCritical: statusCritical ?? this.statusCritical,
    isDark:         isDark         ?? this.isDark,
  );

  @override
  AppPalette lerp(AppPalette other, double t) => AppPalette(
    isDark:         t < 0.5 ? isDark : other.isDark,
    bg:             Color.lerp(bg,             other.bg,             t)!,
    surface1:       Color.lerp(surface1,       other.surface1,       t)!,
    surface2:       Color.lerp(surface2,       other.surface2,       t)!,
    surface3:       Color.lerp(surface3,       other.surface3,       t)!,
    sidebarBg:      Color.lerp(sidebarBg,      other.sidebarBg,      t)!,
    topbarBg:       Color.lerp(topbarBg,       other.topbarBg,       t)!,
    border:         Color.lerp(border,         other.border,         t)!,
    borderStrong:   Color.lerp(borderStrong,   other.borderStrong,   t)!,
    divider:        Color.lerp(divider,        other.divider,        t)!,
    text:           Color.lerp(text,           other.text,           t)!,
    textMute:       Color.lerp(textMute,       other.textMute,       t)!,
    textDim:        Color.lerp(textDim,        other.textDim,        t)!,
    blue:           Color.lerp(blue,           other.blue,           t)!,
    blue700:        Color.lerp(blue700,        other.blue700,        t)!,
    blue50:         Color.lerp(blue50,         other.blue50,         t)!,
    green:          Color.lerp(green,          other.green,          t)!,
    green50:        Color.lerp(green50,        other.green50,        t)!,
    statusNormal:   Color.lerp(statusNormal,   other.statusNormal,   t)!,
    statusInfo:     Color.lerp(statusInfo,     other.statusInfo,     t)!,
    statusWarning:  Color.lerp(statusWarning,  other.statusWarning,  t)!,
    statusCritical: Color.lerp(statusCritical, other.statusCritical, t)!,
  );
}

/// `context.pal.bg`  is shorter than  `AppPalette.of(context).bg`
extension AppPaletteX on BuildContext {
  AppPalette get pal => AppPalette.of(this);
}
