import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/format.dart';

/// The established boxed-field look used throughout the app (see
/// `_SettingsField` in settings_screen.dart, the inline fields in
/// `_RequestLeaveDialog`/`_PaymentModal`): uppercase label above, a
/// `surface2` box with a `border` outline, no Material floating label.
/// Extracted here as a shared, public widget so every dialog looks and
/// behaves the same instead of re-implementing it (or drifting from it —
/// see feedback_dont_relabel_reuse_screens for why that matters).
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.obscure = false,
    this.keyboardType,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (label.isNotEmpty) ...[
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 6),
    ],
    Container(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? 56 : 38),
      decoration: BoxDecoration(
        color: enabled ? context.pal.surface2 : context.pal.surface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.pal.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      alignment: maxLines > 1 ? null : Alignment.centerLeft,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: enabled,
        style: AppTheme.bodySm.copyWith(color: enabled ? context.pal.text : context.pal.textDim),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ),
  ]);
}

/// The established boxed-dropdown look (see `_HDropdown` in
/// settings_screen.dart). Generic over [T] — the app's original per-file
/// copies were String-only, which is why new dialogs kept reaching for
/// Material's default `DropdownButtonFormField` instead (it needed int
/// keys) and drifted off-style. `isExpanded: true` here also closes off
/// the overflow class of bug that caused (a dropdown with unconstrained
/// intrinsic width inside a Row/Expanded).
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.displayBuilder,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) displayBuilder;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      decoration: BoxDecoration(
        color: enabled ? context.pal.surface2 : context.pal.surface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.pal.border),
      ),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: context.pal.surface2,
        style: AppTheme.bodySm.copyWith(color: enabled ? context.pal.text : context.pal.textDim),
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.map((v) => DropdownMenuItem(value: v, child: Text(displayBuilder(v), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: enabled ? (v) { if (v != null) onChanged?.call(v); } : null,
      )),
    ),
  ]);
}

/// The established boxed date-picker field (see `_DateField` in
/// my_leave_screen.dart).
class LabeledDateField extends StatelessWidget {
  const LabeledDateField({super.key, required this.label, required this.date, required this.onTap, this.placeholder = 'Select date'});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String placeholder;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(child: Text(date != null ? formatDate(date!) : placeholder,
              style: AppTheme.bodySm.copyWith(color: date != null ? context.pal.text : context.pal.textDim))),
          Icon(Symbols.calendar_month, size: 15, color: context.pal.textDim),
        ]),
      ),
    ),
  ]);
}

/// A disabled-looking read-only row, for fields shown but not editable by
/// the current user (e.g. Position, gated to Director/Admin).
class LabeledStaticField extends StatelessWidget {
  const LabeledStaticField({super.key, required this.label, required this.value, this.hint});
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      height: 38,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: context.pal.surface3, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(child: Text(value, style: AppTheme.bodySm.copyWith(color: context.pal.textDim), overflow: TextOverflow.ellipsis)),
        if (hint != null) Icon(Symbols.lock, size: 13, color: context.pal.textDim),
      ]),
    ),
    if (hint != null) Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(hint!, style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
    ),
  ]);
}
