class SparePart {
  final int    id;
  final String sku;
  final String name;
  final String category;       // machine_part | consumable | accessory | equipment | other
  final String unitOfMeasure;  // piece | box | litre | set | kg | roll
  final double unitCost;
  final String currency;
  final int    stockQty;
  final int    reorderLevel;
  final bool   isLowStock;
  final String supplier;
  final bool   isActive;
  final List<String> compatibleModels;

  const SparePart({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.unitOfMeasure,
    required this.unitCost,
    this.currency = 'TZS',
    required this.stockQty,
    required this.reorderLevel,
    required this.isLowStock,
    required this.supplier,
    this.isActive = true,
    this.compatibleModels = const [],
  });

  factory SparePart.fromJson(Map<String, dynamic> j) => SparePart(
    id:             (j['id'] as num).toInt(),
    sku:            j['sku']           as String? ?? j['part_number'] as String? ?? '—',
    name:           j['name']          as String? ?? '—',
    category:       j['category']      as String? ?? 'machine_part',
    unitOfMeasure:  j['unit_of_measure'] as String? ?? 'piece',
    unitCost:       (j['unit_cost']    as num? ?? 0).toDouble(),
    currency:       j['currency']      as String? ?? 'TZS',
    stockQty:       (j['stock_qty']    as num? ?? 0).toInt(),
    reorderLevel:   (j['reorder_level'] as num? ?? 0).toInt(),
    isLowStock:     j['is_low_stock']  as bool? ?? false,
    supplier:       j['supplier']      as String? ?? '—',
    isActive:       j['is_active']     as bool? ?? true,
    compatibleModels: (j['compatible_models'] as List? ?? [])
        .map((e) => e.toString()).toList(),
  );

  bool get isOutOfStock => stockQty == 0;

  // Keep partNumber as alias for backward compat with service ticket add-part dialog
  String get partNumber => sku;
  String get description => category;
}
