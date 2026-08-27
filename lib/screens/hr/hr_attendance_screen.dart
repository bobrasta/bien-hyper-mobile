import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/attendance_service.dart';
import '../../services/staff_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';

/// Attendance — manual daily marking is the primary path (always works, no
/// external dependency); bulk Excel import from a biometric terminal export
/// is a best-effort bonus path layered on top of the same records table.
class HrAttendanceScreen extends StatefulWidget {
  const HrAttendanceScreen({super.key});

  @override
  State<HrAttendanceScreen> createState() => _HrAttendanceScreenState();
}

class _HrAttendanceScreenState extends State<HrAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  List<StaffMember> _staff = [];
  List<AttendanceRecord> _dayRecords = [];
  Map<String, List<AttendanceRecord>> _monthByUser = {};
  bool _loading = true;
  String? _error;
  AttendanceImportResult? _lastImport;

  static const _statuses = ['present', 'late', 'absent', 'half_day', 'leave'];
  static const _statusLabels = {'present': 'Present', 'late': 'Late', 'absent': 'Absent', 'half_day': 'Half Day', 'leave': 'Leave'};

  @override
  void initState() { super.initState(); _load(); }

  static String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final monthStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final monthEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      final results = await Future.wait([
        StaffService.instance.list(),
        AttendanceService.instance.list(start: _fmt(monthStart), end: _fmt(monthEnd)),
      ]);
      final staff = results[0] as List<StaffMember>;
      final monthRecords = results[1] as List<AttendanceRecord>;
      final byUser = <String, List<AttendanceRecord>>{};
      for (final r in monthRecords) {
        byUser.putIfAbsent('${r.userId}', () => []).add(r);
      }
      if (mounted) setState(() {
        _staff = staff;
        _monthByUser = byUser;
        _dayRecords = monthRecords.where((r) => r.date == _fmt(_selectedDate)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) { setState(() => _selectedDate = picked); _load(); }
  }

  Future<void> _markOne(StaffMember s) async {
    final existing = _dayRecords.where((r) => r.userId == s.id).toList();
    String status = existing.isNotEmpty ? existing.first.status : 'present';
    final go = await showDialog<bool>(context: context, builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: Text('Mark — ${s.name}', style: AppTheme.cardTitle),
        content: SizedBox(width: 300, child: LabeledDropdown<String>(
          label: 'Status', value: status, items: _statuses,
          displayBuilder: (v) => _statusLabels[v]!,
          onChanged: (v) => setDialogState(() => status = v),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Save')),
        ],
      ),
    ));
    if (go != true) return;
    try {
      await AttendanceService.instance.mark({'user_id': s.id, 'date': _fmt(_selectedDate), 'status': status});
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _bulkMark(String status) async {
    final selected = await showDialog<List<int>>(context: context, builder: (dialogCtx) => _BulkMarkDialog(staff: _staff, status: _statusLabels[status]!));
    if (selected == null || selected.isEmpty) return;
    try {
      await AttendanceService.instance.bulkMark(userIds: selected, date: _fmt(_selectedDate), status: status);
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _importFile() async {
    final result = await FilePicker.pickFiles(allowMultiple: false, withData: false);
    if (result == null || result.files.single.path == null) return;
    try {
      final res = await AttendanceService.instance.import(result.files.single.path!, result.files.single.name);
      if (mounted) {
        setState(() => _lastImport = res);
        showSuccessToast(context, '${res.matchedCount}/${res.rowCount} row(s) matched.');
      }
      _load();
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Color _statusColor(String s) => switch (s) {
    'present' => AppColors.teal, 'late' => AppColors.amber, 'absent' => AppColors.coral,
    'half_day' => AppColors.info, 'leave' => AppColors.violet, _ => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      final wide = cst.maxWidth >= 900;
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Attendance', style: AppTheme.pageTitle),
              const SizedBox(height: 4),
              Text('Mark days directly, or bulk-import a biometric terminal export', style: AppTheme.bodySub),
            ])),
            OutlinedButton.icon(onPressed: _importFile, icon: const Icon(Symbols.upload_file, size: 16), label: const Text('Import Excel')),
            const SizedBox(width: 8),
            _DatePill(date: _selectedDate, onTap: _pickDate),
          ]),
          const SizedBox(height: 16),
          if (_lastImport != null) _importSummary(_lastImport!),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : SingleChildScrollView(child: wide
                    ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 5, child: _dayCard()),
                        const SizedBox(width: 16),
                        Expanded(flex: 6, child: _monthHeatmap()),
                      ]))
                    : Column(children: [_dayCard(), const SizedBox(height: 16), _monthHeatmap()])),
          ),
        ]),
      );
    });
  }

  Widget _importSummary(AttendanceImportResult r) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.pal.border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Symbols.fact_check, size: 18, color: r.unmatchedRows.isEmpty ? AppColors.teal : AppColors.amber),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r.filename}: ${r.matchedCount}/${r.rowCount} rows matched', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
        if (r.unmatchedRows.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${r.unmatchedRows.length} row(s) need manual marking — no matching staff member or unreadable date:', style: AppTheme.bodySub.copyWith(fontSize: 11)),
          ...r.unmatchedRows.take(5).map((row) => Text('· ${row['name'] ?? row['id'] ?? '—'} (row ${row['row']}) — ${row['reason']}', style: AppTheme.monoXs)),
        ],
      ])),
      GestureDetector(onTap: () => setState(() => _lastImport = null), child: Icon(Symbols.close, size: 16, color: context.pal.textDim)),
    ]),
  );

  Widget _dayCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.pal.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Symbols.today, size: 16, color: context.pal.textDim),
        const SizedBox(width: 8),
        Expanded(child: Text('Mark ${_fmt(_selectedDate)}', style: AppTheme.cardTitle)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: _statuses.map((s) => OutlinedButton(
        onPressed: () => _bulkMark(s),
        style: OutlinedButton.styleFrom(foregroundColor: _statusColor(s), side: BorderSide(color: _statusColor(s).withValues(alpha: 0.4))),
        child: Text('Mark ${_statusLabels[s]}'),
      )).toList()),
      const SizedBox(height: 14),
      const Divider(),
      const SizedBox(height: 8),
      ..._staff.map((s) {
        final rec = _dayRecords.where((r) => r.userId == s.id).toList();
        final status = rec.isNotEmpty ? rec.first.status : null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            onTap: () => _markOne(s),
            child: Row(children: [
              Expanded(child: Text(s.name, style: AppTheme.bodySm)),
              if (status != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(_statusLabels[status]!, style: AppTheme.monoXs.copyWith(color: _statusColor(status))),
              ) else Text('Unmarked', style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
            ]),
          ),
        );
      }),
    ]),
  );

  Widget _monthHeatmap() {
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: context.pal.isDark ? const Color(0xFF15130F) : const Color(0xFF1C1712), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This Month', style: AppTheme.cardTitle.copyWith(color: Colors.white)),
        const SizedBox(height: 14),
        ..._staff.take(8).map((s) {
          final records = {for (final r in _monthByUser['${s.id}'] ?? <AttendanceRecord>[]) r.date: r};
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 90, child: Text(s.name, style: AppTheme.bodySub.copyWith(color: Colors.white70, fontSize: 10.5), overflow: TextOverflow.ellipsis)),
              Expanded(child: Row(children: List.generate(daysInMonth, (i) {
                final date = DateTime(_selectedDate.year, _selectedDate.month, i + 1);
                final rec = records[_fmt(date)];
                final color = rec != null ? _statusColor(rec.status) : Colors.white.withValues(alpha: 0.08);
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AspectRatio(aspectRatio: 1, child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))),
                ));
              }))),
            ]),
          );
        }),
      ]),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(999), border: Border.all(color: context.pal.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.calendar_month, size: 15, color: context.pal.textDim),
        const SizedBox(width: 6),
        Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}', style: AppTheme.bodySm),
      ]),
    ),
  );
}

class _BulkMarkDialog extends StatefulWidget {
  const _BulkMarkDialog({required this.staff, required this.status});
  final List<StaffMember> staff;
  final String status;

  @override
  State<_BulkMarkDialog> createState() => _BulkMarkDialogState();
}

class _BulkMarkDialogState extends State<_BulkMarkDialog> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    title: Text('Mark ${widget.status} — select staff', style: AppTheme.cardTitle),
    content: SizedBox(width: 340, height: 360, child: ListView(children: widget.staff.map((s) => CheckboxListTile(
      value: _selected.contains(s.id),
      onChanged: (v) => setState(() { if (v == true) _selected.add(s.id); else _selected.remove(s.id); }),
      title: Text(s.name, style: AppTheme.bodySm),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    )).toList())),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.of(context).pop(_selected.toList()), child: const Text('Mark Selected')),
    ],
  );
}
