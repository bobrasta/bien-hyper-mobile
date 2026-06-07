import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/invoice.dart';
import '../../services/invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Color _statusColor(PaymentStatus s) => switch (s) {
  PaymentStatus.pending   => AppColors.textDim,
  PaymentStatus.sent      => AppColors.blue,
  PaymentStatus.partial   => AppColors.amber,
  PaymentStatus.paid      => AppColors.teal,
  PaymentStatus.overdue   => AppColors.coral,
  PaymentStatus.waived    => AppColors.violet,
  PaymentStatus.cancelled => AppColors.coral,
};

String _fmt(int tzs) {
  if (tzs >= 1000000) return 'TSh ${(tzs / 1e6).toStringAsFixed(1)}M';
  if (tzs >= 1000)    return 'TSh ${(tzs / 1000).toStringAsFixed(0)}K';
  return 'TSh $tzs';
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Invoice> _all      = [];
  List<Invoice> _filtered = [];
  Invoice?      _selected;
  bool          _loading  = true;
  String?       _error;
  PaymentStatus? _statusFilter;
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
      final data = await InvoiceService.instance.list();
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
      _filtered = _all.where((inv) {
        final matchStatus = _statusFilter == null || inv.status == _statusFilter;
        final matchSearch = q.isEmpty ||
            inv.invoiceNumber.toLowerCase().contains(q) ||
            (inv.displayName).toLowerCase().contains(q);
        return matchStatus && matchSearch;
      }).toList();
      if (_selected != null && !_filtered.any((inv) => inv.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  Future<void> _doAction(Future<Invoice> Function() action) async {
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

  Future<void> _showPaymentModal(Invoice inv) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PaymentModal(invoice: inv, onSaved: () {
        _load();
        setState(() => _selected = null);
      }),
    );
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
            Text('Invoices', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('${_filtered.length} invoice${_filtered.length == 1 ? '' : 's'}',
                style: AppTheme.bodySub),
          ]);
          final searchBox = SizedBox(
            width: 220, height: 36,
            child: TextField(
              controller: _searchCtrl,
              style: AppTheme.bodySm,
              decoration: InputDecoration(
                hintText: 'Search client / INV number…',
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
          );
          if (narrow) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleBlock, const SizedBox(height: 12), searchBox]);
          }
          return Row(children: [titleBlock, const Spacer(), searchBox]);
        }),
      ),

      // ── Status chips ──
      _StatusChips(
        current: _statusFilter,
        onChanged: (s) => setState(() { _statusFilter = s; _applyFilter(); }),
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
                  width: 440,
                  child: _InvoiceTable(
                    items: _filtered,
                    selected: _selected,
                    onSelect: (inv) async {
                      if (inv.lineItems.isEmpty || inv.payments.isEmpty) {
                        final full = await InvoiceService.instance.get(inv.id);
                        if (!mounted) return;
                        setState(() => _selected = full);
                      } else {
                        setState(() => _selected = inv);
                      }
                    },
                  ),
                )
              else
                Expanded(
                  child: _InvoiceTable(
                    items: _filtered,
                    selected: null,
                    onSelect: (inv) async {
                      if (inv.lineItems.isEmpty || inv.payments.isEmpty) {
                        final full = await InvoiceService.instance.get(inv.id);
                        if (!mounted) return;
                        setState(() => _selected = full);
                      } else {
                        setState(() => _selected = inv);
                      }
                    },
                  ),
                ),
              if (_selected != null) ...[
                VerticalDivider(width: 1, color: context.pal.border),
                Expanded(child: _DetailPanel(
                  inv: _selected!,
                  onClose:  () => setState(() => _selected = null),
                  onSend:   () => _doAction(() => InvoiceService.instance.send(_selected!.id)),
                  onCancel: () => _doAction(() => InvoiceService.instance.cancel(_selected!.id)),
                  onPay:    () => _showPaymentModal(_selected!),
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
  final PaymentStatus? current;
  final ValueChanged<PaymentStatus?> onChanged;

  static const _statuses = [
    (PaymentStatus.pending,   'Pending'),
    (PaymentStatus.sent,      'Sent'),
    (PaymentStatus.partial,   'Partial'),
    (PaymentStatus.paid,      'Paid'),
    (PaymentStatus.overdue,   'Overdue'),
    (PaymentStatus.cancelled, 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      children: [
        _chip(context, null, 'All'),
        ..._statuses.map((s) => _chip(context, s.$1, s.$2)),
      ],
    ),
  );

  Widget _chip(BuildContext ctx, PaymentStatus? value, String label) {
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
          border: Border.all(color: active
              ? (value == null ? ctx.pal.borderStrong : _statusColor(value))
              : ctx.pal.border),
        ),
        child: Text(label, style: AppTheme.bodySm.copyWith(
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

// ── Invoice table ──────────────────────────────────────────────────────────────

class _InvoiceTable extends StatelessWidget {
  const _InvoiceTable({required this.items, required this.selected, required this.onSelect});
  final List<Invoice>  items;
  final Invoice?       selected;
  final ValueChanged<Invoice> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('No invoices found', style: AppTheme.bodySub));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.border),
      itemBuilder: (_, i) {
        if (i == 0) return _header(context);
        final inv = items[i - 1];
        final isActive = selected?.id == inv.id;
        return GestureDetector(
          onTap: () => onSelect(inv),
          child: Container(
            color: isActive ? context.pal.surface2 : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              SizedBox(width: 140, child: Text(inv.invoiceNumber,
                  style: AppTheme.monoXs.copyWith(fontSize: 12, color: context.pal.textDim))),
              Expanded(child: Text(inv.displayName,
                  style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
              SizedBox(width: 110, child: Text(_fmt(inv.total),
                  style: AppTheme.bodySm.copyWith(color: AppColors.amber))),
              SizedBox(width: 90,  child: Text(_fmt(inv.balanceDue),
                  style: AppTheme.bodySm.copyWith(
                    color: inv.balanceDue > 0 ? AppColors.coral : AppColors.teal,
                    fontWeight: FontWeight.w600,
                  ))),
              SizedBox(width: 110, child: _StatusBadge(inv.status)),
              SizedBox(width: 90,  child: Text(inv.dueDate.length >= 10 ? inv.dueDate.substring(0, 10) : inv.dueDate,
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
    child: Row(children: [
      SizedBox(width: 140, child: Text('INV NUMBER', style: AppTheme.labelCaps)),
      const Expanded(child: Text('CLIENT',    style: _hStyle)),
      SizedBox(width: 110,  child: Text('TOTAL',    style: AppTheme.labelCaps)),
      SizedBox(width: 90,   child: Text('BALANCE',  style: AppTheme.labelCaps)),
      SizedBox(width: 110,  child: Text('STATUS',   style: AppTheme.labelCaps)),
      SizedBox(width: 90,   child: Text('DUE DATE', style: AppTheme.labelCaps)),
    ]),
  );
}

const _hStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.08);

// ── Status badge ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final PaymentStatus status;
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Detail panel ───────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.inv,
    required this.onClose,
    required this.onSend,
    required this.onCancel,
    required this.onPay,
  });
  final Invoice      inv;
  final VoidCallback onClose;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Expanded(child: Text(inv.invoiceNumber,
              style: AppTheme.pageTitle.copyWith(fontSize: 18))),
          GestureDetector(onTap: onClose,
              child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
        ]),
        const SizedBox(height: 4),
        _StatusBadge(inv.status),
        const SizedBox(height: 20),

        // Client / SO info
        _row('Client', inv.displayName),
        if (inv.salesOrderNumber != null) _row('Sales Order', inv.salesOrderNumber!),
        if (inv.clientContact != null)    _row('Contact', inv.clientContact!),
        if (inv.clientEmail != null)      _row('Email', inv.clientEmail!),
        _row('Issue Date', inv.issueDate.length >= 10 ? inv.issueDate.substring(0, 10) : inv.issueDate),
        _row('Due Date',   inv.dueDate.length >= 10   ? inv.dueDate.substring(0, 10)   : inv.dueDate),
        _row('Currency',   inv.currency),
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
            _fin('Subtotal', inv.subtotal, context),
            if (inv.taxAmount > 0) _fin('Tax', inv.taxAmount, context),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: AppTheme.bodyStrong),
              Text(_fmt(inv.total),
                  style: AppTheme.bodyStrong.copyWith(color: AppColors.amber, fontSize: 15)),
            ]),
            if (inv.amountPaid > 0) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Paid', style: AppTheme.bodySub),
                Text(_fmt(inv.amountPaid),
                    style: AppTheme.bodySub.copyWith(color: AppColors.teal)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Balance Due', style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
                Text(_fmt(inv.balanceDue),
                    style: AppTheme.bodyStrong.copyWith(
                      color: inv.balanceDue > 0 ? AppColors.coral : AppColors.teal,
                      fontSize: 13,
                    )),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 20),

        // Line items
        Text('Line Items', style: AppTheme.bodyStrong),
        const SizedBox(height: 8),
        if (inv.lineItems.isEmpty)
          Text('Load detail to view items', style: AppTheme.bodySub)
        else
          ...inv.lineItems.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.pal.surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.pal.border),
            ),
            child: Row(children: [
              Expanded(child: Text(item.description,
                  style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500))),
              Text('${item.quantity.toStringAsFixed(item.quantity == item.quantity.truncate() ? 0 : 1)}'
                   ' × ${_fmt(item.unitPrice)}',
                  style: AppTheme.bodySub.copyWith(fontSize: 11)),
              const SizedBox(width: 12),
              Text(_fmt(item.total),
                  style: AppTheme.bodySm.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600)),
            ]),
          )),

        // Payment history
        if (inv.payments.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Payment History', style: AppTheme.bodyStrong),
          const SizedBox(height: 8),
          ...inv.payments.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.pal.surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.pal.border),
            ),
            child: Row(children: [
              Icon(Symbols.payments, size: 14, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.paymentNumber,
                    style: AppTheme.monoXs.copyWith(color: context.pal.textDim, fontSize: 11)),
                Text('${p.methodLabel}${p.reference != null ? ' · ${p.reference}' : ''}',
                    style: AppTheme.bodySub.copyWith(fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmt(p.amount),
                    style: AppTheme.bodySm.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                Text(p.paidAt.length >= 10 ? p.paidAt.substring(0, 10) : p.paidAt,
                    style: AppTheme.bodySub.copyWith(fontSize: 10)),
              ]),
            ]),
          )),
        ],

        if (inv.notes != null) ...[
          const SizedBox(height: 16),
          Text('Notes', style: AppTheme.bodyStrong),
          const SizedBox(height: 4),
          Text(inv.notes!, style: AppTheme.bodySub),
        ],

        const SizedBox(height: 24),

        // Actions
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (inv.canSend)
            AppButton(label: 'Send Invoice', icon: Symbols.send,
                variant: BtnVariant.primary, onPressed: onSend),
          if (inv.canPay)
            AppButton(label: 'Record Payment', icon: Symbols.payments,
                variant: BtnVariant.primary, onPressed: onPay),
          if (inv.canCancel)
            AppButton(label: 'Cancel', icon: Symbols.cancel,
                variant: BtnVariant.ghost, onPressed: onCancel),
        ]),
      ]),
    );
  }
}

Widget _row(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 110, child: Text(label, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textDim))),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
  ]),
);

Widget _fin(String label, int amount, BuildContext ctx) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: AppTheme.bodySub),
    Text(_fmt(amount), style: AppTheme.bodySub),
  ]),
);

// ── Record Payment modal ───────────────────────────────────────────────────────

class _PaymentModal extends StatefulWidget {
  const _PaymentModal({required this.invoice, required this.onSaved});
  final Invoice      invoice;
  final VoidCallback onSaved;
  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  final _amtCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _datCtrl = TextEditingController();
  final _noteCtrl= TextEditingController();
  String _method = 'cash';
  bool   _saving = false;

  @override
  void initState() {
    super.initState();
    _amtCtrl.text = widget.invoice.balanceDue.toString();
    _datCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _amtCtrl.dispose(); _refCtrl.dispose();
    _datCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0 || _saving) return;
    setState(() => _saving = true);
    try {
      await InvoiceService.instance.recordPayment(widget.invoice.id, {
        'amount':         amount,
        'payment_method': _method,
        'reference':      _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
        'paid_at':        _datCtrl.text.trim(),
        'notes':          _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
      });
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).pop(),
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
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                const Icon(Symbols.payments, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text('Record Payment — ${widget.invoice.invoiceNumber}',
                    style: AppTheme.bodyStrong)),
                GestureDetector(onTap: () => Navigator.of(context).pop(),
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Balance due: ${_fmt(widget.invoice.balanceDue)}',
                  style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 12)),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _field('Amount *', _amtCtrl, context, numeric: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Date *', _datCtrl, context, hint: 'YYYY-MM-DD')),
                ]),
                const SizedBox(height: 12),
                _label('Payment Method'),
                const SizedBox(height: 5),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.pal.surface2,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                    value: _method, isExpanded: true,
                    dropdownColor: context.pal.surface2,
                    style: AppTheme.bodySm,
                    icon: Icon(Symbols.expand_more, size: 14, color: context.pal.textDim),
                    items: const [
                      DropdownMenuItem(value: 'cash',          child: Text('Cash')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'mobile_money',  child: Text('Mobile Money')),
                      DropdownMenuItem(value: 'cheque',        child: Text('Cheque')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _method = v); },
                  )),
                ),
                const SizedBox(height: 12),
                _field('Reference / Transaction ID', _refCtrl, context,
                    hint: 'Cheque no., M-Pesa ref…'),
                const SizedBox(height: 12),
                _field('Notes', _noteCtrl, context, maxLines: 2),
              ]),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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
                      : Text('Save Payment', style: AppTheme.bodyStrong.copyWith(
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

Widget _label(String text) =>
    Text(text.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10));

Widget _field(String label, TextEditingController ctrl, BuildContext ctx,
    {String? hint, int maxLines = 1, bool numeric = false}) =>
  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _label(label),
    const SizedBox(height: 5),
    Container(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? 56 : 36),
      decoration: BoxDecoration(
        color: ctx.pal.surface2,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ctx.pal.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: TextField(
        controller: ctrl, maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: AppTheme.bodySm,
        decoration: InputDecoration(
          hintText: hint, border: InputBorder.none, isDense: true,
          contentPadding: EdgeInsets.zero,
          hintStyle: AppTheme.bodySm.copyWith(color: ctx.pal.textDim),
        ),
      ),
    ),
  ]);
