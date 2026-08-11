import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/leave_request.dart';
import '../../services/late_arrival_service.dart';
import '../../services/leave_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

class MyLeaveScreen extends StatefulWidget {
  const MyLeaveScreen({super.key});

  @override
  State<MyLeaveScreen> createState() => _MyLeaveScreenState();
}

class _MyLeaveScreenState extends State<MyLeaveScreen> {
  List<LeaveRequest> _requests = [];
  bool    _loading = true;
  String? _error;
  bool    _showRequestDialog = false;
  bool    _showLateDialog = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await LeaveService.instance.list();
      if (mounted) setState(() { _requests = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _cancel(LeaveRequest r) async {
    try {
      await LeaveService.instance.cancel(r.id);
      if (mounted) { showSuccessToast(context, 'Leave request cancelled.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      LayoutBuilder(builder: (ctx, cst) {
        final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(pad),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (ctx, cst) {
                final narrow = cst.maxWidth < 560;
                final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My Leave', style: AppTheme.pageTitle),
                  const SizedBox(height: 4),
                  Text('Request time off or let HR know you\'re running late', style: AppTheme.bodySub),
                ]);
                final actions = Row(mainAxisSize: MainAxisSize.min, children: [
                  AppButton(label: 'Running Late', icon: Symbols.schedule, variant: BtnVariant.ghost,
                      onPressed: () => setState(() => _showLateDialog = true)),
                  const SizedBox(width: 8),
                  AppButton(label: 'Request Leave', icon: Symbols.add, variant: BtnVariant.primary,
                      onPressed: () => setState(() => _showRequestDialog = true)),
                ]);
                if (narrow) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 12), actions]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [titleBlock, const Spacer(), actions]);
              }),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_error != null)
                ErrorView(message: _error!, onRetry: _load)
              else if (_requests.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No leave requests yet', style: TextStyle(color: AppColors.textMute))))
              else
                Column(children: _requests.map((r) => _LeaveCard(request: r, onCancel: () => _cancel(r))).toList()),
            ]),
          ),
        );
      }),
      if (_showRequestDialog)
        _RequestLeaveDialog(
          onClose: () => setState(() => _showRequestDialog = false),
          onSaved: () { setState(() => _showRequestDialog = false); _load(); },
        ),
      if (_showLateDialog)
        _RunningLateDialog(
          onClose: () => setState(() => _showLateDialog = false),
        ),
    ]);
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.request, required this.onCancel});
  final LeaveRequest request;
  final VoidCallback onCancel;

  Color get _statusColor => switch (request.status) {
    LeaveStatus.pending   => AppColors.amber,
    LeaveStatus.approved  => AppColors.teal,
    LeaveStatus.rejected  => AppColors.coral,
    LeaveStatus.cancelled => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Symbols.event, size: 16, color: _statusColor),
        const SizedBox(width: 8),
        Text(request.type.label, style: AppTheme.bodyStrong.copyWith(fontSize: 13.5)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
          child: Text(request.status.label, style: AppTheme.bodySub.copyWith(color: _statusColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      Text('${request.startDate} → ${request.endDate}  ·  ${request.daysCount} day(s)', style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
      if (request.reason != null && request.reason!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(request.reason!, style: AppTheme.bodySub.copyWith(fontSize: 12)),
      ],
      if (request.status == LeaveStatus.rejected && request.rejectionReason != null) ...[
        const SizedBox(height: 6),
        Text('Reason: ${request.rejectionReason}', style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 12)),
      ],
      if (request.canCancel) ...[
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: GestureDetector(
          onTap: onCancel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(6)),
            child: Text('Cancel', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
          ),
        )),
      ],
    ]),
  );
}

// ── Request Leave dialog ─────────────────────────────────────────────────────

class _RequestLeaveDialog extends StatefulWidget {
  const _RequestLeaveDialog({required this.onClose, required this.onSaved});
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_RequestLeaveDialog> createState() => _RequestLeaveDialogState();
}

class _RequestLeaveDialogState extends State<_RequestLeaveDialog> {
  LeaveType _type = LeaveType.vacation;
  DateTime  _start = DateTime.now();
  DateTime  _end   = DateTime.now();
  final _reasonCtrl = TextEditingController();
  bool    _saving = false;
  String? _error;

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context, initialDate: isStart ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) { _start = picked; if (_end.isBefore(_start)) _end = picked; }
        else { _end = picked; }
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_end.isBefore(_start)) { setState(() => _error = 'End date must be on or after start date.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await LeaveService.instance.create({
        'type': _type.apiValue, 'start_date': _iso(_start), 'end_date': _iso(_end),
        'reason': _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 460,
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                const Icon(Symbols.event, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('Request Leave', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose, child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12)),
                  ),
                ],
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('LEAVE TYPE', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(child: DropdownButton<LeaveType>(
                      value: _type, isExpanded: true, dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
                      icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
                      items: LeaveType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                      onChanged: (v) => setState(() => _type = v ?? LeaveType.vacation),
                    )),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _DateField(label: 'Start Date', date: _start, onTap: () => _pickDate(true))),
                  const SizedBox(width: 14),
                  Expanded(child: _DateField(label: 'End Date', date: _end, onTap: () => _pickDate(false))),
                ]),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerLeft, child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${_end.difference(_start).inDays + 1} day(s)', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                )),
                const SizedBox(height: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('REASON (OPTIONAL)', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  Container(
                    height: 70,
                    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(controller: _reasonCtrl, maxLines: null, expands: true, style: AppTheme.bodySm,
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Any details HR should know…')),
                  ),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(child: GestureDetector(onTap: widget.onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: _save,
                  child: Container(height: 38,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Submit Request', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13)))))),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(child: Text(formatDate(date), style: AppTheme.bodySm)),
          Icon(Symbols.calendar_month, size: 15, color: context.pal.textDim),
        ]),
      ),
    ),
  ]);
}

// ── Running Late dialog ────────────────────────────────────────────────────

class _RunningLateDialog extends StatefulWidget {
  const _RunningLateDialog({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_RunningLateDialog> createState() => _RunningLateDialogState();
}

class _RunningLateDialogState extends State<_RunningLateDialog> {
  final _timeCtrl   = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _timeCtrl.dispose(); _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await LateArrivalService.instance.report(
        expectedTime: _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (mounted) { showSuccessToast(context, 'HR has been notified.'); widget.onClose(); }
    } catch (e) {
      if (mounted) { setState(() => _saving = false); showErrorToast(context, e); }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                const Icon(Symbols.schedule, size: 18, color: AppColors.amber),
                const SizedBox(width: 10),
                Text('Running Late', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose, child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('EXPECTED ARRIVAL (OPTIONAL)', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(controller: _timeCtrl, style: AppTheme.bodySm,
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'e.g. 9:30am')),
                  ),
                ]),
                const SizedBox(height: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('REASON (OPTIONAL)', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  Container(
                    height: 70,
                    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(controller: _reasonCtrl, maxLines: null, expands: true, style: AppTheme.bodySm,
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'e.g. Traffic, appointment…')),
                  ),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(child: GestureDetector(onTap: widget.onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: _save,
                  child: Container(height: 38,
                    decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Notify HR', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13)))))),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}
