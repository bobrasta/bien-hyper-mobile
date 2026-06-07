class InventoryItem {
  final int    id;
  final String sku;
  final String name;
  final String? description;
  final String category;
  final String unitOfMeasure;
  final double unitCost;
  final String currency;
  final int    stockQty;
  final int    reorderLevel;
  final bool   isLowStock;
  final String supplier;
  final bool   isActive;
  // v2 enriched fields
  final String? manufacturer;
  final String? barcode;
  final bool    hasCe;
  final bool    hasFda;
  final bool    hasTbs;
  final Map<String, dynamic> specifications;
  final int?    preferredSupplierId;
  final List<String> compatibleModels;

  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    this.description,
    required this.category,
    required this.unitOfMeasure,
    required this.unitCost,
    this.currency = 'TZS',
    required this.stockQty,
    required this.reorderLevel,
    required this.isLowStock,
    this.supplier = '',
    this.isActive = true,
    this.manufacturer,
    this.barcode,
    this.hasCe  = false,
    this.hasFda = false,
    this.hasTbs = false,
    this.specifications = const {},
    this.preferredSupplierId,
    this.compatibleModels = const [],
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
    id:            (j['id'] as num).toInt(),
    sku:           j['sku']             as String? ?? j['part_number'] as String? ?? '—',
    name:          j['name']            as String? ?? '—',
    description:   j['description']     as String?,
    category:      j['category']        as String? ?? 'other',
    unitOfMeasure: j['unit_of_measure'] as String? ?? 'piece',
    unitCost:      (j['unit_cost']      as num? ?? 0).toDouble(),
    currency:      j['currency']        as String? ?? 'TZS',
    stockQty:      (j['stock_qty']      as num? ?? 0).toInt(),
    reorderLevel:  (j['reorder_level']  as num? ?? 0).toInt(),
    isLowStock:    j['is_low_stock']    as bool? ?? false,
    supplier:      j['supplier']        as String? ?? '',
    isActive:      j['is_active']       as bool? ?? true,
    manufacturer:  j['manufacturer']    as String?,
    barcode:       j['barcode']         as String?,
    hasCe:         j['has_ce']          as bool? ?? false,
    hasFda:        j['has_fda']         as bool? ?? false,
    hasTbs:        j['has_tbs']         as bool? ?? false,
    specifications: j['specifications'] is Map
        ? Map<String, dynamic>.from(j['specifications'] as Map)
        : <String, dynamic>{},
    preferredSupplierId: j['preferred_supplier_id'] != null
        ? (j['preferred_supplier_id'] as num).toInt()
        : null,
    compatibleModels: (j['compatible_models'] as List? ?? [])
        .map((e) => e.toString()).toList(),
  );

  bool get isOutOfStock => stockQty == 0;

  // Backward-compat aliases used by service ticket screen
  String get partNumber => sku;
}
