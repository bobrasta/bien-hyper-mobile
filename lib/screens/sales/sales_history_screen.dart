import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/invoice.dart';
import '../../services/invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/pdf_download.dart';
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
  int get _overdueCount     => _filtered.where((i) => i.isOverdue).length;

  Invoice? _selected;

  void _openDetail(Invoice inv) => setState(() => _selected = inv);

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 26.0;
      return Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(width: 2, height: 36, decoration: BoxDecoration(color: AppColors.textMute, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sales History', style: AppTheme.pageTitle.copyWith(fontSize: 23)),
                const SizedBox(height: 3),
                Text(
                  _loading ? 'Loading…' : '${_periodLabel(_period)} · ${items.length} invoice${items.length == 1 ? '' : 's'} · ${tshFromDouble(_totalRevenue)} revenue · ${tshFromDouble(_totalCollected)} collected',
                  style: AppTheme.bodySub.copyWith(fontSize: 12),
                ),
              ])),
              ...[
                ('all', 'All time'), ('year', 'This year'), ('quarter', 'This quarter'), ('month', 'This month'),
              ].map((p) => Padding(padding: const EdgeInsets.only(left: 6), child: _PeriodChip(label: p.$2, active: _period == p.$1, onTap: () => setState(() => _period = p.$1)))),
              const SizedBox(width: 8),
              SizedBox(
                width: 190, height: 32,
                child: TextField(
                  controller: _searchCtrl,
                  style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Invoice, client, order…',
                    hintStyle: AppTheme.bodySub.copyWith(fontSize: 12),
                    prefixIcon: Icon(Symbols.search, size: 15, color: context.pal.textDim),
                    filled: true, fillColor: context.pal.surface1,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: context.pal.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: context.pal.border)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (!_loading && _error == null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Container(
                decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
                child: Row(children: [
                  Expanded(child: _histStat('Revenue', Symbols.payments, AppColors.cyan, tshFromDouble(_totalRevenue), '${items.length} invoices raised')),
                  Expanded(child: _histStat('Collected', Symbols.hand_gesture, AppColors.green, tshFromDouble(_totalCollected), '${items.where((i) => i.isPaid).length} paid in full', border: true)),
                  Expanded(child: _histStat('Outstanding', Symbols.hourglass_top, AppColors.amber, tshFromDouble(_totalOutstanding), '$_overdueCount overdue', border: true)),
                  Expanded(child: _histStat('Avg invoice', Symbols.receipt_long, AppColors.violet, items.isEmpty ? '—' : tshFromDouble(_totalRevenue ~/ items.length), 'across period', border: true)),
                  Expanded(child: _histStat('Days to pay', Symbols.timer, AppColors.textMute, _avgDaysToPay(items), 'average, paid invoices', border: true)),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
              child: _loading
                  ? shimmerTable(count: 10, cols: 7)
                  : _error != null
                      ? ErrorView(message: _error!, onRetry: _load)
                      : Container(
                          decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(children: [
                            Container(
                              height: 38, padding: const EdgeInsets.symmetric(horizontal: 16),
                              color: context.pal.surface2,
                              child: Row(children: [
                                SizedBox(width: 130, child: Text('INVOICE', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
                                Expanded(flex: 3, child: Text('CLIENT', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
                                Expanded(flex: 2, child: Text('TRAIL', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
                                Expanded(child: Text('TOTAL', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
                                Expanded(child: Text('COLLECTED', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
                                Expanded(child: Text('BALANCE', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
                                Expanded(child: Text('STATUS', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
                                Expanded(child: Text('DATE', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
                              ]),
                            ),
                            Expanded(child: items.isEmpty
                                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Symbols.history, size: 40, color: context.pal.textDim),
                                    const SizedBox(height: 10),
                                    Text('No sales records found', style: AppTheme.bodyStrong.copyWith(color: context.pal.textMute)),
                                    const SizedBox(height: 4),
                                    Text(_search.isNotEmpty ? 'Try a different search term' : 'Completed invoices will appear here', style: AppTheme.bodySub),
                                  ]))
                                : ListView.builder(
                                    itemCount: items.length,
                                    itemBuilder: (_, i) => _HistoryRow(inv: items[i], selected: _selected?.id == items[i].id, onTap: () => _openDetail(items[i])),
                                  )),
                          ]),
                        ),
            ),
          ),
        ]),
        if (_selected != null) ...[
          Positioned.fill(child: GestureDetector(onTap: () => setState(() => _selected = null), child: Container(color: const Color(0x8C06070A)))),
          Positioned(top: 0, right: 0, bottom: 0, child: _InvoiceDetailPanel(inv: _selected!, onClose: () => setState(() => _selected = null))),
        ],
      ]);
    });
  }

  Widget _histStat(String label, IconData icon, Color color, String value, String note, {bool border = false}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: border ? BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.06)))) : null,
    child: Builder(builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 7),
        Expanded(child: Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 8),
      Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 19, color: color)),
      const SizedBox(height: 5),
      Text(note, style: AppTheme.bodySub.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
    ])),
  );

  String _periodLabel(String p) => switch (p) { 'year' => 'This year', 'quarter' => 'This quarter', 'month' => 'This month', _ => 'All time' };

  String _avgDaysToPay(List<Invoice> items) {
    final paid = items.where((i) => i.isPaid && i.payments.isNotEmpty).toList();
    if (paid.isEmpty) return '—';
    final days = paid.map((i) {
      final issue = DateTime.tryParse(i.issueDate);
      final paidAt = DateTime.tryParse(i.payments.last.paidAt);
      if (issue == null || paidAt == null) return 0;
      return paidAt.difference(issue).inDays;
    }).where((d) => d >= 0).toList();
    if (days.isEmpty) return '—';
    return (days.reduce((a, b) => a + b) / days.length).toStringAsFixed(1);
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
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.green.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? AppColors.green.withValues(alpha: 0.5) : context.pal.border),
          ),
          child: Text(label, style: AppTheme.bodySm.copyWith(fontSize: 12, color: active ? AppColors.green : context.pal.textMute)),
        ),
      );
}

// ── History row ────────────────────────────────────────────────────────────────

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({required this.inv, required this.selected, required this.onTap});
  final Invoice inv;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hovered = false;

  Color _statusColor() => switch (widget.inv.effectiveStatus) {
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.selected ? AppColors.cyan.withValues(alpha: 0.07) : (_hovered ? context.pal.surface2 : null),
            border: Border(bottom: BorderSide(color: context.pal.divider)),
          ),
          child: Row(children: [
            SizedBox(width: 130, child: Row(children: [
              Container(width: 3, height: 26, decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 9),
              Expanded(child: Text(inv.invoiceNumber, style: AppTheme.monoXs.copyWith(color: widget.selected ? AppColors.green : context.pal.textMute, fontSize: 11.5))),
            ])),
            Expanded(flex: 3, child: Text(inv.displayName, style: AppTheme.bodySm.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Wrap(spacing: 5, runSpacing: 4, children: [
              _trailChip('Order', inv.salesOrderNumber ?? 'Direct', context.pal.textMute),
              if (inv.isPaid) _trailChip('Paid', inv.payments.isNotEmpty ? inv.payments.first.paymentNumber : 'Settled', AppColors.green)
              else _trailChip('Balance', 'Awaiting', AppColors.amber),
            ])),
            Expanded(child: Text(tshFromDouble(inv.total), textAlign: TextAlign.right, style: AppTheme.monoSm.copyWith(fontSize: 12.5))),
            Expanded(child: Text(inv.amountPaid > 0 ? tshFromDouble(inv.amountPaid) : '—', textAlign: TextAlign.right, style: AppTheme.monoSm.copyWith(fontSize: 12, color: inv.amountPaid > 0 ? AppColors.green : context.pal.textDim))),
            Expanded(child: Text(hasBalance ? tshFromDouble(inv.balanceDue) : '—', textAlign: TextAlign.right, style: AppTheme.monoSm.copyWith(fontSize: 12, color: hasBalance ? AppColors.amber : context.pal.textDim))),
            Expanded(child: Align(alignment: Alignment.centerRight, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
              child: Text(inv.effectiveStatus.label, style: AppTheme.monoXs.copyWith(color: statusColor, fontSize: 9.5)),
            ))),
            Expanded(child: Text(_fmtDate(inv.issueDate), textAlign: TextAlign.right, style: AppTheme.monoXs.copyWith(fontSize: 11, color: context.pal.textDim))),
          ]),
        ),
      ),
    );
  }

  Widget _trailChip(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
    child: Text(value, style: AppTheme.monoXs.copyWith(fontSize: 9, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d != null ? formatDate(d) : iso;
  }
}

// ── Invoice detail side panel ─────────────────────────────────────────────────

class _InvoiceDetailPanel extends StatelessWidget {
  const _InvoiceDetailPanel({required this.inv, required this.onClose});
  final Invoice inv;
  final VoidCallback onClose;

  Future<void> _viewPdf(BuildContext context) =>
      downloadPdf(context, () => InvoiceService.instance.pdfBytes(inv.id), '${inv.invoiceNumber}.pdf');

  Color _statusColor() => switch (inv.effectiveStatus) {
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

    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: context.pal.surface1,
        border: Border(left: BorderSide(color: context.pal.borderStrong)),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 60, offset: Offset(-24, 0))
        ],
      ),
      child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(children: [
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(inv.invoiceNumber, style: AppTheme.pageTitle.copyWith(fontSize: 19)),
                  const SizedBox(width: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(inv.effectiveStatus.label.toUpperCase(),
                        style: AppTheme.monoXs.copyWith(color: statusColor, fontSize: 9.5)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('${inv.displayName} · issued ${_fmtDate2(inv.issueDate)}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
              ])),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.pal.border),
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

          Container(width: double.infinity, height: 1, color: context.pal.divider),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _viewPdf(context),
                icon: const Icon(Symbols.download, size: 15),
                label: const Text('Download PDF'),
              )),
              const SizedBox(width: 9),
              Expanded(child: OutlinedButton.icon(onPressed: onClose, icon: const Icon(Symbols.close, size: 15), label: const Text('Close'))),
            ]),
          ),
      ]),
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
