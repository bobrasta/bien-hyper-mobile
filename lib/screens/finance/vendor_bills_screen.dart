import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/expense.dart';
import '../../models/supplier.dart';
import '../../models/vendor_bill.dart';
import '../../services/expense_service.dart';
import '../../services/supplier_service.dart';
import '../../services/vendor_bill_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

class VendorBillsScreen extends StatefulWidget {
  const VendorBillsScreen({super.key});

  @override
  State<VendorBillsScreen> createState() => _VendorBillsScreenState();
}

class _VendorBillsScreenState extends State<VendorBillsScreen> {
  List<VendorBill>      _bills      = [];
  List<Supplier>        _suppliers  = [];
  List<ExpenseCategory> _categories = [];
  bool    _loading = true;
  String? _error;
  bool    _showCreate = false;
  VendorBill? _selected;

  int get _totalPayable => _bills.where((b) => !b.isPaid && b.status != 'cancelled').fold(0, (s, b) => s + b.balanceDue);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
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

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      LayoutBuilder(builder: (ctx, cst) {
        final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(pad),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (ctx, cst) {
                final narrow = cst.maxWidth < 560;
                final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Accounts Payable', style: AppTheme.pageTitle),
                  const SizedBox(height: 4),
                  Text('Vendor bills & supplier payments', style: AppTheme.bodySub),
                ]);
                final action = AppButton(label: 'New Bill', icon: Symbols.add, variant: BtnVariant.primary,
                    onPressed: () => setState(() => _showCreate = true));
                if (narrow) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    titleBlock, const SizedBox(height: 12), action,
                  ]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  titleBlock, const Spacer(), action,
                ]);
              }),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else if (_error != null)
                ErrorView(message: _error!, onRetry: _load)
              else ...[
                AdaptiveColumns(
                  wideCols: 3, mediumCols: 2, narrowCols: 1,
                  children: [
                    _Kpi(label: 'Outstanding Payable', value: tshFromDouble(_totalPayable), icon: Symbols.account_balance_wallet, color: AppColors.coral),
                    _Kpi(label: 'Total Bills', value: '${_bills.length}', icon: Symbols.receipt_long, color: AppColors.amber),
                    _Kpi(label: 'Suppliers', value: '${_suppliers.length}', icon: Symbols.business, color: AppColors.blue),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: context.pal.surface1,
                    borderRadius: BorderRadius.circular(AppColors.rLg),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: HScrollTable(minWidth: 800, child: _BillsTable(
                    bills: _bills,
                    onSelect: (b) => setState(() => _selected = b),
                  )),
                ),
              ],
            ]),
          ),
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
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 19, color: color),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 20)),
      ])),
    ]),
  );
}

class _BillsTable extends StatelessWidget {
  const _BillsTable({required this.bills, required this.onSelect});
  final List<VendorBill> bills;
  final ValueChanged<VendorBill> onSelect;

  Color _statusColor(String s) => switch (s) {
    'paid'      => AppColors.teal,
    'partial'   => AppColors.blue,
    'overdue'   => AppColors.coral,
    'cancelled' => AppColors.textMute,
    _           => AppColors.amber,
  };

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No vendor bills yet', style: TextStyle(color: AppColors.textMute))),
      );
    }
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(120),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.3),
        4: FlexColumnWidth(1),
        5: FixedColumnWidth(80),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
          children: ['Bill No.', 'Supplier', 'Total', 'Due Date', 'Status', ''].map((h) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(h.toUpperCase(), style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
            )).toList(),
        ),
        ...bills.asMap().entries.map((e) {
          final b = e.value;
          final color = _statusColor(b.status);
          return TableRow(
            decoration: BoxDecoration(
              border: e.key == bills.length - 1 ? null : Border(bottom: BorderSide(color: context.pal.divider)),
            ),
            children: [
              _TCell(child: Text(b.billNumber, style: AppTheme.monoXs.copyWith(color: context.pal.textMute))),
              _TCell(child: Text(b.supplierName ?? '—', style: AppTheme.bodySm.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
              _TCell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tshFromDouble(b.total), style: AppTheme.monoSm.copyWith(color: AppColors.amber, fontSize: 12)),
                if (b.balanceDue > 0)
                  Text('Due: ${tshFromDouble(b.balanceDue)}', style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: AppColors.coral)),
              ])),
              _TCell(child: Text(b.dueDate, style: AppTheme.monoXs)),
              _TCell(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(b.statusLabel, style: AppTheme.bodySub.copyWith(color: color, fontSize: 11.5, fontWeight: FontWeight.w500)),
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: GestureDetector(
                  onTap: () => onSelect(b),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: b.canPay ? AppColors.teal : context.pal.surface3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(b.canPay ? 'Pay' : 'View', style: AppTheme.bodySub.copyWith(
                      color: b.canPay ? const Color(0xFF06120F) : context.pal.textMute,
                      fontSize: 11.5, fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _TCell extends StatelessWidget {
  const _TCell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: child,
  );
}

// ── New Bill Dialog ──────────────────────────────────────────────────────────────

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
  final _lines = [_BillLineEntry()];
  bool   _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.suppliers.isNotEmpty) _supplierId = widget.suppliers.first.id;
    if (widget.categories.isNotEmpty) _categoryId = widget.categories.first.id;
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
      child: GestureDetector(
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
                const Icon(Symbols.receipt_long, size: 18, color: AppColors.coral),
                const SizedBox(width: 10),
                Text('New Vendor Bill', style: AppTheme.bodyStrong),
                const Spacer(),
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
                    child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12)),
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
                  SizedBox(width: 90, child: _Dropdown<double>(
                    label: 'VAT %',
                    value: _taxRate,
                    items: const [
                      DropdownMenuItem(value: 0.0, child: Text('0%')),
                      DropdownMenuItem(value: 18.0, child: Text('18%')),
                    ],
                    onChanged: (v) => setState(() => _taxRate = v ?? 0),
                  )),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Text('Line Items', style: AppTheme.bodyStrong),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _lines.add(_BillLineEntry())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.teal), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Symbols.add, size: 14, color: AppColors.teal),
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
      ),
    ),
  );
}

class _InlineField extends StatelessWidget {
  const _InlineField({required this.controller, required this.hint, this.number = false});
  final TextEditingController controller;
  final String hint;
  final bool number;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(7), border: Border.all(color: context.pal.border)),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Center(child: TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: AppTheme.bodySm.copyWith(fontSize: 12.5),
      decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: hint,
          hintStyle: AppTheme.bodySub.copyWith(fontSize: 12, color: context.pal.textDim)),
    )),
  );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      height: 38,
      decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<T>(
        value: value, isExpanded: true, dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items, onChanged: onChanged,
      )),
    ),
  ]);
}

// ── Bill detail / payment sheet ───────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: const Color(0xAA06070A),
        alignment: Alignment.center,
        child: GestureDetector(
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
                  const Icon(Symbols.receipt, size: 18, color: AppColors.coral),
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
                  if (_showPayForm && bill.canPay) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _InlineField(controller: _amountCtrl, hint: 'Amount', number: true)),
                      const SizedBox(width: 8),
                      Expanded(child: Container(
                        height: 36,
                        decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(7), border: Border.all(color: context.pal.border)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                          value: _method, isExpanded: true, dropdownColor: context.pal.surface2,
                          style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                          icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                            DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                          ],
                          onChanged: (v) => setState(() => _method = v ?? 'cash'),
                        )),
                      )),
                    ]),
                  ],
                ]),
              ),
              if (bill.canPay) ...[
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
        ),
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
