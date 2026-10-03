// lib/services/cto_dashboard_service.dart
import '../models/cto_approval.dart';
import '../models/cto_overview.dart';
import '../models/expense.dart';
import 'api_client.dart';
import 'expense_service.dart';
import 'per_diem_service.dart';
import 'stock_out_request_service.dart';

class CtoDashboardService {
  CtoDashboardService._();
  static final instance = CtoDashboardService._();
  final _dio = ApiClient.instance.dio;

  Future<CtoOverview> loadOverview() async {
    final res = await _dio.get('/dashboard/cto-overview');
    return CtoOverview.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  /// Everything sitting at the CTO step, oldest first. Expenses are fetched
  /// directly with status + no date range (= all time) so an old pending one
  /// isn't hidden behind the This-year default or page 1.
  Future<List<CtoApproval>> loadApprovals() async {
    final perDiemF = PerDiemService.instance.list(status: 'pending_cto');
    final expenseF = _dio
        .get('/expenses', queryParameters: {'status': 'pending_cto', 'per_page': 500})
        .then((res) => ApiClient.unwrapList(res).$1.map((j) => Expense.fromJson(j as Map<String, dynamic>)).toList());
    final stockF = StockOutRequestService.instance.list(status: 'pending');
    final perDiems = await perDiemF;
    final expenses = await expenseF;
    final stock = await stockF;
    final out = <CtoApproval>[
      ...perDiems.map(CtoApproval.fromPerDiem),
      ...expenses.map(CtoApproval.fromExpense),
      ...stock.map(CtoApproval.fromStock),
    ];
    out.sort((a, b) => (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100)));
    return out;
  }

  /// Loads the full per-diem (lines, revisions, signature block) for the detail view.
  Future<CtoApproval> refreshTrip(CtoApproval a) async =>
      a.perDiem == null ? a : CtoApproval.fromPerDiem(await PerDiemService.instance.show(a.perDiem!.id));

  Future<void> approve(CtoApproval a) async {
    switch (a.kind) {
      case CtoApprovalKind.trip:
        if (a.perDiem != null) await PerDiemService.instance.approve(a.perDiem!.id);
      case CtoApprovalKind.expense:
        // Director-routed categories can't be approved at the CTO step — the
        // API 422s; forwarding them is an escalate.
        if (a.expense != null) {
          a.expense!.requiresDirectorApproval
              ? await ExpenseService.instance.escalate(a.expense!.id)
              : await ExpenseService.instance.approve(a.expense!.id);
        }
      case CtoApprovalKind.stock:
        if (a.stock != null) await StockOutRequestService.instance.approve(a.stock!.id);
    }
  }

  Future<void> returnItem(CtoApproval a, String reason) async {
    switch (a.kind) {
      case CtoApprovalKind.trip:
        if (a.perDiem != null) await PerDiemService.instance.reject(a.perDiem!.id, reason: reason);
      case CtoApprovalKind.expense:
        if (a.expense != null) await ExpenseService.instance.reject(a.expense!.id, reason: reason);
      case CtoApprovalKind.stock:
        if (a.stock != null) await StockOutRequestService.instance.reject(a.stock!.id, reason: reason);
    }
  }

  Future<void> decideTechnicianEdit(CtoApproval a, {required bool accept}) async {
    if (a.perDiem == null || a.pendingRevisionId == null) return;
    accept
        ? await PerDiemService.instance.approveTechnicianEdit(a.perDiem!.id, a.pendingRevisionId!)
        : await PerDiemService.instance.rejectTechnicianEdit(a.perDiem!.id, a.pendingRevisionId!);
  }
}
