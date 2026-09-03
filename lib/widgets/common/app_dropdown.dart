import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';

/// One option in an [AppSelectField] or [AppMultiSelectField].
class AppSelectItem<T> {
  const AppSelectItem({required this.value, required this.label, this.leading});
  final T value;
  final String label;
  final Widget? leading;
}

// Shared chrome: bordered trigger box with a label above it and a chevron
// that flips when open, plus the floating panel the trigger opens — used
// by both the single- and multi-select variants below so they read as one
// consistent component family, matching the reference design.

class _DropdownShell extends StatefulWidget {
  const _DropdownShell({
    required this.label,
    required this.triggerText,
    required this.triggerBuilder,
    required this.panelBuilder,
    this.badge,
    this.width,
  });
  final String? label;
  final String triggerText;
  final Widget Function(BuildContext context, bool open) triggerBuilder;
  final Widget Function(BuildContext context, VoidCallback close) panelBuilder;
  final int? badge;
  final double? width;

  @override
  State<_DropdownShell> createState() => _DropdownShellState();
}

class _DropdownShellState extends State<_DropdownShell> {
  final _link = LayerLink();
  final _triggerKey = GlobalKey();
  OverlayEntry? _entry;
  bool _open = false;

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  void _toggle() => _open ? _close() : _openPanel();

  void _openPanel() {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? widget.width ?? 220;
    _entry = OverlayEntry(builder: (ctx) => Stack(children: [
      // Full-screen tap-catcher so tapping outside the panel closes it.
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close)),
      CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: Offset(0, (box?.size.height ?? 40) + 6),
        child: Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: ctx.pal.surface1,
                  border: Border.all(color: ctx.pal.borderStrong),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.panelBuilder(ctx, _close),
              ),
            ),
          ),
        ),
      ),
    ]));
    Overlay.of(context).insert(_entry!);
    setState(() => _open = true);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.label != null) ...[
        Text(widget.label!.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
        const SizedBox(height: 6),
      ],
      GestureDetector(
        key: _triggerKey,
        onTap: _toggle,
        child: Container(
          height: 38, width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            border: Border.all(color: _open ? AppColors.blue.withValues(alpha: 0.55) : context.pal.border),
          ),
          child: Row(children: [
            Expanded(child: Text(widget.triggerText, style: AppTheme.bodySm.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (widget.badge != null && widget.badge! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(999)),
                child: Text('${widget.badge}', style: AppTheme.monoXs.copyWith(fontSize: 10, color: Colors.white, height: 1.4)),
              ),
            ],
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 140),
              child: Icon(Symbols.expand_more, size: 17, color: context.pal.textDim),
            ),
          ]),
        ),
      ),
    ]),
  );
}

Widget _panelRow(BuildContext context, {required Widget leading, required Widget label, required bool selected, required VoidCallback onTap}) {
  return _HoverRow(onTap: onTap, selected: selected, child: Row(children: [
    leading,
    const SizedBox(width: 9),
    Expanded(child: label),
  ]));
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.selected, required this.onTap});
  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        color: widget.selected
            ? AppColors.blue.withValues(alpha: 0.10)
            : (_hovered ? context.pal.surface2 : Colors.transparent),
        child: widget.child,
      ),
    ),
  );
}

/// Single-select — bordered box, opens a floating list below, closes on pick.
/// Matches the "Project status" / "Country" combobox pattern in the
/// reference design; replaces a plain DropdownButton one screen at a time.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key, this.label, required this.value, required this.items,
    required this.onChanged, this.hint = 'Select…', this.width,
  });
  final String? label;
  final T? value;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T> onChanged;
  final String hint;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final selected = items.where((i) => i.value == value);
    final triggerText = selected.isNotEmpty ? selected.first.label : hint;
    return _DropdownShell(
      label: label, triggerText: triggerText, width: width,
      triggerBuilder: (_, _) => const SizedBox.shrink(),
      panelBuilder: (ctx, close) => ListView(
        shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 6),
        children: items.map((i) => _panelRow(
          ctx,
          leading: i.leading ?? const SizedBox(width: 16),
          label: Text(i.label, style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
          selected: i.value == value,
          onTap: () { onChanged(i.value); close(); },
        )).toList(),
      ),
    );
  }
}

/// Multi-select — bordered box shows "N selected" + a count badge, opens a
/// floating checklist that stays open while toggling multiple options.
/// Matches the "Industry" / "Country" checkbox pattern in the reference
/// design.
class AppMultiSelectField<T> extends StatefulWidget {
  const AppMultiSelectField({
    super.key, this.label, required this.values, required this.items,
    required this.onChanged, this.hint = 'Select…', this.width,
  });
  final String? label;
  final Set<T> values;
  final List<AppSelectItem<T>> items;
  final ValueChanged<Set<T>> onChanged;
  final String hint;
  final double? width;

  @override
  State<AppMultiSelectField<T>> createState() => _AppMultiSelectFieldState<T>();
}

class _AppMultiSelectFieldState<T> extends State<AppMultiSelectField<T>> {
  @override
  Widget build(BuildContext context) {
    final triggerText = widget.values.isEmpty
        ? widget.hint
        : widget.values.length == 1
            ? widget.items.firstWhere((i) => widget.values.contains(i.value), orElse: () => widget.items.first).label
            : '${widget.values.length} selected';
    return _DropdownShell(
      label: widget.label, triggerText: triggerText, width: widget.width,
      badge: widget.values.length > 1 ? widget.values.length : null,
      triggerBuilder: (_, _) => const SizedBox.shrink(),
      panelBuilder: (ctx, close) => StatefulBuilder(builder: (ctx, setPanelState) => ListView(
        shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 6),
        children: widget.items.map((i) {
          final isSelected = widget.values.contains(i.value);
          return _panelRow(
            ctx,
            leading: SizedBox(width: 18, height: 18, child: Checkbox(
              value: isSelected,
              onChanged: (_) => setPanelState(() {
                final next = Set<T>.from(widget.values);
                isSelected ? next.remove(i.value) : next.add(i.value);
                widget.onChanged(next);
              }),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: ctx.pal.textDim),
              activeColor: AppColors.blue,
            )),
            label: Text(i.label, style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
            selected: false,
            onTap: () => setPanelState(() {
              final next = Set<T>.from(widget.values);
              isSelected ? next.remove(i.value) : next.add(i.value);
              widget.onChanged(next);
            }),
          );
        }).toList(),
      )),
    );
  }
}
