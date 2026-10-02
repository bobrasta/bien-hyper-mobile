import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyDownEvent;
import 'package:material_symbols_icons/symbols.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import 'labeled_field.dart';

// Case/whitespace/hyphen/punctuation-insensitive match key — "xray",
// "x-ray" and "X Ray" all normalize the same way. Used as the default
// client-side filter and by the machine-model combobox specifically (see
// hypermed_claude_code_prompt.md Section 4). Deliberately not fuzzy.
String normalizeForSearch(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// One option in an [AppSelectField], [AppMultiSelectField] or
/// [AppSearchableSelectField].
class AppSelectItem<T> {
  const AppSelectItem({required this.value, required this.label, this.leading, this.trailing});
  final T value;
  final String label;
  final Widget? leading;
  /// Extra info shown at the row's end (e.g. a stock-count badge) —
  /// [AppSearchableSelectField] only; ignored elsewhere.
  final Widget? trailing;
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
        Text(widget.label!, style: AppTheme.fieldLabel),
        const SizedBox(height: 6),
      ],
      GestureDetector(
        key: _triggerKey,
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: fieldHeightOf(context), width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: fieldBoxDecoration(context, focused: _open),
          child: Row(children: [
            Expanded(child: Text(widget.triggerText, style: AppTheme.fieldText, maxLines: 1, overflow: TextOverflow.ellipsis)),
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

Widget _panelRow(BuildContext context, {required Widget leading, required Widget label, required bool selected, required VoidCallback onTap, Widget? trailing}) {
  return _HoverRow(onTap: onTap, selected: selected, child: Row(children: [
    leading,
    const SizedBox(width: 9),
    Expanded(child: label),
    if (trailing != null) ...[const SizedBox(width: 8), trailing],
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

/// Searchable select (combobox) — click and type, options filter live, pick
/// one; selected value shown with a clear (x) button. Two modes:
/// - Client-side: pass [items]; filtered locally by [normalizeForSearch].
/// - Server-side: pass [asyncSearch]; debounced, shows loading/"no results".
/// Never both empty — one of the two must be provided.
/// Per hypermed_claude_code_prompt.md Section 4: use this everywhere a user
/// picks from a long or growing list (hospitals, staff, machine models…).
class AppSearchableSelectField<T> extends StatefulWidget {
  const AppSearchableSelectField({
    super.key,
    this.label,
    this.selectedLabel,
    this.items,
    this.asyncSearch,
    required this.onSelected,
    this.hint = 'Type to search…',
    this.width,
    this.createNewLabel,
    this.onCreateNew,
    this.onTextChanged,
  }) : assert(items != null || asyncSearch != null, 'Provide items or asyncSearch');

  final String? label;
  /// Display text for the currently selected value (shown when the field
  /// isn't focused/being typed into). Null/empty shows [hint].
  final String? selectedLabel;
  /// Client-side candidate pool. Filtered locally as the user types.
  final List<AppSelectItem<T>>? items;
  /// Server-side search — called (debounced) with the typed query.
  final Future<List<AppSelectItem<T>>> Function(String query)? asyncSearch;
  /// Fires with the picked item, or null when the field is cleared via (x).
  final ValueChanged<AppSelectItem<T>?> onSelected;
  final String hint;
  final double? width;
  /// When set alongside [onCreateNew], an extra row offers creating a new
  /// entry from the typed text if nothing matches (e.g. machine models).
  final String Function(String query)? createNewLabel;
  final ValueChanged<String>? onCreateNew;
  /// Fires on every keystroke with the raw typed text — for genuinely
  /// free-text fields (like machine model) where the caller wants to fall
  /// back to whatever's typed even if the user never explicitly picks a
  /// suggestion or the "Create new" row.
  final ValueChanged<String>? onTextChanged;

  @override
  State<AppSearchableSelectField<T>> createState() => _AppSearchableSelectFieldState<T>();
}

class _AppSearchableSelectFieldState<T> extends State<AppSearchableSelectField<T>> {
  final _link = LayerLink();
  final _triggerKey = GlobalKey();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  OverlayEntry? _entry;
  Timer? _debounce;
  bool _open = false;
  bool _loading = false;
  // Set just before unfocus() in _pick()/_createNew() so _onFocusChange's
  // revert-on-blur-without-a-pick branch doesn't stomp the text those two
  // just set — widget.selectedLabel is a prop from the parent's setState,
  // which hasn't rebuilt this widget yet when the focus listener fires
  // (unfocus() notifies synchronously), so it's still the pre-pick value.
  bool _suppressBlurRevert = false;
  String _query = '';
  List<AppSelectItem<T>> _results = const [];
  int _highlight = -1;

  bool get _isAsync => widget.asyncSearch != null;
  static const _maxLocalResults = 50;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selectedLabel ?? '';
    _focusNode.addListener(_onFocusChange);
    if (!_isAsync) _results = widget.items ?? const [];
  }

  @override
  void didUpdateWidget(covariant AppSearchableSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.selectedLabel != oldWidget.selectedLabel) {
      _controller.text = widget.selectedLabel ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _entry?.remove();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      _runQuery(_controller.text);
      _openPanel();
    } else {
      if (_suppressBlurRevert) {
        _suppressBlurRevert = false;
      } else {
        // Revert to the committed selection's label if the user clicked
        // away without picking anything (mirrors a native combobox).
        _controller.text = widget.selectedLabel ?? '';
      }
      _closePanel();
    }
  }

  void _onChanged(String text) {
    widget.onTextChanged?.call(text);
    setState(() { _query = text; _highlight = -1; });
    if (_isAsync) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () => _runQuery(text));
    } else {
      _runQuery(text);
    }
    _entry?.markNeedsBuild();
  }

  Future<void> _runQuery(String query) async {
    if (_isAsync) {
      if (query.trim().isEmpty) {
        setState(() { _results = const []; _loading = false; });
        _entry?.markNeedsBuild();
        return;
      }
      setState(() => _loading = true);
      _entry?.markNeedsBuild();
      final results = await widget.asyncSearch!(query.trim());
      if (!mounted) return;
      setState(() { _results = results; _loading = false; });
      _entry?.markNeedsBuild();
    } else {
      final key = normalizeForSearch(query);
      final all = widget.items ?? const [];
      // The panel builds every row, so a long pool (e.g. ~1,700 inventory
      // items) is capped to the first matches — typing narrows it.
      final matches = key.isEmpty ? all : all.where((i) => normalizeForSearch(i.label).contains(key));
      setState(() => _results = matches.take(_maxLocalResults).toList());
      _entry?.markNeedsBuild();
    }
  }

  bool get _showCreateNew =>
      widget.onCreateNew != null &&
      _query.trim().isNotEmpty &&
      !_loading &&
      !_results.any((i) => normalizeForSearch(i.label) == normalizeForSearch(_query));

  int get _rowCount => _results.length + (_showCreateNew ? 1 : 0);

  void _selectIndex(int index) {
    if (index < 0 || index >= _rowCount) return;
    if (index < _results.length) {
      _pick(_results[index]);
    } else {
      _createNew();
    }
  }

  void _pick(AppSelectItem<T> item) {
    _suppressBlurRevert = true;
    widget.onSelected(item);
    _controller.text = item.label;
    _focusNode.unfocus();
  }

  void _createNew() {
    _suppressBlurRevert = true;
    widget.onCreateNew?.call(_query.trim());
    _focusNode.unfocus();
  }

  void _clear() {
    widget.onSelected(null);
    _controller.clear();
    setState(() { _query = ''; _highlight = -1; });
    _runQuery('');
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_rowCount > 0) {
        setState(() => _highlight = (_highlight + 1) % _rowCount);
        _entry?.markNeedsBuild();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_rowCount > 0) {
        setState(() => _highlight = (_highlight - 1 + _rowCount) % _rowCount);
        _entry?.markNeedsBuild();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_highlight >= 0) {
        _selectIndex(_highlight);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openPanel() {
    if (_open) { _entry?.markNeedsBuild(); return; }
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? widget.width ?? 220;
    _entry = OverlayEntry(builder: (ctx) => Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _focusNode.unfocus())),
      CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: Offset(0, (box?.size.height ?? 40) + 6),
        child: Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: _buildPanel(ctx)),
          ),
        ),
      ),
    ]));
    Overlay.of(context).insert(_entry!);
    setState(() => _open = true);
  }

  void _closePanel() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  Widget _buildPanel(BuildContext ctx) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: ctx.pal.surface1,
        border: Border.all(color: ctx.pal.borderStrong),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: _panelBody(ctx),
    );
  }

  Widget _panelBody(BuildContext ctx) {
    if (_isAsync && _query.trim().isEmpty) {
      return _panelMessage(ctx, 'Type to search…');
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_results.isEmpty && !_showCreateNew) {
      return _panelMessage(ctx, 'No results');
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        for (var i = 0; i < _results.length; i++)
          _panelRow(ctx,
            leading: _results[i].leading ?? const SizedBox(width: 16),
            label: Text(_results[i].label, style: AppTheme.bodySm.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis),
            trailing: _results[i].trailing,
            selected: i == _highlight,
            onTap: () => _pick(_results[i]),
          ),
        if (_showCreateNew)
          _panelRow(ctx,
            leading: Icon(Symbols.add, size: 16, color: AppColors.blue),
            label: Text(
              widget.createNewLabel?.call(_query.trim()) ?? 'Create new: "${_query.trim()}"',
              style: AppTheme.bodySm.copyWith(fontSize: 12.5, color: AppColors.blue),
            ),
            selected: _results.length == _highlight,
            onTap: _createNew,
          ),
      ],
    );
  }

  Widget _panelMessage(BuildContext ctx, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
    child: Text(text, style: AppTheme.bodySm.copyWith(fontSize: 12.5, color: ctx.pal.textDim)),
  );

  @override
  Widget build(BuildContext context) {
    final hasValue = (widget.selectedLabel ?? '').isNotEmpty;
    return CompositedTransformTarget(
      link: _link,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTheme.fieldLabel),
          const SizedBox(height: 6),
        ],
        // The Settings text input (LabeledTextField) with this combobox's
        // own FocusNode (keyboard navigation + panel open/close hang off it).
        SizedBox(key: _triggerKey, width: widget.width, child: Focus(
          onKeyEvent: _handleKey,
          child: LabeledTextField(
            label: '',
            controller: _controller,
            focusNode: _focusNode,
            prefixIcon: Symbols.search,
            hint: widget.hint,
            onChanged: _onChanged,
            onSubmitted: (_) { if (_highlight >= 0) _selectIndex(_highlight); },
            // Desktop platforms default onTapOutside to an immediate
            // unfocus() on raw pointer-down — the results panel lives in a
            // separate Overlay, so every tap on a row counted as "outside"
            // and closed the panel (via _onFocusChange) before the tap could
            // resolve into onTap, so _pick() never ran. The full-screen
            // GestureDetector in _openPanel() already handles "click
            // elsewhere closes it" correctly — so disable the built-in one.
            onTapOutside: (_) {},
            suffix: hasValue && !_focusNode.hasFocus
                ? GestureDetector(onTap: _clear, child: Icon(Symbols.close, size: 15, color: context.pal.textDim))
                : null,
          ),
        )),
      ]),
    );
  }
}
