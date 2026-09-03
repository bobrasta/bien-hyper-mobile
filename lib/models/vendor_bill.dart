class VendorBillLineItem {
  final int    id;
  final String description;
  final double quantity;
  final int    unitPrice;
  final int    total;

  const VendorBillLineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory VendorBillLineItem.fromJson(Map<String, dynamic> j) => VendorBillLineItem(
    id:          (j['id'] as num? ?? 0).toInt(),
    description: j['description'] as String? ?? '',
    quantity:    (j['quantity'] as num? ?? 1).toDouble(),
    unitPrice:   (j['unit_price'] as num? ?? 0).toInt(),
    total:       (j['total'] as num? ?? 0).toInt(),
  );
}

class VendorBillPayment {
  final int    id;
  final String paymentNumber;
  final int    amount;
  final String paymentMethod;
  final String? reference;
  final String paidAt;
  final String? recordedBy;

  const VendorBillPayment({
    required this.id,
    required this.paymentNumber,
    required this.amount,
    required this.paymentMethod,
    this.reference,
    required this.paidAt,
    this.recordedBy,
  });

  factory VendorBillPayment.fromJson(Map<String, dynamic> j) => VendorBillPayment(
    id:            (j['id'] as num).toInt(),
    paymentNumber: j['payment_number'] as String? ?? '—',
    amount:        (j['amount'] as num? ?? 0).toInt(),
    paymentMethod: j['payment_method'] as String? ?? 'cash',
    reference:     j['reference'] as String?,
    paidAt:        j['paid_at'] as String? ?? '',
    recordedBy:    j['recorded_by'] as String?,
  );

  String get methodLabel => switch (paymentMethod) {
    'bank_transfer' => 'Bank Transfer',
    'mobile_money'  => 'Mobile Money',
    'cheque'        => 'Cheque',
    _               => 'Cash',
  };
}

class VendorBill {
  final int     id;
  final String  billNumber;
  final int     supplierId;
  final String? supplierName;
  final int?    purchaseOrderId;
  final String? purchaseOrderNumber;
  final int?    categoryId;
  final String? categoryName;
  final String  issueDate;
  final String  dueDate;
  final int     subtotal;
  final double  taxRate;
  final int     taxAmount;
  final int     total;
  final int     amountPaid;
  final int     balanceDue;
  final String  status; // pending | approved | partial | paid | overdue | cancelled
  final String  currency;
  final String? notes;
  final String? createdByName;
  final String? approvedByName;
  final String? approvedAt;
  final List<VendorBillLineItem> lineItems;
  final List<VendorBillPayment>  payments;
  final DateTime? createdAt;

  const VendorBill({
    required this.id,
    required this.billNumber,
    required this.supplierId,
    this.supplierName,
    this.purchaseOrderId,
    this.purchaseOrderNumber,
    this.categoryId,
    this.categoryName,
    required this.issueDate,
    required this.dueDate,
    required this.subtotal,
    this.taxRate = 0,
    required this.taxAmount,
    required this.total,
    required this.amountPaid,
    required this.balanceDue,
    required this.status,
    this.currency = 'TZS',
    this.notes,
    this.createdByName,
    this.approvedByName,
    this.approvedAt,
    this.lineItems = const [],
    this.payments  = const [],
    this.createdAt,
  });

  factory VendorBill.fromJson(Map<String, dynamic> j) => VendorBill(
    id:                  (j['id'] as num).toInt(),
    billNumber:          j['bill_number'] as String? ?? '—',
    supplierId:          (j['supplier_id'] as num? ?? 0).toInt(),
    supplierName:        j['supplier_name'] as String?,
    purchaseOrderId:     j['purchase_order_id'] != null ? (j['purchase_order_id'] as num).toInt() : null,
    purchaseOrderNumber: j['purchase_order_number'] as String?,
    categoryId:          j['category_id'] != null ? (j['category_id'] as num).toInt() : null,
    categoryName:        j['category_name'] as String?,
    issueDate:           j['issue_date'] as String? ?? '—',
    dueDate:             j['due_date'] as String? ?? '—',
    subtotal:            (j['subtotal'] as num? ?? 0).toInt(),
    taxRate:             (j['tax_rate'] as num? ?? 0).toDouble(),
    taxAmount:           (j['tax_amount'] as num? ?? 0).toInt(),
    total:               (j['total'] as num? ?? 0).toInt(),
    amountPaid:          (j['amount_paid'] as num? ?? 0).toInt(),
    balanceDue:          (j['balance_due'] as num? ?? 0).toInt(),
    status:              j['status'] as String? ?? 'pending',
    currency:            j['currency'] as String? ?? 'TZS',
    notes:               j['notes'] as String?,
    createdByName:       j['created_by_name'] as String?,
    approvedByName:      j['approved_by_name'] as String?,
    approvedAt:          j['approved_at'] as String?,
    lineItems:           (j['line_items'] as List? ?? [])
                             .map((e) => VendorBillLineItem.fromJson(e as Map<String, dynamic>)).toList(),
    payments:            (j['payments'] as List? ?? [])
                             .map((e) => VendorBillPayment.fromJson(e as Map<String, dynamic>)).toList(),
    createdAt:           j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
  );

  String get statusLabel => switch (status) {
    'approved'  => 'Approved',
    'partial'   => 'Partial',
    'paid'      => 'Paid',
    'overdue'   => 'Overdue',
    'cancelled' => 'Cancelled',
    _           => 'Pending',
  };

  bool get isPaid      => status == 'paid';
  // Director approval is required (status: 'approved') before a payment
  // can be recorded — a plain 'pending' bill isn't payable yet.
  bool get canApprove => status == 'pending';
  bool get canPay      => status == 'approved' || status == 'partial';
  bool get canCancel   => !isPaid && status != 'cancelled';
}
