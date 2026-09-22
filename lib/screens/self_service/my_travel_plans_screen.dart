import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/per_diem_request.dart';
import '../../services/per_diem_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/pdf_download.dart';
import '../../widgets/common/error_view.dart';
import '../approvals/per_diem_revise_dialog.dart';

// Section 7: "My travel plans" — a technician's own submitted per-diem
// requests. PerDiemController::index() is already scoped server-side to
// the caller's own requests for anyone without team-lead/accountant
// authority, so this screen is purely a new read-only view over data the
// backend already restricts correctly — see Section 1.
class MyTravelPlansScreen extends StatefulWidget {
  const MyTravelPlansScreen({super.key, this.onOpenTicket});
  final void Function(int ticketId)? onOpenTicket;

  @override
  State<MyTravelPlansScreen> createState() => _MyTravelPlansScreenState();
}

class _MyTravelPlansScreenState extends State<MyTravelPlansScreen> {
  List<PerDiemRequest> _plans = [];
  bool    _loading = true;
  String? _error;
  int?    _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await PerDiemService.instance.list();
      if (mounted) setState(() { _plans = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _downloadPdf(PerDiemRequest p) => downloadPdf(
    context, () => PerDiemService.instance.pdfBytes(p.id), 'travel-plan-${p.id}.pdf',
  );

  // Section 15.5: reproduces the approved WORKPLAN template cell-for-cell.
  Future<void> _downloadXlsx(PerDiemRequest p) => downloadPdf(
    context, () => PerDiemService.instance.xlsxBytes(p.id), 'travel-plan-${p.id}.xlsx',
  );

  // Section 8: "the CTO grants edit permission on a specific plan... while
  // granted, the technician can edit only what was unlocked." Reuses the
  // same day-by-day editor the CTO uses, in propose mode — the edit is
  // stored for CTO review, not applied immediately.
  void _showProposeEditDialog(PerDiemRequest p) {
    showDialog<void>(
      context: context,
      builder: (_) => PerDiemReviseDialog(
        request: p,
        isProposal: true,
        onClose: () => Navigator.of(context).pop(),
        onSaved: () {
          Navigator.of(context).pop();
          if (mounted) { showSuccessToast(context, 'Edit submitted — awaiting CTO approval.'); _load(); }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Travel Plans', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Status of per-diem requests you\'ve submitted', style: AppTheme.bodySub),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else if (_plans.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No travel plans submitted yet', style: TextStyle(color: context.pal.textMute))))
            else
              Column(children: _plans.map((p) => _PlanCard(
                plan: p,
                expanded: _expandedId == p.id,
                onToggle: () => setState(() => _expandedId = _expandedId == p.id ? null : p.id),
                onDownload: () => _downloadPdf(p),
                onDownloadXlsx: () => _downloadXlsx(p),
                onProposeEdit: p.hasActiveEditGrant ? () => _showProposeEditDialog(p) : null,
                onOpenTicket: (widget.onOpenTicket == null || p.serviceTicketId == null)
                    ? null : () => widget.onOpenTicket!(p.serviceTicketId!),
              )).toList()),
          ]),
        ),
      );
    });
  }
}

Color _stageColor(PerDiemRequest p) {
  if (p.status == PerDiemStatus.rejected) return AppColors.coral;
  if (p.status == PerDiemStatus.cancelled) return AppColors.textMute;
  if (p.isPaid) return AppColors.teal;
  if (p.isPendingTeamLead) return AppColors.amber;
  if (p.isPendingCto) return AppColors.blue;
  if (p.isPendingPayment) return AppColors.violet;
  if (p.isPendingDirector) return AppColors.teal;
  return AppColors.textMute;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan, required this.expanded, required this.onToggle,
    required this.onDownload, required this.onDownloadXlsx, this.onOpenTicket, this.onProposeEdit,
  });
  final PerDiemRequest plan;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDownload;
  final VoidCallback onDownloadXlsx;
  final VoidCallback? onOpenTicket;
  // Non-null only when the CTO has granted this technician edit access on
  // this plan (Section 8: "a technician cannot edit by default").
  final VoidCallback? onProposeEdit;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(plan);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: onToggle,
          child: Row(children: [
            Icon(Symbols.flight_takeoff, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(plan.destination, style: AppTheme.bodyStrong.copyWith(fontSize: 13.5))),
            if (plan.wasEdited) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('Edited by CTO', style: AppTheme.bodySub.copyWith(color: AppColors.amber, fontSize: 10)),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(plan.status.label, style: AppTheme.bodySub.copyWith(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Icon(expanded ? Symbols.expand_less : Symbols.expand_more, size: 18, color: context.pal.textDim),
          ]),
        ),
        const SizedBox(height: 10),
        Text('${plan.startDate} → ${plan.endDate}  ·  ${plan.daysCount} day(s)  ·  TSh ${plan.amount}', style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
        if (onOpenTicket != null) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onOpenTicket,
            child: Text('Linked ticket #${plan.serviceTicketId}', style: AppTheme.bodySm.copyWith(fontSize: 12, color: AppColors.teal, decoration: TextDecoration.underline)),
          ),
        ],
        if (plan.status == PerDiemStatus.rejected && plan.rejectionReason != null) ...[
          const SizedBox(height: 6),
          Text('Reason: ${plan.rejectionReason}', style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 12)),
        ],
        if (plan.status == PerDiemStatus.cancelled && plan.cancellationReason != null) ...[
          const SizedBox(height: 6),
          Text('Reason: ${plan.cancellationReason}', style: AppTheme.bodySub.copyWith(color: context.pal.textMute, fontSize: 12)),
        ],
        if (expanded) ...[
          const Divider(height: 24),
          if (plan.lines.isNotEmpty) ...[
            Text('DAY-BY-DAY ITINERARY', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
            const SizedBox(height: 8),
            ...plan.lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Day ${l.seqNo} · ${l.date}${l.siteName != null ? ' · ${l.siteName}' : ''}${l.activity != null ? ' · ${l.activity}' : ''} — TSh ${l.total}',
                style: AppTheme.bodySub.copyWith(fontSize: 12),
              ),
            )),
            const SizedBox(height: 10),
          ],
          if (plan.summary != null) ...[
            Text('SUMMARY', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
            const SizedBox(height: 8),
            Wrap(spacing: 18, runSpacing: 4, children: [
              Text('Sites: ${plan.summary!.sitesVisited}', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              Text('Days: ${plan.summary!.daysSpent}', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              Text('Avg days/site: ${plan.summary!.avgDaysPerSite?.toStringAsFixed(1) ?? '-'}', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              Text('Avg cost/site: ${plan.summary!.avgCostPerSite != null ? 'TSh ${plan.summary!.avgCostPerSite!.toStringAsFixed(0)}' : '-'}', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              Text('Grand total: TSh ${plan.summary!.grandTotal}', style: AppTheme.bodyStrong.copyWith(fontSize: 12, color: AppColors.teal)),
            ]),
            const SizedBox(height: 10),
          ],
          if (plan.paymentSnapshot != null) ...[
            Text('PAYMENT DETAILS', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            Text(
              '${plan.paymentSnapshot!.provider ?? ''} · ${plan.paymentSnapshot!.accountNumber ?? ''} · ${plan.paymentSnapshot!.accountName ?? ''}',
              style: AppTheme.bodySub.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 10),
          ],
          if (plan.adjustments.isNotEmpty) ...[
            Text('PAYMENT ADJUSTMENTS', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
            const SizedBox(height: 8),
            ...plan.adjustments.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${a.amount >= 0 ? '+' : ''}TSh ${a.amount} — ${a.reason}', style: AppTheme.bodySub.copyWith(fontSize: 12)),
            )),
            const SizedBox(height: 10),
          ],
          if (plan.revisions.where((r) => !r.isPendingReview).isNotEmpty) ...[
            Text('REVISION HISTORY', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
            const SizedBox(height: 8),
            ...plan.revisions.where((r) => !r.isPendingReview).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${r.editedByName ?? 'Someone'} (${r.editorRole}) · ${r.reason}${r.status == 'rejected' ? ' (rejected)' : ''}',
                style: AppTheme.bodySub.copyWith(fontSize: 12),
              ),
            )),
            const SizedBox(height: 6),
          ],
          if (plan.hasActiveEditGrant) ...[
            Builder(builder: (context) {
              final pendingReview = plan.revisions.where((r) => r.isPendingReview).isNotEmpty;
              if (pendingReview) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Your proposed edit is awaiting CTO review.', style: AppTheme.bodySub.copyWith(fontSize: 12, color: AppColors.blue)),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('The CTO has given you edit access on this plan.', style: AppTheme.bodySub.copyWith(fontSize: 12, color: context.pal.textDim)),
              );
            }),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (onProposeEdit != null && plan.revisions.where((r) => r.isPendingReview).isEmpty) ...[
              GestureDetector(
                onTap: onProposeEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Symbols.edit_calendar, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Propose Edit', style: AppTheme.bodySub.copyWith(fontSize: 12, color: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: onDownload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.download, size: 14, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Text('Download PDF', style: AppTheme.bodySub.copyWith(fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDownloadXlsx,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.table_chart, size: 14, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Text('Download XLSX', style: AppTheme.bodySub.copyWith(fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
