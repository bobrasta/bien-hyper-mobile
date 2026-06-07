enum PaymentStatus { pending, partial, paid, overdue, waived, cancelled, sent }

extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.pending   => 'Pending',
    PaymentStatus.partial   => 'Partial',
    PaymentStatus.paid      => 'Paid',
    PaymentStatus.overdue   => 'Overdue',
    PaymentStatus.waived    => 'Waived',
    PaymentStatus.cancelled => 'Cancelled',
    PaymentStatus.sent      => 'Sent',
  };
}

PaymentStatus _parseStatus(String s) => switch (s) {
  'partial'   => PaymentStatus.partial,
  'paid'      => PaymentStatus.paid,
  'overdue'   => PaymentStatus.overdue,
  'waived'    => PaymentStatus.waived,
  'cancelled' => PaymentStatus.cancelled,
  'sent'      => PaymentStatus.sent,
  _           => PaymentStatus.pending,
};

class Payment {
  final int     id;
  final String  paymentNumber;
  final int     invoiceId;
  final int     amount;
  final String  paymentMethod;
  final String? reference;
  final String  paidAt;
  final String? notes;
  final String? recordedBy;

  const Payment({
    required this.id,
    required this.paymentNumber,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    this.reference,
    required this.paidAt,
    this.notes,
    this.recordedBy,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id:            (j['id'] as num).toInt(),
    paymentNumber: j['payment_number'] as String? ?? '—',
    invoiceId:     (j['invoice_id'] as num? ?? 0).toInt(),
    amount:        (j['amount'] as num? ?? 0).toInt(),
    paymentMethod: j['payment_method'] as String? ?? 'cash',
    reference:     j['reference'] as String?,
    paidAt:        j['paid_at'] as String? ?? '',
    notes:         j['notes'] as String?,
    recordedBy:    j['recorded_by'] as String?,
  );

  String get methodLabel => switch (paymentMethod) {
    'bank_transfer' => 'Bank Transfer',
    'mobile_money'  => 'Mobile Money',
    'cheque'        => 'Cheque',
    _               => 'Cash',
  };
}

class InvoiceLineItem {
  final String description;
  final double quantity;
  final int    unitPrice;
  final int    total;

  const InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> j) => InvoiceLineItem(
    description: j['description'] as String? ?? '',
    quantity:    (j['quantity']   as num? ?? 1).toDouble(),
    unitPrice:   (j['unit_price'] as num? ?? 0).toInt(),
    total:       (j['total']      as num? ?? 0).toInt(),
  );
}

class Invoice {
  final int           id;
  final String        invoiceNumber;
  // Hospital invoices
  final String?       hospitalName;
  // Sales-linked invoices
  final int?          salesOrderId;
  final String?       salesOrderNumber;
  final String?       clientName;
  final String?       clientContact;
  final String?       clientEmail;
  // Dates
  final String        issueDate;
  final String        dueDate;
  // Financials
  final int           subtotal;
  final double        taxRate;
  final int           taxAmount;
  final int           total;
  final int           amountPaid;
  final PaymentStatus status;
  final String        currency;
  final String?       notes;
  // Relations
  final List<InvoiceLineItem> lineItems;
  final List<Payment>         payments;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    this.hospitalName,
    this.salesOrderId,
    this.salesOrderNumber,
    this.clientName,
    this.clientContact,
    this.clientEmail,
    required this.issueDate,
    required this.dueDate,
    required this.subtotal,
    this.taxRate = 0,
    required this.taxAmount,
    required this.total,
    required this.amountPaid,
    required this.status,
    this.currency = 'TZS',
    this.notes,
    this.lineItems = const [],
    this.payments  = const [],
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    id:              (j['id'] as num).toInt(),
    invoiceNumber:   j['invoice_number'] as String? ?? '—',
    hospitalName:    j['hospital'] is Map
                         ? (j['hospital'] as Map)['name'] as String?
                         : j['hospital_name'] as String?,
    salesOrderId:    j['sales_order_id'] != null ? (j['sales_order_id'] as num).toInt() : null,
    salesOrderNumber:j['sales_order_number'] as String?,
    clientName:      j['client_name'] as String?,
    clientContact:   j['client_contact'] as String?,
    clientEmail:     j['client_email'] as String?,
    issueDate:       j['issue_date'] as String? ?? j['created_at'] as String? ?? '—',
    dueDate:         j['due_date']   as String? ?? '—',
    subtotal:        (j['subtotal']    as num? ?? 0).toInt(),
    taxRate:         (j['tax_rate']    as num? ?? 0).toDouble(),
    taxAmount:       (j['tax_amount']  as num? ?? 0).toInt(),
    total:           (j['total']       as num? ?? 0).toInt(),
    amountPaid:      (j['amount_paid'] as num? ?? 0).toInt(),
    status:          _parseStatus(j['status'] as String? ?? 'pending'),
    currency:        j['currency']     as String? ?? 'TZS',
    notes:           j['notes']        as String?,
    lineItems:       (j['line_items']  as List? ?? [])
                         .map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>)).toList(),
    payments:        (j['payments']    as List? ?? [])
                         .map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList(),
  );

  int    get balanceDue  => (total - amountPaid).clamp(0, total);
  String get displayName => clientName ?? hospitalName ?? '—';
  bool get isPaid        => status == PaymentStatus.paid || status == PaymentStatus.waived;
  bool get canSend       => status == PaymentStatus.pending;
  bool get canPay        => !isPaid && status != PaymentStatus.cancelled;
  bool get canCancel     => !isPaid;
}
