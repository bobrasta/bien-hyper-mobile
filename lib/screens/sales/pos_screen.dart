import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/hospital.dart';
import '../../models/invoice.dart';
import '../../models/inventory_item.dart';
import '../../models/location.dart';
import '../../models/sales_order.dart';
import '../../services/hospital_service.dart';
import '../../services/inventory_service.dart';
import '../../services/location_service.dart';
import '../../services/pos_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmtAmount(int tzs) {
  final s = tzs.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${tzs < 0 ? '-' : ''}TSh $buf';
}

const _paymentMethods = [
  ('cash', 'Cash'),
  ('bank_transfer', 'Bank Transfer'),
  ('mobile_money', 'Mobile Money'),
  ('cheque', 'Cheque'),
];

// ── Cart line ────────────────────────────────────────────────────────────────

class _CartLine {
  _CartLine({this.inventoryItem, String description = '', int qty = 1, int unitPrice = 0})
      : descCtrl  = TextEditingController(text: description),
        qtyCtrl   = TextEditingController(text: qty.toString()),
        priceCtrl = TextEditingController(text: unitPrice.toString());

  final InventoryItem? inventoryItem;
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  int get qty       => int.tryParse(qtyCtrl.text) ?? 0;
  int get unitPrice  => int.tryParse(priceCtrl.text) ?? 0;
  int get lineTotal  => qty * unitPrice;

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  bool    _loading = true;
  String? _error;

  List<InventoryItem> _catalog   = [];
  List<Location>       _locations = [];
  List<Hospital>        _hospitals = [];

  int? _locationId;
  int? _hospitalId;
  final List<_CartLine> _cart = [];

  final _searchCtrl      = TextEditingController();
  final _clientNameCtrl  = TextEditingController();
  final _discountCtrl    = TextEditingController(text: '0');
  final _taxCtrl         = TextEditingController(text: '0');
  final _paymentRefCtrl  = TextEditingController();
  String _paymentMethod  = 'cash';
  bool   _checkingOut    = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _clientNameCtrl.dispose();
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    _paymentRefCtrl.dispose();
    for (final line in _cart) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        InventoryService.instance.list(),
        LocationService.instance.list(),
        HospitalService.instance.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog   = results[0] as List<InventoryItem>;
        _locations = results[1] as List<Location>;
        _hospitals = results[2] as List<Hospital>;
        _locationId ??= _locations.isNotEmpty ? _locations.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  List<InventoryItem> get _filteredCatalog {
    final q = _searchCtrl.text.trim().toLowerCase();
    final active = _catalog.where((i) => i.isActive);
    if (q.isEmpty) return active.take(60).toList();
    return active.where((i) =>
        i.name.toLowerCase().contains(q) ||
        i.sku.toLowerCase().contains(q) ||
        (i.barcode?.toLowerCase().contains(q) ?? false)
    ).take(60).toList();
  }

  void _addToCart(InventoryItem item) {
    final existing = _cart.where((l) => l.inventoryItem?.id == item.id).firstOrNull;
    if (existing != null) {
      setState(() => existing.qtyCtrl.text = (existing.qty + 1).toString());
      return;
    }
    setState(() => _cart.add(_CartLine(
      inventoryItem: item,
      description: item.name,
      qty: 1,
      unitPrice: item.unitCost.round(),
    )));
  }

  void _addCustomLine() {
    setState(() => _cart.add(_CartLine(description: '', qty: 1, unitPrice: 0)));
  }

  void _removeLine(_CartLine line) {
    setState(() { _cart.remove(line); line.dispose(); });
  }

  void _onScanSubmit(String value) {
    final q = value.trim().toLowerCase();
    if (q.isEmpty) return;
    final match = _catalog.where((i) =>
        i.isActive && (i.sku.toLowerCase() == q || i.barcode?.toLowerCase() == q)
    ).firstOrNull;
    if (match != null) {
      _addToCart(match);
      _searchCtrl.clear();
    }
  }

  int get _subtotal => _cart.fold(0, (sum, l) => sum + l.lineTotal);
  int get _discount  => int.tryParse(_discountCtrl.text) ?? 0;
  int get _tax       => int.tryParse(_taxCtrl.text) ?? 0;
  int get _total     => _subtotal - _discount + _tax;

  bool get _canCheckout =>
      !_checkingOut && _locationId != null && _cart.isNotEmpty &&
      _cart.every((l) => l.qty > 0 && l.descCtrl.text.trim().isNotEmpty);

  Future<void> _checkout() async {
    if (!_canCheckout) return;
    setState(() => _checkingOut = true);
    try {
      final result = await PosService.instance.checkout({
        'client_name':   _clientNameCtrl.text.trim().isEmpty ? null : _clientNameCtrl.text.trim(),
        'hospital_id':   _hospitalId,
        'location_id':   _locationId,
        'discount_amount': _discount,
        'tax_amount':    _tax,
        'payment_method': _paymentMethod,
        'payment_reference': _paymentRefCtrl.text.trim().isEmpty ? null : _paymentRefCtrl.text.trim(),
        'items': _cart.map((l) => {
          'inventory_item_id': l.inventoryItem?.id,
          'description':       l.descCtrl.text.trim(),
          'unit_of_measure':   l.inventoryItem?.unitOfMeasure ?? 'pcs',
          'quantity':          l.qty,
          'unit_price':        l.unitPrice,
        }).toList(),
      });

      if (!mounted) return;
      setState(() => _checkingOut = false);

      if (result is PosCheckoutInvoice) {
        await showDialog<void>(
          context: context,
          builder: (_) => _ReceiptDialog(salesOrder: result.salesOrder, invoice: result.invoice),
        );
      } else if (result is PosCheckoutPendingApproval) {
        await showDialog<void>(
          context: context,
          builder: (_) => _PendingApprovalDialog(
            orderNumber: result.salesOrder.orderNumber, message: result.message),
        );
      }
      if (mounted) _resetSale();
      _load();
    } catch (e) {
      if (mounted) {
        setState(() => _checkingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  void _resetSale() {
    for (final line in _cart) {
      line.dispose();
    }
    setState(() {
      _cart.clear();
      _clientNameCtrl.clear();
      _discountCtrl.text = '0';
      _taxCtrl.text = '0';
      _paymentRefCtrl.clear();
      _paymentMethod = 'cash';
      _hospitalId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Point of Sale', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Counter checkout — confirm, deliver, invoice and pay in one step',
                style: AppTheme.bodySub),
          ]),
          const Spacer(),
          AppButton(label: 'Refresh Stock', icon: Symbols.refresh, variant: BtnVariant.ghost, onPressed: _load),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, cst) {
          final narrow = cst.maxWidth < 900;
          final catalog = _buildCatalogPanel(context);
          final cart    = _buildCartPanel(context);
          if (narrow) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                SizedBox(height: 420, child: catalog),
                const SizedBox(height: 16),
                cart,
              ]),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: catalog),
              const SizedBox(width: 16),
              SizedBox(width: 400, child: cart),
            ]),
          );
        }),
      ),
    ]);
  }

  // ── Catalog panel ──────────────────────────────────────────────────────────

  Widget _buildCatalogPanel(BuildContext context) {
    final items = _filteredCatalog;
    return Container(
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            onSubmitted: _onScanSubmit,
            style: AppTheme.bodySm,
            decoration: InputDecoration(
              hintText: 'Scan barcode or search by name / SKU…',
              hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
              prefixIcon: Icon(Symbols.barcode_scanner, size: 18, color: context.pal.textDim),
              filled: true, fillColor: context.pal.surface2,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.pal.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.pal.border)),
            ),
          ),
        ),
        Divider(height: 1, color: context.pal.border),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('No items found', style: AppTheme.bodySub))
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220, mainAxisExtent: 96, crossAxisSpacing: 10, mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogTile(context, items[i]),
                ),
        ),
      ]),
    );
  }

  Widget _catalogTile(BuildContext context, InventoryItem item) {
    final outOfStock = item.isOutOfStock;
    return GestureDetector(
      onTap: outOfStock ? null : () => _addToCart(item),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.pal.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500, fontSize: 12)),
          const Spacer(),
          Text(item.sku, style: AppTheme.monoXs.copyWith(color: context.pal.textDim, fontSize: 10)),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(child: Text(_fmtAmount(item.unitCost.round()),
                style: AppTheme.bodySm.copyWith(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600))),
            Text(outOfStock ? 'Out' : '${item.stockQty}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: outOfStock ? AppColors.coral : (item.isLowStock ? AppColors.amber : context.pal.textDim))),
          ]),
        ]),
      ),
    );
  }

  // ── Cart / checkout panel ──────────────────────────────────────────────────

  Widget _buildCartPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.pal.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.shopping_cart, size: 16, color: AppColors.teal),
          const SizedBox(width: 6),
          Text('Cart (${_cart.length})', style: AppTheme.bodyStrong),
          const Spacer(),
          GestureDetector(
            onTap: _addCustomLine,
            child: Row(children: [
              Icon(Symbols.add, size: 14, color: AppColors.teal),
              const SizedBox(width: 2),
              Text('Custom item', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 11.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),

        if (_cart.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Cart is empty — tap an item to add it', style: AppTheme.bodySub)),
          )
        else
          ..._cart.map((line) => _cartLineTile(context, line)),

        const SizedBox(height: 12),
        Divider(height: 1, color: context.pal.border),
        const SizedBox(height: 12),

        _field('Client Name (optional)', _clientNameCtrl, context, hint: 'Walk-in Customer'),
        const SizedBox(height: 10),
        _hospitalDropdown(context),
        const SizedBox(height: 10),
        _locationDropdown(context),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field('Discount', _discountCtrl, context, numeric: true, onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: _field('Tax', _taxCtrl, context, numeric: true, onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 10),
        _paymentMethodDropdown(context),
        const SizedBox(height: 10),
        _field('Payment Reference (optional)', _paymentRefCtrl, context, hint: 'Txn ID / cheque no.'),
        const SizedBox(height: 14),

        _totalsBox(context),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: _checkingOut
              ? const Center(child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2)))
              : AppButton(
                  label: 'Checkout — ${_fmtAmount(_total)}',
                  icon: Symbols.point_of_sale,
                  variant: BtnVariant.primary,
                  onPressed: _canCheckout ? _checkout : null,
                ),
        ),
      ]),
    );
  }

  Widget _cartLineTile(BuildContext context, _CartLine line) {
    final isCustom = line.inventoryItem == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.pal.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: isCustom
                ? TextField(
                    controller: line.descCtrl,
                    onChanged: (_) => setState(() {}),
                    style: AppTheme.bodySm.copyWith(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Description', isDense: true, border: InputBorder.none,
                      hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim, fontSize: 12),
                    ),
                  )
                : Text(line.descCtrl.text, style: AppTheme.bodySm.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500)),
          ),
          GestureDetector(onTap: () => _removeLine(line),
              child: Icon(Symbols.close, size: 15, color: context.pal.textDim)),
        ]),
        if (line.inventoryItem != null)
          Text(line.inventoryItem!.sku, style: AppTheme.monoXs.copyWith(color: context.pal.textDim, fontSize: 10)),
        const SizedBox(height: 6),
        Row(children: [
          _qtyStepper(context, line),
          const SizedBox(width: 8),
          Expanded(
            child: _miniPriceField('Unit price', line.priceCtrl, context),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(_fmtAmount(line.lineTotal), textAlign: TextAlign.right,
                style: AppTheme.bodySm.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  Widget _qtyStepper(BuildContext context, _CartLine line) => Container(
    height: 30,
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: context.pal.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => setState(() {
          final q = line.qty - 1;
          line.qtyCtrl.text = (q < 1 ? 1 : q).toString();
        }),
        child: SizedBox(width: 26, child: Icon(Symbols.remove, size: 13, color: context.pal.textDim)),
      ),
      SizedBox(
        width: 32,
        child: TextField(
          controller: line.qtyCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
          style: AppTheme.bodySm.copyWith(fontSize: 12),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        ),
      ),
      GestureDetector(
        onTap: () => setState(() => line.qtyCtrl.text = (line.qty + 1).toString()),
        child: SizedBox(width: 26, child: Icon(Symbols.add, size: 13, color: context.pal.textDim)),
      ),
    ]),
  );

  Widget _miniPriceField(String hint, TextEditingController ctrl, BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: context.pal.border),
    ),
    child: Center(child: TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      style: AppTheme.bodySm.copyWith(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint, hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim, fontSize: 11),
        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
      ),
    )),
  );

  Widget _field(String label, TextEditingController ctrl, BuildContext context,
      {String? hint, bool numeric = false, ValueChanged<String>? onChanged}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
        const SizedBox(height: 5),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: context.pal.border),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            onChanged: onChanged,
            style: AppTheme.bodySm,
            decoration: InputDecoration(
              hintText: hint, hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ]);

  Widget _locationDropdown(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('SHIP FROM LOCATION', style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
      const SizedBox(height: 5),
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: context.pal.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: context.pal.border),
        ),
        child: DropdownButtonHideUnderline(child: DropdownButton<int>(
          value: _locationId, isExpanded: true,
          dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
          icon: Icon(Symbols.expand_more, size: 14, color: context.pal.textDim),
          items: _locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
          onChanged: (v) => setState(() => _locationId = v),
        )),
      ),
    ],
  );

  Widget _hospitalDropdown(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('HOSPITAL (OPTIONAL)', style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
      const SizedBox(height: 5),
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: context.pal.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: context.pal.border),
        ),
        child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
          value: _hospitalId, isExpanded: true,
          hint: Text('— Walk-in —', style: AppTheme.bodySub.copyWith(fontSize: 12)),
          dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
          icon: Icon(Symbols.expand_more, size: 14, color: context.pal.textDim),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('— Walk-in —')),
            ..._hospitals.map((h) => DropdownMenuItem<int?>(value: h.id, child: Text(h.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => setState(() => _hospitalId = v),
        )),
      ),
    ],
  );

  Widget _paymentMethodDropdown(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('PAYMENT METHOD', style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
      const SizedBox(height: 5),
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: context.pal.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: context.pal.border),
        ),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _paymentMethod, isExpanded: true,
          dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
          icon: Icon(Symbols.expand_more, size: 14, color: context.pal.textDim),
          items: _paymentMethods.map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2))).toList(),
          onChanged: (v) { if (v != null) setState(() => _paymentMethod = v); },
        )),
      ),
    ],
  );

  Widget _totalsBox(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.pal.surface2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(children: [
      _totalRow('Subtotal', _subtotal),
      if (_discount > 0) _totalRow('Discount', -_discount, color: AppColors.coral),
      if (_tax > 0) _totalRow('Tax', _tax),
      const Divider(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Total', style: AppTheme.bodyStrong),
        Text(_fmtAmount(_total), style: AppTheme.bodyStrong.copyWith(color: AppColors.amber, fontSize: 15)),
      ]),
    ]),
  );

  Widget _totalRow(String label, int amount, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppTheme.bodySub),
      Text(amount < 0 ? '-${_fmtAmount(-amount)}' : _fmtAmount(amount),
          style: AppTheme.bodySub.copyWith(color: color)),
    ]),
  );
}

// ── Receipt dialog ─────────────────────────────────────────────────────────────

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.salesOrder, required this.invoice});
  final SalesOrder salesOrder;
  final Invoice invoice;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Container(
      width: 420,
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.check_circle, size: 22, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(child: Text('Sale Complete', style: AppTheme.pageTitle.copyWith(fontSize: 16))),
        ]),
        const SizedBox(height: 4),
        Text(invoice.invoiceNumber, style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
        const SizedBox(height: 16),

        ...salesOrder.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text('${item.quantityOrdered}× ${item.description}', style: AppTheme.bodySm)),
            Text(_fmtAmount(item.totalPrice), style: AppTheme.bodySm),
          ]),
        )),
        const Divider(height: 20),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total Paid', style: AppTheme.bodyStrong),
          Text(_fmtAmount(invoice.total),
              style: AppTheme.bodyStrong.copyWith(color: AppColors.amber, fontSize: 16)),
        ]),
        const SizedBox(height: 4),
        if (invoice.payments.isNotEmpty)
          Text('Paid via ${invoice.payments.first.methodLabel}', style: AppTheme.bodySub),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: AppButton(label: 'New Sale', icon: Symbols.point_of_sale,
              variant: BtnVariant.primary, onPressed: () => Navigator.pop(context)),
        ),
      ]),
    ),
  );
}

// ── Pending-approval dialog ─────────────────────────────────────────────────────

class _PendingApprovalDialog extends StatelessWidget {
  const _PendingApprovalDialog({required this.orderNumber, required this.message});
  final String orderNumber;
  final String message;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Container(
      width: 420,
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.hourglass_top, size: 22, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(child: Text('Needs Manager Approval', style: AppTheme.pageTitle.copyWith(fontSize: 15))),
        ]),
        const SizedBox(height: 8),
        Text(orderNumber, style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
        const SizedBox(height: 10),
        Text(message, style: AppTheme.bodySm),
        const SizedBox(height: 6),
        Text('The sale has been saved as a pending order under Sales → Orders — it will complete once approved.',
            style: AppTheme.bodySub),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: AppButton(label: 'OK', variant: BtnVariant.normal, onPressed: () => Navigator.pop(context)),
        ),
      ]),
    ),
  );
}
