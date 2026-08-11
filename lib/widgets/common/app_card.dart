import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../theme/app_palette.dart';
/// Generic card — mirrors the CSS `.card` class.
///
/// Set [glass] to true for the gwgps-style translucent, backdrop-blurred
/// panel (mirrors `.panel { backdrop-filter: blur(16px) }` in
/// fleet-command.css) instead of the default opaque surface.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.header,
    this.trailing,
    this.glass = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Widget? header;
  final Widget? trailing;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final radius = BorderRadius.circular(AppColors.rLg);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Expanded(child: header!),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    );

    if (!glass) {
      return Container(
        decoration: BoxDecoration(
          color: pal.surface1,
          borderRadius: radius,
          border: Border.all(color: pal.border),
        ),
        child: content,
      );
    }

    // Glass variant: translucent panel fill + backdrop blur + hairline
    // border + soft shadow, tuned separately per theme so it reads as glass
    // rather than muddy (matches gwgps's --panel / --shadow tokens).
    final panelFill = pal.isDark
        ? pal.surface1.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.82);
    final shadow = pal.isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ];

    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: panelFill,
              borderRadius: radius,
              border: Border.all(color: pal.border),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Reusable card header title row
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.meta,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: context.pal.textMute),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title, style: AppTheme.cardTitle),
          ),
          if (meta != null) Text(meta!, style: AppTheme.monoXs),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}
