import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/inventory_item.dart';
import '../../models/quotation.dart';
import '../../services/inventory_service.dart';
import '../../services/quotation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

// ── Status colours ─────────────────────────────────────────────────────────────
Color _statusColor(String status) => switch (status) {
  'draft'     => AppColors.textDim,
  'sent'      => AppColors.blue,
  'accepted'  => AppColors.teal,
  'rejected'  => AppColors.coral,
  'expired'   => AppColors.amber,
  'converted' => AppColors.violet,
  _           => AppColors.textDim,
};

String _fmtAmount(int tzs) {
  if (tzs >= 1000000) return 'TSh ${(tzs / 1e6).toStringAsFixed(1)}M';
  if (tzs >= 1000)    return 'TSh ${(tzs / 1000).toStringAsFixed(0)}K';
  return 'TSh $tzs';
}

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  List<Quotation> _all      = [];
  List<Quotation> _filtered = [];
  Quotation?      _selected;
  bool            _loading  = true;
  String?         _error;
  String?         _statusFilter;
  bool            _showForm = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await QuotationService.instance.list();
      if (!mounted) return;
      setState(() { _all = data; _loading = false; });
      _applyFilter();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((qt) {
        final matchStatus = _statusFilter == null || qt.status == _statusFilter;
        final matchSearch = q.isEmpty ||
            qt.clientName.toLowerCase().contains(q) ||
            qt.quotationNumber.toLowerCase().contains(q);
        return matchStatus && matchSearch;
      }).toList();
      if (_selected != null && !_filtered.any((qt) => qt.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  Future<void> _doAction(Future<Quotation> Function() action) async {
    try {
      final updated = await action();
      await _load();
      if (!mounted) return;
      setState(() => _selected = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _convert(Quotation qt) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: Text('Convert to Sales Order', style: AppTheme.bodyStrong),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Convert ${qt.quotationNumber} into a Sales Order?', style: AppTheme.bodySm),
          const SizedBox(height: 12),
          _formField('Expected Delivery Date', ctrl, 'YYYY-MM-DD', context),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Convert', style: TextStyle(color: AppColors.teal)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await QuotationService.instance.convert(
        qt.id,
        expectedDeliveryDate: ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : null,
      );
      ctrl.dispose();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales Order created successfully')),
        );
      }
    } catch (e) {
      ctrl.dispose();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
          child: LayoutBuilder(builder: (_, cst) {
            final narrow = cst.maxWidth < 580;
            final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Quotations', style: AppTheme.pageTitle),
              const SizedBox(height: 4),
              Text('${_filtered.length} quotation${_filtered.length == 1 ? '' : 's'}',
                  style: AppTheme.bodySub),
            ]);
            final actions = Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 220,
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  style: AppTheme.bodySm,
                  decoration: InputDecoration(
                    hintText: 'Search client / QT number…',
                    hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                    prefixIcon: Icon(Symbols.search, size: 16, color: context.pal.textDim),
                    filled: true, fillColor: context.pal.surface2,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.pal.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.pal.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'New Quotation', icon: Symbols.add, variant: BtnVariant.primary,
                onPressed: () => setState(() => _showForm = true),
              ),
            ]);
            if (narrow) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleBlock, const SizedBox(height: 12), actions]);
            }
            return Row(children: [titleBlock, const Spacer(), actions]);
          }),
        ),

        // ── Status filter chips ──
        _StatusChips(
          current: _statusFilter,
          onChanged: (s) { setState(() { _statusFilter = s; _applyFilter(); }); },
        ),

        // ── Body: list + detail ──
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_error != null)
          Expanded(child: ErrorView(message: _error!, onRetry: _load))
        else
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // List panel — use Expanded when no detail panel so width stays bounded
                if (_selected != null)
                  SizedBox(
                    width: 420,
                    child: _QuotationTable(
                      items: _filtered,
                      selected: _selected,
                      onSelect: (qt) async {
                        if (qt.items.isEmpty) {
                          final full = await QuotationService.instance.get(qt.id);
                          if (!mounted) return;
                          setState(() => _selected = full);
                        } else {
                          setState(() => _selected = qt);
                        }
                      },
                    ),
                  )
                else
                  Expanded(
                    child: _QuotationTable(
                      items: _filtered,
                      selected: null,
                      onSelect: (qt) async {
                        if (qt.items.isEmpty) {
                          final full = await QuotationService.instance.get(qt.id);
                          if (!mounted) return;
                          setState(() => _selected = full);
                        } else {
                          setState(() => _selected = qt);
                        }
                      },
                    ),
                  ),
                // Detail panel
                if (_selected != null) ...[
                  VerticalDivider(width: 1, color: context.pal.border),
                  Expanded(child: _DetailPanel(
                    qt: _selected!,
                    onClose: () => setState(() => _selected = null),
                    onSend:    () => _doAction(() => QuotationService.instance.send(_selected!.id)),
                    onAccept:  () => _doAction(() => QuotationService.instance.accept(_selected!.id)),
                    onReject:  () => _doAction(() => QuotationService.instance.reject(_selected!.id)),
                    onConvert: () => _convert(_selected!),
                    onDelete:  () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await QuotationService.instance.delete(_selected!.id);
                        setState(() => _selected = null);
                        await _load();
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(friendlyError(e))),
                          );
                        }
                      }
                    },
                  )),
                ],
              ],
            ),
          ),
      ]),

      if (_showForm)
        _QuotationFormModal(
          onClose: () => setState(() => _showForm = false),
          onSaved: () { setState(() => _showForm = false); _load(); },
        ),
    ]);
  }
}

// ── Status filter chips ────────────────────────────────────────────────────────

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.current, required this.onChanged});
  final String? current;
  final ValueChanged<String?> onChanged;

  static const _statuses = [
    ('draft', 'Draft'), ('sent', 'Sent'), ('accepted', 'Accepted'),
    ('rejected', 'Rejected'), ('converted', 'Converted'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      children: [
        _chip(context, null, 'All'),
        ...(_statuses.map((s) => _chip(context, s.$1, s.$2))),
      ],
    ),
  );

  Widget _chip(BuildContext ctx, String? value, String label) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onChanged(active ? null : value),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (value == null ? ctx.pal.surface3 : _statusColor(value).withValues(alpha: 0.15))
              : ctx.pal.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? (value == null ? ctx.pal.borderStrong : _statusColor(value))
                : ctx.pal.border,
          ),
        ),
        child: Text(label,
          style: AppTheme.bodySm.copyWith(
            fontSize: 12,
            color: active
                ? (value == null ? ctx.pal.text : _statusColor(value))
                : ctx.pal.textMute,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
      ),
    );
  }
}

// ── Quotation table ────────────────────────────────────────────────────────────

class _QuotationTable extends StatelessWidget {
  const _QuotationTable({required this.items, required this.selected, required this.onSelect});
  final List<Quotation> items;
  final Quotation? selected;
  final ValueChanged<Quotation> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('No quotations found', style: AppTheme.bodySub));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(0),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.border),
      itemBuilder: (_, i) {
        if (i == 0) return _tableHeader(context);
        final qt = items[i - 1];
        final isActive = selected?.id == qt.id;
        return GestureDetector(
          onTap: () => onSelect(qt),
          child: Container(
            color: isActive ? context.pal.surface2 : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              SizedBox(width: 140, child: Text(qt.quotationNumber,
                  style: AppTheme.monoXs.copyWith(fontSize: 12, color: context.pal.textDim))),
              Expanded(child: Text(qt.clientName,
                  style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
              SizedBox(width: 110, child: Text(_fmtAmount(qt.totalAmount),
                  style: AppTheme.bodySm.copyWith(color: AppColors.amber))),
              SizedBox(width: 120, child: _StatusBadge(qt.status, qt.statusLabel)),
              SizedBox(width: 100, child: Text(qt.createdAt.substring(0, 10),
                  style: AppTheme.bodySub.copyWith(fontSize: 11))),
            ]),
          ),
        );
      },
    );
  }

  Widget _tableHeader(BuildContext context) => Container(
    color: context.pal.surface2,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(children: [
      SizedBox(width: 140, child: Text('QT NUMBER', style: AppTheme.labelCaps)),
      const Expanded(child: Text('CLIENT',    style: _hStyle)),
      SizedBox(width: 110,  child: Text('AMOUNT',   style: AppTheme.labelCaps)),
      SizedBox(width: 120,  child: Text('STATUS',   style: AppTheme.labelCaps)),
      SizedBox(width: 100,  child: Text('CREATED',  style: AppTheme.labelCaps)),
    ]),
  );
}

const _hStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.08);

// ── Status badge ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status, this.label);
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Detail panel ───────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.qt,
    required this.onClose,
    required this.onSend,
    required this.onAccept,
    required this.onReject,
    required this.onConvert,
    required this.onDelete,
  });

  final Quotation qt;
  final VoidCallback onClose;
  final VoidCallback onSend;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onConvert;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(child: Text(qt.quotationNumber,
              style: AppTheme.pageTitle.copyWith(fontSize: 18))),
          GestureDetector(
            onTap: onClose,
            child: Icon(Symbols.close, size: 18, color: context.pal.textDim),
          ),
        ]),
        const SizedBox(height: 4),
        _StatusBadge(qt.status, qt.statusLabel),
        const SizedBox(height: 20),

        // Client info
        _infoRow('Client', qt.clientName),
        if (qt.clientContact != null) _infoRow('Contact', qt.clientContact!),
        if (qt.clientEmail != null) _infoRow('Email', qt.clientEmail!),
        if (qt.validUntil != null) _infoRow('Valid Until', qt.validUntil!),
        _infoRow('Currency', qt.currency),
        if (qt.createdByName != null) _infoRow('Created By', qt.createdByName!),
        const SizedBox(height: 16),

        // Financials
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(children: [
            _finRow('Subtotal', qt.subtotal, context),
            if (qt.discountAmount > 0) _finRow('Discount', -qt.discountAmount, context, isDiscount: true),
            if (qt.taxAmount > 0) _finRow('Tax', qt.taxAmount, context),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: AppTheme.bodyStrong),
              Text(_fmtAmount(qt.totalAmount),
                  style: AppTheme.bodyStrong.copyWith(color: AppColors.amber, fontSize: 15)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // Line items
        Text('Line Items', style: AppTheme.bodyStrong),
        const SizedBox(height: 8),
        if (qt.items.isEmpty)
          Text('Load detail to view items', style: AppTheme.bodySub)
        else
          ...qt.items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.pal.surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.pal.border),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.description, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500)),
                if (item.itemSku != null)
                  Text(item.itemSku!, style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
              ])),
              Text('${item.quantity} × ${_fmtAmount(item.unitPrice)}',
                  style: AppTheme.bodySub.copyWith(fontSize: 11)),
              const SizedBox(width: 12),
              Text(_fmtAmount(item.totalPrice),
                  style: AppTheme.bodySm.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600)),
            ]),
          )),

        if (qt.notes != null) ...[
          const SizedBox(height: 16),
          Text('Notes', style: AppTheme.bodyStrong),
          const SizedBox(height: 4),
          Text(qt.notes!, style: AppTheme.bodySub),
        ],

        const SizedBox(height: 24),

        // Action buttons
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (qt.status == 'draft') ...[
            AppButton(label: 'Send to Client', icon: Symbols.send, variant: BtnVariant.primary, onPressed: onSend),
            AppButton(label: 'Delete', icon: Symbols.delete, variant: BtnVariant.ghost, onPressed: onDelete),
          ],
          if (qt.status == 'sent') ...[
            AppButton(label: 'Mark Accepted', icon: Symbols.check_circle, variant: BtnVariant.primary, onPressed: onAccept),
            AppButton(label: 'Mark Rejected', icon: Symbols.cancel, variant: BtnVariant.ghost, onPressed: onReject),
          ],
          if (qt.status == 'accepted')
            AppButton(label: 'Convert to Sales Order', icon: Symbols.swap_horiz, variant: BtnVariant.primary, onPressed: onConvert),
        ]),
      ]),
    );
  }
}

Widget _infoRow(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 110, child: Text(label, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textDim))),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
  ]),
);

Widget _finRow(String label, int amount, BuildContext ctx, {bool isDiscount = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: AppTheme.bodySub),
    Text(
      isDiscount ? '-${_fmtAmount(-amount)}' : _fmtAmount(amount),
      style: AppTheme.bodySub.copyWith(
        color: isDiscount ? AppColors.coral : null,
      ),
    ),
  ]),
);

// ── Quotation form modal ───────────────────────────────────────────────────────

class _QuotationFormModal extends StatefulWidget {
  const _QuotationFormModal({required this.onClose, required this.onSaved});
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_QuotationFormModal> createState() => _QuotationFormModalState();
}

class _QuotationFormModalState extends State<_QuotationFormModal> {
  final _clientCtrl  = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _notesCtrl   = TextEditingController();
  final _validCtrl   = TextEditingController();
  String _currency   = 'TZS';
  bool   _saving     = false;
  final _lines = [_LineItemEntry(), _LineItemEntry()];
  List<InventoryItem> _invItems = [];

  @override
  void initState() {
    super.initState();
    InventoryService.instance.list().then((items) {
      if (mounted) setState(() => _invItems = items);
    });
  }

  @override
  void dispose() {
    _clientCtrl.dispose(); _contactCtrl.dispose();
    _emailCtrl.dispose();  _notesCtrl.dispose(); _validCtrl.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _clientCtrl.text.trim().isEmpty) return;
    final validLines = _lines.where((l) => l.descCtrl.text.trim().isNotEmpty).toList();
    if (validLines.isEmpty) return;

    setState(() => _saving = true);
    try {
      await QuotationService.instance.create({
        'client_name':    _clientCtrl.text.trim(),
        'client_contact': _contactCtrl.text.trim().isNotEmpty ? _contactCtrl.text.trim() : null,
        'client_email':   _emailCtrl.text.trim().isNotEmpty   ? _emailCtrl.text.trim()   : null,
        'valid_until':    _validCtrl.text.trim().isNotEmpty    ? _validCtrl.text.trim()   : null,
        'currency':       _currency,
        'notes':          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        'items': validLines.map((l) => {
          'inventory_item_id': l.selectedItem?.id,
          'description':       l.descCtrl.text.trim(),
          'unit_of_measure':   l.uomCtrl.text.trim().isNotEmpty ? l.uomCtrl.text.trim() : 'pcs',
          'quantity':          int.tryParse(l.qtyCtrl.text) ?? 1,
          'unit_price':        int.tryParse(l.priceCtrl.text.replaceAll(',', '')) ?? 0,
          'discount_percent':  double.tryParse(l.discCtrl.text) ?? 0,
        }).toList(),
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
          width: 640,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                const Icon(Symbols.request_quote, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('New Quotation', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),

            // Body
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Client info row
                Row(children: [
                  Expanded(child: _formField('Client Name *', _clientCtrl, 'Hospital or company', context)),
                  const SizedBox(width: 12),
                  Expanded(child: _formField('Contact Person', _contactCtrl, 'Dr. Name', context)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _formField('Email', _emailCtrl, 'client@hospital.tz', context)),
                  const SizedBox(width: 12),
                  Expanded(child: _formField('Valid Until', _validCtrl, 'YYYY-MM-DD', context)),
                  const SizedBox(width: 12),
                  SizedBox(width: 100, child: _dropField('Currency', _currency,
                    ['TZS', 'USD', 'EUR', 'KES'],
                    (v) => setState(() => _currency = v), context,
                  )),
                ]),
                const SizedBox(height: 20),

                // Line items
                Row(children: [
                  Text('Line Items', style: AppTheme.bodyStrong),
                  const SizedBox(width: 8),
                  Text('(${_lines.length})', style: AppTheme.bodySub.copyWith(fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _lines.add(_LineItemEntry())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.teal),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Symbols.add, size: 14, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Text('Add Item', style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                ..._lines.asMap().entries.map((e) => _LineItemRow(
                  entry: e.value,
                  index: e.key,
                  invItems: _invItems,
                  onRemove: _lines.length > 1
                      ? () => setState(() { _lines[e.key].dispose(); _lines.removeAt(e.key); })
                      : null,
                  onChanged: () => setState(() {}),
                )),
                const SizedBox(height: 12),
                _formField('Notes', _notesCtrl, 'Payment terms, delivery notes…', context, maxLines: 2),
              ]),
            )),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                      : Text('Create Quotation', style: AppTheme.bodyStrong.copyWith(
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

// ── Line item entry (mutable state for form) ───────────────────────────────────

class _LineItemEntry {
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

// ── Line item row in form ──────────────────────────────────────────────────────

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({
    required this.entry,
    required this.index,
    required this.invItems,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineItemEntry entry;
  final int index;
  final List<InventoryItem> invItems;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.pal.surface2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          flex: 3,
          child: _InvItemPicker(
            items: invItems,
            selected: entry.selectedItem,
            onSelected: (item) {
              entry.selectedItem = item;
              if (item != null) {
                entry.descCtrl.text  = item.name;
                entry.uomCtrl.text   = item.unitOfMeasure;
                entry.priceCtrl.text = item.unitCost.toStringAsFixed(0);
              }
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 8),
        if (onRemove != null)
          GestureDetector(onTap: onRemove,
            child: Icon(Symbols.close, size: 16, color: context.pal.textDim)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(flex: 3, child: _miniField('Description *', entry.descCtrl, context)),
        const SizedBox(width: 6),
        Expanded(flex: 1, child: _miniField('UOM', entry.uomCtrl, context)),
        const SizedBox(width: 6),
        Expanded(flex: 1, child: _miniField('Qty', entry.qtyCtrl, context, numeric: true)),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _miniField('Unit Price', entry.priceCtrl, context, numeric: true)),
        const SizedBox(width: 6),
        Expanded(flex: 1, child: _miniField('Disc%', entry.discCtrl, context, numeric: true)),
      ]),
    ]),
  );
}

class _InvItemPicker extends StatelessWidget {
  const _InvItemPicker({required this.items, required this.selected, required this.onSelected});
  final List<InventoryItem> items;
  final InventoryItem? selected;
  final ValueChanged<InventoryItem?> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: context.pal.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<InventoryItem?>(
        value: selected,
        isExpanded: true,
        hint: Text('Link inventory item (optional)', style: AppTheme.bodySub.copyWith(fontSize: 11)),
        dropdownColor: context.pal.surface2,
        style: AppTheme.bodySm.copyWith(fontSize: 12),
        icon: Icon(Symbols.expand_more, size: 14, color: context.pal.textDim),
        items: [
          const DropdownMenuItem<InventoryItem?>(value: null, child: Text('— None —')),
          ...items.map((item) => DropdownMenuItem<InventoryItem?>(
            value: item,
            child: Text('${item.sku} · ${item.name}',
                overflow: TextOverflow.ellipsis),
          )),
        ],
        onChanged: onSelected,
      ),
    ),
  );
}

// ── Small field helpers ────────────────────────────────────────────────────────

Widget _formField(String label, TextEditingController ctrl, String hint, BuildContext ctx,
    {int maxLines = 1}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 5),
      Container(
        constraints: BoxConstraints(minHeight: maxLines > 1 ? 60 : 36),
        decoration: BoxDecoration(
          color: ctx.pal.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: ctx.pal.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: TextField(
          controller: ctrl, maxLines: maxLines,
          style: AppTheme.bodySm,
          decoration: InputDecoration(
            hintText: hint, border: InputBorder.none, isDense: true,
            contentPadding: EdgeInsets.zero,
            hintStyle: AppTheme.bodySm.copyWith(color: ctx.pal.textDim),
          ),
        ),
      ),
    ]);

Widget _miniField(String label, TextEditingController ctrl, BuildContext ctx, {bool numeric = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 9, letterSpacing: 0.05)),
      const SizedBox(height: 3),
      Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: ctx.pal.surface1,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ctx.pal.border),
        ),
        child: Center(child: TextField(
          controller: ctrl,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          style: AppTheme.bodySm.copyWith(fontSize: 12),
          decoration: const InputDecoration(
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
          ),
        )),
      ),
    ]);

Widget _dropField(String label, String value, List<String> items,
    ValueChanged<String> onChanged, BuildContext ctx) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 5),
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ctx.pal.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: ctx.pal.border),
        ),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: value, isExpanded: true,
          dropdownColor: ctx.pal.surface2,
          style: AppTheme.bodySm,
          icon: Icon(Symbols.expand_more, size: 14, color: ctx.pal.textDim),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        )),
      ),
    ]);
