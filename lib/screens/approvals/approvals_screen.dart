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
  String? _error;

  List<StockOutRequest> get _pendingStockOut =>
      _stockOut.where((r) => r.status == StockOutStatus.pending).toList();
  List<PerDiemRequest> get _pendingPerDiem =>
      _perDiem.where((r) =>
          r.isPendingTeamLead || r.isPendingCto || r.isPendingPayment || r.isPendingDirector).toList();
  List<Expense> get _pendingExpenses => _expenses.where(
      (e) => e.status == ExpenseStatus.pendingCto || e.status == ExpenseStatus.pendingDirector).toList();
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
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        StockOutRequestService.instance.list(status: 'pending'),
        PerDiemService.instance.list(),
        ExpenseService.instance.list(),
        PurchaseOrderService.instance.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _stockOut       = results[0] as List<StockOutRequest>;
        _perDiem        = results[1] as List<PerDiemRequest>;
        _expenses       = results[2] as List<Expense>;
        _purchaseOrders = results[3] as List<PurchaseOrder>;
        _loading        = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
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
    final reason = await showDialog<String>(context: context, builder: (_) => _RejectReasonDialog());
    if (reason == null) return;
    try {
      await PerDiemService.instance.rejectTeamLead(r.id, reason: reason.isEmpty ? null : reason);
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
    final reason = await showDialog<String>(context: context, builder: (_) => _RejectReasonDialog());
    if (reason == null) return;
    try {
      await PerDiemService.instance.reject(r.id, reason: reason.isEmpty ? null : reason);
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
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : ValueListenableBuilder<String>(
                      valueListenable: userRoleNotifier,
                      builder: (_, role, _) => TabBarView(controller: _tab, children: [
                        _StockOutTab(requests: _pendingStockOut, pad: pad, onApprove: _approveStockOut, onReject: _rejectStockOut),
                        _PerDiemTab(
                          requests: _pendingPerDiem, pad: pad, viewerRole: role,
                          onForward: _forwardPerDiem, onRejectTeamLead: _rejectPerDiemTeamLead,
                          onApprove: _approvePerDiem, onReject: _rejectPerDiem,
                          onInitiatePayment: _initiatePerDiemPayment,
                          onAuthorizePayment: _authorizePerDiemPayment,
                        ),
                        _ExpenseTab(
                          expenses: _pendingExpenses, pad: pad, viewerRole: role,
                          onApprove: _approveExpense, onEscalate: _escalateExpense, onReject: _rejectExpense,
                        ),
                        _PurchaseOrderTab(
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
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    title: Text('Reject Request', style: AppTheme.bodyStrong),
    content: TextField(
      controller: _ctrl, maxLines: 3, style: AppTheme.bodySm,
      decoration: InputDecoration(hintText: 'Reason (optional)', hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim)),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()), child: Text('Reject', style: TextStyle(color: AppColors.coral))),
    ],
  );
}

class _InitiatePaymentDialog extends StatefulWidget {
  @override
  State<_InitiatePaymentDialog> createState() => _InitiatePaymentDialogState();
}

class _InitiatePaymentDialogState extends State<_InitiatePaymentDialog> {
  static const _methods = ['cash', 'bank_transfer', 'mobile_money', 'cheque'];
  String _method = _methods.first;
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
        items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(
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
            : atDirectorAuth ? canDirector
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
                            : atDirectorAuth ? 'Authorize Payment'
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
                      : atDirectorAuth ? 'Waiting on the Director to authorize payment.'
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
  });
  final List<Expense> expenses;
  final double pad;
  final String viewerRole;
  final ValueChanged<Expense> onApprove;
  final ValueChanged<Expense> onEscalate;
  final ValueChanged<Expense> onReject;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Center(child: Text('No pending expenses', style: TextStyle(color: context.pal.textMute)));
    }
    final canCto = hasCtoApprovalAuthority(viewerRole);
    final canDirector = hasDirectorAuthority(viewerRole);

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(children: expenses.map((e) {
        final atCto = e.status == ExpenseStatus.pendingCto;
        // If flagged for Director, CTO can only escalate (approve would 422 server-side).
        final mustEscalate = atCto && e.requiresDirectorApproval;
        final canActOnThis = atCto ? canCto : canDirector;

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
                  color: (atCto ? AppColors.amber : AppColors.violet).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(e.status.label, style: AppTheme.monoXs.copyWith(
                    color: atCto ? AppColors.amber : AppColors.violet, fontSize: 9.5)),
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
            if (canActOnThis) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => onReject(e),
                  child: Container(height: 36,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Reject', style: AppTheme.bodySm.copyWith(color: AppColors.coral)))),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => mustEscalate ? onEscalate(e) : onApprove(e),
                  child: Container(height: 36,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(mustEscalate ? 'Escalate to Director' : 'Approve',
                        style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 12.5)))),
                )),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              Text(atCto ? 'Waiting on CTO.' : 'Waiting on the Director.',
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
