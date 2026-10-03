// lib/models/cto_approval.dart — one row in the CTO's "Awaiting your approval"
// desk. A thin adapter over the three real models so the dashboard can list,
// sort and act on them uniformly; the source object is kept for the actual
// API call (CtoDashboardService.approve / returnItem).
import 'expense.dart';
import 'per_diem_request.dart';
import 'stock_out_request.dart';

enum CtoApprovalKind { trip, expense, stock }

enum CtoDecision { approved, returned }

enum CtoStepState { done, current, returned, upcoming }

class CtoApprovalLine {
  final String a, b, c;
  const CtoApprovalLine(this.a, this.b, [this.c = '']);
}

class CtoApprovalStep {
  final String label;
  final String sub;
  final CtoStepState state;
  const CtoApprovalStep(this.label, this.sub, this.state);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _dm(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';
}
String _n(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class CtoApproval {
  final CtoApprovalKind kind;
  final String key;        // unique across kinds, e.g. "trip-142"
  final String ref;        // display id
  final String requester;
  final String title;
  final String meta;
  final int? amount;       // TSh; null for stock
  final String? qtyLabel;  // stock: "×1"
  final String? flag;      // amber note (technician edit, director escalation…)
  final List<CtoApprovalLine> lines;
  final List<CtoApprovalStep> steps;
  final DateTime? createdAt;

  final PerDiemRequest? perDiem;
  final Expense? expense;
  final StockOutRequest? stock;
  final int? pendingRevisionId; // technician-proposed per-diem edit awaiting CTO

  const CtoApproval({
    required this.kind, required this.key, required this.ref, required this.requester,
    required this.title, required this.meta, this.amount, this.qtyLabel, this.flag,
    this.lines = const [], this.steps = const [], this.createdAt,
    this.perDiem, this.expense, this.stock, this.pendingRevisionId,
  });

  /// Per-diem server rule: rejection_reason required, min 10 chars.
  bool get returnNeedsReason => kind == CtoApprovalKind.trip;
  bool get canEditDays => kind == CtoApprovalKind.trip && perDiem != null;
  String get approveLabel => kind == CtoApprovalKind.trip
      ? 'Approve trip + per diem'
      : (expense?.requiresDirectorApproval ?? false) ? 'Forward to Director' : 'Approve';
  String get nextAfterApprove => kind == CtoApprovalKind.stock
      ? 'Stores notified to issue'
      : (expense?.requiresDirectorApproval ?? false) ? 'Sent to the Director' : 'Sent to Finance for payment';

  /// Trip and its per diem are one PerDiemRequest — approving it approves both.
  factory CtoApproval.fromPerDiem(PerDiemRequest r) {
    final rev = r.revisions.where((x) => x.isPendingReview).firstOrNull;
    return CtoApproval(
      kind: CtoApprovalKind.trip,
      key: 'trip-${r.id}',
      ref: 'PD-${r.id.toString().padLeft(4, '0')}',
      requester: r.staffNameSnapshot ?? r.userName ?? '—',
      title: (r.purpose?.isNotEmpty ?? false) ? r.purpose! : r.destination,
      meta: '${_dm(r.startDate)}–${_dm(r.endDate)} · ${r.daysCount} days',
      amount: r.summary?.grandTotal ?? r.amount,
      flag: rev == null ? null : 'Technician proposed edit · ${rev.reason}',
      pendingRevisionId: rev?.id,
      createdAt: DateTime.tryParse(r.createdAt ?? ''),
      lines: r.lines.map((l) => CtoApprovalLine(
            _dm(l.date),
            [l.siteName ?? l.district ?? l.region, l.activity].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
            _n(l.total),
          )).toList(),
      steps: r.signatureBlock.isNotEmpty
          ? r.signatureBlock.map((s) => CtoApprovalStep(
                s.roleLabel,
                s.personName ?? (s.pending ? 'Pending' : '—'),
                s.stage == 'cto' ? CtoStepState.current : (s.pending ? CtoStepState.upcoming : CtoStepState.done),
              )).toList()
          : [
              CtoApprovalStep('Requester', r.staffNameSnapshot ?? r.userName ?? '—', CtoStepState.done),
              CtoApprovalStep('Team lead', r.teamLeadReviewerName ?? '—', CtoStepState.done),
              const CtoApprovalStep('CTO · you', 'Pending', CtoStepState.current),
              const CtoApprovalStep('Finance', 'pays', CtoStepState.upcoming),
            ],
      perDiem: r,
    );
  }

  factory CtoApproval.fromExpense(Expense e) => CtoApproval(
        kind: CtoApprovalKind.expense,
        key: 'expense-${e.id}',
        ref: e.reference ?? 'EX-${e.id.toString().padLeft(4, '0')}',
        requester: e.createdByName ?? '—',
        title: e.name,
        meta: [e.categoryName, _dm(e.expenseDate)].whereType<String>().join(' · '),
        amount: e.grossAmount,
        flag: e.requiresDirectorApproval ? 'Goes to the Director after you' : null,
        createdAt: e.createdAt,
        lines: [
          if (e.categoryName != null) CtoApprovalLine('Cat.', e.categoryName!),
          CtoApprovalLine('Date', _dm(e.expenseDate)),
          CtoApprovalLine('Paid', e.paymentModeLabel),
          CtoApprovalLine('Net', 'Before tax', _n(e.amount)),
          if (e.taxAmount > 0) CtoApprovalLine('Tax', '${e.taxRate.toStringAsFixed(0)}%', _n(e.taxAmount)),
          if (e.notes?.isNotEmpty ?? false) CtoApprovalLine('Note', e.notes!),
        ],
        steps: [
          CtoApprovalStep('Requester', e.createdByName ?? '—', CtoStepState.done),
          const CtoApprovalStep('CTO · you', 'Pending', CtoStepState.current),
          if (e.requiresDirectorApproval) const CtoApprovalStep('Director', 'next', CtoStepState.upcoming),
          const CtoApprovalStep('Finance', 'pays', CtoStepState.upcoming),
        ],
        expense: e,
      );

  factory CtoApproval.fromStock(StockOutRequest s) => CtoApproval(
        kind: CtoApprovalKind.stock,
        key: 'stock-${s.id}',
        ref: 'SR-${s.id.toString().padLeft(4, '0')}',
        requester: s.requesterName ?? '—',
        title: '${s.itemName ?? 'Item'} ×${s.quantity}',
        meta: [if (s.serviceTicketNumber != null) 'For ${s.serviceTicketNumber}', s.locationName].whereType<String>().join(' · '),
        qtyLabel: '×${s.quantity}',
        flag: s.type == 'write_off' ? 'Write-off, not an issue to a ticket' : null,
        createdAt: DateTime.tryParse(s.createdAt ?? ''),
        lines: [
          if (s.itemSku != null) CtoApprovalLine('SKU', s.itemSku!),
          if (s.locationName != null) CtoApprovalLine('From', s.locationName!),
          if (s.serviceTicketNumber != null) CtoApprovalLine('Ticket', s.serviceTicketNumber!),
          CtoApprovalLine('Reason', s.reason),
        ],
        steps: [
          CtoApprovalStep('Requester', s.requesterName ?? '—', CtoStepState.done),
          const CtoApprovalStep('CTO · you', 'Pending', CtoStepState.current),
          const CtoApprovalStep('Stores', 'issues part', CtoStepState.upcoming),
        ],
        stock: s,
      );
}
