class PurchaseOrderItem {
  final int    id;
  final int    inventoryItemId;
  final String? itemName;
  final String? itemSku;
  final int    quantityOrdered;
  final int    quantityReceived;
  final double unitCost;
  final String currency;
  final double totalCost;
  final String? batchNumber;
  final String? expiryDate;
  final String? notes;

  const PurchaseOrderItem({
    required this.id,
    required this.inventoryItemId,
    this.itemName,
    this.itemSku,
    required this.quantityOrdered,
    this.quantityReceived = 0,
    required this.unitCost,
    this.currency = 'USD',
    required this.totalCost,
    this.batchNumber,
    this.expiryDate,
    this.notes,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> j) {
    final item = j['inventory_item'] as Map<String, dynamic>?;
    return PurchaseOrderItem(
      id:               (j['id'] as num).toInt(),
      inventoryItemId:  (j['inventory_item_id'] as num).toInt(),
      itemName:         item?['name'] as String?,
      itemSku:          item?['sku']  as String?,
      quantityOrdered:  (j['quantity_ordered']  as num? ?? 0).toInt(),
      quantityReceived: (j['quantity_received'] as num? ?? 0).toInt(),
      unitCost:         (j['unit_cost']         as num? ?? 0).toDouble(),
      currency:         j['currency']           as String? ?? 'USD',
      totalCost:        (j['total_cost']        as num? ?? 0).toDouble(),
      batchNumber:      j['batch_number']        as String?,
      expiryDate:       j['expiry_date']         as String?,
      notes:            j['notes']               as String?,
    );
  }

  bool get isFullyReceived => quantityReceived >= quantityOrdered;
}

class PurchaseOrder {
  final int    id;
  final String poNumber;
  final int?   supplierId;
  final String? supplierName;
  final String status;         // draft | sent | acknowledged | partially_received | received | cancelled
  final String? orderedByName;
  final DateTime? expectedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final DateTime? sentAt;
  final String currency;
  final double totalAmount;
  final String? shippingAddress;
  final String? terms;
  final String? notes;
  final DateTime createdAt;
  final List<PurchaseOrderItem> items;

  const PurchaseOrder({
    required this.id,
    required this.poNumber,
    this.supplierId,
    this.supplierName,
    required this.status,
    this.orderedByName,
    this.expectedDeliveryDate,
    this.actualDeliveryDate,
    this.sentAt,
    this.currency = 'USD',
    required this.totalAmount,
    this.shippingAddress,
    this.terms,
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) {
    final supplier   = j['supplier']   as Map<String, dynamic>?;
    final orderedBy  = j['ordered_by'] as Map<String, dynamic>?;

    return PurchaseOrder(
      id:                   (j['id'] as num).toInt(),
      poNumber:             j['po_number']       as String? ?? '—',
      supplierId:           j['supplier_id'] != null ? (j['supplier_id'] as num).toInt() : null,
      supplierName:         supplier?['name']    as String?,
      status:               j['status']          as String? ?? 'draft',
      orderedByName:        orderedBy?['name']   as String?,
      expectedDeliveryDate: j['expected_delivery_date'] != null
          ? DateTime.tryParse(j['expected_delivery_date'] as String) : null,
      actualDeliveryDate:   j['actual_delivery_date'] != null
          ? DateTime.tryParse(j['actual_delivery_date'] as String) : null,
      sentAt:               j['sent_at'] != null
          ? DateTime.tryParse(j['sent_at'] as String) : null,
      currency:             j['currency']        as String? ?? 'USD',
      totalAmount:          (j['total_amount']   as num? ?? 0).toDouble(),
      shippingAddress:      j['shipping_address'] as String?,
      terms:                j['terms']            as String?,
      notes:                j['notes']            as String?,
      createdAt:            DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      items:                (j['items'] as List? ?? [])
          .map((i) => PurchaseOrderItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }

  String get statusLabel => switch (status) {
    'draft'               => 'Draft',
    'sent'                => 'Sent',
    'acknowledged'        => 'Acknowledged',
    'partially_received'  => 'Partial GRN',
    'received'            => 'Received',
    'cancelled'           => 'Cancelled',
    _                     => status,
  };
}
