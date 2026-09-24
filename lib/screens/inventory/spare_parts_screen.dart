import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/spare_part.dart';
import '../../services/spare_part_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_error.dart';
import '../../utils/csv_export.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart' show FieldFocusBox;
import '../../widgets/common/shimmer_box.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common/app_button.dart';
import '../../theme/app_palette.dart';

class SparePartsScreen extends StatefulWidget {
  const SparePartsScreen({super.key});

  @override
  State<SparePartsScreen> createState() => _SparePartsScreenState();
}

class _SparePartsScreenState extends State<SparePartsScreen> {
  String  _stockFilter    = 'all';    // 'all' | 'low' | 'out'
  String? _categoryFilter;
  String  _search         = '';
  SparePart? _selected;
  bool _showAdd     = false;
  bool _showEdit    = false;
  bool _showAdjust  = false;

  List<SparePart> _allParts  = [];
  bool            _loading   = true;
  String?         _error;
  int             _showCount = 25;
  static const    _pageSize  = 25;

  @override
  void initState() {
    super.initState();
    // Stale-while-revalidate: show the last-known catalog immediately (if
    // any) instead of blanking to a spinner on every navigation — see
    // MachineService for the full reasoning.
    final cached = SparePartService.cachedDefaultList;
    if (cached != null) { _allParts = cached; _loading = false; }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_allParts.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final data = await SparePartService.instance.list();
      if (mounted) setState(() { _allParts = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _deletePart(SparePart part) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.pal.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Deactivate ${part.name}?', style: AppTheme.bodyStrong),
        content: Text(
          'The item will be deactivated and hidden from active inventory.',
          style: AppTheme.bodySub,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.bodySm.copyWith(color: context.pal.textMute)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Deactivate', style: AppTheme.bodySm.copyWith(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SparePartService.instance.delete(part.id);
      if (mounted) {
        setState(() { if (_selected == part) _selected = null; });
        _load();
      }
    } catch (_) {}
  }

  Future<void> _exportCsv() async {
    try {
      final data = _filtered;
      final path = await CsvExport.inventory(data);
      if (path != null && mounted) showSuccessToast(context, 'Exported ${data.length} item(s) to CSV');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  List<SparePart> get _filtered {
    var list = _allParts;
    if (_stockFilter == 'low') list = list.where((p) => p.isLowStock && !p.isOutOfStock).toList();
    if (_stockFilter == 'out') list = list.where((p) => p.isOutOfStock).toList();
    if (_categoryFilter != null) list = list.where((p) => p.category == _categoryFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.sku.toLowerCase().contains(q) ||
        p.supplier.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final allFiltered = _filtered;
    final parts       = allFiltered.take(_showCount).toList();
    final remaining   = allFiltered.length - parts.length;
    final lowCount = _allParts.where((p) => p.isLowStock && !p.isOutOfStock).length;
    final outCount = _allParts.where((p) => p.isOutOfStock).length;
    final totalValue = _allParts.fold(0.0, (s, p) => s + p.stockQty * p.unitCost);

    // Category counts for filter chips
    final categories = <String, int>{};
    for (final p in _allParts) {
      categories[p.category] = (categories[p.category] ?? 0) + 1;
    }

    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header ───────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
          child: LayoutBuilder(builder: (ctx, cst) {
            final narrow = cst.maxWidth < 600;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!narrow)
                Row(children: [
                  Text('Parts & Inventory', style: AppTheme.pageTitle),
                  const Spacer(),
                  AppButton(label: 'Export', icon: Symbols.download, variant: BtnVariant.ghost,
                      onPressed: _exportCsv),
                  const SizedBox(width: 8),
                  AppButton(label: 'Add Item', icon: Symbols.add, variant: BtnVariant.primary,
                      onPressed: () => setState(() => _showAdd = true)),
                ])
              else ...[
                Text('Parts & Inventory', style: AppTheme.pageTitle),
                const SizedBox(height: 10),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  AppButton(label: 'Export', icon: Symbols.download, variant: BtnVariant.ghost,
                      onPressed: _exportCsv),
                  const SizedBox(width: 8),
                  AppButton(label: 'Add Item', icon: Symbols.add, variant: BtnVariant.primary,
                      onPressed: () => setState(() => _showAdd = true)),
                ]),
              ],
              const SizedBox(height: 6),
              Text(
                '${_allParts.length} SKUs · $lowCount low stock · '
                '$outCount out of stock · Stock value: ${tshFromDouble(totalValue)}',
                style: AppTheme.bodySub,
              ),
              const SizedBox(height: 14),
              // Stock filter + search
              if (!narrow)
                Row(children: [
                  _Chip(label: 'All',        count: '${_allParts.length}',
                      active: _stockFilter == 'all', onTap: () => setState(() { _stockFilter = 'all'; _showCount = _pageSize; })),
                  const SizedBox(width: 6),
                  _Chip(label: 'Low Stock',  count: '$lowCount', color: AppColors.amber,
                      active: _stockFilter == 'low', onTap: () => setState(() { _stockFilter = 'low'; _showCount = _pageSize; })),
                  const SizedBox(width: 6),
                  _Chip(label: 'Out of Stock', count: '$outCount', color: AppColors.coral,
                      active: _stockFilter == 'out', onTap: () => setState(() { _stockFilter = 'out'; _showCount = _pageSize; })),
                  const SizedBox(width: 14),
                  // Category filter
                  if (categories.isNotEmpty) ...[
                    _Chip(label: 'All Categories', count: '',
                        active: _categoryFilter == null,
                        onTap: () => setState(() { _categoryFilter = null; _showCount = _pageSize; })),
                    const SizedBox(width: 6),
                    ...categories.entries.take(4).map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(
                        label: _catLabel(e.key), count: '${e.value}',
                        active: _categoryFilter == e.key,
                        onTap: () => setState(() { _categoryFilter = _categoryFilter == e.key ? null : e.key; _showCount = _pageSize; }),
                      ),
                    )),
                  ],
                  const Spacer(),
                  Container(
                    width: 240, height: 32,
                    decoration: BoxDecoration(
                      color: context.pal.surface1,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.pal.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: [
                      Icon(Symbols.search, size: 14, color: context.pal.textDim),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(
                        onChanged: (v) => setState(() { _search = v; _showCount = _pageSize; }),
                        style: AppTheme.bodySm,
                        decoration: InputDecoration(
                          hintText: 'Search name, SKU, supplier—',
                          hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                          border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                        ),
                      )),
                    ]),
                  ),
                ])
              else
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    height: 32,
                    decoration: BoxDecoration(color: context.pal.surface1,
                        borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: [
                      Icon(Symbols.search, size: 14, color: context.pal.textDim),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(
                        onChanged: (v) => setState(() { _search = v; _showCount = _pageSize; }),
                        style: AppTheme.bodySm,
                        decoration: InputDecoration(
                          hintText: 'Search name, SKU, supplier—',
                          hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                          border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                        ),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _Chip(label: 'All', count: '${_allParts.length}',
                        active: _stockFilter == 'all', onTap: () => setState(() { _stockFilter = 'all'; _showCount = _pageSize; })),
                    _Chip(label: 'Low Stock', count: '$lowCount', color: AppColors.amber,
                        active: _stockFilter == 'low', onTap: () => setState(() { _stockFilter = 'low'; _showCount = _pageSize; })),
                    _Chip(label: 'Out of Stock', count: '$outCount', color: AppColors.coral,
                        active: _stockFilter == 'out', onTap: () => setState(() { _stockFilter = 'out'; _showCount = _pageSize; })),
                  ]),
                ]),
            ]);
          }),
        ),

        // ── Two-panel ────────────────────────────────────────────────────────
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Table
            Expanded(
              flex: 3,
              child: RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: context.pal.border))),
                      child: Row(children: [
                        _Th('SKU',        flex: 1),
                        _Th('Name',       flex: 3),
                        _Th('Category',   flex: 1),
                        _Th('Supplier',   flex: 2),
                        _Th('In Stock',   flex: 1),
                        _Th('Reorder At', flex: 1),
                        _Th('Unit Cost',  flex: 1),
                        const SizedBox(width: 70),
                      ]),
                    ),
                    if (_loading)
                      shimmerTable(count: 8, cols: 6)
                    else if (_error != null && _allParts.isEmpty)
                      ErrorView(message: _error!, onRetry: _load, compact: true)
                    else if (parts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Symbols.inventory_2, size: 36, color: context.pal.textDim),
                          const SizedBox(height: 10),
                          Text('No items found', style: AppTheme.bodySub),
                        ])),
                      )
                    else ...[
                      ...parts.map((p) => _PartRow(
                        part: p,
                        selected: _selected == p,
                        onTap:    () => setState(() => _selected = _selected == p ? null : p),
                        onEdit:   () => setState(() { _selected = p; _showEdit = true; }),
                        onDelete: () => _deletePart(p),
                      )),
                      if (remaining > 0)
                        GestureDetector(
                          onTap: () => setState(() => _showCount += _pageSize),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            child: Text('Load $remaining more',
                              style: AppTheme.bodySm.copyWith(color: AppColors.teal, fontSize: 12.5)),
                          ),
                        )
                      else if (parts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(child: Text('Showing all ${parts.length} items',
                            style: AppTheme.bodySub.copyWith(fontSize: 12))),
                        ),
                    ]
                  ]),
                ),
              ),
            ),

            // Detail panel
            if (_selected != null) ...[
              Container(width: 1, color: context.pal.border),
              SizedBox(
                width: 320,
                child: _PartDetailPanel(
                  part:      _selected!,
                  onClose:   () => setState(() => _selected = null),
                  onEdit:    () => setState(() => _showEdit = true),
                  onAdjust:  () => setState(() => _showAdjust = true),
                ),
              ),
            ],
          ]),
        ),
      ]),

      // Add modal
      if (_showAdd)
        _PartFormModal(
          onClose: () => setState(() => _showAdd = false),
          onSaved: () { setState(() => _showAdd = false); _load(); },
        ),

      // Edit modal
      if (_showEdit && _selected != null)
        _PartFormModal(
          part:    _selected!,
          onClose: () => setState(() => _showEdit = false),
          onSaved: () { setState(() => _showEdit = false); _load(); },
        ),

      // Adjust stock modal
      if (_showAdjust && _selected != null)
        _AdjustStockModal(
          part:    _selected!,
          onClose: () => setState(() => _showAdjust = false),
          onSaved: () { setState(() => _showAdjust = false); _load(); },
        ),
    ]);
  }

  static String _catLabel(String cat) => switch (cat) {
    'machine_part' => 'Machine Part',
    'consumable'   => 'Consumable',
    'accessory'    => 'Accessory',
    'equipment'    => 'Equipment',
    _              => 'Other',
  };
}

// ── Part table row ───────────────────────────────────────────────────────────

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.part,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });
  final SparePart part;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final stockColor = part.isOutOfStock
        ? AppColors.coral
        : part.isLowStock ? AppColors.amber : AppColors.teal;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? context.pal.surface2 : Colors.transparent,
          border: Border(bottom: BorderSide(color: context.pal.divider)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // SKU
          Expanded(flex: 1, child: Text(part.sku,
              style: AppTheme.monoXs.copyWith(color: context.pal.textMute, fontSize: 11))),
          // Name
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(part.name, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            Text(part.supplier, style: AppTheme.bodySub.copyWith(fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ])),
          // Category
          Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _catColor(part.category).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_catLabel(part.category),
                style: AppTheme.monoXs.copyWith(
                    color: _catColor(part.category), fontSize: 9.5),
                overflow: TextOverflow.ellipsis),
          ))),
          // Supplier
          Expanded(flex: 2, child: Text(part.supplier,
              style: AppTheme.bodySub.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
          // Stock qty
          Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (part.isOutOfStock || part.isLowStock) ...[
                Icon(part.isOutOfStock ? Symbols.error : Symbols.warning,
                    size: 12, color: stockColor),
                const SizedBox(width: 3),
              ],
              Text('${part.stockQty} ${part.unitOfMeasure}',
                  style: AppTheme.monoXs.copyWith(color: stockColor, fontWeight: FontWeight.w700)),
            ]),
          ))),
          // Reorder level
          Expanded(flex: 1, child: Text('— ${part.reorderLevel}',
              style: AppTheme.monoXs.copyWith(color: context.pal.textDim))),
          // Unit cost
          Expanded(flex: 1, child: Text(tshFromDouble(part.unitCost),
              style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
          // Actions
          SizedBox(width: 70, child: Row(children: [
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onEdit,
              child: Icon(Symbols.edit, size: 15, color: context.pal.textDim),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Symbols.delete_outline, size: 15, color: AppColors.coral),
            ),
          ])),
        ]),
      ),
    );
  }

  static String _catLabel(String cat) => switch (cat) {
    'machine_part' => 'Part',
    'consumable'   => 'Consumable',
    'accessory'    => 'Accessory',
    'equipment'    => 'Equipment',
    _              => 'Other',
  };

  static Color _catColor(String cat) => switch (cat) {
    'machine_part' => AppColors.teal,
    'consumable'   => AppColors.violet,
    'accessory'    => AppColors.blue,
    'equipment'    => AppColors.amber,
    _              => AppColors.textDim,
  };
}

// ── Part detail panel ────────────────────────────────────────────────────────

class _PartDetailPanel extends StatelessWidget {
  const _PartDetailPanel({
    required this.part,
    required this.onClose,
    this.onEdit,
    this.onAdjust,
  });
  final SparePart part;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    final stockColor = part.isOutOfStock
        ? AppColors.coral
        : part.isLowStock ? AppColors.amber : AppColors.teal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(part.name, style: AppTheme.bodyStrong)),
          GestureDetector(onTap: onClose,
              child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
        ]),
        const SizedBox(height: 4),
        Text(part.sku, style: AppTheme.monoXs.copyWith(color: context.pal.textMute)),
        const SizedBox(height: 16),

        // Stock status card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: stockColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: stockColor.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(part.isOutOfStock
                ? Symbols.error
                : part.isLowStock ? Symbols.warning : Symbols.check_circle,
                size: 20, color: stockColor),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${part.stockQty} ${part.unitOfMeasure} in stock',
                  style: AppTheme.bodyStrong.copyWith(color: stockColor)),
              Text(part.isOutOfStock
                  ? 'Out of stock — reorder immediately'
                  : part.isLowStock
                      ? 'Below reorder level (${part.reorderLevel})'
                      : 'Stock level OK',
                  style: AppTheme.bodySub.copyWith(fontSize: 11.5, color: stockColor)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        _DetailRow('SKU',           part.sku),
        _DetailRow('Category',      _catLabel(part.category)),
        _DetailRow('Unit',          part.unitOfMeasure),
        _DetailRow('Supplier',      part.supplier),
        _DetailRow('Unit Cost',     tshFromDouble(part.unitCost)),
        _DetailRow('Stock Qty',     '${part.stockQty} ${part.unitOfMeasure}'),
        _DetailRow('Reorder Level', '${part.reorderLevel} ${part.unitOfMeasure}'),
        _DetailRow('Stock Value',   tshFromDouble(part.stockQty * part.unitCost)),

        if (part.compatibleModels.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Compatible Machines', style: AppTheme.cardTitle.copyWith(fontSize: 12)),
          const SizedBox(height: 8),
          ...part.compatibleModels.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Symbols.medical_services, size: 12, color: context.pal.textDim),
              const SizedBox(width: 8),
              Expanded(child: Text(m, style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
            ]),
          )),
        ],

        const SizedBox(height: 20),

        // Receive / adjust stock button
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: onAdjust,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Symbols.add_circle, size: 16, color: Color(0xFF06120F)),
                const SizedBox(width: 8),
                Text('Adjust Stock', style: AppTheme.bodyStrong.copyWith(
                    color: const Color(0xFF06120F), fontSize: 13)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: onEdit,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: context.pal.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text('Edit Item', style: AppTheme.bodySm)),
            ),
          ),
        ),
      ]),
    );
  }

  static String _catLabel(String cat) => switch (cat) {
    'machine_part' => 'Machine Part',
    'consumable'   => 'Consumable',
    'accessory'    => 'Accessory',
    'equipment'    => 'Equipment',
    _              => 'Other',
  };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12))),
      Expanded(child: Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
    ]),
  );
}

// ── Add / Edit modal (shared) ────────────────────────────────────────────────

class _PartFormModal extends StatefulWidget {
  const _PartFormModal({this.part, required this.onClose, this.onSaved});
  final SparePart? part;
  final VoidCallback  onClose;
  final VoidCallback? onSaved;

  @override
  State<_PartFormModal> createState() => _PartFormModalState();
}

class _PartFormModalState extends State<_PartFormModal> {
  late final _nameCtrl    = TextEditingController(text: widget.part?.name ?? '');
  late final _skuCtrl     = TextEditingController(text: widget.part?.sku  ?? '');
  late final _qtyCtrl     = TextEditingController(text: widget.part != null ? '${widget.part!.stockQty}' : '0');
  late final _costCtrl    = TextEditingController(text: widget.part != null ? widget.part!.unitCost.toStringAsFixed(0) : '');
  late final _reorderCtrl = TextEditingController(text: widget.part != null ? '${widget.part!.reorderLevel}' : '2');
  late String _category   = widget.part?.category      ?? 'machine_part';
  late String _uom        = widget.part?.unitOfMeasure  ?? 'piece';
  late String _supplier   = widget.part?.supplier       ?? 'Mindray East Africa';
  bool    _saving = false;
  String? _error;

  static const _categories  = ['machine_part', 'consumable', 'accessory', 'equipment', 'other'];
  static const _catLabels   = ['Machine Part', 'Consumable', 'Accessory', 'Equipment', 'Other'];
  static const _uoms        = ['piece', 'box', 'litre', 'set', 'kg', 'roll'];
  static const _suppliers   = [
    'Mindray East Africa', 'Dräger East Africa Ltd', 'GE Healthcare Africa',
    'Siemens Healthineers EA', 'Parker Laboratories', 'Tuttnauer Africa',
    'Seca Medical', 'Other',
  ];

  bool get _isEdit => widget.part != null;

  @override
  void dispose() {
    _nameCtrl.dispose(); _skuCtrl.dispose();
    _qtyCtrl.dispose(); _costCtrl.dispose(); _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _nameCtrl.text.trim().isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      final data = {
        'name':           _nameCtrl.text.trim(),
        'sku':            _skuCtrl.text.trim(),
        'category':       _category,
        'unit_of_measure': _uom,
        'unit_cost':      double.tryParse(_costCtrl.text.trim()) ?? 0,
        'stock_qty':      int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        'reorder_level':  int.tryParse(_reorderCtrl.text.trim()) ?? 2,
        'supplier':       _supplier,
      };
      if (_isEdit) {
        await SparePartService.instance.update(widget.part!.id, data);
      } else {
        await SparePartService.instance.create(data);
      }
      if (mounted) showSuccessToast(context, _isEdit ? 'Item updated' : 'Item added to inventory');
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorToast(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 520,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Icon(_isEdit ? Symbols.edit : Symbols.inventory_2, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text(_isEdit ? 'Edit: ${widget.part!.name}' : 'Add Inventory Item',
                    style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            // Form
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _Field(label: 'Item Name', ctrl: _nameCtrl, hint: 'e.g. Flow Sensor Module')),
                  const SizedBox(width: 14),
                  Expanded(child: _Field(label: 'SKU', ctrl: _skuCtrl, hint: 'e.g. MIN-FS-6800')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _Dropdown(
                    label: 'Category',
                    value: _category,
                    items: _categories, labels: _catLabels,
                    onChanged: (v) => setState(() => _category = v),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _Dropdown(
                    label: 'Unit of Measure',
                    value: _uom,
                    items: _uoms,
                    onChanged: (v) => setState(() => _uom = v),
                  )),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _Field(label: 'Qty in Stock', ctrl: _qtyCtrl, hint: '0', numeric: true)),
                  const SizedBox(width: 14),
                  Expanded(child: _Field(label: 'Reorder Level', ctrl: _reorderCtrl, hint: '2', numeric: true)),
                  const SizedBox(width: 14),
                  Expanded(child: _Field(label: 'Unit Cost (TSh)', ctrl: _costCtrl, hint: '0', numeric: true)),
                ]),
                const SizedBox(height: 14),
                _Dropdown(
                  label: 'Supplier',
                  value: _suppliers.contains(_supplier) ? _supplier : _suppliers.last,
                  items: _suppliers,
                  onChanged: (v) => setState(() => _supplier = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
                ],
              ]),
            )),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(border: Border.all(color: context.pal.border),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: _save,
                  child: Container(height: 38,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEdit ? 'Save Changes' : 'Add Item',
                          style: AppTheme.bodyStrong.copyWith(
                              color: const Color(0xFF06120F), fontSize: 13)))),
                )),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ── Adjust Stock modal ───────────────────────────────────────────────────────

class _AdjustStockModal extends StatefulWidget {
  const _AdjustStockModal({required this.part, required this.onClose, this.onSaved});
  final SparePart     part;
  final VoidCallback  onClose;
  final VoidCallback? onSaved;

  @override
  State<_AdjustStockModal> createState() => _AdjustStockModalState();
}

class _AdjustStockModalState extends State<_AdjustStockModal> {
  final _qtyCtrl    = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  bool   _add     = true;   // true = add, false = remove
  bool   _saving  = false;
  String? _error;

  @override
  void dispose() { _qtyCtrl.dispose(); _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) { setState(() => _error = 'Enter a valid quantity.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await SparePartService.instance.adjust(
        widget.part.id,
        _add ? qty : -qty,
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) {
        showSuccessToast(context, _add
            ? '+$qty ${widget.part.unitOfMeasure} added to ${widget.part.name}'
            : '-$qty ${widget.part.unitOfMeasure} removed from ${widget.part.name}');
      }
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorToast(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = (_add ? widget.part.stockQty + (int.tryParse(_qtyCtrl.text) ?? 0)
                           : widget.part.stockQty - (int.tryParse(_qtyCtrl.text) ?? 0))
        .clamp(0, 999999);

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: const Color(0xAA06070A),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 420,
            decoration: BoxDecoration(
              color: context.pal.surface1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.pal.borderStrong),
              boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  Icon(Symbols.inventory, size: 18, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Adjust Stock — ${widget.part.name}',
                      style: AppTheme.bodyStrong, overflow: TextOverflow.ellipsis)),
                  GestureDetector(onTap: widget.onClose,
                      child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  // Current stock
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.pal.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('CURRENT STOCK', style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
                        const SizedBox(height: 2),
                        Text('${widget.part.stockQty} ${widget.part.unitOfMeasure}',
                            style: AppTheme.bodyStrong),
                      ])),
                      Icon(Symbols.arrow_forward, size: 16, color: AppColors.teal),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('AFTER ADJUSTMENT', style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
                        const SizedBox(height: 2),
                        Text('$preview ${widget.part.unitOfMeasure}',
                            style: AppTheme.bodyStrong.copyWith(color: AppColors.teal)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Add / Remove toggle
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _add = true),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: _add ? AppColors.tealSoft : context.pal.surface2,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                          border: Border.all(color: _add ? AppColors.teal : context.pal.border),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Symbols.add, size: 14, color: AppColors.teal),
                          const SizedBox(width: 4),
                          Text('Receive / Add', style: AppTheme.bodySm.copyWith(
                              color: AppColors.teal, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    )),
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _add = false),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: !_add ? AppColors.coralSoft : context.pal.surface2,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                          border: Border.all(color: !_add ? AppColors.coral : context.pal.border),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Symbols.remove, size: 14, color: AppColors.coral),
                          const SizedBox(width: 4),
                          Text('Use / Remove', style: AppTheme.bodySm.copyWith(
                              color: AppColors.coral, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    SizedBox(width: 100, child: _Field(label: 'Quantity', ctrl: _qtyCtrl,
                        hint: '1', numeric: true,
                        onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 14),
                    Expanded(child: _Field(label: 'Reason', ctrl: _reasonCtrl,
                        hint: 'e.g. received new shipment')),
                  ]),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(height: 38,
                      decoration: BoxDecoration(border: Border.all(color: context.pal.border),
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('Cancel', style: AppTheme.bodySm))),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: _saving ? null : _submit,
                    child: Container(height: 38,
                      decoration: BoxDecoration(color: AppColors.teal,
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(child: _saving
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Confirm Adjustment', style: AppTheme.bodyStrong.copyWith(
                            color: const Color(0xFF06120F), fontSize: 13)))),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Shared form widgets ──────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.ctrl, required this.hint,
      this.numeric = false, this.onChanged});
  final String label, hint;
  final TextEditingController ctrl;
  final bool numeric;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    FieldFocusBox(
      builder: (context, focusNode) => TextField(
        controller: ctrl,
        focusNode: focusNode,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: AppTheme.bodySm,
        onChanged: onChanged,
        decoration: InputDecoration(hintText: hint,
            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
      ),
    ),
  ]);
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items,
      this.labels, required this.onChanged});
  final String label, value;
  final List<String> items;
  final List<String>? labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        isExpanded: true,
        dropdownColor: context.pal.surface2,
        style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.asMap().entries.map((e) => DropdownMenuItem(
          value: e.value,
          child: Text(labels != null ? labels![e.key] : e.value),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);
}

// ── Filter chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.active,
      required this.onTap, this.color});
  final String label, count;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? (color ?? AppColors.teal).withValues(alpha: 0.12) : context.pal.surface1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? (color ?? AppColors.teal) : context.pal.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: AppTheme.bodySm.copyWith(
            color: active ? (color ?? AppColors.teal) : context.pal.textMute, fontSize: 12)),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: (color ?? AppColors.teal).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(count, style: AppTheme.bodySub.copyWith(
                color: color ?? AppColors.teal, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    ),
  );
}

// ── Table header cell ────────────────────────────────────────────────────────

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex});
  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(label.toUpperCase(),
        style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.10)),
  );
}
