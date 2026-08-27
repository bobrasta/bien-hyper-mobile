import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/invoice.dart';
import '../../services/invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/shimmer_box.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Invoice> _invoices = [];
  bool    _loading = true;
  String? _error;
  String  _period  = 'all';
  String  _search  = '';
  final   _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
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
      if (mounted) setState(() { _invoices = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Invoice> get _filtered {
    final now = DateTime.now();
    DateTime? since;
    if (_period == 'month')   since = DateTime(now.year, now.month, 1);
    if (_period == 'quarter') since = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
    if (_period == 'year')    since = DateTime(now.year, 1, 1);

    var list = _invoices;
    if (since != null) {
      list = list.where((inv) {
        final d = DateTime.tryParse(inv.issueDate);
        return d != null && d.isAfter(since!.subtract(const Duration(days: 1)));
      }).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((inv) =>
          inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.displayName.toLowerCase().contains(q) ||
          (inv.salesOrderNumber?.toLowerCase().contains(q) ?? false)).toList();
    }
    return [...list]..sort((a, b) => b.issueDate.compareTo(a.issueDate));
  }

  int get _totalRevenue     => _filtered.fold(0, (s, i) => s + i.total);
  int get _totalCollected   => _filtered.fold(0, (s, i) => s + i.amountPaid);
  int get _totalOutstanding => _filtered.fold(0, (s, i) => s + i.balanceDue);
  int get _overdueCount     => _filtered.where((i) => i.status == PaymentStatus.overdue).length;

  void _openDetail(Invoice inv) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _InvoiceDetailDialog(inv: inv),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Column(children: [
      // ── Top bar ───────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          border: Border(bottom: BorderSide(color: context.pal.border)),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Symbols.history, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Text('Sales History', style: AppTheme.pageTitle.copyWith(fontSize: 16)),
            ]),
            const SizedBox(height: 2),
            Text(
              _loading ? 'Loading…' : '${items.length} invoice${items.length == 1 ? '' : 's'}',
              style: AppTheme.bodySub,
            ),
          ]),
          const Spacer(),

          // Period chips
          ...[
            ('all', 'All Time'),
            ('year', 'This Year'),
            ('quarter', 'This Quarter'),
            ('month', 'This Month'),
          ].map((p) => _PeriodChip(
                label: p.$2,
                active: _period == p.$1,
                onTap: () => setState(() => _period = p.$1),
              )),

          const SizedBox(width: 16),

          // Search
          Container(
            height: 34,
            width: 220,
            decoration: BoxDecoration(
              color: context.pal.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.pal.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Icon(Symbols.search, size: 14, color: context.pal.textDim),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Invoice, client, order…',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: AppTheme.bodySub.copyWith(fontSize: 12),
                  ),
                ),
              ),
              if (_search.isNotEmpty)
                GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                  child: Icon(Symbols.close, size: 13, color: context.pal.textDim),
                ),
            ]),
          ),
        ]),
      ),

      // ── KPI cards ─────────────────────────────────────────────────────────
      if (!_loading && _error == null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: context.pal.bg,
            border: Border(bottom: BorderSide(color: context.pal.border)),
          ),
          child: Row(children: [
            _KpiCard(
              icon: Symbols.payments,
              label: 'Total Revenue',
              value: tshFromDouble(_totalRevenue),
              color: AppColors.teal,
            ),
            const SizedBox(width: 12),
            _KpiCard(
              icon: Symbols.check_circle,
              label: 'Collected',
              value: tshFromDouble(_totalCollected),
              color: AppColors.green,
            ),
            const SizedBox(width: 12),
            _KpiCard(
              icon: Symbols.pending,
              label: 'Outstanding',
              value: tshFromDouble(_totalOutstanding),
              color: _totalOutstanding > 0 ? AppColors.amber : AppColors.textDim,
            ),
            const SizedBox(width: 12),
            _KpiCard(
              icon: Symbols.receipt_long,
              label: 'Invoices',
              value: '${items.length}',
              color: AppColors.violet,
            ),
            const SizedBox(width: 12),
            _KpiCard(
              icon: Symbols.warning,
              label: 'Overdue',
              value: '$_overdueCount',
              color: _overdueCount > 0 ? AppColors.coral : AppColors.textDim,
              highlight: _overdueCount > 0,
            ),
          ]),
        ),

      // ── Table header ──────────────────────────────────────────────────────
      if (!_loading && _error == null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            border: Border(bottom: BorderSide(color: context.pal.border)),
          ),
          child: Row(children: [
            const SizedBox(width: 4),
            SizedBox(width: 130, child: Text('INVOICE',   style: AppTheme.labelCaps)),
            Expanded(flex: 3, child: Text('CLIENT',     style: AppTheme.labelCaps)),
            Expanded(flex: 2, child: Text('ORDER',      style: AppTheme.labelCaps)),
            SizedBox(width: 110, child: Text('TOTAL',   style: AppTheme.labelCaps)),
            SizedBox(width: 100, child: Text('COLLECTED', style: AppTheme.labelCaps)),
            SizedBox(width: 90,  child: Text('BALANCE',  style: AppTheme.labelCaps)),
            SizedBox(width: 80,  child: Text('STATUS',   style: AppTheme.labelCaps)),
            SizedBox(width: 86,  child: Text('DATE',     style: AppTheme.labelCaps)),
          ]),
        ),

      // ── List ──────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: shimmerTable(count: 10, cols: 7))
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : items.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Symbols.history, size: 48,
                              color: context.pal.textDim),
                          const SizedBox(height: 12),
                          Text('No sales records found',
                              style: AppTheme.bodyStrong
                                  .copyWith(color: context.pal.textMute)),
                          const SizedBox(height: 4),
                          Text(
                            _search.isNotEmpty
                                ? 'Try a different search term'
                                : 'Completed invoices will appear here',
                            style: AppTheme.bodySub,
                          ),
                        ]),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) => _HistoryRow(
                          inv: items[i],
                          onTap: () => _openDetail(items[i]),
                        ),
                      ),
      ),
    ]);
  }
}

// ── Period chip ────────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.teal : Colors.transparent,
            border: Border.all(
              color: active ? AppColors.teal : context.pal.border,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: AppTheme.bodySm.copyWith(
                color: active
                    ? const Color(0xFF06120F)
                    : context.pal.textMute,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
      );
}

// ── KPI card ───────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });
  final IconData icon;
  final String label, value;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: highlight
                ? color.withValues(alpha: 0.08)
                : context.pal.surface1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: highlight ? color.withValues(alpha: 0.3) : context.pal.border,
            ),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: AppTheme.labelCaps.copyWith(fontSize: 9.5),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTheme.bodyStrong.copyWith(
                        color: color, fontSize: 13.5),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      );
}

// ── History row ────────────────────────────────────────────────────────────────

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({required this.inv, required this.onTap});
  final Invoice inv;
  final VoidCallback onTap;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hovered = false;

  Color _statusColor() => switch (widget.inv.status) {
    PaymentStatus.paid      => AppColors.green,
    PaymentStatus.partial   => AppColors.amber,
    PaymentStatus.overdue   => AppColors.coral,
    PaymentStatus.cancelled => AppColors.textDim,
    PaymentStatus.sent      => AppColors.teal,
    _                       => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    final inv         = widget.inv;
    final statusColor = _statusColor();
    final hasBalance  = inv.balanceDue > 0;
    final isOverdue   = inv.status == PaymentStatus.overdue;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? context.pal.surface2
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isOverdue ? AppColors.coral : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(color: context.pal.divider, width: 0.5),
            ),
          ),
          child: Row(children: [
            // Overdue dot indicator
            SizedBox(
              width: 4,
              child: isOverdue
                  ? Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        shape: BoxShape.circle,
                      ))
                  : null,
            ),

            // Invoice number
            SizedBox(
              width: 130,
              child: Text(inv.invoiceNumber,
                  style: AppTheme.monoXs.copyWith(
                      color: AppColors.teal, fontSize: 11.5)),
            ),

            // Client
            Expanded(flex: 3, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv.displayName,
                  style: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis),
              if (inv.clientContact != null)
                Text(inv.clientContact!,
                    style: AppTheme.bodySub.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
            ])),

            // Order
            Expanded(flex: 2, child: Text(
                inv.salesOrderNumber ?? '—',
                style: inv.salesOrderNumber != null
                    ? AppTheme.monoXs.copyWith(
                        color: context.pal.textMute, fontSize: 11)
                    : AppTheme.bodySub.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis)),

            // Total
            SizedBox(width: 110, child: Text(tshFromDouble(inv.total),
                style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),

            // Collected
            SizedBox(
              width: 100,
              child: Text(
                inv.amountPaid > 0 ? tshFromDouble(inv.amountPaid) : '—',
                style: AppTheme.bodySm.copyWith(
                    color: inv.amountPaid > 0
                        ? AppColors.green
                        : context.pal.textDim,
                    fontSize: 12),
              ),
            ),

            // Balance
            SizedBox(
              width: 90,
              child: Text(
                hasBalance ? tshFromDouble(inv.balanceDue) : '—',
                style: AppTheme.bodySm.copyWith(
                    color: hasBalance ? AppColors.amber : context.pal.textDim,
                    fontSize: 12),
              ),
            ),

            // Status badge
            SizedBox(
              width: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(inv.status.label,
                    style: AppTheme.monoXs.copyWith(
                        color: statusColor, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
            ),

            // Date
            SizedBox(
              width: 86,
              child: Text(_fmtDate(inv.issueDate),
                  style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
            ),
          ]),
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d != null ? formatDate(d) : iso;
  }
}

// ── Invoice detail dialog ──────────────────────────────────────────────────────

class _InvoiceDetailDialog extends StatelessWidget {
  const _InvoiceDetailDialog({required this.inv});
  final Invoice inv;

  Color _statusColor() => switch (inv.status) {
    PaymentStatus.paid      => AppColors.green,
    PaymentStatus.partial   => AppColors.amber,
    PaymentStatus.overdue   => AppColors.coral,
    PaymentStatus.cancelled => AppColors.textDim,
    PaymentStatus.sent      => AppColors.teal,
    _                       => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final collectedPct = inv.total > 0
        ? (inv.amountPaid / inv.total).clamp(0.0, 1.0)
        : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 520,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.pal.borderStrong),
          boxShadow: const [
            BoxShadow(
                color: Color(0x55000000), blurRadius: 60, offset: Offset(0, 20))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              Icon(Symbols.receipt_long, size: 18, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv.invoiceNumber,
                    style: AppTheme.pageTitle.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(inv.status.label,
                      style: AppTheme.monoXs.copyWith(
                          color: statusColor, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: context.pal.surface2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Symbols.close, size: 15, color: context.pal.textDim),
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: context.pal.border),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Collection progress bar
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.pal.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('TOTAL AMOUNT', style: AppTheme.labelCaps),
                        const SizedBox(height: 2),
                        Text(tshFromDouble(inv.total),
                            style: AppTheme.bodyStrong.copyWith(
                                fontSize: 18, color: AppColors.amber)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        Text('COLLECTED', style: AppTheme.labelCaps),
                        const SizedBox(height: 2),
                        Text(tshFromDouble(inv.amountPaid),
                            style: AppTheme.bodyStrong.copyWith(
                                fontSize: 15, color: AppColors.green)),
                      ]),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: collectedPct,
                        minHeight: 6,
                        backgroundColor: context.pal.surface3,
                        valueColor: AlwaysStoppedAnimation(
                          collectedPct >= 1.0 ? AppColors.green : AppColors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      Text('${(collectedPct * 100).toStringAsFixed(0)}% collected',
                          style: AppTheme.bodySub.copyWith(fontSize: 11)),
                      if (inv.balanceDue > 0)
                        Text('${tshFromDouble(inv.balanceDue)} remaining',
                            style: AppTheme.bodySub.copyWith(
                                fontSize: 11, color: AppColors.amber)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // Info grid
                Wrap(children: [
                  _infoTile(context, 'Client', inv.displayName),
                  if (inv.clientContact != null)
                    _infoTile(context, 'Contact', inv.clientContact!),
                  if (inv.clientEmail != null)
                    _infoTile(context, 'Email', inv.clientEmail!),
                  _infoTile(context, 'Issue Date', _fmtDate2(inv.issueDate)),
                  _infoTile(context, 'Due Date', _fmtDate2(inv.dueDate)),
                  if (inv.salesOrderNumber != null)
                    _infoTile(context, 'Sales Order', inv.salesOrderNumber!),
                ]),
                const SizedBox(height: 8),

                // Line items
                if (inv.lineItems.isNotEmpty) ...[
                  Text('Line Items', style: AppTheme.bodyStrong),
                  const SizedBox(height: 8),
                  ...inv.lineItems.map((li) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.pal.surface2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.pal.border),
                        ),
                        child: Row(children: [
                          Expanded(
                              child: Text(li.description,
                                  style: AppTheme.bodySm.copyWith(
                                      fontWeight: FontWeight.w500))),
                          const SizedBox(width: 8),
                          Text('${li.quantity.toStringAsFixed(li.quantity == li.quantity.toInt() ? 0 : 1)} × ${tshFromDouble(li.unitPrice)}',
                              style: AppTheme.bodySub.copyWith(fontSize: 11)),
                          const SizedBox(width: 12),
                          Text(tshFromDouble(li.total),
                              style: AppTheme.bodySm.copyWith(
                                  color: AppColors.amber,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      )),
                ],

                // Payment history
                if (inv.payments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Payments', style: AppTheme.bodyStrong),
                  const SizedBox(height: 8),
                  ...inv.payments.map((pay) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.green.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Icon(Symbols.check_circle,
                              size: 14, color: AppColors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(pay.paymentNumber,
                                  style: AppTheme.monoXs.copyWith(
                                      fontSize: 11, color: context.pal.textMute)),
                              Text(pay.methodLabel,
                                  style: AppTheme.bodySub.copyWith(fontSize: 11)),
                            ]),
                          ),
                          Text(tshFromDouble(pay.amount),
                              style: AppTheme.bodyStrong.copyWith(
                                  color: AppColors.green, fontSize: 12.5)),
                        ]),
                      )),
                ],
              ]),
            ),
          ),

          // Footer close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: AppButton(
              label: 'Close',
              variant: BtnVariant.ghost,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoTile(BuildContext context, String label, String value) =>
      SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: AppTheme.labelCaps),
            const SizedBox(height: 2),
            Text(value,
                style: AppTheme.bodySm, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  String _fmtDate2(String iso) {
    final d = DateTime.tryParse(iso);
    return d != null ? formatDate(d) : iso;
  }
}
