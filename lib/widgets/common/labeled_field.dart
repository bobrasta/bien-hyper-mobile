import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/format.dart';

/// Height of a single-line field (14px text + 12px vertical padding +
/// border) — dropdown/date/static boxes use it so they line up with text
/// fields in the same row.
const double kFieldHeight = 44;

/// The shared focus-reactive box every text-entry field sits in: a
/// recessed (`bg`-filled) rounded box with a `borderStrong` outline at rest
/// that turns the theme accent while focused, plus a solid translucent
/// accent "halo" ring around the outside (a zero-blur spread shadow, not a
/// soft glow). One place owns the FocusNode + listener so every field call
/// site just does `FieldFocusBox(builder: (focusNode) =>
/// TextField(focusNode: focusNode, ...))` instead of re-implementing focus
/// tracking per screen — a call site that doesn't pass the focusNode
/// through never gets the focused look.
class FieldFocusBox extends StatefulWidget {
  const FieldFocusBox({
    super.key,
    required this.builder,
    this.minHeight = 0,
    this.enabled = true,
    this.alignment,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.hasError = false,
    this.radius = 10,
    this.height,
    this.focusNode,
  });

  final Widget Function(BuildContext context, FocusNode focusNode) builder;
  // Optional caller-owned node, for fields whose focus something else also
  // drives (keyboard navigation, overlays). Otherwise the box owns one.
  final FocusNode? focusNode;
  final double minHeight;
  final bool enabled;
  final Alignment? alignment;
  final EdgeInsetsGeometry padding;
  // A validation error always wins the border color, focused or not — the
  // user needs to see what's wrong before the field looks "fine" again.
  final bool hasError;
  final double radius;
  // Fixed height — for multi-line fields using `expands: true`, which
  // need a bounded height from their parent.
  final double? height;

  @override
  State<FieldFocusBox> createState() => _FieldFocusBoxState();
}

class _FieldFocusBoxState extends State<FieldFocusBox> {
  FocusNode? _ownNode;
  FocusNode get _focusNode => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;

  void _onFocus() {
    if (mounted && _focused != _focusNode.hasFocus) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    _focused = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(FieldFocusBox old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    curve: Curves.easeOut,
    height: widget.height,
    constraints: widget.height == null ? BoxConstraints(minHeight: widget.minHeight) : null,
    decoration: fieldBoxDecoration(context, focused: _focused, hasError: widget.hasError, enabled: widget.enabled, radius: widget.radius),
    padding: widget.padding,
    alignment: widget.alignment,
    child: widget.builder(context, _focusNode),
  );
}

/// The Settings field box — recessed bg fill, borderStrong outline that
/// turns teal (coral on error) with a solid 20% halo while focused/open.
/// The ONE definition of the look: FieldFocusBox, DropdownFieldBox,
/// LabeledDateField and the combobox triggers all draw with this.
BoxDecoration fieldBoxDecoration(BuildContext context, {bool focused = false, bool hasError = false, bool enabled = true, bool active = false, double radius = 10}) {
  final pal = context.pal;
  final accent = hasError ? AppColors.coral : AppColors.teal;
  final lit = focused || active || hasError;
  return BoxDecoration(
    color: enabled ? pal.bg : pal.surface3,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: lit ? accent : pal.borderStrong, width: focused ? 1.6 : 1.2),
    boxShadow: [BoxShadow(
      color: focused ? accent.withValues(alpha: 0.20) : Colors.transparent,
      spreadRadius: focused ? 3 : 0,
      blurRadius: 0,
    )],
  );
}

/// The established boxed-field look used throughout the app (see
/// `_SettingsField` in settings_screen.dart, the inline fields in
/// `_RequestLeaveDialog`/`_PaymentModal`): sentence-case label above, a
/// `surface2` box with a `border` outline (teal + glow while focused), no
/// Material floating label. Extracted here as a shared, public widget so
/// every dialog looks and behaves the same instead of re-implementing it
/// (or drifting from it — see feedback_dont_relabel_reuse_screens for why
/// that matters).
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
    this.onChanged,
    this.onSubmitted,
    this.hasError = false,
    this.prefixIcon,
    this.suffix,
    this.focusNode,
    this.autofocus = false,
    this.onTap,
    this.onTapOutside,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  // Coral border (+ coral halo while focused) — wins over the focus accent.
  final bool hasError;
  // Search boxes and similar: leading icon / trailing widget inside the box.
  final IconData? prefixIcon;
  final Widget? suffix;
  // Caller-owned node for fields whose focus also drives something else
  // (search overlays, combobox keyboard navigation).
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (label.isNotEmpty) ...[
      Text(label, style: AppTheme.fieldLabel),
      const SizedBox(height: 6),
    ],
    FieldFocusBox(
      enabled: enabled,
      hasError: hasError,
      focusNode: focusNode,
      builder: (context, node) {
        final field = TextField(
          controller: controller,
          focusNode: node,
          autofocus: autofocus,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          keyboardType: keyboardType,
          enabled: enabled,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTap: onTap,
          onTapOutside: onTapOutside,
          cursorColor: context.pal.text,
          cursorWidth: 1.5,
          style: AppTheme.fieldText.copyWith(color: enabled ? context.pal.text : context.pal.textDim),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.fieldHint,
            filled: false,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        );
        if (prefixIcon == null && suffix == null) return field;
        return Row(children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 16, color: context.pal.textDim),
            const SizedBox(width: 8),
          ],
          Expanded(child: field),
          if (suffix != null) ...[const SizedBox(width: 8), suffix!],
        ]);
      },
    ),
  ]);
}

/// Search box — the Settings text input (LabeledTextField) with a search
/// icon. Use for every list/table filter. [width] null = fill the parent
/// (wrap it in Expanded inside a Row).
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.width,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double? width;
  final bool autofocus;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _own;
  TextEditingController get _ctrl => widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = LabeledTextField(
      label: '',
      controller: _ctrl,
      hint: widget.hint,
      prefixIcon: Symbols.search,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
    return widget.width == null ? field : SizedBox(width: widget.width, child: field);
  }
}

/// Compact Settings-look box for inline table/grid editors (qty, price and
/// similar cells) — same focus behaviour as every other field, sized down.
class CellField extends StatelessWidget {
  const CellField({
    super.key,
    required this.controller,
    this.hint,
    this.textAlign = TextAlign.center,
    this.keyboardType,
    this.onChanged,
    this.mono = false,
    this.suffixText,
  });

  final TextEditingController controller;
  final String? hint;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool mono;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    final base = mono ? AppTheme.monoSm.copyWith(fontSize: 12.5) : AppTheme.fieldText.copyWith(fontSize: 13);
    return FieldFocusBox(
      radius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      builder: (context, focusNode) => TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: textAlign,
        keyboardType: keyboardType,
        onChanged: onChanged,
        cursorColor: context.pal.text,
        cursorWidth: 1.5,
        style: base.copyWith(color: context.pal.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.fieldHint.copyWith(fontSize: 13),
          suffixText: suffixText,
          suffixStyle: AppTheme.bodySub.copyWith(fontSize: 11.5),
          filled: false, border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
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
    Text(label, style: AppTheme.fieldLabel),
    const SizedBox(height: 6),
    DropdownFieldBox<T>(
      value: value,
      enabled: enabled,
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(displayBuilder(v), overflow: TextOverflow.ellipsis))).toList(),
      // DropdownButton only passes null when the picked item's value IS
      // null, so forward it as-is — dropping it made a nullable option
      // like "None" impossible to re-select.
      onChanged: (v) => onChanged?.call(v as T),
    ),
  ]);
}

/// The Settings dropdown box on its own (no label) — the single place the
/// app's dropdown field is drawn. LabeledDropdown uses it; use it directly
/// for filter bars or wherever items are already DropdownMenuItems.
class DropdownFieldBox<T> extends StatelessWidget {
  const DropdownFieldBox({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.active = false,
    this.width,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool enabled;
  // Filter dropdowns: teal border while a filter is applied.
  final bool active;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    decoration: fieldBoxDecoration(context, enabled: enabled, active: active),
    height: kFieldHeight,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: DropdownButtonHideUnderline(child: DropdownButton<T>(
      value: value,
      isExpanded: true,
      dropdownColor: context.pal.surface2,
      style: AppTheme.fieldText.copyWith(color: enabled ? context.pal.text : context.pal.textDim),
      icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
      hint: hint == null ? null : Text(hint!, style: AppTheme.fieldHint, overflow: TextOverflow.ellipsis),
      items: items,
      onChanged: enabled ? onChanged : null,
    )),
  );
}

/// The established boxed date-picker field (see `_DateField` in
/// my_leave_screen.dart).
class LabeledDateField extends StatelessWidget {
  const LabeledDateField({super.key, required this.label, required this.date, required this.onTap, this.placeholder = 'Select date', this.onClear});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String placeholder;
  // Optional — shows a clear (×) button while a date is set, for fields
  // where "no date" is a valid answer.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.fieldLabel),
    const SizedBox(height: 6),
    GestureDetector(
      onTap: onTap,
      child: Container(
        height: kFieldHeight,
        decoration: fieldBoxDecoration(context),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Expanded(child: Text(date != null ? formatDate(date!) : placeholder,
              style: AppTheme.fieldText.copyWith(color: date != null ? context.pal.text : context.pal.textDim))),
          if (date != null && onClear != null) ...[
            GestureDetector(onTap: onClear, child: Icon(Symbols.close, size: 14, color: context.pal.textDim)),
            const SizedBox(width: 8),
          ],
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
    Text(label, style: AppTheme.fieldLabel),
    const SizedBox(height: 6),
    Container(
      height: kFieldHeight,
      alignment: Alignment.centerLeft,
      decoration: fieldBoxDecoration(context, enabled: false),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        Expanded(child: Text(value, style: AppTheme.fieldText.copyWith(color: context.pal.textDim), overflow: TextOverflow.ellipsis)),
        if (hint != null) Icon(Symbols.lock, size: 13, color: context.pal.textDim),
      ]),
    ),
    if (hint != null) Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(hint!, style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
    ),
  ]);
}
