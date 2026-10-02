import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/expense.dart';
import '../../models/supplier.dart';
import '../../models/tax_rate.dart';
import '../../models/vendor_bill.dart';
import '../../services/expense_service.dart';
import '../../services/supplier_service.dart';
import '../../services/tax_rate_service.dart';
import '../../services/vendor_bill_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/phone_layout.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';

class VendorBillsScreen extends StatefulWidget {
  const VendorBillsScreen({super.key});

  @override
  State<VendorBillsScreen> createState() => _VendorBillsScreenState();
}

class _VendorBillsScreenState extends State<VendorBillsScreen> {
  final _payRunKey = GlobalKey();
  List<VendorBill>      _bills      = [];
  List<Supplier>        _suppliers  = [];
  List<ExpenseCategory> _categories = [];
  bool    _loading = true;
  bool    _payingRun = false;
  String? _error;
  bool    _showCreate = false;
  VendorBill? _selected;

  List<VendorBill> get _open => _bills.where((b) => b.canPay).toList();
  int get _totalPayable => _open.fold(0, (s, b) => s + b.balanceDue);

  List<VendorBill> get _dueSoon {
    final now = DateTime.now();
    return _open.where((b) {
      final d = DateTime.tryParse(b.dueDate);
      if (d == null) return false;
      final days = d.difference(now).inDays;
      return days >= 0 && days <= 7;
    }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<VendorBill> get _overdue {
    final now = DateTime.now();
    return _open.where((b) {
      final d = DateTime.tryParse(b.dueDate);
      return d != null && d.isBefore(now);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    // Stale-while-revalidate — same reasoning as MachineListScreen's own
    // fix: show the last-known bundle instantly on a fresh mount (this
    // widget isn't kept alive across navigation), then quietly refresh.
    final cached = VendorBillService.cachedDefaultList;
    if (cached != null) {
      _bills = cached;
      _suppliers = SupplierService.cachedDefaultList ?? [];
      _categories = ExpenseService.cachedCategories ?? [];
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      // Only show the blank/shimmer state when there's genuinely nothing
      // to show yet — a background refresh of an already-populated list
      // (or a return visit seeded from the cache above) updates silently.
      if (_bills.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        VendorBillService.instance.list(),
        SupplierService.instance.list(),
        ExpenseService.instance.categories(),
      ]);
      if (!mounted) return;
      setState(() {
        _bills      = results[0] as List<VendorBill>;
        _suppliers  = results[1] as List<Supplier>;
        _categories = results[2] as List<ExpenseCategory>;
        _loading    = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  void _scrollToPayRun() {
    final ctx = _payRunKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _schedulePayRun() async {
    final due = _dueSoon;
    if (due.isEmpty) return;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      backgroundColor: context.pal.surface1,
      title: const Text('Schedule pay run'),
      content: Text('This will record a full payment against ${due.length} bill(s) totalling ${tshFromDouble(due.fold<int>(0, (s, b) => s + b.balanceDue))}. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Pay all')),
      ],
    ));
    if (confirmed != true) return;
    setState(() => _payingRun = true);
    try {
      for (final b in due) {
        await VendorBillService.instance.recordPayment(b.id, {
          'amount': b.balanceDue,
          'payment_method': 'bank_transfer',
          'paid_at': DateTime.now().toIso8601String().substring(0, 10),
        });
      }
      if (mounted) showSuccessToast(context, 'Pay run complete — ${due.length} bill(s) paid.');
      _load();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _payingRun = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      LayoutBuilder(builder: (ctx, cst) {
        final pad  = cst.maxWidth < 560 ? 16.0 : 26.0;
        final wide = cst.maxWidth >= 1000;
        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TitleWithActions(
              leading: Container(width: 2, height: 36, decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2))),
              title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Accounts Payable', style: AppTheme.pageTitle.copyWith(fontSize: 23)),
                const SizedBox(height: 3),
                Text('Vendor bills & supplier payments · ${_suppliers.length} suppliers on file', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              ]),
              actions: [
                OutlinedButton.icon(onPressed: _scrollToPayRun, icon: const Icon(Symbols.send, size: 15), label: const Text('Pay run')),
                FilledButton.icon(onPressed: () => setState(() => _showCreate = true), icon: const Icon(Symbols.add, size: 16), label: const Text('New bill')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  // A background refresh failing while stale-but-valid
                  // cached data is already showing shouldn't blow that
                  // away — only "genuinely nothing to show" surfaces the
                  // error screen.
                  : _error != null && _bills.isEmpty
                      ? ErrorView(message: _error!, onRetry: _load)
                      : SingleChildScrollView(child: wide
                          ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Expanded(flex: 7, child: _mainColumn(context)),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: _rail(context)),
                            ]))
                          : Column(children: [_mainColumn(context), const SizedBox(height: 16), _rail(context)])),
            ),
          ]),
        );
      }),
      if (_showCreate)
        _NewBillDialog(
          suppliers: _suppliers,
          categories: _categories,
          onClose: () => setState(() => _showCreate = false),
          onSaved: () { setState(() => _showCreate = false); _load(); },
        ),
      if (_selected != null)
        _BillDetailSheet(
          bill: _selected!,
          onClose: () => setState(() => _selected = null),
          onChanged: () { setState(() => _selected = null); _load(); },
        ),
    ]);
  }

  Widget _mainColumn(BuildContext context) {
    final overdueTotal = _overdue.fold<int>(0, (s, b) => s + b.balanceDue);
    final dueSoonTotal = _dueSoon.fold<int>(0, (s, b) => s + b.balanceDue);
    final paidToDate = _bills.fold<int>(0, (s, b) => s + b.amountPaid);

    final now = DateTime.now();
    final buckets = <String, int>{'Current': 0, '1–30 d': 0, '31–60 d': 0, '60 d +': 0};
    for (final b in _open) {
      final d = DateTime.tryParse(b.dueDate);
      final daysLate = d == null ? 0 : now.difference(d).inDays;
      if (daysLate <= 0) buckets['Current'] = buckets['Current']! + b.balanceDue;
      else if (daysLate <= 30) buckets['1–30 d'] = buckets['1–30 d']! + b.balanceDue;
      else if (daysLate <= 60) buckets['31–60 d'] = buckets['31–60 d']! + b.balanceDue;
      else buckets['60 d +'] = buckets['60 d +']! + b.balanceDue;
    }
    final bucketColors = {'Current': AppColors.green, '1–30 d': AppColors.amber, '31–60 d': const Color(0xFFFF8A3D), '60 d +': AppColors.coral};
    final agingTotal = buckets.values.fold(0, (a, b) => a + b);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, cst) {
            final total = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('OUTSTANDING PAYABLE', style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
              const SizedBox(height: 5),
              Text(tshFromDouble(_totalPayable), style: AppTheme.kpiValue.copyWith(fontSize: 25)),
            ]);
            final stats = [
              _apStat('Due in 7 days', tshFromDouble(dueSoonTotal), AppColors.amber),
              _apStat('Overdue', tshFromDouble(overdueTotal), AppColors.coral),
              _apStat('Open bills', '${_open.length}', context.pal.text),
              _apStat('Paid to date', tshFromDouble(paidToDate), AppColors.green),
            ];
            // Phones: headline total, then the four figures two to a row.
            if (isPhoneWidth(cst.maxWidth)) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                total,
                const SizedBox(height: 14),
                PhoneStatGrid(spacing: 12, children: stats),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              total,
              const Spacer(),
              for (final (i, st) in stats.indexed) ...[if (i > 0) const SizedBox(width: 22), st],
            ]);
          }),
          const SizedBox(height: 16),
          if (agingTotal > 0) ClipRRect(borderRadius: BorderRadius.circular(4), child: Row(children: buckets.entries.map((e) =>
              Expanded(flex: (e.value == 0 ? 1 : e.value), child: Container(width: double.infinity, height: 8, color: e.value == 0 ? context.pal.surface3 : bucketColors[e.key])),
          ).toList())),
          const SizedBox(height: 11),
          Wrap(spacing: 20, runSpacing: 6, children: buckets.entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: bucketColors[e.key], borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 7),
            Text(e.key, style: AppTheme.bodySub.copyWith(fontSize: 11)),
            const SizedBox(width: 6),
            Text(tshFromDouble(e.value), style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: context.pal.text)),
          ])).toList()),
        ]),
      ),
      const SizedBox(height: 14),
      // Phones: one card per bill; wider screens keep the table.
      LayoutBuilder(builder: (context, cst) => isPhoneWidth(cst.maxWidth) ? _billCards(context) : Container(
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            height: 38, padding: const EdgeInsets.symmetric(horizontal: 16),
            color: context.pal.surface2,
            child: Row(children: [
              SizedBox(width: 100, child: Text('BILL NO.', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
              Expanded(flex: 3, child: Text('SUPPLIER', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
              Expanded(child: Text('TOTAL', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
              Expanded(child: Text('DUE', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
              Expanded(child: Text('DUE DATE', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
              Expanded(child: Text('STATUS', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
              const SizedBox(width: 54),
            ]),
          ),
          if (_bills.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No vendor bills yet.', style: AppTheme.bodySub))),
          ..._bills.map((b) {
            final now2 = DateTime.now();
            final d = DateTime.tryParse(b.dueDate);
            final daysDiff = d?.difference(now2).inDays;
            final overdue = b.status == 'overdue' || (daysDiff != null && daysDiff < 0 && b.canPay);
            final agingLabel = b.isPaid ? 'settled' : b.status == 'cancelled' ? 'voided' : daysDiff == null ? '—' : daysDiff >= 0 ? 'in $daysDiff days' : '${-daysDiff} days late';
            final stColor = switch (b.status) { 'paid' => AppColors.green, 'approved' => AppColors.cyan, 'partial' => AppColors.amber, 'cancelled' => AppColors.textMute, _ => overdue ? AppColors.coral : context.pal.textMute };
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: overdue ? AppColors.coral.withValues(alpha: 0.05) : null, border: Border(bottom: BorderSide(color: context.pal.divider))),
              child: Row(children: [
                SizedBox(width: 100, child: Text(b.billNumber, style: AppTheme.monoXs.copyWith(fontSize: 11, color: context.pal.textMute))),
                Expanded(flex: 3, child: Text(b.supplierName ?? '—', style: AppTheme.bodySm.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(child: Text(tshFromDouble(b.total), textAlign: TextAlign.right, style: AppTheme.monoSm.copyWith(fontSize: 12.5))),
                Expanded(child: Text(b.balanceDue > 0 ? tshFromDouble(b.balanceDue) : '—', textAlign: TextAlign.right, style: AppTheme.monoSm.copyWith(fontSize: 12.5, color: overdue ? AppColors.coral : context.pal.text))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.dueDate, style: AppTheme.monoXs.copyWith(fontSize: 10.5)),
                  Text(agingLabel, style: AppTheme.bodySub.copyWith(fontSize: 10, color: overdue ? AppColors.coral : context.pal.textDim)),
                ])),
                Expanded(child: Align(alignment: Alignment.centerRight, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: stColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
                  child: Text(b.statusLabel.toUpperCase(), style: AppTheme.monoXs.copyWith(fontSize: 9, color: stColor)),
                ))),
                SizedBox(width: 54, child: Align(alignment: Alignment.centerRight, child: OutlinedButton(
                  onPressed: () => setState(() => _selected = b),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 26)),
                  child: Text(b.canApprove ? 'Approve' : b.canPay ? 'Pay' : 'View', style: const TextStyle(fontSize: 11)),
                ))),
              ]),
            );
          }),
        ]),
      )),
    ]);
  }

  Widget _billCards(BuildContext context) {
    if (_bills.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text('No vendor bills yet.', style: AppTheme.bodySub)));
    }
    final now = DateTime.now();
    return Column(children: [
      for (final b in _bills)
        Builder(builder: (context) {
          final d = DateTime.tryParse(b.dueDate);
          final daysDiff = d?.difference(now).inDays;
          final overdue = b.status == 'overdue' || (daysDiff != null && daysDiff < 0 && b.canPay);
          final aging = b.isPaid ? 'settled' : b.status == 'cancelled' ? 'voided' : daysDiff == null ? '' : daysDiff >= 0 ? 'in $daysDiff days' : '${-daysDiff} days late';
          final stColor = switch (b.status) { 'paid' => AppColors.green, 'approved' => AppColors.cyan, 'partial' => AppColors.amber, 'cancelled' => AppColors.textMute, _ => overdue ? AppColors.coral : context.pal.textMute };
          return PhoneRecordCard(
            margin: const EdgeInsets.only(bottom: 8),
            title: b.supplierName ?? '—',
            subtitle: b.billNumber,
            badge: PhonePill(b.statusLabel, stColor),
            meta: ['due ${b.dueDate}${aging.isEmpty ? '' : ' ($aging)'}', 'total ${tshFromDouble(b.total)}'],
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(b.balanceDue > 0 ? tshFromDouble(b.balanceDue) : 'Paid',
                  style: AppTheme.bodyStrong.copyWith(fontSize: 14, color: overdue ? AppColors.coral : null)),
              if (b.canApprove || b.canPay) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _selected = b),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(64, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: Text(b.canApprove ? 'Approve' : 'Pay', style: const TextStyle(fontSize: 12.5)),
                ),
              ],
            ]),
            onTap: () => setState(() => _selected = b),
          );
        }),
    ]);
  }

  Widget _apStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9)),
    const SizedBox(height: 5),
    Text(value, style: AppTheme.monoXs.copyWith(fontSize: 15, color: color)),
  ]);

  Widget _sectionHeader(BuildContext context, IconData icon, Color color, String title) => Row(children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 8),
    Text(title.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10.5)),
    const SizedBox(width: 8),
    Expanded(child: Container(width: double.infinity, height: 1, color: context.pal.divider)),
  ]);

  Widget _rail(BuildContext context) {
    final due = _dueSoon;
    final dueTotal = due.fold<int>(0, (s, b) => s + b.balanceDue);
    final bySupplier = <String, int>{};
    for (final b in _bills) { bySupplier[b.supplierName ?? '—'] = (bySupplier[b.supplierName ?? '—'] ?? 0) + b.total; }
    final topSuppliers = bySupplier.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxSupplier = topSuppliers.isEmpty ? 1 : topSuppliers.first.value;

    return Column(key: _payRunKey, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionHeader(context, Symbols.event_available, AppColors.green, 'Next pay run'),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(tshFromDouble(dueTotal), style: AppTheme.kpiValue.copyWith(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(child: Text('${due.length} bill${due.length == 1 ? '' : 's'} due within 7 days', style: AppTheme.bodySub.copyWith(fontSize: 11))),
          ]),
          const SizedBox(height: 10),
          Container(width: double.infinity, height: 1, color: context.pal.divider),
          const SizedBox(height: 10),
          if (due.isEmpty) Text('Nothing due within a week.', style: AppTheme.bodySub.copyWith(fontSize: 12))
          else ...due.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(Symbols.check_box_outline_blank, size: 14, color: context.pal.textDim),
              const SizedBox(width: 9),
              Expanded(child: Text(b.supplierName ?? '—', style: AppTheme.bodySub.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(tshFromDouble(b.balanceDue), style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: context.pal.text)),
            ]),
          )),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: due.isEmpty || _payingRun ? null : _schedulePayRun,
            child: _payingRun ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Schedule pay run'),
          )),
        ]),
      ),
      const SizedBox(height: 16),
      _sectionHeader(context, Symbols.apartment, AppColors.violet, 'Top suppliers'),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        child: topSuppliers.isEmpty
            ? Text('No bills on file yet.', style: AppTheme.bodySub.copyWith(fontSize: 12))
            : Column(children: topSuppliers.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.key, style: AppTheme.bodySub.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(tshFromDouble(e.value), style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: context.pal.text)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: e.value / maxSupplier, minHeight: 6, backgroundColor: context.pal.surface3, valueColor: AlwaysStoppedAnimation(AppColors.violet))),
                ]),
              )).toList()),
      ),
    ]);
  }
}

// ── New Bill Dialog ──────────────────────────────────────────────────────────

class _BillLineEntry {
  final descCtrl  = TextEditingController();
  final qtyCtrl   = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();

  void dispose() { descCtrl.dispose(); qtyCtrl.dispose(); priceCtrl.dispose(); }
}

class _NewBillDialog extends StatefulWidget {
  const _NewBillDialog({required this.suppliers, required this.categories, required this.onClose, required this.onSaved});
  final List<Supplier> suppliers;
  final List<ExpenseCategory> categories;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_NewBillDialog> createState() => _NewBillDialogState();
}

class _NewBillDialogState extends State<_NewBillDialog> {
  int?   _supplierId;
  int?   _categoryId;
  double _taxRate = 18;
  List<TaxRate> _taxRates = const [];
  final _lines = [_BillLineEntry()];
  bool   _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.suppliers.isNotEmpty) _supplierId = widget.suppliers.first.id;
    if (widget.categories.isNotEmpty) _categoryId = widget.categories.first.id;
    _loadTaxRates();
  }

  Future<void> _loadTaxRates() async {
    try {
      final all = await TaxRateService.instance.list();
      if (!mounted || all.isEmpty) return;
      final seenRates = <double>{};
      final rates = all.where((r) => seenRates.add(r.rate)).toList();
      final defaultRate = rates.firstWhere((r) => r.isDefault, orElse: () => rates.first);
      setState(() { _taxRates = rates; _taxRate = defaultRate.rate; });
    } catch (_) {
      // Falls back to the static 0%/18% items below — non-critical.
    }
  }

  @override
  void dispose() {
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final validLines = _lines.where((l) => l.descCtrl.text.trim().isNotEmpty).toList();
    if (_supplierId == null || _categoryId == null || validLines.isEmpty) {
      setState(() => _error = 'Supplier, category and at least one line item are required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final now = DateTime.now();
      final due = now.add(const Duration(days: 30));
      await VendorBillService.instance.create({
        'supplier_id': _supplierId,
        'category_id': _categoryId,
        'tax_rate':    _taxRate,
        'issue_date':  now.toIso8601String().substring(0, 10),
        'due_date':    due.toIso8601String().substring(0, 10),
        'line_items':  validLines.map((l) => {
          'description': l.descCtrl.text.trim(),
          'quantity':    double.tryParse(l.qtyCtrl.text) ?? 1,
          'unit_price':  int.tryParse(l.priceCtrl.text.replaceAll(',', '')) ?? 0,
        }).toList(),
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: PhoneModalBox(scroll: false, child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 600,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                Icon(Symbols.receipt_long, size: 18, color: AppColors.coral),
                const SizedBox(width: 10),
                Expanded(child: Text('New Vendor Bill', style: AppTheme.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis)),
                GestureDetector(onTap: widget.onClose, child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12)),
                  ),
                ],
                Row(children: [
                  Expanded(child: _Dropdown(
                    label: 'Supplier',
                    value: _supplierId,
                    items: widget.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _supplierId = v),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _Dropdown(
                    label: 'Expense Category',
                    value: _categoryId,
                    items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  )),
                  const SizedBox(width: 12),
                  SizedBox(width: 130, child: _Dropdown<double>(
                    label: 'VAT %',
                    value: _taxRate,
                    items: _taxRates.isNotEmpty
                        ? _taxRates.map((r) => DropdownMenuItem(value: r.rate, child: Text(r.name, overflow: TextOverflow.ellipsis))).toList()
                        : const [
                            DropdownMenuItem(value: 0.0, child: Text('0%')),
                            DropdownMenuItem(value: 18.0, child: Text('18%')),
                          ],
                    onChanged: (v) => setState(() => _taxRate = v ?? 0),
                  )),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('Line Items', style: AppTheme.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  GestureDetector(
                    onTap: () => setState(() => _lines.add(_BillLineEntry())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.teal), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Symbols.add, size: 14, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Text('Add Item', style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                ..._lines.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(flex: 3, child: _InlineField(controller: e.value.descCtrl, hint: 'Description')),
                    const SizedBox(width: 8),
                    Expanded(child: _InlineField(controller: e.value.qtyCtrl, hint: 'Qty', number: true)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _InlineField(controller: e.value.priceCtrl, hint: 'Unit price', number: true)),
                    if (_lines.length > 1) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() { e.value.dispose(); _lines.removeAt(e.key); }),
                        child: Icon(Symbols.close, size: 16, color: context.pal.textDim),
                      ),
                    ],
                  ]),
                )),
              ]),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Expanded(child: GestureDetector(onTap: widget.onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: _save,
                  child: Container(height: 38,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Bill', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13)))))),
              ]),
            ),
          ]),
        ),
      )),
    ),
  );
}

class _InlineField extends StatelessWidget {
  const _InlineField({required this.controller, required this.hint, this.number = false});
  final TextEditingController controller;
  final String hint;
  final bool number;

  @override
  Widget build(BuildContext context) => LabeledTextField(label: '', controller: controller, keyboardType: number ? TextInputType.number : TextInputType.text, hint: hint);
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.fieldLabel),
    const SizedBox(height: 6),
    DropdownFieldBox<T>(
      value: value,
      items: items,
      onChanged: onChanged,
    ),
  ]);
}

// ── Bill detail / payment sheet ──────────────────────────────────────────────

class _BillDetailSheet extends StatefulWidget {
  const _BillDetailSheet({required this.bill, required this.onClose, required this.onChanged});
  final VendorBill bill;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  @override
  State<_BillDetailSheet> createState() => _BillDetailSheetState();
}

class _BillDetailSheetState extends State<_BillDetailSheet> {
  final _amountCtrl = TextEditingController();
  String _method = 'cash';
  bool   _paying = false;
  bool   _approving = false;
  bool   _showPayForm = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.bill.balanceDue.toString();
  }

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  Future<void> _pay() async {
    if (_paying) return;
    final amount = int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;
    setState(() => _paying = true);
    try {
      await VendorBillService.instance.recordPayment(widget.bill.id, {
        'amount': amount,
        'payment_method': _method,
        'paid_at': DateTime.now().toIso8601String().substring(0, 10),
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        showErrorToast(context, e);
      }
    }
  }

  Future<void> _cancelBill() async {
    try {
      await VendorBillService.instance.cancel(widget.bill.id);
      widget.onChanged();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _approve() async {
    if (_approving) return;
    setState(() => _approving = true);
    try {
      await VendorBillService.instance.approve(widget.bill.id);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _approving = false);
        showErrorToast(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: const Color(0xAA06070A),
        alignment: Alignment.center,
        child: PhoneModalBox(child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 460,
            decoration: BoxDecoration(
              color: context.pal.surface1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.pal.borderStrong),
              boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  Icon(Symbols.receipt, size: 18, color: AppColors.coral),
                  const SizedBox(width: 10),
                  Expanded(child: Text(bill.billNumber, style: AppTheme.bodyStrong)),
                  GestureDetector(onTap: widget.onClose, child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Row('Supplier', bill.supplierName ?? '—'),
                  _Row('Issue Date', bill.issueDate),
                  _Row('Due Date', bill.dueDate),
                  _Row('Subtotal', tshFromDouble(bill.subtotal)),
                  _Row('VAT (${bill.taxRate.toStringAsFixed(0)}%)', tshFromDouble(bill.taxAmount)),
                  _Row('Total', tshFromDouble(bill.total), bold: true),
                  _Row('Paid', tshFromDouble(bill.amountPaid), color: AppColors.teal),
                  if (bill.balanceDue > 0)
                    _Row('Balance Due', tshFromDouble(bill.balanceDue), color: AppColors.coral, bold: true),
                  if (bill.approvedByName != null)
                    _Row('Approved by', bill.approvedByName!, color: AppColors.teal)
                  else if (bill.canApprove)
                    _Row('Approval', 'Awaiting Director approval', color: AppColors.amber),
                  if (_showPayForm && bill.canPay) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _InlineField(controller: _amountCtrl, hint: 'Amount', number: true)),
                      const SizedBox(width: 8),
                      Expanded(child: DropdownFieldBox<String>(
                        value: _method,
                        items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                            DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                          ],
                        onChanged: (v) => setState(() => _method = v ?? 'cash'),
                      )),
                    ]),
                  ],
                ]),
              ),
              if (bill.canCancel) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: _cancelBill,
                      child: Container(height: 42,
                        decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('Cancel Bill', style: AppTheme.bodySm))),
                    )),
                    const SizedBox(width: 10),
                    if (bill.canApprove)
                      Expanded(flex: 2, child: GestureDetector(
                        onTap: _approve,
                        child: Container(height: 42,
                          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                          child: Center(child: _approving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Approve for Payment',
                                style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13)))),
                      ))
                    else if (bill.canPay)
                      Expanded(flex: 2, child: GestureDetector(
                        onTap: _showPayForm ? _pay : () => setState(() => _showPayForm = true),
                        child: Container(height: 42,
                          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                          child: Center(child: _paying
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_showPayForm ? 'Confirm Payment' : 'Record Payment',
                                style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13)))),
                      )),
                  ]),
                ),
              ],
            ]),
          ),
        )),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color, this.bold = false});
  final String label, value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 130, child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12.5))),
      Expanded(child: Text(value, style: AppTheme.bodySm.copyWith(
        color: color ?? context.pal.text,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
      ))),
    ]),
  );
}
