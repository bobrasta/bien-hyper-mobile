import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/expense.dart';
import '../../services/expense_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense>         _expenses   = [];
  List<ExpenseCategory> _categories = [];
  bool    _loading = true;
  String? _error;
  bool    _showCreate = false;

  double get _totalThisMonth {
    final now = DateTime.now();
    return _expenses.where((e) {
      final d = DateTime.tryParse(e.expenseDate);
      return d != null && d.year == now.year && d.month == now.month;
    }).fold(0, (s, e) => s + e.grossAmount);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ExpenseService.instance.list(),
        ExpenseService.instance.categories(),
      ]);
      if (!mounted) return;
      setState(() {
        _expenses   = results[0] as List<Expense>;
        _categories = results[1] as List<ExpenseCategory>;
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
                  Text('Expenses', style: AppTheme.pageTitle),
                  const SizedBox(height: 4),
                  Text('Operating expenses & petty cash', style: AppTheme.bodySub),
                ]);
                final action = AppButton(label: 'New Expense', icon: Symbols.add, variant: BtnVariant.primary,
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
                    _Kpi(label: 'This Month', value: tshFromDouble(_totalThisMonth), icon: Symbols.calendar_month, color: AppColors.coral),
                    _Kpi(label: 'Total Expenses', value: '${_expenses.length}', icon: Symbols.receipt_long, color: AppColors.amber),
                    _Kpi(label: 'Categories', value: '${_categories.length}', icon: Symbols.category, color: AppColors.blue),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: context.pal.surface1,
                    borderRadius: BorderRadius.circular(AppColors.rLg),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: HScrollTable(minWidth: 780, child: _ExpensesTable(expenses: _expenses)),
                ),
              ],
            ]),
          ),
        );
      }),
      if (_showCreate)
        _NewExpenseDialog(
          categories: _categories,
          onClose: () => setState(() => _showCreate = false),
          onSaved: () { setState(() => _showCreate = false); _load(); },
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

class _ExpensesTable extends StatelessWidget {
  const _ExpensesTable({required this.expenses});
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No expenses recorded', style: TextStyle(color: AppColors.textMute))),
      );
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.4),
        3: FlexColumnWidth(1.3),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(1.2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
          children: ['Description', 'Category', 'Amount', 'VAT', 'Method', 'Date'].map((h) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(h.toUpperCase(), style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
            )).toList(),
        ),
        ...expenses.asMap().entries.map((e) {
          final x = e.value;
          return TableRow(
            decoration: BoxDecoration(
              border: e.key == expenses.length - 1 ? null : Border(bottom: BorderSide(color: context.pal.divider)),
            ),
            children: [
              _TCell(child: Text(x.name, style: AppTheme.bodySm.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
              _TCell(child: Text(x.categoryName ?? '—', style: AppTheme.bodySub.copyWith(fontSize: 12))),
              _TCell(child: Text(tshFromDouble(x.grossAmount), style: AppTheme.monoSm.copyWith(color: AppColors.coral, fontSize: 12))),
              _TCell(child: Text(x.taxAmount > 0 ? tshFromDouble(x.taxAmount) : '—', style: AppTheme.monoXs)),
              _TCell(child: Text(x.paymentModeLabel, style: AppTheme.bodySub.copyWith(fontSize: 11.5))),
              _TCell(child: Text(x.expenseDate, style: AppTheme.monoXs)),
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

// ── New Expense Dialog ──────────────────────────────────────────────────────────

class _NewExpenseDialog extends StatefulWidget {
  const _NewExpenseDialog({required this.categories, required this.onClose, required this.onSaved});
  final List<ExpenseCategory> categories;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_NewExpenseDialog> createState() => _NewExpenseDialogState();
}

class _NewExpenseDialogState extends State<_NewExpenseDialog> {
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl    = TextEditingController();
  int?    _categoryId;
  double  _taxRate   = 18;
  String  _paymentMode = 'cash';
  bool    _saving  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) _categoryId = widget.categories.first.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _amountCtrl.dispose(); _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (_nameCtrl.text.trim().isEmpty || amount <= 0 || _categoryId == null) {
      setState(() => _error = 'Please fill in description, category and a valid amount.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ExpenseService.instance.create({
        'name':         _nameCtrl.text.trim(),
        'category_id':  _categoryId,
        'amount':       amount,
        'tax_rate':     _taxRate,
        'payment_mode': _paymentMode,
        'expense_date': DateTime.now().toIso8601String().substring(0, 10),
        'reference':    _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
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
          width: 480,
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
                const Icon(Symbols.receipt_long, size: 18, color: AppColors.coral),
                const SizedBox(width: 10),
                Text('New Expense', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose, child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12)),
                  ),
                ],
                _LabeledField('Description', TextField(controller: _nameCtrl, style: AppTheme.bodySm,
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'e.g. Office rent'))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _LabeledDropdown(
                    label: 'Category',
                    value: _categoryId,
                    items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _LabeledDropdown(
                    label: 'Payment Mode',
                    value: _paymentMode,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                      DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                    ],
                    onChanged: (v) => setState(() => _paymentMode = v ?? 'cash'),
                  )),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _LabeledField('Amount (TSh, excl. VAT)', TextField(controller: _amountCtrl,
                      keyboardType: TextInputType.number, style: AppTheme.bodySm,
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '0')))),
                  const SizedBox(width: 14),
                  Expanded(child: _LabeledDropdown(
                    label: 'VAT %',
                    value: _taxRate,
                    items: const [
                      DropdownMenuItem(value: 0.0,  child: Text('0%')),
                      DropdownMenuItem(value: 18.0, child: Text('18%')),
                    ],
                    onChanged: (v) => setState(() => _taxRate = v ?? 0),
                  )),
                ]),
                const SizedBox(height: 14),
                _LabeledField('Reference (optional)', TextField(controller: _refCtrl, style: AppTheme.bodySm,
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Receipt / invoice no.'))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      : Text('Save Expense', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13)))))),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField(this.label, this.field);
  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      height: 38,
      decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(child: field),
    ),
  ]);
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({required this.label, required this.value, required this.items, required this.onChanged});
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
