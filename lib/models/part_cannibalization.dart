enum CannibalizationStatus { open, replacementOrdered, resolved }

extension CannibalizationStatusX on CannibalizationStatus {
  String get label => switch (this) {
    CannibalizationStatus.open                => 'Open',
    CannibalizationStatus.replacementOrdered  => 'Replacement Ordered',
    CannibalizationStatus.resolved            => 'Resolved',
  };
}

CannibalizationStatus _parseStatus(String s) => switch (s) {
  'replacement_ordered' => CannibalizationStatus.replacementOrdered,
  'resolved'             => CannibalizationStatus.resolved,
  _                      => CannibalizationStatus.open,
};

class PartCannibalization {
  final int      id;
  final int      sourceSerialNumberId;
  final String?  sourceSerialNumber;
  final String?  sourceItemName;
  final String?  partName;
  final int?     partQty;
  final int?     destinationTicketId;
  final String?  destinationTicketNumber;
  final String?  destinationMachineName;
  final String?  removedByName;
  final String?  removedAt;
  final CannibalizationStatus status;
  final int?     replacementPurchaseOrderId;
  final String?  replacementPoNumber;
  final String?  replacementOrderedAt;
  final String?  replacementReceivedAt;
  final String?  resolvedAt;
  final String?  notes;
  final String?  createdAt;

  const PartCannibalization({
    required this.id,
    required this.sourceSerialNumberId,
    this.sourceSerialNumber,
    this.sourceItemName,
    this.partName,
    this.partQty,
    this.destinationTicketId,
    this.destinationTicketNumber,
    this.destinationMachineName,
    this.removedByName,
    this.removedAt,
    required this.status,
    this.replacementPurchaseOrderId,
    this.replacementPoNumber,
    this.replacementOrderedAt,
    this.replacementReceivedAt,
    this.resolvedAt,
    this.notes,
    this.createdAt,
  });

  factory PartCannibalization.fromJson(Map<String, dynamic> j) => PartCannibalization(
    id:                       (j['id'] as num).toInt(),
    sourceSerialNumberId:     (j['source_serial_number_id'] as num? ?? 0).toInt(),
    sourceSerialNumber:       j['source_serial_number'] as String?,
    sourceItemName:           j['source_item_name'] as String?,
    partName:                 j['part_name'] as String?,
    partQty:                  j['part_qty'] != null ? (j['part_qty'] as num).toInt() : null,
    destinationTicketId:      j['destination_ticket_id'] != null ? (j['destination_ticket_id'] as num).toInt() : null,
    destinationTicketNumber:  j['destination_ticket_number'] as String?,
    destinationMachineName:   j['destination_machine_name'] as String?,
    removedByName:            j['removed_by_name'] as String?,
    removedAt:                j['removed_at'] as String?,
    status:                   _parseStatus(j['status'] as String? ?? 'open'),
    replacementPurchaseOrderId: j['replacement_purchase_order_id'] != null ? (j['replacement_purchase_order_id'] as num).toInt() : null,
    replacementPoNumber:      j['replacement_po_number'] as String?,
    replacementOrderedAt:     j['replacement_ordered_at'] as String?,
    replacementReceivedAt:    j['replacement_received_at'] as String?,
    resolvedAt:               j['resolved_at'] as String?,
    notes:                    j['notes'] as String?,
    createdAt:                j['created_at'] as String?,
  );
}
