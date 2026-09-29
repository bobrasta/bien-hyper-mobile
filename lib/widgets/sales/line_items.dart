// Line-item editing pieces shared by the Quotation and Invoice builders.
// UI only — each document keeps its own save logic and API.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/inventory_item.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../common/app_dropdown.dart';
import '../common/labeled_field.dart';

// ── Line item entry (mutable state for form) ───────────────────────────────────

class LineItemEntry {
  final descCtrl  = TextEditingController();
  final uomCtrl   = TextEditingController(text: 'pcs');
  final qtyCtrl   = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final discCtrl  = TextEditingController(text: '0');
  InventoryItem? selectedItem;

  void dispose() {
    descCtrl.dispose(); uomCtrl.dispose();
    qtyCtrl.dispose();  priceCtrl.dispose(); discCtrl.dispose();
  }
}

// ── Line item row — compact table row matching the design's Line items panel ────

class LineItemTableRow extends StatelessWidget {
  const LineItemTableRow({
    super.key,
    required this.entry,
    required this.invItems,
    required this.onChanged,
    required this.onRemove,
    this.showDiscount = true,
  });

  final LineItemEntry entry;
  final List<InventoryItem> invItems;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  /// Quotations carry a per-line discount; invoices don't.
  final bool showDiscount;

  int get _lineTotal {
    final qty = int.tryParse(entry.qtyCtrl.text) ?? 0;
    final price = int.tryParse(entry.priceCtrl.text.replaceAll(',', '')) ?? 0;
    final disc = showDiscount ? (double.tryParse(entry.discCtrl.text) ?? 0) : 0;
    return ((qty * price) * (1 - disc / 100)).round();
  }

  Future<void> _pickItem(BuildContext context) async {
    final picked = await showDialog<InventoryItem?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: const Text('Link inventory item'),
        content: SizedBox(width: 360, height: 360, child: InvItemPicker(
          items: invItems, selected: entry.selectedItem,
          onSelected: (item) => Navigator.of(dialogCtx).pop(item),
        )),
        actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(null), child: const Text('Custom item (no link)'))],
      ),
    );
    entry.selectedItem = picked;
    if (picked != null) {
      entry.descCtrl.text  = picked.name;
      entry.uomCtrl.text   = picked.unitOfMeasure;
      entry.priceCtrl.text = picked.unitCost.toStringAsFixed(0);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(flex: 3, child: GestureDetector(
        onTap: () => _pickItem(context),
        child: entry.selectedItem != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(entry.descCtrl.text, style: AppTheme.bodySm.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(entry.selectedItem!.sku, style: AppTheme.monoXs.copyWith(fontSize: 10, color: context.pal.textMute)),
              ])
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                // The unified text input; the search icon opens the inventory picker.
                child: LabeledTextField(
                  label: '',
                  controller: entry.descCtrl,
                  hint: 'Item description…',
                  onChanged: (_) => onChanged(),
                  suffix: GestureDetector(
                    onTap: () => _pickItem(context),
                    child: MouseRegion(cursor: SystemMouseCursors.click,
                        child: Icon(Symbols.search, size: 15, color: context.pal.textDim)),
                  ),
                ),
              ),
      )),
      SizedBox(width: 44, child: _cellField(entry.qtyCtrl, context, onChanged)),
      const SizedBox(width: 8),
      SizedBox(width: 90, child: _cellField(entry.priceCtrl, context, onChanged)),
      const SizedBox(width: 8),
      if (showDiscount) ...[
        SizedBox(width: 56, child: _cellField(entry.discCtrl, context, onChanged)),
        const SizedBox(width: 8),
      ],
      SizedBox(width: 96, child: Text(tshFromDouble(_lineTotal.toDouble()), textAlign: TextAlign.right,
          style: AppTheme.monoSm.copyWith(fontSize: 12))),
      SizedBox(width: 22, child: onRemove != null
          ? GestureDetector(onTap: onRemove, child: Icon(Symbols.close, size: 15, color: context.pal.textDim))
          : null),
    ]),
  );

  Widget _cellField(TextEditingController ctrl, BuildContext context, VoidCallback onChanged) => CellField(
    controller: ctrl,
    textAlign: TextAlign.right,
    mono: true,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => onChanged(),
  );
}

// Inventory catalog can run to hundreds/thousands of SKUs — client-side
// combobox per Section 4 of hypermed_claude_code_prompt.md.
class InvItemPicker extends StatelessWidget {
  const InvItemPicker({super.key, required this.items, required this.selected, required this.onSelected});
  final List<InventoryItem> items;
  final InventoryItem? selected;
  final ValueChanged<InventoryItem?> onSelected;

  @override
  Widget build(BuildContext context) => AppSearchableSelectField<InventoryItem>(
    hint: 'Link inventory item (optional)',
    selectedLabel: selected == null ? null : '${selected!.sku} · ${selected!.name}',
    items: items.map((item) => AppSelectItem(
      value: item, label: '${item.sku} · ${item.name}')).toList(),
    onSelected: (item) => onSelected(item?.value),
  );
}

// ── Date picker field ──────────────────────────────────────────────────────────

class SalesDateField extends StatelessWidget {
  const SalesDateField({
    super.key,
    required this.label,
    required this.selected,
    required this.onPicked,
    this.firstDate,
  });
  final String label;
  final DateTime? selected;
  final ValueChanged<DateTime?> onPicked;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) => LabeledDateField(
    label: label,
    date: selected,
    placeholder: 'Pick a date',
    onClear: () => onPicked(null),
    onTap: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: selected ?? now.add(const Duration(days: 30)),
        firstDate: firstDate ?? now,
        lastDate: now.add(const Duration(days: 365 * 5)),
      );
      if (picked != null) onPicked(picked);
    },
  );
}

