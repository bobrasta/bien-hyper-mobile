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

// Column widths shared by the line rows and each builder's header row.
const double kLineQtyW   = 76;
const double kLinePriceW = 130;
const double kLineDiscW  = 76;
const double kLineTotalW = 110;

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

  void _pick(InventoryItem? item) {
    entry.selectedItem = item;
    if (item != null) {
      entry.descCtrl.text  = item.name;
      entry.uomCtrl.text   = item.unitOfMeasure;
      entry.priceCtrl.text = item.sellingPrice.toStringAsFixed(0);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Type to search the inventory (name or SKU) and pick from the
      // dropdown, or keep typing for a custom line that isn't in stock.
      Expanded(flex: 3, child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: AppSearchableSelectField<InventoryItem>(
          key: ObjectKey(entry),
          hint: 'Type an item name or SKU…',
          selectedLabel: entry.descCtrl.text,
          items: [for (final i in invItems) AppSelectItem(value: i, label: '${i.name} · ${i.sku}')],
          onSelected: (sel) {
            if (sel == null) {
              entry.selectedItem = null;
              entry.descCtrl.clear();
              onChanged();
            } else {
              _pick(sel.value);
            }
          },
          onTextChanged: (text) {
            // Free text: typing after a pick unlinks the inventory item.
            entry.descCtrl.text = text;
            entry.selectedItem = null;
            onChanged();
          },
        ),
      )),
      SizedBox(width: kLineQtyW, child: _numField(entry.qtyCtrl, onChanged)),
      const SizedBox(width: 8),
      SizedBox(width: kLinePriceW, child: _numField(entry.priceCtrl, onChanged)),
      const SizedBox(width: 8),
      if (showDiscount) ...[
        SizedBox(width: kLineDiscW, child: _numField(entry.discCtrl, onChanged)),
        const SizedBox(width: 8),
      ],
      SizedBox(width: kLineTotalW, child: Text(tshFromDouble(_lineTotal.toDouble()), textAlign: TextAlign.right,
          style: AppTheme.monoSm.copyWith(fontSize: 12))),
      SizedBox(width: 22, child: onRemove != null
          ? GestureDetector(onTap: onRemove, child: Icon(Symbols.close, size: 15, color: context.pal.textDim))
          : null),
    ]),
  );

  // The unified text input, right-aligned for numbers.
  Widget _numField(TextEditingController ctrl, VoidCallback onChanged) => LabeledTextField(
    label: '',
    controller: ctrl,
    textAlign: TextAlign.right,
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

