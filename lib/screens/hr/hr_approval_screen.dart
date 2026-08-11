import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/late_arrival.dart';
import '../../models/leave_request.dart';
import '../../services/late_arrival_service.dart';
import '../../services/leave_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';

class HrApprovalScreen extends StatefulWidget {
  const HrApprovalScreen({super.key});

  @override
  State<HrApprovalScreen> createState() => _HrApprovalScreenState();
}

class _HrApprovalScreenState extends State<HrApprovalScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  List<LeaveRequest> _all = [];
  List<LateArrival>  _lateArrivals = [];
  bool    _loading = true;
  String? _error;

  List<LeaveRequest> get _pending => _all.where((r) => r.status == LeaveStatus.pending).toList();
  List<LeaveRequest> get _onLeaveNow {
    final today = DateTime.now();
    return _all.where((r) {
      if (r.status != LeaveStatus.approved) return false;
      final start = DateTime.tryParse(r.startDate);
      final end = DateTime.tryParse(r.endDate);
      if (start == null || end == null) return false;
      return !today.isBefore(start) && !today.isAfter(end);
    }).toList();
  }

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
        LeaveService.instance.list(),
        LateArrivalService.instance.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _all = results[0] as List<LeaveRequest>;
        _lateArrivals = results[1] as List<LateArrival>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _approve(LeaveRequest r) async {
    try {
      await LeaveService.instance.approve(r.id);
      if (mounted) { showSuccessToast(context, 'Approved.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _reject(LeaveRequest r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectReasonDialog(),
    );
    if (reason == null) return;
    try {
      await LeaveService.instance.reject(r.id, reason: reason.isEmpty ? null : reason);
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
            Text('HR — Leave & Attendance', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Review requests, see who\'s out, track late arrivals', style: AppTheme.bodySub),
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
              Tab(text: 'Pending (${_pending.length})'),
              Tab(text: 'On Leave (${_onLeaveNow.length})'),
              Tab(text: 'Late Arrivals'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : TabBarView(controller: _tab, children: [
                      _PendingTab(requests: _pending, pad: pad, onApprove: _approve, onReject: _reject),
                      _OnLeaveTab(requests: _onLeaveNow, pad: pad),
                      _LateArrivalsTab(arrivals: _lateArrivals, pad: pad),
                    ]),
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
    title: Text('Reject Leave Request', style: AppTheme.bodyStrong),
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

class _PendingTab extends StatelessWidget {
  const _PendingTab({required this.requests, required this.pad, required this.onApprove, required this.onReject});
  final List<LeaveRequest> requests;
  final double pad;
  final ValueChanged<LeaveRequest> onApprove;
  final ValueChanged<LeaveRequest> onReject;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(child: Text('No pending requests', style: TextStyle(color: AppColors.textMute)));
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
            Icon(Symbols.person, size: 16, color: context.pal.textMute),
            const SizedBox(width: 8),
            Expanded(child: Text('${r.userName ?? '—'} · ${r.type.label}', style: AppTheme.bodyStrong.copyWith(fontSize: 13.5))),
          ]),
          const SizedBox(height: 8),
          Text('${r.startDate} → ${r.endDate}  ·  ${r.daysCount} day(s)', style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
          if (r.reason != null && r.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.reason!, style: AppTheme.bodySub.copyWith(fontSize: 12)),
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

class _OnLeaveTab extends StatelessWidget {
  const _OnLeaveTab({required this.requests, required this.pad});
  final List<LeaveRequest> requests;
  final double pad;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(child: Text('Nobody is on leave right now', style: TextStyle(color: AppColors.textMute)));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Container(
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Column(children: requests.asMap().entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: e.key == requests.length - 1 ? null : Border(bottom: BorderSide(color: context.pal.divider))),
          child: Row(children: [
            Icon(Symbols.event_available, size: 16, color: AppColors.teal),
            const SizedBox(width: 10),
            Expanded(child: Text(e.value.userName ?? '—', style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
            Text('${e.value.type.label} · back ${e.value.endDate}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
          ]),
        )).toList()),
      ),
    );
  }
}

class _LateArrivalsTab extends StatelessWidget {
  const _LateArrivalsTab({required this.arrivals, required this.pad});
  final List<LateArrival> arrivals;
  final double pad;

  @override
  Widget build(BuildContext context) {
    if (arrivals.isEmpty) {
      return const Center(child: Text('No late-arrival reports', style: TextStyle(color: AppColors.textMute)));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Container(
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Column(children: arrivals.asMap().entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: e.key == arrivals.length - 1 ? null : Border(bottom: BorderSide(color: context.pal.divider))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.schedule, size: 16, color: AppColors.amber),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(e.value.userName ?? '—', style: AppTheme.bodySm.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(e.value.date, style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
              ]),
              if (e.value.expectedTime != null || e.value.reason != null) ...[
                const SizedBox(height: 3),
                Text(
                  [if (e.value.expectedTime != null) 'ETA ${e.value.expectedTime}', if (e.value.reason != null) e.value.reason!].join(' · '),
                  style: AppTheme.bodySub.copyWith(fontSize: 11.5),
                ),
              ],
            ])),
          ]),
        )).toList()),
      ),
    );
  }
}
