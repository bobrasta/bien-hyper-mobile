import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../theme/app_palette.dart';
/// Generic card — mirrors the CSS `.card` class
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.header,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Widget? header;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(
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
