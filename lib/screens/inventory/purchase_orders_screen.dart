import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/purchase_order.dart';
import '../../widgets/common/app_dropdown.dart';
import '../../services/supplier_service.dart';
import '../../services/location_service.dart';
import '../../services/inventory_service.dart';
import '../../models/supplier.dart';
import '../../models/location.dart';
import '../../models/inventory_item.dart';
import '../../services/purchase_order_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/shimmer_box.dart';
import '../../widgets/common/labeled_field.dart';
import '../../widgets/common/period_filter.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  String? _statusFilter;
  PurchaseOrder? _selected;
  bool _showGrn = false;

  List<PurchaseOrder> _orders = [];
  bool   _loading = true;
  String? _error;
  Period _period = Period.defaultPeriod;

  @override
  void initState() {
    super.initState();
    // Stale-while-revalidate: show the last-known list immediately (if any)
    // instead of blanking to a spinner on every navigation — see
    // MachineService for the full reasoning.
    final cached = PurchaseOrderService.cachedDefaultList;
    if (cached != null) { _orders = cached; _loading = false; }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_orders.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final data = await PurchaseOrderService.instance.list(status: _statusFilter, period: _period);
      if (mounted) setState(() { _orders = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _newOrder() async {
    final created = await showDialog<PurchaseOrder>(context: context, builder: (_) => const _NewPurchaseOrderDialog());
    if (created == null || !mounted) return;
    showSuccessToast(context, 'Purchase order ${created.poNumber} created as a draft.');
    _load();
    _loadDetail(created.id);
  }

  Future<void> _loadDetail(int id) async {
    // Show a cached full record instantly (if we have one) rather than
    // leaving the panel on the list row's summary fields until the fetch
    // resolves.
    final cached = PurchaseOrderService.cachedById[id];
    if (cached != null && mounted) setState(() => _selected = cached);
    try {
      final full = await PurchaseOrderService.instance.get(id);
      if (mounted) setState(() => _selected = full);
    } catch (_) {}
  }

  Future<void> _doAction(Future<PurchaseOrder> Function() fn, String msg) async {
    try {
      final updated = await fn();
      if (mounted) { setState(() { _selected = updated; _showGrn = false; }); _load(); }
      if (mounted) showSuccessToast(context, msg);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  static Color _statusColor(String s) => switch (s) {
    'draft'                      => AppColors.textDim,
    'pending_sales_manager'      => AppColors.amber,
    'pending_director_review'    => AppColors.amber,
    'pending_payment_initiation' => AppColors.amber,
    'pending_director_final'     => AppColors.amber,
    'approved'                   => AppColors.violet,
    'rejected'                   => AppColors.coral,
    'sent'                       => AppColors.blue,
    'acknowledged'               => AppColors.violet,
    'partially_received'         => AppColors.amber,
    'received'                   => AppColors.teal,
    'cancelled'                  => AppColors.coral,
    _                            => AppColors.textDim,
  };

  @override
  Widget build(BuildContext context) {
    const statuses = ['draft', 'sent', 'acknowledged', 'partially_received', 'received', 'cancelled'];
    const sLabels  = ['Draft', 'Sent', 'Acknowledged', 'Partial GRN', 'Received', 'Cancelled'];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Header ──
      Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Purchase Orders', style: AppTheme.pageTitle),
            const SizedBox(height: 2),
            Text('Track orders to suppliers', style: AppTheme.bodySub),
          ]),
          const SizedBox(width: 20),
          Wrap(spacing: 6, children: [
            _StatusChip(label: 'All', active: _statusFilter == null,
                onTap: () { setState(() => _statusFilter = null); _load(); }),
            ...statuses.asMap().entries.map((e) => _StatusChip(
              label: sLabels[e.key], color: _statusColor(e.value),
              active: _statusFilter == e.value,
              onTap: () {
                setState(() => _statusFilter = _statusFilter == e.value ? null : e.value);
                _load();
              },
            )),
          ]),
          const Spacer(),
          PeriodSelector(value: _period, onChanged: (p) { setState(() => _period = p); _load(); }),
          const SizedBox(width: 8),
          AppButton(label: 'New Order', icon: Symbols.add, variant: BtnVariant.primary,
              onPressed: _newOrder),
        ]),
      ),
      Expanded(child: Stack(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // List
          Expanded(flex: 3, child: RefreshIndicator(
            onRefresh: _load,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
                child: Row(children: [
                  _Th('PO Number', flex: 2), _Th('Supplier', flex: 3),
                  _Th('Status', flex: 2), _Th('Total', flex: 2), _Th('Date', flex: 2),
                ]),
              ),
              Expanded(child: _loading
                ? shimmerTable(count: 8, cols: 5)
                : _error != null && _orders.isEmpty
                  ? ErrorView(message: _error!, onRetry: _load, compact: true)
                  : _orders.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Symbols.receipt_long, size: 36, color: context.pal.textDim),
                        const SizedBox(height: 10),
                        Text('No purchase orders', style: AppTheme.bodySub),
                      ]))
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) {
                          final po = _orders[i];
                          return _PORow(
                            po: po, selected: _selected?.id == po.id,
                            statusColor: _statusColor(po.status),
                            onTap: () {
                              setState(() => _selected = po);
                              _loadDetail(po.id);
                            },
                          );
                        },
                      )),
            ]),
          )),
          // Detail
          if (_selected != null) ...[
            Container(width: 1, color: context.pal.border),
            Expanded(flex: 2, child: _PODetailPanel(
              po: _selected!,
              statusColor: _statusColor(_selected!.status),
              onClose:  () => setState(() => _selected = null),
              onSubmitForApproval: () => _doAction(
                () => PurchaseOrderService.instance.submitForApproval(_selected!.id),
                'Submitted for approval'),
              onSend:   () => _doAction(
                () => PurchaseOrderService.instance.send(_selected!.id), 'PO sent to supplier'),
              onCancel: () => _doAction(
                () => PurchaseOrderService.instance.cancel(_selected!.id), 'PO cancelled'),
              onReceive: () => setState(() => _showGrn = true),
            )),
          ],
        ]),
        // GRN modal overlay
        if (_showGrn && _selected != null)
          _GrnModal(
            po: _selected!,
            onClose: () => setState(() => _showGrn = false),
            onReceived: (data) => _doAction(
              () => PurchaseOrderService.instance.receive(_selected!.id, data),
              'Goods received — stock updated'),
          ),
      ])),
    ]);
  }
}

// ── PO row ─────────────────────────────────────────────────────────────────────

class _PORow extends StatelessWidget {
  const _PORow({required this.po, required this.selected,
      required this.statusColor, required this.onTap});
  final PurchaseOrder po;
  final bool selected;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        color: selected ? context.pal.surface2 : Colors.transparent,
        border: Border(bottom: BorderSide(color: context.pal.divider)),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: Text(po.poNumber,
            style: AppTheme.monoXs.copyWith(color: AppColors.teal, fontSize: 12))),
        Expanded(flex: 3, child: Text(po.supplierName ?? '—',
            style: AppTheme.bodyStrong.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(po.statusLabel, style: AppTheme.monoXs.copyWith(
              color: statusColor, fontSize: 11), overflow: TextOverflow.ellipsis),
        ))),
        Expanded(flex: 2, child: Text('${po.currency} ${po.totalAmount.toStringAsFixed(0)}',
            style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
        Expanded(flex: 2, child: Text(formatDate(po.createdAt),
            style: AppTheme.bodySub.copyWith(fontSize: 12))),
      ]),
    ),
  );
}

// ── PO detail panel ────────────────────────────────────────────────────────────

class _PODetailPanel extends StatelessWidget {
  const _PODetailPanel({
    required this.po, required this.statusColor, required this.onClose,
    this.onSubmitForApproval, this.onSend, this.onCancel, this.onReceive,
  });
  final PurchaseOrder po;
  final Color statusColor;
  final VoidCallback onClose;
  final VoidCallback? onSubmitForApproval, onSend, onCancel, onReceive;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(po.poNumber,
            style: AppTheme.monoXs.copyWith(color: AppColors.teal, fontSize: 13))),
        GestureDetector(onTap: onClose,
            child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
      ]),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
        ),
        child: Text(po.statusLabel, style: AppTheme.bodyStrong.copyWith(
            color: statusColor, fontSize: 12.5)),
      ),
      const SizedBox(height: 14),
      if (po.supplierName != null) _Row('Supplier', po.supplierName!),
      _Row('Currency', po.currency),
      _Row('Total', '${po.currency} ${po.totalAmount.toStringAsFixed(2)}'),
      if (po.orderedByName != null) _Row('Ordered By', po.orderedByName!),
      if (po.expectedDeliveryDate != null)
        _Row('Expected', formatDate(po.expectedDeliveryDate!)),
      if (po.sentAt != null) _Row('Sent At', formatDate(po.sentAt!)),
      _Row('Created', formatDate(po.createdAt)),
      if (po.salesApprovedByName != null) _Row('Sales Approved By', po.salesApprovedByName!),
      if (po.directorReviewedByName != null) _Row('Director Reviewed By', po.directorReviewedByName!),
      if (po.paymentInitiatedByName != null) _Row('Payment Initiated By', po.paymentInitiatedByName!),
      if (po.directorApprovedByName != null) _Row('Final Approval By', po.directorApprovedByName!),
      if (po.rejectedByName != null) _Row('Rejected By', po.rejectedByName!),
      if (po.rejectionReason != null) _Row('Rejection Reason', po.rejectionReason!),
      if (po.notes != null) ...[
        const SizedBox(height: 10),
        Text(po.notes!, style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
      ],
      if (po.items.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Items (${po.items.length})', style: AppTheme.cardTitle.copyWith(fontSize: 12)),
        const SizedBox(height: 8),
        ...po.items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.itemName ?? '—',
                  style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
              Text('${item.currency} ${item.unitCost.toStringAsFixed(0)} each',
                  style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Text('Ordered: ', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
              Text('${item.quantityOrdered}', style: AppTheme.bodyStrong.copyWith(fontSize: 12)),
              const SizedBox(width: 12),
              Text('Received: ', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
              Text('${item.quantityReceived}',
                  style: AppTheme.bodyStrong.copyWith(
                      fontSize: 12,
                      color: item.isFullyReceived ? AppColors.teal : null)),
            ]),
          ]),
        )),
      ],
      const SizedBox(height: 20),
      // Action buttons
      if (po.status == 'draft') ...[
        _ActionBtn(label: 'Submit for Approval', color: AppColors.blue,
            icon: Symbols.send, onTap: onSubmitForApproval),
        const SizedBox(height: 8),
      ],
      if (const {
        'pending_sales_manager', 'pending_director_review',
        'pending_payment_initiation', 'pending_director_final',
      }.contains(po.status)) ...[
        Text('Review this order from the Approvals screen — the right stage owner needs to act on it there.',
            style: AppTheme.bodySub.copyWith(fontSize: 11.5, fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
      ],
      if (po.status == 'approved')
        _ActionBtn(label: 'Send to Supplier', color: AppColors.blue,
            icon: Symbols.send, onTap: onSend),
      if (['sent', 'acknowledged', 'partially_received'].contains(po.status)) ...[
        _ActionBtn(label: 'Receive Goods (GRN)', color: AppColors.teal,
            icon: Symbols.move_to_inbox, onTap: onReceive),
        const SizedBox(height: 8),
      ],
      if (!['received', 'cancelled'].contains(po.status)) ...[
        const SizedBox(height: 4),
        _ActionBtn(label: 'Cancel Order', color: AppColors.coral,
            icon: Symbols.cancel, onTap: onCancel),
      ],
    ]),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12))),
      Expanded(child: Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.color, required this.icon, this.onTap});
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(label, style: AppTheme.bodyStrong.copyWith(color: color, fontSize: 13)),
        ]),
      ),
    ),
  );
}

// ── GRN modal ─────────────────────────────────────────────────────────────────

class _GrnModal extends StatefulWidget {
  const _GrnModal({required this.po, required this.onClose, required this.onReceived});
  final PurchaseOrder po;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onReceived;

  @override
  State<_GrnModal> createState() => _GrnModalState();
}

class _GrnModalState extends State<_GrnModal> {
  late final List<TextEditingController> _qtyCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = widget.po.items.map((item) =>
      TextEditingController(text: '${item.quantityOrdered - item.quantityReceived}')
    ).toList();
  }

  @override
  void dispose() {
    for (final c in _qtyCtrl) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; });
    try {
      final items = widget.po.items.asMap().entries.map((e) => {
        'purchase_order_item_id': e.value.id,
        'quantity_received': int.tryParse(_qtyCtrl[e.key].text) ?? 0,
      }).where((i) => (i['quantity_received'] as int) > 0).toList();

      if (items.isEmpty) {
        setState(() { _saving = false; _error = 'Enter at least one received quantity.'; });
        return;
      }

      widget.onReceived({'items': items});
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyError(e); });
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A), alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 500,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: BoxDecoration(
            color: context.pal.surface1, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Icon(Symbols.move_to_inbox, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text('Goods Received — ${widget.po.poNumber}',
                    style: AppTheme.bodyStrong, overflow: TextOverflow.ellipsis)),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(children: [
                ...widget.po.items.asMap().entries.map((e) {
                  final item = e.value;
                  final remaining = item.quantityOrdered - item.quantityReceived;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.pal.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.itemName ?? '—', style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
                        Text('Ordered: ${item.quantityOrdered}  ·  '
                            'Already received: ${item.quantityReceived}  ·  '
                            'Remaining: $remaining',
                            style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                      ])),
                      const SizedBox(width: 12),
                      SizedBox(width: 80, child: CellField(controller: _qtyCtrl[e.key], hint: 'Qty', keyboardType: TextInputType.number)),
                    ]),
                  );
                }),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
                ],
              ]),
            )),
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
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Confirm Receipt', style: AppTheme.bodyStrong.copyWith(
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

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active, required this.onTap, this.color});
  final String label;
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
      child: Text(label, style: AppTheme.bodySm.copyWith(
          color: active ? (color ?? AppColors.teal) : context.pal.textMute, fontSize: 12)),
    ),
  );
}

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

// ── New purchase order ────────────────────────────────────────────────────────
// Supplier + receiving location + lines (catalogue item, qty, unit cost).
// Saved as a draft; the approval chain starts from the PO detail panel.

class _PoLine {
  InventoryItem? item;
  final qty = TextEditingController(text: '1');
  final cost = TextEditingController();
  int get quantity => int.tryParse(qty.text.trim()) ?? 0;
  int get unitCost => int.tryParse(cost.text.replaceAll(',', '').trim()) ?? 0;
  void dispose() { qty.dispose(); cost.dispose(); }
}

class _NewPurchaseOrderDialog extends StatefulWidget {
  const _NewPurchaseOrderDialog();
  @override
  State<_NewPurchaseOrderDialog> createState() => _NewPurchaseOrderDialogState();
}

class _NewPurchaseOrderDialogState extends State<_NewPurchaseOrderDialog> {
  List<Supplier> _suppliers = SupplierService.cachedDefaultList ?? [];
  List<Location> _locations = LocationService.cachedDefaultList ?? [];
  List<InventoryItem> _items = InventoryService.cachedDefaultList ?? [];
  int? _supplierId;
  int? _locationId;
  DateTime? _expected;
  String _currency = 'TZS';
  final _notes = TextEditingController();
  final List<_PoLine> _lines = [_PoLine()];
  bool _loading = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    try {
      final r = await Future.wait([
        SupplierService.instance.list(),
        LocationService.instance.list(),
        InventoryService.instance.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _suppliers = r[0] as List<Supplier>;
        _locations = r[1] as List<Location>;
        _items = r[2] as List<InventoryItem>;
        _locationId ??= _locations.isNotEmpty ? _locations.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  int get _total => _lines.fold(0, (s, l) => s + l.quantity * l.unitCost);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _expected ?? now.add(const Duration(days: 14)),
        firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 730)));
    if (d != null) setState(() => _expected = d);
  }

  Future<void> _save() async {
    final lines = _lines.where((l) => l.item != null).toList();
    final problem = _supplierId == null ? 'Choose a supplier.'
        : _locationId == null ? 'Choose where the goods will be received.'
        : lines.isEmpty ? 'Add at least one item.'
        : lines.any((l) => l.quantity < 1) ? 'Every line needs a quantity of at least 1.'
        : null;
    if (problem != null) { setState(() => _error = problem); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final po = await PurchaseOrderService.instance.create({
        'supplier_id': _supplierId,
        'location_id': _locationId,
        'currency': _currency,
        if (_expected != null) 'expected_delivery_date': _expected!.toIso8601String().substring(0, 10),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'items': [
          for (final l in lines)
            {'inventory_item_id': l.item!.id, 'quantity_ordered': l.quantity, 'unit_cost': l.unitCost, 'currency': _currency},
        ],
      });
      if (mounted) Navigator.pop(context, po);
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
    }
  }

  Widget _lineRow(_PoLine l, int i) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(flex: 5, child: AppSearchableSelectField<int>(
        label: i == 0 ? 'Item' : null,
        hint: 'Search catalogue…',
        selectedLabel: l.item == null ? null : '${l.item!.sku} · ${l.item!.name}',
        items: [for (final it in _items) AppSelectItem(value: it.id, label: '${it.sku} · ${it.name}')],
        onSelected: (sel) => setState(() {
          l.item = sel == null ? null : _items.firstWhere((it) => it.id == sel.value);
          if (l.item != null && l.cost.text.trim().isEmpty && l.item!.unitCost > 0) {
            l.cost.text = l.item!.unitCost.round().toString();
          }
        }),
      )),
      const SizedBox(width: 10),
      SizedBox(width: 90, child: LabeledTextField(label: i == 0 ? 'Qty' : '', controller: l.qty,
          keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
      const SizedBox(width: 10),
      SizedBox(width: 140, child: LabeledTextField(label: i == 0 ? 'Unit cost ($_currency)' : '', controller: l.cost,
          keyboardType: TextInputType.number, hint: '0', onChanged: (_) => setState(() {}))),
      const SizedBox(width: 6),
      SizedBox(width: 32, height: kFieldHeight, child: _lines.length > 1
          ? IconButton(
              tooltip: 'Remove line',
              icon: Icon(Symbols.close, size: 16, color: context.pal.textDim),
              onPressed: () => setState(() { _lines.removeAt(i).dispose(); }),
            )
          : null),
    ]),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: _loading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Symbols.shopping_cart, size: 18, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(child: Text('New purchase order', style: AppTheme.bodyStrong)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
                ]),
                Text('Saved as a draft — send it for approval from the order panel.', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: AppSearchableSelectField<int>(
                      label: 'Supplier',
                      hint: 'Search suppliers…',
                      selectedLabel: _supplierId == null ? null : _suppliers.firstWhere((s) => s.id == _supplierId).name,
                      items: [for (final s in _suppliers) AppSelectItem(value: s.id, label: s.name)],
                      onSelected: (sel) => setState(() => _supplierId = sel?.value),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: LabeledDropdown<int?>(
                      label: 'Receive at',
                      value: _locationId,
                      items: [null, for (final l in _locations) l.id],
                      displayBuilder: (id) => id == null ? 'Choose location' : _locations.firstWhere((l) => l.id == id).name,
                      onChanged: (v) => setState(() => _locationId = v),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: LabeledDateField(label: 'Expected delivery (optional)', date: _expected, onTap: _pickDate,
                        onClear: () => setState(() => _expected = null))),
                    const SizedBox(width: 12),
                    SizedBox(width: 160, child: LabeledDropdown<String>(
                      label: 'Currency', value: _currency, items: const ['TZS', 'USD', 'EUR'],
                      displayBuilder: (c) => c, onChanged: (v) => setState(() => _currency = v),
                    )),
                  ]),
                  const SizedBox(height: 18),
                  Text('ITEMS', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _lines.length; i++) _lineRow(_lines[i], i),
                  Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_PoLine())),
                    icon: const Icon(Symbols.add, size: 16), label: const Text('Add item'),
                  )),
                  const SizedBox(height: 8),
                  LabeledTextField(label: 'Notes (optional)', controller: _notes, maxLines: 3),
                ]))),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  Text('Total  ', style: AppTheme.bodySub),
                  Text('$_currency ${_total.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
                      style: AppTheme.monoSm.copyWith(fontSize: 15, color: context.pal.text)),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create draft'),
                  ),
                ]),
              ]),
      ),
    ),
  );
}
