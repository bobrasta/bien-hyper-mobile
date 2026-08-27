import 'api_client.dart';

class PayrollItem {
  final int id;
  final int payrollRunId;
  final int userId;
  final String? userName;
  final int baseSalary;
  final int allowancesTotal;
  final int overtimeAmount;
  final int payeAmount;
  final int nssfAmount;
  final int heslbAmount;
  final int otherDeductions;
  final int grossPay;
  final int netPay;
  final String? notes;

  const PayrollItem({
    required this.id, required this.payrollRunId, required this.userId, this.userName,
    required this.baseSalary, required this.allowancesTotal, required this.overtimeAmount,
    required this.payeAmount, required this.nssfAmount, required this.heslbAmount,
    required this.otherDeductions, required this.grossPay, required this.netPay, this.notes,
  });

  factory PayrollItem.fromJson(Map<String, dynamic> j) => PayrollItem(
    id: (j['id'] as num).toInt(),
    payrollRunId: (j['payroll_run_id'] as num).toInt(),
    userId: (j['user_id'] as num).toInt(),
    userName: j['user_name'] as String?,
    baseSalary: (j['base_salary'] as num).toInt(),
    allowancesTotal: (j['allowances_total'] as num).toInt(),
    overtimeAmount: (j['overtime_amount'] as num).toInt(),
    payeAmount: (j['paye_amount'] as num).toInt(),
    nssfAmount: (j['nssf_amount'] as num).toInt(),
    heslbAmount: (j['heslb_amount'] as num).toInt(),
    otherDeductions: (j['other_deductions'] as num).toInt(),
    grossPay: (j['gross_pay'] as num).toInt(),
    netPay: (j['net_pay'] as num).toInt(),
    notes: j['notes'] as String?,
  );
}

class PayrollRun {
  final int id;
  final int periodMonth;
  final int periodYear;
  final String status;
  final int grossTotal;
  final int deductionsTotal;
  final int netTotal;
  final int? itemsCount;
  final List<PayrollItem> items;
  final String? createdByName;
  final String? approvedByName;
  final String? approvedAt;
  final String? paidAt;

  const PayrollRun({
    required this.id, required this.periodMonth, required this.periodYear, required this.status,
    required this.grossTotal, required this.deductionsTotal, required this.netTotal,
    this.itemsCount, this.items = const [], this.createdByName, this.approvedByName,
    this.approvedAt, this.paidAt,
  });

  factory PayrollRun.fromJson(Map<String, dynamic> j) => PayrollRun(
    id: (j['id'] as num).toInt(),
    periodMonth: (j['period_month'] as num).toInt(),
    periodYear: (j['period_year'] as num).toInt(),
    status: j['status'] as String,
    grossTotal: (j['gross_total'] as num?)?.toInt() ?? 0,
    deductionsTotal: (j['deductions_total'] as num?)?.toInt() ?? 0,
    netTotal: (j['net_total'] as num?)?.toInt() ?? 0,
    itemsCount: (j['items_count'] as num?)?.toInt(),
    items: (j['items'] as List<dynamic>? ?? []).map((i) => PayrollItem.fromJson(i as Map<String, dynamic>)).toList(),
    createdByName: j['created_by_name'] as String?,
    approvedByName: j['approved_by_name'] as String?,
    approvedAt: j['approved_at'] as String?,
    paidAt: j['paid_at'] as String?,
  );
}

class SalaryAdjustment {
  final int id;
  final int userId;
  final int? previousSalary;
  final int newSalary;
  final String? reason;
  final String effectiveDate;
  final String? approvedByName;

  const SalaryAdjustment({
    required this.id, required this.userId, this.previousSalary, required this.newSalary,
    this.reason, required this.effectiveDate, this.approvedByName,
  });

  factory SalaryAdjustment.fromJson(Map<String, dynamic> j) => SalaryAdjustment(
    id: (j['id'] as num).toInt(),
    userId: (j['user_id'] as num).toInt(),
    previousSalary: (j['previous_salary'] as num?)?.toInt(),
    newSalary: (j['new_salary'] as num).toInt(),
    reason: j['reason'] as String?,
    effectiveDate: j['effective_date'] as String,
    approvedByName: j['approved_by_name'] as String?,
  );
}

class EligibleStaffOption {
  final int id;
  final String name;
  const EligibleStaffOption({required this.id, required this.name});
  factory EligibleStaffOption.fromJson(Map<String, dynamic> j) =>
      EligibleStaffOption(id: (j['id'] as num).toInt(), name: j['name'] as String);
}

class PayrollService {
  PayrollService._();
  static final instance = PayrollService._();
  final _dio = ApiClient.instance.dio;

  Future<List<PayrollRun>> runs() async {
    final res = await _dio.get('/payroll-runs');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => PayrollRun.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PayrollRun> createRun({required int month, required int year}) async {
    final res = await _dio.post('/payroll-runs', data: {'period_month': month, 'period_year': year});
    return PayrollRun.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PayrollRun> show(int runId) async {
    final res = await _dio.get('/payroll-runs/$runId');
    return PayrollRun.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<List<EligibleStaffOption>> eligibleStaff(int runId) async {
    final res = await _dio.get('/payroll-runs/$runId/eligible-staff');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => EligibleStaffOption.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PayrollItem> upsertItem(int runId, Map<String, dynamic> data) async {
    final res = await _dio.post('/payroll-runs/$runId/items', data: data);
    return PayrollItem.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteItem(int runId, int itemId) => _dio.delete('/payroll-runs/$runId/items/$itemId');

  Future<PayrollRun> review(int runId) async {
    final res = await _dio.post('/payroll-runs/$runId/review');
    return PayrollRun.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PayrollRun> approve(int runId) async {
    final res = await _dio.post('/payroll-runs/$runId/approve');
    return PayrollRun.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PayrollRun> markPaid(int runId) async {
    final res = await _dio.post('/payroll-runs/$runId/mark-paid');
    return PayrollRun.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<List<SalaryAdjustment>> salaryAdjustments(int userId) async {
    final res = await _dio.get('/staff/$userId/salary-adjustments');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => SalaryAdjustment.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<SalaryAdjustment> addSalaryAdjustment(int userId, Map<String, dynamic> data) async {
    final res = await _dio.post('/staff/$userId/salary-adjustments', data: data);
    return SalaryAdjustment.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
