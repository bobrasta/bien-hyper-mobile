import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show userRoleNotifier, hasCtoApprovalAuthority, hasTeamLeadAuthority,
    hasDirectorAuthority, hasProcurementSalesStageAuthority, hasAccountantAuthority;
import '../../models/expense.dart';
import '../../models/per_diem_request.dart';
import '../../models/purchase_order.dart';
import '../../models/stock_out_request.dart';
import '../../services/expense_service.dart';
import '../../services/per_diem_service.dart';
import '../../services/purchase_order_service.dart';
import '../../services/stock_out_request_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import 'per_diem_revise_dialog.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, this.initialTabIndex});
  final int? initialTabIndex;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: 4, vsync: this,
    initialIndex: (widget.initialTabIndex ?? 0).clamp(0, 3),
  );

  static const _pendingPoStatuses = {
    'pending_sales_manager', 'pending_director_review',
    'pending_payment_initiation', 'pending_director_final',
  };

  List<StockOutRequest>  _stockOut = [];
  List<PerDiemRequest>   _perDiem  = [];
  List<Expense>          _expenses = [];
  List<PurchaseOrder>    _purchaseOrders = [];
  bool    _loading = true;
  // Per-tab load failure (e.g. a team_leader correctly lacks finance access
  // and can't see Expenses at all) — kept separate per tab so one 403
  // doesn't take the other three tabs down with it.
  String? _stockOutError;
  String? _perDiemError;
  String? _expensesError;
  String? _purchaseOrdersError;

  List<StockOutRequest> get _pendingStockOut =>
      _stockOut.where((r) => r.status == StockOutStatus.pending).toList();
  List<PerDiemRequest> get _pendingPerDiem =>
      _perDiem.where((r) =>
          r.isPendingTeamLead || r.isPendingCto || r.isPendingPayment || r.isPendingDirector).toList();
  List<Expense> get _pendingExpenses => _expenses.where(
      (e) => e.status == ExpenseStatus.pendingCto || e.status == ExpenseStatus.pendingDirector
          || e.status == ExpenseStatus.pendingPayment || e.status == ExpenseStatus.pendingRelease).toList();
  List<PurchaseOrder> get _pendingPurchaseOrders =>
      _purchaseOrders.where((po) => _pendingPoStatuses.contains(po.status)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _stockOutError = null; _perDiemError = null; _expensesError = null; _purchaseOrdersError = null;
    });
    // Each tab's resource loads independently — one tab lacking permission
    // (e.g. team_leader has no finance access, so Expenses 403s) must not
    // block the other three tabs the same user IS authorised to act on.
    await Future.wait([
      _loadStockOut(),
      _loadPerDiem(),
      _loadExpenses(),
      _loadPurchaseOrders(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadStockOut() async {
    try {
      final v = await StockOutRequestService.instance.list(status: 'pending');
      if (mounted) setState(() => _stockOut = v);
    } catch (e) {
      if (mounted) setState(() { _stockOut = []; _stockOutError = friendlyError(e); });
    }
  }

  Future<void> _loadPerDiem() async {
    try {
      final v = await PerDiemService.instance.list();
      if (mounted) setState(() => _perDiem = v);
    } catch (e) {
      if (mounted) setState(() { _perDiem = []; _perDiemError = friendlyError(e); });
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final v = await ExpenseService.instance.list();
      if (mounted) setState(() => _expenses = v);
    } catch (e) {
      if (mounted) setState(() { _expenses = []; _expensesError = friendlyError(e); });
    }
  }

  Future<void> _loadPurchaseOrders() async {
    try {
      final v = await PurchaseOrderService.instance.list();
      if (mounted) setState(() => _purchaseOrders = v);
    } catch (e) {
      if (mounted) setState(() { _purchaseOrders = []; _purchaseOrdersError = friendlyError(e); });
    }
  }

  Future<void> _approveStockOut(StockOutRequest r) async {
    try {
      await StockOutRequestService.instance.approve(r.id);
      if (mounted) { showSuccessToast(context, 'Approved.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _rejectStockOut(StockOutRequest r) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _RejectReasonDialog());
    if (reason == null) return;
    try {
      await StockOutRequestService.instance.reject(r.id, reason: reason.isEmpty ? null : reason);
      if (mounted) { showSuccessToast(context, 'Rejected.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _forwardPerDiem(PerDiemRequest r) async {
    try {
      await PerDiemService.instance.approveTeamLead(r.id);
      if (mounted) { showSuccessToast(context, 'Forwarded to CTO.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _rejectPerDiemTeamLead(PerDiemRequest r) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _RejectReasonDialog(minLength: 10));
    if (reason == null) return;
    try {
      await PerDiemService.instance.rejectTeamLead(r.id, reason: reason);
      if (mounted) { showSuccessToast(context, 'Rejected.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _approvePerDiem(PerDiemRequest r) async {
    try {
      await PerDiemService.instance.approve(r.id);
      if (mounted) { showSuccessToast(context, 'Approved.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _rejectPerDiem(PerDiemRequest r) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _RejectReasonDialog(minLength: 10));
    if (reason == null) return;
    try {
      await PerDiemService.instance.reject(r.id, reason: reason);
      if (mounted) { showSuccessToast(context, 'Rejected.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _initiatePerDiemPayment(PerDiemRequest r) async {
    final result = await showDialog<(String?, String?)>(context: context, builder: (_) => _InitiatePaymentDialog());
    if (result == null) return;
    try {
      await PerDiemService.instance.initiatePayment(r.id, method: result.$1, reference: result.$2);
      if (mounted) { showSuccessToast(context, 'Payment initiated — sent to Director for authorization.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _authorizePerDiemPayment(PerDiemRequest r) async {
    try {
      await PerDiemService.instance.markPaid(r.id);
      if (mounted) { showSuccessToast(context, 'Payment authorized — marked paid.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  // Section 8: CTO day-by-day editing.
  void _showRevisePerDiemDialog(PerDiemRequest r) {
    showDialog<void>(
      context: context,
      builder: (_) => PerDiemReviseDialog(
        request: r,
        onClose: () => Navigator.of(context).pop(),
        onSaved: () {
          Navigator.of(context).pop();
          if (mounted) { showSuccessToast(context, 'Travel plan updated.'); _load(); }
        },
      ),
    );
  }

  Future<void> _toggleEditGrant(PerDiemRequest r) async {
    try {
      if (r.hasActiveEditGrant) {
        await PerDiemService.instance.revokeEditAccess(r.id);
        if (mounted) showSuccessToast(context, 'Edit access revoked.');
      } else {
        await PerDiemService.instance.grantEditAccess(r.id);
        if (mounted) showSuccessToast(context, 'Edit access granted to ${r.userName ?? 'the technician'}.');
      }
      _load();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _approveTechnicianEdit(PerDiemRequest r, PerDiemRevision rev) async {
    try {
      await PerDiemService.instance.approveTechnicianEdit(r.id, rev.id);
      if (mounted) { showSuccessToast(context, 'Technician\'s edit applied.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _rejectTechnicianEdit(PerDiemRequest r, PerDiemRevision rev) async {
    try {
      await PerDiemService.instance.rejectTechnicianEdit(r.id, rev.id);
      if (mounted) { showSuccessToast(context, 'Proposed edit rejected.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _approveExpense(Expense e) async {
    try {
      await ExpenseService.instance.approve(e.id);
      if (mounted) { showSuccessToast(context, 'Approved.'); _load(); }
    } catch (err) {
      if (mounted) showErrorToast(context, err);
    }
  }

  Future<void> _escalateExpense(Expense e) async {
    try {
      await ExpenseService.instance.escalate(e.id);
      if (mounted) { showSuccessToast(context, 'Escalated to Director.'); _load(); }
    } catch (err) {
      if (mounted) showErrorToast(context, err);
    }
  }

  Future<void> _rejectExpense(Expense e) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _RejectReasonDialog());
    if (reason == null) return;
    try {
      await ExpenseService.instance.reject(e.id, reason: reason.isEmpty ? null : reason);
      if (mounted) { showSuccessToast(context, 'Rejected.'); _load(); }
    } catch (err) {
      if (mounted) showErrorToast(context, err);
    }
  }

  Future<void> _initiateExpensePayment(Expense e) async {
    final result = await showDialog<(String?, String?)>(context: context,
        builder: (_) => const _InitiatePaymentDialog(methods: ['cash', 'bank', 'mobile_money']));
    if (result == null) return;
    try {
      await ExpenseService.instance.initiatePayment(e.id, paymentMethod: result.$1, reference: result.$2);
      if (mounted) { showSuccessToast(context, 'Payment initiated — awaiting release.'); _load(); }
    } catch (err) {
      if (mounted) showErrorToast(context, err);
    }
  }

  Future<void> _releaseExpensePayment(Expense e) async {
    try {
      await ExpenseService.instance.markPaid(e.id);
      if (mounted) { showSuccessToast(context, 'Payment released — marked paid.'); _load(); }
    } catch (err) {
      if (mounted) showErrorToast(context, err);
    }
  }

  Future<void> _approvePoSalesStage(PurchaseOrder po) async {
    try {
      await PurchaseOrderService.instance.approveSalesManager(po.id);
      if (mounted) { showSuccessToast(context, 'Approved — sent to director review.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _rejectPoSalesStage(PurchaseOrder po) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _RejectReasonDialog());
    if (reason == null) return;
    try {
      await PurchaseOrderService.instance.rejectSalesManager(po.id, reason: reason.isEmpty ? null : reason);
      if (mounted) { showSuccessToast(context, 'Rejected.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _approvePoDirectorReview(PurchaseOrder po) async {
    try {
      await PurchaseOrderService.instance.approveDirectorReview(po.id);
      if (mounted) { showSuccessToast(context, 'Approved — sent for payment initiation.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _rejectPoDirectorReview(PurchaseOrder po) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _RejectReasonDialog());
    if (reason == null) return;
    try {
      await PurchaseOrderService.instance.rejectDirectorReview(po.id, reason: reason.isEmpty ? null : reason);
      if (mounted) { showSuccessToast(context, 'Rejected.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _initiatePoPayment(PurchaseOrder po) async {
    try {
      await PurchaseOrderService.instance.initiatePayment(po.id);
      if (mounted) { showSuccessToast(context, 'Payment initiated — sent for final approval.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _approvePoDirectorFinal(PurchaseOrder po) async {
    try {
      await PurchaseOrderService.instance.approveDirectorFinal(po.id);
      if (mounted) { showSuccessToast(context, 'Fully approved — ready to send to supplier.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _rejectPoDirectorFinal(PurchaseOrder po) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _RejectReasonDialog());
    if (reason == null) return;
    try {
      await PurchaseOrderService.instance.rejectDirectorFinal(po.id, reason: reason.isEmpty ? null : reason);
      if (mounted) { showSuccessToast(context, 'Rejected.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Approvals', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Requests waiting on your sign-off', style: AppTheme.bodySub),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          margin: EdgeInsets.symmetric(horizontal: pad),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: TabBar(
            controller: _tab,
            labelColor: AppColors.teal,
            unselectedLabelColor: context.pal.textMute,
            indicatorColor: AppColors.teal,
            indicatorWeight: 2,
            labelStyle: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
            unselectedLabelStyle: AppTheme.bodySm,
            tabs: [
              Tab(text: 'Stock-Out (${_pendingStockOut.length})'),
              Tab(text: 'Per Diem (${_pendingPerDiem.length})'),
              Tab(text: 'Expenses (${_pendingExpenses.length})'),
              Tab(text: 'Purchase Orders (${_pendingPurchaseOrders.length})'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ValueListenableBuilder<String>(
                      valueListenable: userRoleNotifier,
                      builder: (_, role, _) => TabBarView(controller: _tab, children: [
                        _stockOutError != null
                            ? ErrorView(message: _stockOutError!, onRetry: _loadStockOut)
                            : _StockOutTab(requests: _pendingStockOut, pad: pad, onApprove: _approveStockOut, onReject: _rejectStockOut),
                        _perDiemError != null
                            ? ErrorView(message: _perDiemError!, onRetry: _loadPerDiem)
                            : _PerDiemTab(
                          requests: _pendingPerDiem, pad: pad, viewerRole: role,
                          onForward: _forwardPerDiem, onRejectTeamLead: _rejectPerDiemTeamLead,
                          onApprove: _approvePerDiem, onReject: _rejectPerDiem,
                          onInitiatePayment: _initiatePerDiemPayment,
                          onAuthorizePayment: _authorizePerDiemPayment,
                          onRevise: _showRevisePerDiemDialog,
                          onToggleEditGrant: _toggleEditGrant,
                          onApproveTechnicianEdit: _approveTechnicianEdit,
                          onRejectTechnicianEdit: _rejectTechnicianEdit,
                        ),
                        _expensesError != null
                            ? ErrorView(message: _expensesError!, onRetry: _loadExpenses)
                            : _ExpenseTab(
                          expenses: _pendingExpenses, pad: pad, viewerRole: role,
                          onApprove: _approveExpense, onEscalate: _escalateExpense, onReject: _rejectExpense,
                          onInitiatePayment: _initiateExpensePayment, onReleasePayment: _releaseExpensePayment,
                        ),
                        _purchaseOrdersError != null
                            ? ErrorView(message: _purchaseOrdersError!, onRetry: _loadPurchaseOrders)
                            : _PurchaseOrderTab(
                          orders: _pendingPurchaseOrders, pad: pad, viewerRole: role,
                          onApproveSalesStage: _approvePoSalesStage, onRejectSalesStage: _rejectPoSalesStage,
                          onApproveDirectorReview: _approvePoDirectorReview, onRejectDirectorReview: _rejectPoDirectorReview,
                          onInitiatePayment: _initiatePoPayment,
                          onApproveDirectorFinal: _approvePoDirectorFinal, onRejectDirectorFinal: _rejectPoDirectorFinal,
                        ),
                      ]),
                    ),
        ),
      ]);
    });
  }
}

class _RejectReasonDialog extends StatefulWidget {
  // 0 (default) keeps every existing reject flow exactly as it was —
  // optional reason. Per-diem's two reject actions pass 10 (matching
  // PerDiemController's own required|min:10 validation) since the backend
  // rejects an under-length reason anyway; better to catch it here than
  // round-trip a 422.
  const _RejectReasonDialog({this.minLength = 0});
  final int minLength;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() {
    final text = _ctrl.text.trim();
    if (widget.minLength > 0 && text.length < widget.minLength) {
      setState(() => _error = 'Reason must be at least ${widget.minLength} characters.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    title: Text('Reject Request', style: AppTheme.bodyStrong),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ctrl, maxLines: 3, style: AppTheme.bodySm,
        decoration: InputDecoration(
          hintText: widget.minLength > 0 ? 'Reason (required)' : 'Reason (optional)',
          hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 6),
        Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12)),
      ],
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      TextButton(onPressed: _submit, child: Text('Reject', style: TextStyle(color: AppColors.coral))),
    ],
  );
}

class _InitiatePaymentDialog extends StatefulWidget {
  // Per-Diem's payment_method enum is cash/bank_transfer/mobile_money/cheque;
  // Expense's is cash/bank/mobile_money (matches its existing payment_mode
  // vocabulary) — pass the caller's own list rather than hardcoding one.
  const _InitiatePaymentDialog({this.methods = const ['cash', 'bank_transfer', 'mobile_money', 'cheque']});
  final List<String> methods;

  @override
  State<_InitiatePaymentDialog> createState() => _InitiatePaymentDialogState();
}

class _InitiatePaymentDialogState extends State<_InitiatePaymentDialog> {
  late String _method = widget.methods.first;
  final _refCtrl = TextEditingController();

  @override
  void dispose() { _refCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    title: Text('Initiate Payment', style: AppTheme.bodyStrong),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Payment method', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: _method,
        isExpanded: true,
        dropdownColor: context.pal.surface1,
        style: AppTheme.bodySm.copyWith(color: context.pal.text),
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        items: widget.methods.map((m) => DropdownMenuItem(value: m, child: Text(
            m.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
            style: AppTheme.bodySm))).toList(),
        onChanged: (v) => setState(() => _method = v ?? _method),
      ),
      const SizedBox(height: 12),
      Text('Reference (optional)', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
      const SizedBox(height: 6),
      TextField(
        controller: _refCtrl, style: AppTheme.bodySm,
        decoration: InputDecoration(
          isDense: true, border: const OutlineInputBorder(),
          hintText: 'Transaction ID, cheque no., etc.',
          hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
        ),
      ),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      TextButton(
        onPressed: () => Navigator.of(context).pop((_method, _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim())),
        child: Text('Initiate', style: TextStyle(color: AppColors.teal)),
      ),
    ],
  );
}

class _StockOutTab extends StatelessWidget {
  const _StockOutTab({required this.requests, required this.pad, required this.onApprove, required this.onReject});
  final List<StockOutRequest> requests;
  final double pad;
  final ValueChanged<StockOutRequest> onApprove;
  final ValueChanged<StockOutRequest> onReject;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(child: Text('No pending stock-out requests', style: TextStyle(color: context.pal.textMute)));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(children: requests.map((r) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(r.type == 'write_off' ? Symbols.delete_forever : Symbols.remove_circle,
                size: 16, color: r.type == 'write_off' ? AppColors.amber : AppColors.coral),
            const SizedBox(width: 8),
            Expanded(child: Text('${r.itemName ?? '—'} · ${r.quantity} unit(s)',
                style: AppTheme.bodyStrong.copyWith(fontSize: 13.5))),
          ]),
          const SizedBox(height: 8),
          Text('${r.type == 'write_off' ? 'Write-off' : 'Issue'} · ${r.locationName ?? '—'} · requested by ${r.requesterName ?? '—'}'
                  '${r.serviceTicketNumber != null ? ' · for ${r.serviceTicketNumber}' : ''}',
              style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
          if (r.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.reason, style: AppTheme.bodySub.copyWith(fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => onReject(r),
              child: Container(height: 36,
                decoration: BoxDecoration(border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('Reject', style: AppTheme.bodySm.copyWith(color: AppColors.coral)))),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => onApprove(r),
              child: Container(height: 36,
                decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('Approve', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 12.5)))),
            )),
          ]),
        ]),
      )).toList()),
    );
  }
}

class _PerDiemTab extends StatelessWidget {
  const _PerDiemTab({
    required this.requests, required this.pad, required this.viewerRole,
    required this.onForward, required this.onRejectTeamLead,
    required this.onApprove, required this.onReject,
    required this.onInitiatePayment, required this.onAuthorizePayment,
    required this.onRevise, required this.onToggleEditGrant,
    required this.onApproveTechnicianEdit, required this.onRejectTechnicianEdit,
  });
  final List<PerDiemRequest> requests;
  final double pad;
  final String viewerRole;
  final ValueChanged<PerDiemRequest> onForward;
  final ValueChanged<PerDiemRequest> onRejectTeamLead;
  final ValueChanged<PerDiemRequest> onApprove;
  final ValueChanged<PerDiemRequest> onReject;
  final ValueChanged<PerDiemRequest> onInitiatePayment;
  final ValueChanged<PerDiemRequest> onAuthorizePayment;
  // Section 8: CTO day-by-day editing + technician edit-grant toggle.
  final ValueChanged<PerDiemRequest> onRevise;
  final ValueChanged<PerDiemRequest> onToggleEditGrant;
  // Technician's proposed edit — CTO approve/reject, wired to the pending-
  // review notice below (was previously just a passive text notice).
  final void Function(PerDiemRequest, PerDiemRevision) onApproveTechnicianEdit;
  final void Function(PerDiemRequest, PerDiemRevision) onRejectTechnicianEdit;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(child: Text('No pending per-diem requests', style: TextStyle(color: context.pal.textMute)));
    }
    final canTeamLead = hasTeamLeadAuthority(viewerRole);
    final canCto = hasCtoApprovalAuthority(viewerRole);
    final canAccountant = hasAccountantAuthority(viewerRole);
    final canDirector = hasDirectorAuthority(viewerRole);

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(children: requests.map((r) {
        // Five real stages: requester -> team lead -> CTO -> finance
        // (initiates payment) -> Director (authorizes/marks paid) — each
        // shows the same full request to whoever's turn it is, so nobody
        // approves or rejects on a summary alone.
        final atTeamLead = r.isPendingTeamLead;
        final atCto = r.isPendingCto;
        final atPaymentInit = r.isPendingPayment;
        final atDirectorAuth = r.isPendingDirector;
        final stageColor = atTeamLead ? AppColors.amber
            : atCto ? AppColors.blue
            : atPaymentInit ? AppColors.violet
            : atDirectorAuth ? AppColors.teal
            : context.pal.textMute;
        final canActOnThis = atTeamLead ? canTeamLead
            : atCto ? canCto
            : atPaymentInit ? canAccountant
            // Either can release — the accountant, since the Director is
            // often busy, or the Director directly. Never the same person
            // who initiated payment (enforced server-side).
            : atDirectorAuth ? (canAccountant || canDirector)
            : false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Symbols.flight_takeoff, size: 16, color: AppColors.violet),
              const SizedBox(width: 8),
              Expanded(child: Text('${r.userName ?? '—'} · ${r.destination}',
                  style: AppTheme.bodyStrong.copyWith(fontSize: 13.5))),
              // Section 8: "the CTO can edit any active plan" — available
              // at every stage shown here (none of these are rejected/
              // cancelled/paid, which this list never shows anyway).
              if (canCto) ...[
                GestureDetector(
                  onTap: () => onRevise(r),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Symbols.edit_calendar, size: 16, color: context.pal.textDim),
                  ),
                ),
                GestureDetector(
                  onTap: () => onToggleEditGrant(r),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      r.hasActiveEditGrant ? Symbols.lock_open : Symbols.lock,
                      size: 16,
                      color: r.hasActiveEditGrant ? AppColors.amber : context.pal.textDim,
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(r.status.label, style: AppTheme.monoXs.copyWith(
                    color: stageColor, fontSize: 9.5)),
              ),
            ]),
            if (canCto && r.hasActiveEditGrant) ...[
              const SizedBox(height: 4),
              Text('Technician has edit access — tap the unlocked icon to revoke.',
                  style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: AppColors.amber)),
            ],
            const SizedBox(height: 8),
            Text('${r.startDate} → ${r.endDate}  ·  ${r.daysCount} day(s)  ·  TSh ${r.amount}',
                style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
            if (r.purpose != null && r.purpose!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.purpose!, style: AppTheme.bodySub.copyWith(fontSize: 12)),
            ],
            if (r.lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.pal.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: r.lines.asMap().entries.map((e) {
                    final l = e.value;
                    final place = [l.siteName, l.district, l.region]
                        .where((s) => s != null && s.isNotEmpty).join(', ');
                    // Full cost breakdown, not just the line total — the
                    // approver signs off on the composition, not just the
                    // number, so labor/per-diem/transport need to be visible
                    // individually, not collapsed.
                    final costParts = [
                      if (l.laborCost > 0) 'Labor ${l.laborCost}',
                      if (l.perDiemCost > 0) 'Per diem ${l.perDiemCost}',
                      if (l.transportFare > 0) 'Transport ${l.transportFare}',
                    ].join(' · ');
                    return Padding(
                      padding: EdgeInsets.only(bottom: e.key < r.lines.length - 1 ? 8 : 0),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 70, child: Text(l.date,
                            style: AppTheme.monoXs.copyWith(fontSize: 10.5))),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                              [l.activity, place.isEmpty ? null : place]
                                  .where((s) => s != null && s.isNotEmpty).join(' — '),
                              style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                          if (costParts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(costParts, style: AppTheme.monoXs.copyWith(fontSize: 10, color: context.pal.textDim)),
                            ),
                        ])),
                        Text('TSh ${l.total}', style: AppTheme.monoXs.copyWith(fontSize: 10.5)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
            // Section 8: "every edit creates a revision" — shown to
            // everyone who can already see this request, same as the
            // payment trail below.
            if (r.wasEdited) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.pal.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('EDIT HISTORY', style: AppTheme.labelCaps.copyWith(fontSize: 9)),
                  const SizedBox(height: 6),
                  ...r.revisions.where((rev) => rev.status != 'pending_cto_approval').map((rev) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${rev.editorRole == 'cto' ? 'CTO' : 'Technician'} · ${rev.editedByName ?? '—'}: ${rev.reason}'
                      '${rev.status == 'rejected' ? ' (rejected)' : ''}',
                      style: AppTheme.bodySub.copyWith(fontSize: 11),
                    ),
                  )),
                ]),
              ),
            ],
            // Technician's proposed edit awaiting CTO review — "a
            // technician can never approve their own change" is
            // structurally true (they hold no CTO authority), so these
            // buttons are only ever shown to an actual CTO-tier viewer.
            if (r.revisions.any((rev) => rev.isPendingReview)) ...[
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final pending = r.revisions.firstWhere((rev) => rev.isPendingReview);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${pending.editedByName ?? 'Technician'} proposed an edit: ${pending.reason}',
                      style: AppTheme.bodySm.copyWith(fontSize: 11.5, color: AppColors.blue),
                    ),
                    if (canCto) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        GestureDetector(
                          onTap: () => onApproveTechnicianEdit(r, pending),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(6)),
                            child: Text('Approve', style: AppTheme.bodySub.copyWith(fontSize: 11.5, color: const Color(0xFF06120F), fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => onRejectTechnicianEdit(r, pending),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(6)),
                            child: Text('Reject', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                          ),
                        ),
                      ]),
                    ],
                  ]),
                );
              }),
            ],
            if (r.adjustments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ADJUSTMENTS (POST-PAYMENT)', style: AppTheme.labelCaps.copyWith(fontSize: 9, color: AppColors.amber)),
                  const SizedBox(height: 6),
                  ...r.adjustments.map((adj) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${adj.amount >= 0 ? '+' : ''}TSh ${adj.amount} — ${adj.reason}',
                      style: AppTheme.bodySm.copyWith(fontSize: 11.5, color: AppColors.amber),
                    ),
                  )),
                ]),
              ),
            ],
            if (r.paymentInitiatedByName != null) ...[
              // Once finance has initiated payment, CTO/Finance/Director all
              // see the same trail here — this replaces the WhatsApp-group
              // PDF exchange the team uses today, so it must never be gated
              // to only whoever's turn it currently is.
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      'Payment initiated by ${r.paymentInitiatedByName}'
                      '${r.paymentMethod != null ? ' · ${r.paymentMethod!.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}' : ''}'
                      '${r.paymentReference != null && r.paymentReference!.isNotEmpty ? ' · Ref: ${r.paymentReference}' : ''}',
                      style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: AppColors.violet)),
                  if (r.isPaid && r.paidByName != null) ...[
                    const SizedBox(height: 4),
                    Text('Marked paid by ${r.paidByName}${r.paidAt != null ? ' · ${r.paidAt}' : ''}',
                        style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: AppColors.teal)),
                  ],
                ]),
              ),
            ],
            if (canActOnThis) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (atTeamLead || atCto) ...[
                  Expanded(child: GestureDetector(
                    onTap: () => atTeamLead ? onRejectTeamLead(r) : onReject(r),
                    child: Container(height: 36,
                      decoration: BoxDecoration(border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('Reject', style: AppTheme.bodySm.copyWith(color: AppColors.coral)))),
                  )),
                  const SizedBox(width: 10),
                ],
                Expanded(child: GestureDetector(
                  onTap: () => atTeamLead ? onForward(r)
                      : atPaymentInit ? onInitiatePayment(r)
                      : atDirectorAuth ? onAuthorizePayment(r)
                      : onApprove(r),
                  child: Container(height: 36,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(
                        atTeamLead ? 'Forward to CTO'
                            : atPaymentInit ? 'Initiate Payment'
                            : atDirectorAuth ? 'Money is Out'
                            : 'Approve',
                        style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 12.5)))),
                )),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                  atTeamLead ? 'Waiting on the team lead.'
                      : atCto ? 'Waiting on the CTO.'
                      : atPaymentInit ? 'Waiting on the accountant to initiate payment.'
                      : atDirectorAuth ? 'Waiting on the accountant or Director to release payment.'
                      : 'Waiting.',
                  style: AppTheme.bodySub.copyWith(fontSize: 11.5, fontStyle: FontStyle.italic)),
            ],
          ]),
        );
      }).toList()),
    );
  }
}

class _ExpenseTab extends StatelessWidget {
  const _ExpenseTab({
    required this.expenses, required this.pad, required this.viewerRole,
    required this.onApprove, required this.onEscalate, required this.onReject,
    required this.onInitiatePayment, required this.onReleasePayment,
  });
  final List<Expense> expenses;
  final double pad;
  final String viewerRole;
  final ValueChanged<Expense> onApprove;
  final ValueChanged<Expense> onEscalate;
  final ValueChanged<Expense> onReject;
  final ValueChanged<Expense> onInitiatePayment;
  final ValueChanged<Expense> onReleasePayment;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Center(child: Text('No pending expenses', style: TextStyle(color: context.pal.textMute)));
    }
    final canCto = hasCtoApprovalAuthority(viewerRole);
    final canDirector = hasDirectorAuthority(viewerRole);
    final canAccountant = hasAccountantAuthority(viewerRole);

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(children: expenses.map((e) {
        final atCto = e.status == ExpenseStatus.pendingCto;
        final atDirector = e.status == ExpenseStatus.pendingDirector;
        final atPaymentInit = e.status == ExpenseStatus.pendingPayment;
        final atRelease = e.status == ExpenseStatus.pendingRelease;
        // If flagged for Director, CTO can only escalate (approve would 422 server-side).
        final mustEscalate = atCto && e.requiresDirectorApproval;
        final canActOnThis = atCto ? canCto
            : atDirector ? canDirector
            : atPaymentInit ? canAccountant
            // Either can release — the accountant, since the Director is
            // often busy, or the Director directly. Never the same person
            // who initiated payment (enforced server-side).
            : atRelease ? (canAccountant || canDirector)
            : false;
        final stageColor = atCto ? AppColors.amber
            : atDirector ? AppColors.violet
            : atPaymentInit ? AppColors.blue
            : atRelease ? AppColors.teal
            : context.pal.textMute;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Symbols.receipt_long, size: 16, color: AppColors.coral),
              const SizedBox(width: 8),
              Expanded(child: Text('${e.name} · TSh ${e.grossAmount}',
                  style: AppTheme.bodyStrong.copyWith(fontSize: 13.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(e.status.label, style: AppTheme.monoXs.copyWith(
                    color: stageColor, fontSize: 9.5)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${e.categoryName ?? '—'} · ${e.expenseDate} · by ${e.createdByName ?? '—'}',
                style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
            if (mustEscalate) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(e.escalationReason ?? 'Requires Director approval.',
                    style: AppTheme.bodySub.copyWith(fontSize: 11.5, color: AppColors.amber)),
              ),
            ],
            if (e.paymentInitiatedByName != null) ...[
              // Once the accountant has initiated payment, everyone sees the
              // same trail here — mirrors the Per-Diem tab's equivalent panel.
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
                ),
                child: Text('Payment initiated by ${e.paymentInitiatedByName}',
                    style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: AppColors.blue)),
              ),
            ],
            if (canActOnThis) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (atCto || atDirector) ...[
                  Expanded(child: GestureDetector(
                    onTap: () => onReject(e),
                    child: Container(height: 36,
                      decoration: BoxDecoration(border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('Reject', style: AppTheme.bodySm.copyWith(color: AppColors.coral)))),
                  )),
                  const SizedBox(width: 10),
                ],
                Expanded(child: GestureDetector(
                  onTap: () => atPaymentInit ? onInitiatePayment(e)
                      : atRelease ? onReleasePayment(e)
                      : mustEscalate ? onEscalate(e)
                      : onApprove(e),
                  child: Container(height: 36,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(
                        atPaymentInit ? 'Initiate Payment'
                            : atRelease ? 'Release Payment'
                            : mustEscalate ? 'Escalate to Director'
                            : 'Approve',
                        style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 12.5)))),
                )),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                  atCto ? 'Waiting on CTO.'
                      : atDirector ? 'Waiting on the Director.'
                      : atPaymentInit ? 'Waiting on the accountant to initiate payment.'
                      : atRelease ? 'Waiting on the accountant or Director to release payment.'
                      : 'Waiting.',
                  style: AppTheme.bodySub.copyWith(fontSize: 11.5, fontStyle: FontStyle.italic)),
            ],
          ]),
        );
      }).toList()),
    );
  }
}

class _PurchaseOrderTab extends StatelessWidget {
  const _PurchaseOrderTab({
    required this.orders, required this.pad, required this.viewerRole,
    required this.onApproveSalesStage, required this.onRejectSalesStage,
    required this.onApproveDirectorReview, required this.onRejectDirectorReview,
    required this.onInitiatePayment,
    required this.onApproveDirectorFinal, required this.onRejectDirectorFinal,
  });
  final List<PurchaseOrder> orders;
  final double pad;
  final String viewerRole;
  final ValueChanged<PurchaseOrder> onApproveSalesStage;
  final ValueChanged<PurchaseOrder> onRejectSalesStage;
  final ValueChanged<PurchaseOrder> onApproveDirectorReview;
  final ValueChanged<PurchaseOrder> onRejectDirectorReview;
  final ValueChanged<PurchaseOrder> onInitiatePayment;
  final ValueChanged<PurchaseOrder> onApproveDirectorFinal;
  final ValueChanged<PurchaseOrder> onRejectDirectorFinal;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(child: Text('No pending purchase orders', style: TextStyle(color: context.pal.textMute)));
    }
    final canSalesStage = hasProcurementSalesStageAuthority(viewerRole);
    final canDirector   = hasDirectorAuthority(viewerRole);
    final canAccountant = hasAccountantAuthority(viewerRole);

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(children: orders.map((po) {
        final stageColor = AppColors.amber;
        final (canActOnThis, waitingOn, onApprove, onReject, approveLabel) = switch (po.status) {
          'pending_sales_manager' =>
            (canSalesStage, 'the sales manager', onApproveSalesStage, onRejectSalesStage, 'Approve'),
          'pending_director_review' =>
            (canDirector, 'the director', onApproveDirectorReview, onRejectDirectorReview, 'Approve'),
          'pending_payment_initiation' =>
            (canAccountant, 'the accountant', onInitiatePayment, null, 'Initiate Payment'),
          'pending_director_final' =>
            (canDirector, 'the director', onApproveDirectorFinal, onRejectDirectorFinal, 'Final Approve'),
          _ => (false, 'someone else', null, null, ''),
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Symbols.local_shipping, size: 16, color: AppColors.violet),
              const SizedBox(width: 8),
              Expanded(child: Text('${po.poNumber} · ${po.supplierName ?? '—'}',
                  style: AppTheme.bodyStrong.copyWith(fontSize: 13.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(po.statusLabel, style: AppTheme.monoXs.copyWith(
                    color: stageColor, fontSize: 9.5)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${po.currency} ${po.totalAmount.toStringAsFixed(0)}  ·  ordered by ${po.orderedByName ?? '—'}',
                style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
            if (po.items.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(po.items.map((i) => '${i.itemName ?? '—'} ×${i.quantityOrdered}').join(', '),
                  style: AppTheme.bodySub.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (canActOnThis) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (onReject != null) ...[
                  Expanded(child: GestureDetector(
                    onTap: () => onReject(po),
                    child: Container(height: 36,
                      decoration: BoxDecoration(border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('Reject', style: AppTheme.bodySm.copyWith(color: AppColors.coral)))),
                  )),
                  const SizedBox(width: 10),
                ],
                Expanded(child: GestureDetector(
                  onTap: () => onApprove!(po),
                  child: Container(height: 36,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(approveLabel,
                        style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 12.5)))),
                )),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              Text('Waiting on $waitingOn.',
                  style: AppTheme.bodySub.copyWith(fontSize: 11.5, fontStyle: FontStyle.italic)),
            ],
          ]),
        );
      }).toList()),
    );
  }
}
