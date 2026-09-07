import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';

/// Text field styled to match the plain dropdown containers already used
/// next to it (e.g. the technician filter) — same height, fill, and
/// radius, with an optional label, leading icon, and trailing widget slot.
/// No border, at rest or focused — a flat filled box, nothing else. Single
/// point of change for this look across the app: converge every ad-hoc
/// `Container(...) + TextField(...)` onto this instead of restyling each
/// one by hand.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.icon,
    this.trailing,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.textInputAction,
    this.autofocus = false,
    this.height = 34,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final IconData? icon;
  final Widget? trailing;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final bool autofocus;
  // Height of the box (label sits above it, not counted here). Pass a
  // taller value for a multi-line textarea — `expands: true` on the inner
  // TextField needs a bounded height from somewhere.
  final double height;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final multiline = maxLines != 1;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) ...[
        Text(label!, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
        const SizedBox(height: 6),
      ],
      Container(
        height: height,
        padding: EdgeInsets.only(left: 12, right: multiline ? 12 : 0, top: multiline ? 12 : 0, bottom: multiline ? 12 : 0),
        decoration: BoxDecoration(
          color: enabled ? pal.surface1 : pal.surface1.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Padding(
                padding: EdgeInsets.only(top: multiline ? 0 : 0),
                child: Icon(icon, size: 16,
                    color: enabled ? pal.textDim : pal.textDim.withValues(alpha: 0.5)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              keyboardType: keyboardType,
              obscureText: obscureText,
              maxLines: maxLines,
              expands: multiline,
              textInputAction: textInputAction,
              // autofocus: autofocus,
              style: AppTheme.bodySm,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTheme.bodySm.copyWith(color: pal.textDim),
                border: InputBorder.none,
                // isDense: true,
                contentPadding: EdgeInsets.zero,
                // contentPadding: EdgeInsets.only(left: 8),
              ),
            )),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    ]);
  }
}
