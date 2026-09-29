import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/hospital.dart';
import '../../models/inventory_item.dart';
import '../../models/invoice.dart';
import '../../services/hospital_service.dart';
import '../../services/inventory_service.dart';
import '../../services/invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../utils/tin.dart';
import '../../widgets/common/app_dropdown.dart';
import '../../widgets/common/labeled_field.dart';
import '../../widgets/sales/line_items.dart';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Raises an invoice directly — no quotation or sales order behind it
/// (POST /invoices). Quotations are a separate, optional sales document;
/// order-based invoicing still happens from the Sales Order after delivery.
/// Pops with the created [Invoice].
class InvoiceBuilderScreen extends StatefulWidget {
  const InvoiceBuilderScreen({super.key});

  @override
  State<InvoiceBuilderScreen> createState() => _InvoiceBuilderScreenState();
}

class _InvoiceBuilderScreenState extends State<InvoiceBuilderScreen> {
  final _clientCtrl  = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _tinCtrl     = TextEditingController();
  final _notesCtrl   = TextEditingController();
  Hospital? _hospital;
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate   = DateTime.now().add(const Duration(days: 30));
  String _currency    = 'TZS';
  int    _taxRate     = 0;
  bool   _saving      = false;
  final _lines = [LineItemEntry()];
  List<InventoryItem> _invItems = [];
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    InventoryService.instance.list().then((items) {
      if (mounted) setState(() => _invItems = items);
    }).catchError((_) {});
    for (final l in _lines) { _attach(l); }
  }

  void _attach(LineItemEntry l) {
    l.qtyCtrl.addListener(_recalc);
    l.priceCtrl.addListener(_recalc);
  }

  void _recalc() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _clientCtrl.dispose(); _contactCtrl.dispose();
    _emailCtrl.dispose();  _notesCtrl.dispose(); _tinCtrl.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  int get _subtotal => _lines.fold(0, (s, l) {
    final qty = int.tryParse(l.qtyCtrl.text) ?? 0;
    final price = int.tryParse(l.priceCtrl.text.replaceAll(',', '')) ?? 0;
    return s + qty * price;
  });
  // Same rounding as InvoiceController@store.
  int get _tax => (_subtotal * _taxRate / 100).round();

  void _pickHospital(Hospital? h) => setState(() {
    _hospital = h;
    _errors.remove('client');
    if (h != null) {
      _clientCtrl.text = h.name;
      if (h.contactName.isNotEmpty && h.contactName != '—') _contactCtrl.text = h.contactName;
      if (h.contactEmail.isNotEmpty && h.contactEmail != '—') _emailCtrl.text = h.contactEmail;
      if (h.tin != null) { _tinCtrl.text = h.tin!; _errors.remove('tin'); }
    }
  });

  bool _validate() {
    final errs = <String, String>{};
    if (_clientCtrl.text.trim().isEmpty) errs['client'] = 'Pick a client or type a client name';
    final tinErr = tinError(_tinCtrl.text);
    if (tinErr != null) errs['tin'] = tinErr;
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) errs['email'] = 'Enter a valid email';
    final valid = _lines.where((l) => l.descCtrl.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) errs['items'] = 'Add at least one line item';
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.descCtrl.text.trim().isEmpty) continue;
      final qty = int.tryParse(l.qtyCtrl.text);
      final price = int.tryParse(l.priceCtrl.text.replaceAll(',', ''));
      if (qty == null || qty <= 0) errs['items'] = 'Line ${i + 1}: enter a quantity';
      if (price == null || price < 0) errs['items'] = 'Line ${i + 1}: enter a unit price';
    }
    if (_dueDate.isBefore(DateTime(_issueDate.year, _issueDate.month, _issueDate.day))) {
      errs['due'] = 'Due date can’t be before the issue date';
    }
    setState(() => _errors = errs);
    return errs.isEmpty;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    try {
      final valid = _lines.where((l) => l.descCtrl.text.trim().isNotEmpty);
      final inv = await InvoiceService.instance.create({
        'hospital_id':    _hospital?.id,
        'client_name':    _clientCtrl.text.trim(),
        'client_contact': _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        'client_email':   _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'client_tin':     normalizeTin(_tinCtrl.text),
        'issue_date':     _isoDate(_issueDate),
        'due_date':       _isoDate(_dueDate),
        'tax_rate':       _taxRate,
        'currency':       _currency,
        'notes':          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'line_items': valid.map((l) => {
          'description': l.descCtrl.text.trim(),
          'quantity':    int.tryParse(l.qtyCtrl.text) ?? 1,
          'unit_price':  int.tryParse(l.priceCtrl.text.replaceAll(',', '')) ?? 0,
        }).toList(),
      });
      if (mounted) Navigator.of(context).pop<Invoice>(inv);
    } catch (e) {
      // Server-side messages (e.g. the client's credit limit) are shown as-is.
      if (mounted) setState(() { _saving = false; _errors = {'_server': friendlyError(e)}; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.pal.bg,
    appBar: AppBar(
      backgroundColor: context.pal.surface1,
      foregroundColor: context.pal.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 4,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('New invoice', style: AppTheme.bodyStrong.copyWith(fontSize: 15)),
        const SizedBox(width: 10),
        Text('direct — no quotation or order needed', style: AppTheme.bodySub.copyWith(fontSize: 11)),
      ]),
      actions: [
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Symbols.receipt_long, size: 14),
          label: const Text('Create invoice'),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: LayoutBuilder(builder: (ctx, cst) {
      final wide = cst.maxWidth >= 900;
      final left = _leftColumn(context);
      final right = SizedBox(width: wide ? 320 : double.infinity, child: _rightColumn(context));
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: left), const SizedBox(width: 16), right,
              ])
            : Column(children: [left, const SizedBox(height: 16), right]),
      );
    }),
  );

  BoxDecoration _card(BuildContext context) => BoxDecoration(
    color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border));

  Widget _error(String? msg) => msg == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 3), child: Text(msg, style: TextStyle(fontSize: 11, color: AppColors.coral)));

  Widget _leftColumn(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_errors['_server'] != null)
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Symbols.error_outline, size: 14, color: AppColors.coral),
          const SizedBox(width: 8),
          Expanded(child: Text(_errors['_server']!, style: TextStyle(fontSize: 12, color: AppColors.coral))),
        ]),
      ),
    // Client
    Container(
      padding: const EdgeInsets.all(15),
      decoration: _card(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CLIENT', style: AppTheme.labelCaps.copyWith(fontSize: 11)),
        const SizedBox(height: 11),
        AppSearchableSelectField<Hospital>(
          label: 'Find client in directory',
          hint: 'Type a hospital or client name…',
          selectedLabel: _hospital?.name,
          asyncSearch: (q) async => (await HospitalService.instance.search(q))
              .map((h) => AppSelectItem(value: h, label: h.name)).toList(),
          onSelected: (item) => _pickHospital(item?.value),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LabeledTextField(label: 'Client name *', controller: _clientCtrl, hint: 'Name printed on the invoice',
                hasError: _errors['client'] != null,
                onChanged: (_) { if (_errors.containsKey('client')) setState(() => _errors.remove('client')); }),
            _error(_errors['client']),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LabeledTextField(label: 'Client TIN *', controller: _tinCtrl, hint: '123-456-789',
                keyboardType: TextInputType.number, hasError: _errors['tin'] != null,
                onChanged: (_) { if (_errors.containsKey('tin')) setState(() => _errors.remove('tin')); }),
            _error(_errors['tin']),
          ])),
          const SizedBox(width: 12),
          Expanded(child: LabeledTextField(label: 'Contact', controller: _contactCtrl, hint: 'Person or phone')),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LabeledTextField(label: 'Email', controller: _emailCtrl, hint: 'client@hospital.tz',
                keyboardType: TextInputType.emailAddress, hasError: _errors['email'] != null),
            _error(_errors['email']),
          ])),
        ]),
      ]),
    ),
    const SizedBox(height: 14),
    // Line items
    Container(
      decoration: _card(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Symbols.playlist_add, size: 14, color: AppColors.amber),
              const SizedBox(width: 8),
              Text('Line items', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
              if (_errors['items'] != null) ...[
                const SizedBox(width: 8),
                Flexible(child: Text(_errors['items']!, style: TextStyle(fontSize: 11, color: AppColors.coral))),
              ],
              const Spacer(),
              Text('${_lines.length} line${_lines.length == 1 ? '' : 's'}',
                  style: AppTheme.monoXs.copyWith(fontSize: 10, color: context.pal.textMute)),
            ]),
            const SizedBox(height: 11),
            Row(children: [
              Expanded(flex: 3, child: Text('ITEM', style: AppTheme.monoXs.copyWith(fontSize: 9, color: context.pal.textMute))),
              SizedBox(width: 44, child: Text('QTY', textAlign: TextAlign.right, style: AppTheme.monoXs.copyWith(fontSize: 9, color: context.pal.textMute))),
              const SizedBox(width: 8),
              SizedBox(width: 90, child: Text('UNIT PRICE', textAlign: TextAlign.right, style: AppTheme.monoXs.copyWith(fontSize: 9, color: context.pal.textMute))),
              const SizedBox(width: 8),
              SizedBox(width: 96, child: Text('LINE TOTAL', textAlign: TextAlign.right, style: AppTheme.monoXs.copyWith(fontSize: 9, color: context.pal.textMute))),
              const SizedBox(width: 22),
            ]),
            Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Container(height: 1, color: context.pal.divider)),
            ..._lines.asMap().entries.map((e) => LineItemTableRow(
              key: ObjectKey(e.value),
              entry: e.value,
              invItems: _invItems,
              showDiscount: false,
              onRemove: _lines.length > 1
                  ? () => setState(() { _lines[e.key].dispose(); _lines.removeAt(e.key); })
                  : null,
              onChanged: () => setState(() {}),
            )),
            GestureDetector(
              onTap: () => setState(() { final l = LineItemEntry(); _attach(l); _lines.add(l); }),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 32,
                decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Symbols.add, size: 13, color: context.pal.textDim),
                  const SizedBox(width: 7),
                  Text('Add line', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                ]),
              ),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
          decoration: BoxDecoration(color: context.pal.surface2, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: SalesDateField(
              label: 'Issue date', selected: _issueDate, firstDate: DateTime(2020),
              onPicked: (d) { if (d != null) setState(() => _issueDate = d); },
            )),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SalesDateField(
                label: 'Due date', selected: _dueDate, firstDate: DateTime(2020),
                onPicked: (d) { if (d != null) setState(() { _dueDate = d; _errors.remove('due'); }); },
              ),
              _error(_errors['due']),
            ])),
            const SizedBox(width: 14),
            SizedBox(width: 100, child: _drop<int>('VAT', _taxRate, const {0: 'None', 18: '18%'}, (v) => setState(() => _taxRate = v))),
            const SizedBox(width: 14),
            SizedBox(width: 90, child: _drop<String>('Currency', _currency,
                const {'TZS': 'TZS', 'USD': 'USD', 'EUR': 'EUR', 'KES': 'KES'}, (v) => setState(() => _currency = v))),
          ]),
        ),
      ]),
    ),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(15),
      decoration: _card(context),
      child: LabeledTextField(label: 'Notes / payment terms', controller: _notesCtrl, maxLines: 3,
          hint: 'Bank details, payment terms, delivery notes…'),
    ),
  ]);

  Widget _drop<T>(String label, T value, Map<T, String> options, ValueChanged<T> onChanged) =>
      LabeledDropdown<T>(label: label, value: value, items: options.keys.toList(),
          displayBuilder: (v) => options[v]!, onChanged: onChanged);

  Widget _rightColumn(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: const EdgeInsets.all(15),
      decoration: _card(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TOTALS', style: AppTheme.labelCaps.copyWith(fontSize: 11)),
        const SizedBox(height: 10),
        _totalsRow(context, 'Subtotal', tshFromDouble(_subtotal.toDouble())),
        _totalsRow(context, _taxRate == 0 ? 'VAT' : 'VAT $_taxRate%', tshFromDouble(_tax.toDouble())),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Container(height: 1, color: context.pal.divider)),
        _totalsRow(context, 'TOTAL', tshFromDouble((_subtotal + _tax).toDouble()), big: true),
      ]),
    ),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(15),
      decoration: _card(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WHAT HAPPENS ON CREATE', style: AppTheme.labelCaps.copyWith(fontSize: 11)),
        const SizedBox(height: 12),
        _step(context, Symbols.tag, AppColors.teal, 'Gets the next invoice number', 'Status starts as Pending — send it to the client from the invoice.'),
        _step(context, Symbols.account_balance, AppColors.violet, 'Posted to receivables', 'Counts toward Outstanding and the client’s credit limit straight away.'),
        _step(context, Symbols.link_off, context.pal.textDim, 'Stands on its own',
            'Not linked to any quotation or sales order, and no stock is moved.', last: true),
      ]),
    ),
  ]);

  Widget _totalsRow(BuildContext context, String label, String value, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: big ? AppTheme.labelCaps.copyWith(fontSize: 10.5) : AppTheme.bodySub.copyWith(fontSize: 11.5)),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: context.pal.divider)),
      const SizedBox(width: 8),
      Text(value, style: (big ? AppTheme.kpiValue.copyWith(fontSize: 18) : AppTheme.monoSm.copyWith(fontSize: 12.5))
          .copyWith(color: context.pal.text)),
    ]),
  );

  Widget _step(BuildContext context, IconData icon, Color color, String title, String note, {bool last = false}) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 11),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTheme.bodySm.copyWith(fontSize: 11.5, color: color)),
        const SizedBox(height: 2),
        Text(note, style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
      ])),
    ]),
  );
}
