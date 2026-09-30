import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/invoice.dart';
import '../../services/invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../utils/pdf_download.dart';
import '../../widgets/common/app_dropdown.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';
import '../../widgets/common/period_filter.dart';
import '../procurement/tender_forms.dart' show ProcDialog;
import 'invoice_builder_screen.dart';
import 'invoices_screen.dart' show showInvoiceDetail, showRecordPayment, showCreditNotes;

/// All sales — Clickhuduma's sell list: every sale with its payment status,
/// method, totals and who added it, a filtered footer total, and the row
/// action menu (right-click a row, or its Actions button). Drafts and
/// proformas are listed on their own tabs.
class AllSalesScreen extends StatefulWidget {
  const AllSalesScreen({super.key});

  @override
  State<AllSalesScreen> createState() => _AllSalesScreenState();
}

// Column spec: label, width, right-aligned.
typedef _Col = ({String label, double width, bool num});

const List<_Col> _cols = [
  (label: 'Action', width: 100, num: false),
  (label: 'Date', width: 96, num: false),
  (label: 'Invoice No.', width: 130, num: false),
  (label: 'Customer name', width: 210, num: false),
  (label: 'Contact No.', width: 118, num: false),
  (label: 'Payment Status', width: 104, num: false),
  (label: 'Payment Method', width: 118, num: false),
  (label: 'Total Amount', width: 124, num: true),
  (label: 'Total Paid', width: 124, num: true),
  (label: 'Sell Due', width: 124, num: true),
  (label: 'Shipping Status', width: 104, num: false),
  (label: 'Total Items', width: 76, num: true),
  (label: 'Added By', width: 130, num: false),
  (label: 'Sell note', width: 170, num: false),
  (label: 'Staff note', width: 150, num: false),
];

const _payStatuses = {'paid': 'Paid', 'due': 'Due', 'partial': 'Partial', 'overdue': 'Overdue'};
const _shipStatuses = {'ordered': 'Ordered', 'packed': 'Packed', 'shipped': 'Shipped', 'delivered': 'Delivered', 'cancelled': 'Cancelled'};

String _money(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}TSh $b';
}

String _date(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : formatDate(d);
}

String _qty(double? q) => q == null ? '—' : (q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2));

String _methods(Invoice i) => i.paymentMethods.isEmpty
    ? '—'
    : i.paymentMethods.length > 1 ? 'Multiple' : Invoice.methodLabelOf(i.paymentMethods.first);

(String, Color) _payStatusOf(BuildContext context, Invoice i) => switch (i.chPaymentStatus) {
  'paid'      => ('Paid', AppColors.green),
  'partial'   => ('Partial', AppColors.blue),
  'overdue'   => ('Overdue', AppColors.coral),
  'due'       => ('Due', AppColors.amber),
  'cancelled' => ('Cancelled', context.pal.textDim),
  'waived'    => ('Waived', context.pal.textDim),
  'proforma'  => ('Proforma', AppColors.violet),
  'draft'     => ('Draft', context.pal.textMute),
  final s     => (s, context.pal.textMute),
};

class _AllSalesScreenState extends State<AllSalesScreen> {
  // final | draft | proforma
  String _kind = 'final';
  Period _period = Period.defaultPeriod;
  List<Invoice> _all = [];
  bool _loading = true;
  String? _error;

  final _searchCtrl = TextEditingController();
  String? _customer, _payStatus, _addedBy, _shipStatus;
  int _pageSize = 25;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final cached = InvoiceService.cachedDefaultList;
    if (cached != null) {
      _all = cached;
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      if (_all.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final data = await InvoiceService.instance.list(
          period: _period, saleStatus: _kind == 'final' ? null : _kind);
      if (mounted) setState(() { _all = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  void _setKind(String k) {
    if (k == _kind) return;
    setState(() { _kind = k; _all = []; _page = 0; _payStatus = null; });
    _load();
  }

  List<Invoice> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _all.where((i) {
      if (_customer != null && i.displayName != _customer) return false;
      if (_addedBy != null && i.addedBy != _addedBy) return false;
      if (_shipStatus != null && i.shippingStatus != _shipStatus) return false;
      if (_payStatus != null) {
        final s = i.chPaymentStatus;
        // Clickhuduma: "due" and "partial" include the overdue ones.
        final ok = switch (_payStatus) {
          'due'     => s == 'due' || (s == 'overdue' && i.amountPaid == 0),
          'partial' => s == 'partial' || (s == 'overdue' && i.amountPaid > 0),
          _         => s == _payStatus,
        };
        if (!ok) return false;
      }
      if (q.isNotEmpty &&
          !i.invoiceNumber.toLowerCase().contains(q) &&
          !i.displayName.toLowerCase().contains(q) &&
          !(i.contactPhone ?? '').toLowerCase().contains(q) &&
          !(i.notes ?? '').toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final c = b.issueDate.compareTo(a.issueDate);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
  }

  void _resetPage() => setState(() => _page = 0);

  // ── Row actions (Clickhuduma's menu) ─────────────────────────────────────

  Future<Invoice?> _full(Invoice i) async {
    try {
      return await InvoiceService.instance.get(i.id);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
      return null;
    }
  }

  List<PopupMenuEntry<String>> _menuItems(Invoice i) {
    PopupMenuItem<String> item(String v, IconData icon, String label, {bool enabled = true}) => PopupMenuItem(
      value: v,
      enabled: enabled,
      height: 36,
      child: Row(children: [
        Icon(icon, size: 16, color: enabled ? context.pal.textMute : context.pal.textDim),
        const SizedBox(width: 12),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySm.copyWith(fontSize: 13, color: enabled ? context.pal.text : context.pal.textDim))),
      ]),
    );
    final fin = i.isFinal;
    return [
      item('view', Symbols.visibility, 'View'),
      item('edit', Symbols.edit_square, 'Edit', enabled: i.status != PaymentStatus.cancelled),
      item('delete', Symbols.delete, 'Delete'),
      item('shipping', Symbols.local_shipping, 'Edit Shipping'),
      item('print', Symbols.print, 'Print Invoice'),
      item('delivery', Symbols.description, 'Delivery Note'),
      const PopupMenuDivider(),
      item('pay', Symbols.payments, 'Add payment', enabled: i.canPay),
      item('payments', Symbols.receipt_long, 'View Payments', enabled: fin),
      item('duplicate', Symbols.content_copy, 'Duplicate Sell'),
      item('return', Symbols.undo, 'Sell Return', enabled: fin && i.status != PaymentStatus.cancelled),
      item('url', Symbols.visibility, 'Invoice URL'),
      item('notify', Symbols.mail, 'New Sale Notification'),
    ];
  }

  Future<void> _openMenu(Invoice i, Offset global) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final v = await showMenu<String>(
      context: context,
      color: context.pal.surface1,
      position: RelativeRect.fromRect(global & const Size(1, 1), Offset.zero & overlay.size),
      items: _menuItems(i),
    );
    if (v != null && mounted) _run(v, i);
  }

  Future<void> _run(String action, Invoice i) async {
    switch (action) {
      case 'view':
        if (await showInvoiceDetail(context, i.id)) _load();
      case 'edit':
      case 'duplicate':
        final full = await _full(i);
        if (full == null || !mounted) return;
        final saved = await Navigator.push<Invoice>(context, MaterialPageRoute(
          builder: (_) => action == 'edit' ? InvoiceBuilderScreen(editing: full) : InvoiceBuilderScreen(duplicateFrom: full),
        ));
        if (saved != null && mounted) {
          showSuccessToast(context, action == 'edit' ? '${saved.invoiceNumber} saved.' : 'New sale ${saved.invoiceNumber} saved.');
        }
        _load();
      case 'delete':
        final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: Text('Delete ${i.invoiceNumber}?'),
          content: Text(i.isFinal
              ? 'The sale and its payments are removed and the accounts reversed. This cannot be undone.'
              : 'This ${i.saleStatus} will be removed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
                onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
          ],
        ));
        if (ok != true) return;
        try {
          await InvoiceService.instance.delete(i.id);
          if (mounted) showSuccessToast(context, '${i.invoiceNumber} deleted.');
          _load();
        } catch (e) {
          if (mounted) showErrorToast(context, e);
        }
      case 'shipping':
        final saved = await showDialog<bool>(context: context, builder: (_) => _ShippingDialog(invoice: i));
        if (saved == true) _load();
      case 'print':
        await downloadPdf(context, () => InvoiceService.instance.pdfBytes(i.id), '${i.invoiceNumber}.pdf');
      case 'delivery':
        await downloadPdf(context, () => InvoiceService.instance.deliveryNoteBytes(i.id), 'DN-${i.invoiceNumber}.pdf');
      case 'pay':
        final full = await _full(i);
        if (full != null && mounted && await showRecordPayment(context, full)) _load();
      case 'payments':
        final full = await _full(i);
        if (full != null && mounted) await showDialog(context: context, builder: (_) => _PaymentsDialog(invoice: full));
      case 'return':
        final full = await _full(i);
        if (full != null && mounted && await showCreditNotes(context, full)) _load();
      case 'url':
        await _showInvoiceUrl(i);
      case 'notify':
        await showDialog(context: context, builder: (_) => _NotifyDialog(invoice: i));
    }
  }

  Future<void> _showInvoiceUrl(Invoice i) async {
    try {
      final url = await InvoiceService.instance.shareLink(i.id);
      if (!mounted) return;
      await showDialog(context: context, builder: (c) => ProcDialog(
        title: 'Invoice URL · ${i.invoiceNumber}',
        icon: Symbols.link,
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Anyone with this link can open the invoice PDF for the next 7 days.', style: AppTheme.bodySub),
          const SizedBox(height: 12),
          SelectableText(url, style: AppTheme.monoSm.copyWith(fontSize: 12)),
        ]),
        actions: [
          FilledButton.icon(
            icon: const Icon(Symbols.content_copy, size: 15),
            label: const Text('Copy link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(c);
              showSuccessToast(context, 'Link copied.');
            },
          ),
        ],
      ));
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _addSale() async {
    final saved = await Navigator.push<Invoice>(context, MaterialPageRoute(builder: (_) => const InvoiceBuilderScreen()));
    if (saved != null && mounted) showSuccessToast(context, '${saved.invoiceNumber} saved.');
    _load();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final pages = (rows.length / _pageSize).ceil().clamp(1, 1 << 30);
    final page = _page.clamp(0, pages - 1);
    final shown = rows.skip(page * _pageSize).take(_pageSize).toList();
    final customers = {for (final i in _all) i.displayName}.toList()..sort();
    final users = {for (final i in _all) ?i.addedBy}.toList()..sort();

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 24.0;
      return Padding(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Head
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('All sales', style: AppTheme.pageTitle.copyWith(fontSize: 23)),
              const SizedBox(height: 3),
              Text('Right-click a sale for its actions', style: AppTheme.bodySub.copyWith(fontSize: 12)),
            ])),
            FilledButton.icon(onPressed: _addSale, icon: const Icon(Symbols.add, size: 16), label: const Text('Add sale')),
          ]),
          const SizedBox(height: 14),
          // Kind tabs
          Row(children: [
            for (final (k, l) in const [('final', 'Sales'), ('draft', 'Drafts'), ('proforma', 'Proformas')]) ...[
              _Tab(label: l, active: _kind == k, onTap: () => _setKind(k)),
              const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: 12),
          // Filters
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.pal.border)),
            child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
              SizedBox(width: 240, child: AppSearchableSelectField<String>(
                label: 'Customer',
                hint: 'All',
                selectedLabel: _customer,
                items: customers.map((c) => AppSelectItem(value: c, label: c)).toList(),
                onSelected: (it) { _customer = it?.value; _resetPage(); },
              )),
              if (_kind == 'final')
                SizedBox(width: 150, child: LabeledDropdown<String?>(
                  label: 'Payment status', value: _payStatus,
                  items: [null, ..._payStatuses.keys],
                  displayBuilder: (v) => v == null ? 'All' : _payStatuses[v]!,
                  onChanged: (v) { _payStatus = v; _resetPage(); },
                )),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Date range', style: AppTheme.fieldLabel),
                const SizedBox(height: 6),
                PeriodSelector(value: _period, onChanged: (p) { setState(() { _period = p; _page = 0; }); _load(); }),
              ]),
              SizedBox(width: 180, child: LabeledDropdown<String?>(
                label: 'User', value: users.contains(_addedBy) ? _addedBy : null,
                items: [null, ...users],
                displayBuilder: (v) => v ?? 'All',
                onChanged: (v) { _addedBy = v; _resetPage(); },
              )),
              SizedBox(width: 150, child: LabeledDropdown<String?>(
                label: 'Shipping status', value: _shipStatus,
                items: [null, ..._shipStatuses.keys],
                displayBuilder: (v) => v == null ? 'All' : _shipStatuses[v]!,
                onChanged: (v) { _shipStatus = v; _resetPage(); },
              )),
            ]),
          ),
          const SizedBox(height: 12),
          // Table toolbar
          Row(children: [
            Text('Show', style: AppTheme.bodySub),
            const SizedBox(width: 8),
            SizedBox(width: 90, child: DropdownFieldBox<int>(
              value: _pageSize,
              items: const [25, 50, 100, 200].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
              onChanged: (v) => setState(() { _pageSize = v ?? 25; _page = 0; }),
            )),
            const SizedBox(width: 8),
            Text('entries', style: AppTheme.bodySub),
            const Spacer(),
            SizedBox(width: 260, child: SearchField(hint: 'Search…', controller: _searchCtrl,
                onChanged: (_) => _resetPage())),
          ]),
          const SizedBox(height: 10),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error != null && _all.isEmpty
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _table(context, shown, rows)),
          const SizedBox(height: 10),
          Row(children: [
            Text(rows.isEmpty ? 'Showing 0 entries'
                : 'Showing ${page * _pageSize + 1} to ${page * _pageSize + shown.length} of ${rows.length} entries',
                style: AppTheme.bodySub.copyWith(fontSize: 12)),
            const Spacer(),
            TextButton(onPressed: page > 0 ? () => setState(() => _page = page - 1) : null, child: const Text('Previous')),
            Text('${page + 1} / $pages', style: AppTheme.monoSm.copyWith(fontSize: 12)),
            TextButton(onPressed: page < pages - 1 ? () => setState(() => _page = page + 1) : null, child: const Text('Next')),
          ]),
        ]),
      );
    });
  }

  Widget _table(BuildContext context, List<Invoice> shown, List<Invoice> all) {
    final natural = _cols.fold<double>(0, (s, c) => s + c.width);
    return LayoutBuilder(builder: (ctx, cst) {
      // Fill wide screens; scroll sideways on narrow ones (as Clickhuduma does).
      final scale = cst.maxWidth > natural ? cst.maxWidth / natural : 1.0;
      final widths = _cols.map((c) => c.width * scale).toList();
      final tableW = natural * scale;
      return Container(
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.pal.border)),
        clipBehavior: Clip.antiAlias,
        child: Scrollbar(
          thumbVisibility: scale == 1.0,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableW,
              height: cst.maxHeight,
              child: Column(children: [
                _row(context, widths, [for (final c in _cols) Text(c.label, style: AppTheme.labelCaps.copyWith(fontSize: 10))],
                    header: true),
                Expanded(child: shown.isEmpty
                    ? Center(child: Text('No sales found', style: AppTheme.bodySub))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (_, n) => _saleRow(context, widths, shown[n], n.isOdd),
                      )),
                _footer(context, widths, all),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _row(BuildContext context, List<double> widths, List<Widget> cells, {bool header = false, bool footer = false, Color? bg}) =>
      Container(
        color: bg ?? (header || footer ? context.pal.surface2 : null),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: null,
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(alignment: _cols[i].num ? Alignment.centerRight : Alignment.centerLeft, child: cells[i]),
              ),
            ),
        ]),
      );

  Widget _saleRow(BuildContext context, List<double> widths, Invoice i, bool odd) {
    final (label, color) = _payStatusOf(context, i);
    final cell = AppTheme.bodySm.copyWith(fontSize: 12.5);
    final money = AppTheme.monoSm.copyWith(fontSize: 12);
    Text t(String? s, {TextStyle? style}) => Text(s == null || s.trim().isEmpty ? '—' : s,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: style ?? cell);

    return GestureDetector(
      onSecondaryTapDown: (d) => _openMenu(i, d.globalPosition),
      onLongPressStart: (d) => _openMenu(i, d.globalPosition),
      child: InkWell(
        onDoubleTap: () => _run('view', i),
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            color: odd ? context.pal.surface2.withValues(alpha: 0.4) : null,
            border: Border(top: BorderSide(color: context.pal.divider)),
          ),
          child: _row(context, widths, [
            Builder(builder: (bctx) => OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () {
                final box = bctx.findRenderObject() as RenderBox;
                _openMenu(i, box.localToGlobal(Offset(0, box.size.height)));
              },
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text('Actions', overflow: TextOverflow.clip, softWrap: false, style: AppTheme.bodySm.copyWith(fontSize: 11.5))),
                const Icon(Symbols.arrow_drop_down, size: 16),
              ]),
            )),
            t(_date(i.issueDate)),
            t(i.invoiceNumber, style: money.copyWith(fontWeight: FontWeight.w600)),
            Tooltip(message: i.displayName, child: t(i.displayName)),
            t(i.contactPhone, style: money),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ),
            t(_methods(i)),
            t(_money(i.total), style: money),
            t(_money(i.amountPaid), style: money.copyWith(color: AppColors.green)),
            t(_money(i.balanceDue), style: money.copyWith(color: i.balanceDue > 0 ? AppColors.amber : context.pal.textDim)),
            t(_shipStatuses[i.shippingStatus]),
            t(_qty(i.totalItems), style: money),
            t(i.addedBy),
            Tooltip(message: i.notes ?? '', child: t(i.notes)),
            Tooltip(message: i.staffNote ?? '', child: t(i.staffNote)),
          ]),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, List<double> widths, List<Invoice> all) {
    final total = all.fold<int>(0, (s, i) => s + i.total);
    final paid = all.fold<int>(0, (s, i) => s + i.amountPaid);
    final due = all.fold<int>(0, (s, i) => s + i.balanceDue);
    final statusCounts = <String, int>{};
    final methodCounts = <String, int>{};
    for (final i in all) {
      final (l, _) = _payStatusOf(context, i);
      statusCounts[l] = (statusCounts[l] ?? 0) + 1;
      final m = _methods(i);
      if (m != '—') methodCounts[m] = (methodCounts[m] ?? 0) + 1;
    }
    final small = AppTheme.bodySub.copyWith(fontSize: 11);
    final money = AppTheme.monoSm.copyWith(fontSize: 12, fontWeight: FontWeight.w700);
    Widget list(Map<String, int> m) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [for (final e in m.entries) Text('${e.key} - ${e.value}', style: small)]);

    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.borderStrong))),
      child: _row(context, widths, [
        const SizedBox(),
        const SizedBox(),
        const SizedBox(),
        Text('Total (${all.length}):', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
        const SizedBox(),
        list(statusCounts),
        list(methodCounts),
        Text(_money(total), style: money),
        Text(_money(paid), style: money.copyWith(color: AppColors.green)),
        Text(_money(due), style: money.copyWith(color: AppColors.amber)),
        const SizedBox(), const SizedBox(), const SizedBox(), const SizedBox(), const SizedBox(),
      ], footer: true),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});
  final String label; final bool active; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.tealSoft : context.pal.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppColors.teal : context.pal.border),
      ),
      child: Text(label, style: AppTheme.bodySm.copyWith(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? AppColors.teal : context.pal.textMute)),
    ),
  );
}

// ── Edit Shipping ───────────────────────────────────────────────────────────
class _ShippingDialog extends StatefulWidget {
  const _ShippingDialog({required this.invoice});
  final Invoice invoice;
  @override
  State<_ShippingDialog> createState() => _ShippingDialogState();
}

class _ShippingDialogState extends State<_ShippingDialog> {
  late final _details = TextEditingController(text: widget.invoice.shippingDetails ?? '');
  late final _address = TextEditingController(text: widget.invoice.shippingAddress ?? '');
  late final _charges = TextEditingController(text: widget.invoice.shippingCharges > 0 ? '${widget.invoice.shippingCharges}' : '');
  late final _deliveredTo = TextEditingController(text: widget.invoice.deliveredTo ?? '');
  late String? _status = widget.invoice.shippingStatus;
  bool _saving = false;

  @override
  void dispose() {
    _details.dispose(); _address.dispose(); _charges.dispose(); _deliveredTo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final charges = _charges.text.trim().isEmpty ? 0 : int.tryParse(_charges.text.replaceAll(',', '').trim());
    if (charges == null) {
      showErrorToast(context, Exception('Enter the shipping charge as a number.'));
      return;
    }
    setState(() => _saving = true);
    try {
      String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      await InvoiceService.instance.updateShipping(widget.invoice.id, {
        'shipping_details': v(_details),
        'shipping_address': v(_address),
        'shipping_charges': charges,
        'shipping_status':  _status,
        'delivered_to':     v(_deliveredTo),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _saving = false); showErrorToast(context, e); }
    }
  }

  @override
  Widget build(BuildContext context) => ProcDialog(
    title: 'Edit Shipping · ${widget.invoice.invoiceNumber}',
    icon: Symbols.local_shipping,
    width: 560,
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LabeledTextField(label: 'Shipping details', controller: _details, maxLines: 2, hint: 'Vehicle, courier, tracking no.…'),
      const SizedBox(height: 12),
      LabeledTextField(label: 'Shipping address', controller: _address, maxLines: 2, hint: 'Where the goods go'),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: LabeledTextField(label: 'Shipping charges', controller: _charges, hint: '0',
            keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: LabeledDropdown<String?>(
          label: 'Shipping status', value: _status,
          items: [null, ..._shipStatuses.keys],
          displayBuilder: (v) => v == null ? 'Please select' : _shipStatuses[v]!,
          onChanged: (v) => setState(() => _status = v),
        )),
      ]),
      const SizedBox(height: 12),
      LabeledTextField(label: 'Delivered to', controller: _deliveredTo, hint: 'Name of the person who received it'),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Update')),
    ],
  );
}

// ── View Payments ───────────────────────────────────────────────────────────
class _PaymentsDialog extends StatelessWidget {
  const _PaymentsDialog({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final head = AppTheme.labelCaps.copyWith(fontSize: 10);
    final cell = AppTheme.bodySm.copyWith(fontSize: 12.5);
    return ProcDialog(
      title: 'Payments · ${invoice.invoiceNumber}',
      icon: Symbols.receipt_long,
      width: 720,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${invoice.displayName} · total ${_money(invoice.total)} · paid ${_money(invoice.amountPaid)} · due ${_money(invoice.balanceDue)}',
            style: AppTheme.bodySub),
        const SizedBox(height: 12),
        if (invoice.payments.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('No payments yet.', style: AppTheme.bodySub)))
        else ...[
          Row(children: [
            Expanded(flex: 2, child: Text('DATE', style: head)),
            Expanded(flex: 3, child: Text('REFERENCE NO', style: head)),
            Expanded(flex: 3, child: Text('AMOUNT', style: head)),
            Expanded(flex: 3, child: Text('PAYMENT METHOD', style: head)),
            Expanded(flex: 3, child: Text('NOTE', style: head)),
          ]),
          const Divider(),
          for (final p in invoice.payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(flex: 2, child: Text(_date(p.paidAt.length >= 10 ? p.paidAt.substring(0, 10) : p.paidAt), style: cell)),
                Expanded(flex: 3, child: Text([p.paymentNumber, ?p.reference].join(' · '), style: cell)),
                Expanded(flex: 3, child: Text(_money(p.amount), style: AppTheme.monoSm.copyWith(fontSize: 12))),
                Expanded(flex: 3, child: Text(p.methodLabel, style: cell)),
                Expanded(flex: 3, child: Text(p.notes ?? '—', style: cell)),
              ]),
            ),
        ],
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

// ── New Sale Notification ───────────────────────────────────────────────────
class _NotifyDialog extends StatefulWidget {
  const _NotifyDialog({required this.invoice});
  final Invoice invoice;
  @override
  State<_NotifyDialog> createState() => _NotifyDialogState();
}

class _NotifyDialogState extends State<_NotifyDialog> {
  late final Invoice i = widget.invoice;
  late final _to = TextEditingController(text: i.clientEmail ?? '');
  late final _subject = TextEditingController(text: 'Invoice ${i.invoiceNumber} from Hypermed Healthcare');
  late final _message = TextEditingController(text:
      'Dear ${i.displayName},\n\n'
      'Your invoice number is ${i.invoiceNumber}.\n'
      'Total amount: ${_money(i.total)}\n'
      'Paid amount: ${_money(i.amountPaid)}\n'
      'Balance due: ${_money(i.balanceDue)}\n\n'
      'The invoice is attached.\n\n'
      'Thank you for your business.\n'
      'Hypermed Healthcare Ltd');
  bool _sending = false;

  @override
  void dispose() {
    _to.dispose(); _subject.dispose(); _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_to.text.trim())) {
      showErrorToast(context, Exception('Enter the customer’s email address.'));
      return;
    }
    setState(() => _sending = true);
    try {
      final msg = await InvoiceService.instance.notify(i.id,
          to: _to.text.trim(), subject: _subject.text.trim(), message: _message.text);
      if (mounted) { Navigator.pop(context); showSuccessToast(context, msg); }
    } catch (e) {
      if (mounted) { setState(() => _sending = false); showErrorToast(context, e); }
    }
  }

  @override
  Widget build(BuildContext context) => ProcDialog(
    title: 'New Sale Notification · ${i.invoiceNumber}',
    icon: Symbols.mail,
    width: 620,
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LabeledTextField(label: 'To', controller: _to, hint: 'customer@example.com', keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      LabeledTextField(label: 'Subject', controller: _subject),
      const SizedBox(height: 12),
      LabeledTextField(label: 'Message', controller: _message, maxLines: 11),
      const SizedBox(height: 8),
      Text('The invoice PDF is attached. Replies come to you.', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Symbols.send, size: 15),
          label: Text(_sending ? 'Sending…' : 'Send')),
    ],
  );
}
