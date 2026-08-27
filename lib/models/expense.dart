class ExpenseCategory {
  final int    id;
  final String name;
  final int    accountId;
  final bool   requiresDirectorApproval;

  const ExpenseCategory({
    required this.id, required this.name, required this.accountId,
    this.requiresDirectorApproval = false,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
    id:        (j['id'] as num).toInt(),
    name:      j['name'] as String? ?? '—',
    accountId: (j['account_id'] as num? ?? 0).toInt(),
    requiresDirectorApproval: j['requires_director_approval'] as bool? ?? false,
  );
}

enum ExpenseStatus { pendingCto, pendingDirector, approved, rejected }

extension ExpenseStatusX on ExpenseStatus {
  String get label => switch (this) {
    ExpenseStatus.pendingCto      => 'Awaiting CTO',
    ExpenseStatus.pendingDirector => 'Awaiting Director',
    ExpenseStatus.approved        => 'Approved',
    ExpenseStatus.rejected        => 'Rejected',
  };
}

ExpenseStatus _parseExpenseStatus(String s) => switch (s) {
  'pending_director' => ExpenseStatus.pendingDirector,
  'approved'          => ExpenseStatus.approved,
  'rejected'          => ExpenseStatus.rejected,
  _                   => ExpenseStatus.pendingCto,
};

class Expense {
  final int     id;
  final String  name;
  final int     categoryId;
  final String? categoryName;
  final int     amount;
  final double  taxRate;
  final int     taxAmount;
  final int     grossAmount;
  final String  paymentMode; // cash | bank | mobile_money
  final String  expenseDate;
  final String? reference;
  final String? notes;
  final String? createdByName;
  final DateTime? createdAt;
  final ExpenseStatus status;
  final bool     requiresDirectorApproval;
  final String?  escalationReason;
  final String?  reviewerName;
  final String?  rejectionReason;

  const Expense({
    required this.id,
    required this.name,
    required this.categoryId,
    this.categoryName,
    required this.amount,
    this.taxRate = 0,
    required this.taxAmount,
    required this.grossAmount,
    this.paymentMode = 'cash',
    required this.expenseDate,
    this.reference,
    this.notes,
    this.createdByName,
    this.createdAt,
    this.status = ExpenseStatus.pendingCto,
    this.requiresDirectorApproval = false,
    this.escalationReason,
    this.reviewerName,
    this.rejectionReason,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id:            (j['id'] as num).toInt(),
    name:          j['name'] as String? ?? '—',
    categoryId:    (j['category_id'] as num? ?? 0).toInt(),
    categoryName:  j['category_name'] as String?,
    amount:        (j['amount'] as num? ?? 0).toInt(),
    taxRate:       (j['tax_rate'] as num? ?? 0).toDouble(),
    taxAmount:     (j['tax_amount'] as num? ?? 0).toInt(),
    grossAmount:   (j['gross_amount'] as num? ?? 0).toInt(),
    paymentMode:   j['payment_mode'] as String? ?? 'cash',
    expenseDate:   j['expense_date'] as String? ?? '—',
    reference:     j['reference'] as String?,
    notes:         j['notes'] as String?,
    createdByName: j['created_by_name'] as String?,
    createdAt:     j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
    status:        _parseExpenseStatus(j['status'] as String? ?? 'pending_cto'),
    requiresDirectorApproval: j['requires_director_approval'] as bool? ?? false,
    escalationReason: j['escalation_reason'] as String?,
    reviewerName:     j['reviewer_name'] as String?,
    rejectionReason:  j['rejection_reason'] as String?,
  );

  String get paymentModeLabel => switch (paymentMode) {
    'bank'         => 'Bank',
    'mobile_money' => 'Mobile Money',
    _              => 'Cash',
  };
}
