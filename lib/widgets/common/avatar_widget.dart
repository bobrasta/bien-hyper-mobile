import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../theme/app_palette.dart';
enum AvatarVariant { blue, teal, amber, coral, violet }

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.initials,
    this.size = 30,
    this.variant = AvatarVariant.blue,
  });

  final String initials;
  final double size;
  final AvatarVariant variant;

  @override
  Widget build(BuildContext context) {
    final gradient = switch (variant) {
      AvatarVariant.blue   => AppColors.avatarGradient,
      AvatarVariant.teal   => AppColors.avatarTealGradient,
      AvatarVariant.amber  => AppColors.avatarAmberGradient,
      AvatarVariant.coral  => AppColors.avatarCoralGradient,
      AvatarVariant.violet => AppColors.avatarVioletGradient,
    };
    final textColor = variant == AvatarVariant.teal
        ? context.pal.bg
        : Colors.white;

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        border: Border.all(color: context.pal.borderStrong),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTheme.bodySub.copyWith(
          color: textColor,
          fontSize: size * 0.37,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
