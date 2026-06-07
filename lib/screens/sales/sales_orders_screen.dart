import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/sales_order.dart';
import '../../services/invoice_service.dart';
import '../../services/sales_order_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Color _statusColor(String status) => switch (status) {
  'pending'    => AppColors.textDim,
  'confirmed'  => AppColors.blue,
  'delivering' => AppColors.amber,
  'delivered'  => AppColors.teal,
  'cancelled'  => AppColors.coral,
  _            => AppColors.textDim,
};

String _fmtAmount(int tzs) {
  if (tzs >= 1000000) return 'TSh ${(tzs / 1e6).toStringAsFixed(1)}M';
  if (tzs >= 1000)    return 'TSh ${(tzs / 1000).toStringAsFixed(0)}K';
  return 'TSh $tzs';
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class SalesOrdersScreen extends StatefulWidget {
  const SalesOrdersScreen({super.key});

  @override
  State<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends State<SalesOrdersScreen> {
  List<SalesOrder> _all      = [];
  List<SalesOrder> _filtered = [];
  SalesOrder?      _selected;
  bool             _loading  = true;
  String?          _error;
  String?          _statusFilter;
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
      final data = await SalesOrderService.instance.list();
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
      _filtered = _all.where((so) {
        final matchStatus = _statusFilter == null || so.status == _statusFilter;
        final matchSearch = q.isEmpty ||
            so.clientName.toLowerCase().contains(q) ||
            so.orderNumber.toLowerCase().contains(q);
        return matchStatus && matchSearch;
      }).toList();
      if (_selected != null && !_filtered.any((so) => so.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  Future<void> _doAction(Future<SalesOrder> Function() action) async {
    try {
      final updated = await action();
      await _load();
      if (!mounted) return;
      setState(() => _selected = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _showDeliverModal(SalesOrder so) async {
    final full = so.items.isEmpty ? await SalesOrderService.instance.get(so.id) : so;
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _DeliverModal(order: full),
    );
    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Header ──
      Container(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
        child: LayoutBuilder(builder: (_, cst) {
          final narrow = cst.maxWidth < 580;
          final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sales Orders', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('${_filtered.length} order${_filtered.length == 1 ? '' : 's'}',
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
                  hintText: 'Search client / SO number…',
                  hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                  prefixIcon: Icon(Symbols.search, size: 16, color: context.pal.textDim),
                  filled: true, fillColor: context.pal.surface2,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.pal.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.pal.border)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AppButton(label: 'Refresh', icon: Symbols.refresh, variant: BtnVariant.ghost,
                onPressed: _load),
          ]);
          if (narrow) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleBlock, const SizedBox(height: 12), actions]);
          }
          return Row(children: [titleBlock, const Spacer(), actions]);
        }),
      ),

      // ── Status chips ──
      _StatusChips(
        current: _statusFilter,
        onChanged: (s) { setState(() { _statusFilter = s; _applyFilter(); }); },
      ),

      // ── Body ──
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
      else if (_error != null)
        Expanded(child: ErrorView(message: _error!, onRetry: _load))
      else
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selected != null)
                SizedBox(
                  width: 430,
                  child: _OrderTable(
                    items: _filtered,
                    selected: _selected,
                    onSelect: (so) async {
                      if (so.items.isEmpty) {
                        final full = await SalesOrderService.instance.get(so.id);
                        if (!mounted) return;
                        setState(() => _selected = full);
                      } else {
                        setState(() => _selected = so);
                      }
                    },
                  ),
                )
              else
                Expanded(
                  child: _OrderTable(
                    items: _filtered,
                    selected: null,
                    onSelect: (so) async {
                      if (so.items.isEmpty) {
                        final full = await SalesOrderService.instance.get(so.id);
                        if (!mounted) return;
                        setState(() => _selected = full);
                      } else {
                        setState(() => _selected = so);
                      }
                    },
                  ),
                ),
              if (_selected != null) ...[
                VerticalDivider(width: 1, color: context.pal.border),
                Expanded(child: _DetailPanel(
                  so: _selected!,
                  onClose: () => setState(() => _selected = null),
                  onConfirm: () => _doAction(
                    () => SalesOrderService.instance.confirm(_selected!.id)),
                  onDeliver: () => _showDeliverModal(_selected!),
                  onCancel:  () => _doAction(
                    () => SalesOrderService.instance.cancel(_selected!.id)),
                  onInvoice: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await InvoiceService.instance.fromSalesOrder(_selected!.id);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Invoice created — view it under Sales → Invoices')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(friendlyError(e))),
                      );
                    }
                  },
                )),
              ],
            ],
          ),
        ),
    ]);
  }
}

// ── Status chips ───────────────────────────────────────────────────────────────

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.current, required this.onChanged});
  final String? current;
  final ValueChanged<String?> onChanged;

  static const _statuses = [
    ('pending', 'Pending'), ('confirmed', 'Confirmed'),
    ('delivering', 'Delivering'), ('delivered', 'Delivered'), ('cancelled', 'Cancelled'),
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

// ── Order table ────────────────────────────────────────────────────────────────

class _OrderTable extends StatelessWidget {
  const _OrderTable({required this.items, required this.selected, required this.onSelect});
  final List<SalesOrder> items;
  final SalesOrder? selected;
  final ValueChanged<SalesOrder> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('No sales orders found', style: AppTheme.bodySub));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.border),
      itemBuilder: (_, i) {
        if (i == 0) return _header(context);
        final so = items[i - 1];
        final isActive = selected?.id == so.id;
        return GestureDetector(
          onTap: () => onSelect(so),
          child: Container(
            color: isActive ? context.pal.surface2 : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              SizedBox(width: 140, child: Text(so.orderNumber,
                  style: AppTheme.monoXs.copyWith(fontSize: 12, color: context.pal.textDim))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(so.clientName,
                    style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                if (so.quotationNumber != null)
                  Text('From ${so.quotationNumber}',
                      style: AppTheme.bodySub.copyWith(fontSize: 10, color: context.pal.textDim)),
              ])),
              SizedBox(width: 110, child: Text(_fmtAmount(so.totalAmount),
                  style: AppTheme.bodySm.copyWith(color: AppColors.amber))),
              SizedBox(width: 110, child: _StatusBadge(so.status, so.statusLabel)),
              SizedBox(width: 100, child: Text(so.createdAt.substring(0, 10),
                  style: AppTheme.bodySub.copyWith(fontSize: 11))),
            ]),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) => Container(
    color: context.pal.surface2,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: const Row(children: [
      SizedBox(width: 140, child: Text('SO NUMBER', style: _hStyle)),
      Expanded(child: Text('CLIENT',   style: _hStyle)),
      SizedBox(width: 110,  child: Text('AMOUNT',   style: _hStyle)),
      SizedBox(width: 110,  child: Text('STATUS',   style: _hStyle)),
      SizedBox(width: 100,  child: Text('CREATED',  style: _hStyle)),
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
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Detail panel ───────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.so,
    required this.onClose,
    required this.onConfirm,
    required this.onDeliver,
    required this.onCancel,
    required this.onInvoice,
  });

  final SalesOrder so;
  final VoidCallback onClose;
  final VoidCallback onConfirm;
  final VoidCallback onDeliver;
  final VoidCallback onCancel;
  final VoidCallback onInvoice;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(child: Text(so.orderNumber,
              style: AppTheme.pageTitle.copyWith(fontSize: 18))),
          GestureDetector(
            onTap: onClose,
            child: Icon(Symbols.close, size: 18, color: context.pal.textDim),
          ),
        ]),
        const SizedBox(height: 4),
        _StatusBadge(so.status, so.statusLabel),
        if (so.quotationNumber != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Symbols.request_quote, size: 14, color: context.pal.textDim),
            const SizedBox(width: 6),
            Text('From ${so.quotationNumber}',
                style: AppTheme.bodySub.copyWith(fontSize: 12)),
          ]),
        ],
        const SizedBox(height: 20),

        // Info rows
        _row('Client', so.clientName),
        if (so.clientContact != null) _row('Contact', so.clientContact!),
        if (so.expectedDeliveryDate != null) _row('Expected Delivery', so.expectedDeliveryDate!),
        _row('Currency', so.currency),
        if (so.createdByName != null) _row('Created By', so.createdByName!),
        if (so.confirmedByName != null) _row('Confirmed By', so.confirmedByName!),
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
            _finRow('Subtotal', so.subtotal, context),
            if (so.discountAmount > 0) _finRow('Discount', -so.discountAmount, context, isDiscount: true),
            if (so.taxAmount > 0) _finRow('Tax', so.taxAmount, context),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: AppTheme.bodyStrong),
              Text(_fmtAmount(so.totalAmount),
                  style: AppTheme.bodyStrong.copyWith(color: AppColors.amber, fontSize: 15)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // Line items
        Text('Line Items', style: AppTheme.bodyStrong),
        const SizedBox(height: 8),
        if (so.items.isEmpty)
          Text('Load detail to view items', style: AppTheme.bodySub)
        else
          ...so.items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.pal.surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.pal.border),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.description,
                    style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500)),
                if (item.itemSku != null)
                  Text(item.itemSku!,
                      style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
              ])),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${item.quantityDelivered} / ${item.quantityOrdered} ${item.unitOfMeasure}',
                    style: AppTheme.bodySub.copyWith(fontSize: 11)),
                if (item.isFullyDelivered)
                  Text('Delivered', style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w600, color: AppColors.teal))
                else
                  Text('${item.quantityRemaining} remaining',
                      style: AppTheme.bodySub.copyWith(fontSize: 10, color: AppColors.amber)),
              ]),
              const SizedBox(width: 12),
              Text(_fmtAmount(item.totalPrice),
                  style: AppTheme.bodySm.copyWith(
                      color: AppColors.amber, fontWeight: FontWeight.w600)),
            ]),
          )),

        if (so.notes != null) ...[
          const SizedBox(height: 16),
          Text('Notes', style: AppTheme.bodyStrong),
          const SizedBox(height: 4),
          Text(so.notes!, style: AppTheme.bodySub),
        ],

        const SizedBox(height: 24),

        // Action buttons
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (so.canConfirm)
            AppButton(label: 'Confirm Order', icon: Symbols.check_circle,
                variant: BtnVariant.primary, onPressed: onConfirm),
          if (so.canDeliver)
            AppButton(label: 'Record Delivery', icon: Symbols.local_shipping,
                variant: BtnVariant.primary, onPressed: onDeliver),
          if (so.status == 'delivered')
            AppButton(label: 'Generate Invoice', icon: Symbols.receipt_long,
                variant: BtnVariant.primary, onPressed: onInvoice),
          if (so.canCancel)
            AppButton(label: 'Cancel Order', icon: Symbols.cancel,
                variant: BtnVariant.ghost, onPressed: onCancel),
        ]),
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(label, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textDim))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
    ]),
  );

  Widget _finRow(String label, int amount, BuildContext ctx, {bool isDiscount = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTheme.bodySub),
        Text(
          isDiscount ? '-${_fmtAmount(-amount)}' : _fmtAmount(amount),
          style: AppTheme.bodySub.copyWith(color: isDiscount ? AppColors.coral : null),
        ),
      ]),
    );
}

// ── Delivery modal ─────────────────────────────────────────────────────────────

class _DeliverModal extends StatefulWidget {
  const _DeliverModal({required this.order});
  final SalesOrder order;

  @override
  State<_DeliverModal> createState() => _DeliverModalState();
}

class _DeliverModalState extends State<_DeliverModal> {
  late final List<TextEditingController> _qtyCtrls;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrls = widget.order.items.map((item) =>
      TextEditingController(text: item.quantityRemaining.toString())
    ).toList();
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls) { c.dispose(); }
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await SalesOrderService.instance.deliver(
        widget.order.id,
        items: widget.order.items.asMap().entries.map((e) => {
          'sales_order_item_id': e.value.id,
          'quantity_delivered':  int.tryParse(_qtyCtrls[e.key].text) ?? 0,
        }).where((m) => (m['quantity_delivered'] as int) > 0).toList(),
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Container(
      width: 520,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Symbols.local_shipping, size: 18, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(child: Text('Record Delivery — ${widget.order.orderNumber}',
              style: AppTheme.bodyStrong)),
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Icon(Symbols.close, size: 18, color: context.pal.textDim),
          ),
        ]),
        const SizedBox(height: 20),

        // Per-item qty inputs
        ...widget.order.items.asMap().entries.map((e) {
          final item = e.value;
          if (item.isFullyDelivered) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.pal.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.pal.border),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.description,
                    style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500)),
                Text('Remaining: ${item.quantityRemaining} ${item.unitOfMeasure}',
                    style: AppTheme.bodySub.copyWith(fontSize: 11)),
              ])),
              SizedBox(
                width: 80,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.pal.surface1,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: Center(child: TextField(
                    controller: _qtyCtrls[e.key],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm,
                    decoration: const InputDecoration(
                      border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                    ),
                  )),
                ),
              ),
            ]),
          );
        }),

        // Notes
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.pal.border),
          ),
          child: TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: AppTheme.bodySm,
            decoration: InputDecoration(
              hintText: 'Delivery notes (optional)…',
              hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Container(height: 38,
              decoration: BoxDecoration(border: Border.all(color: context.pal.border),
                  borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('Cancel', style: AppTheme.bodySm))),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: _save,
            child: Container(height: 38,
              decoration: BoxDecoration(color: AppColors.teal,
                  borderRadius: BorderRadius.circular(8)),
              child: Center(child: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Confirm Delivery', style: AppTheme.bodyStrong.copyWith(
                    color: const Color(0xFF06120F), fontSize: 13)))),
          )),
        ]),
      ]),
    ),
  );
}
