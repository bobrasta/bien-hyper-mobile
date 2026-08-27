import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/leave_request.dart';
import '../../services/hr_setting_service.dart';
import '../../services/leave_service.dart';
import '../../services/position_service.dart';
import '../../services/public_holiday_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';

class HrSettingsScreen extends StatefulWidget {
  const HrSettingsScreen({super.key});

  @override
  State<HrSettingsScreen> createState() => _HrSettingsScreenState();
}

class _HrSettingsScreenState extends State<HrSettingsScreen> {
  List<LeaveTypeCatalogEntry> _leaveTypes = [];
  List<PublicHoliday> _holidays = [];
  List<Position> _positions = [];
  bool _loading = true;
  String? _error;

  final Map<String, TextEditingController> _settingCtrls = {};
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _settingCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        LeaveService.instance.types(),
        PublicHolidayService.instance.list(),
        HrSettingService.instance.get(),
        PositionService.instance.list(force: true),
      ]);
      if (!mounted) return;
      final settings = results[2] as Map<String, String>;
      for (final entry in settings.entries) {
        _settingCtrls.putIfAbsent(entry.key, () => TextEditingController()).text = entry.value;
      }
      setState(() {
        _leaveTypes = results[0] as List<LeaveTypeCatalogEntry>;
        _holidays   = results[1] as List<PublicHoliday>;
        _positions  = results[3] as List<Position>;
        _loading    = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _saveLeaveTypeDays(LeaveTypeCatalogEntry type, int days) async {
    try {
      await LeaveService.instance.updateType(type.id, {'default_days_per_year': days});
      if (mounted) { showSuccessToast(context, '${type.label} updated.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      final payload = { for (final e in _settingCtrls.entries) e.key: e.value.text.trim() };
      await HrSettingService.instance.update(payload);
      if (mounted) { showSuccessToast(context, 'Settings saved.'); setState(() => _savingSettings = false); }
    } catch (e) {
      if (mounted) { setState(() => _savingSettings = false); showErrorToast(context, e); }
    }
  }

  Future<void> _addHoliday() async {
    final nameCtrl = TextEditingController();
    DateTime? date;
    bool recurring = false;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(builder: (dialogCtx, setDialogState) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: Text('New Public Holiday', style: AppTheme.cardTitle),
        content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          LabeledTextField(label: 'Name', controller: nameCtrl),
          const SizedBox(height: 12),
          LabeledDateField(
            label: 'Date',
            date: date,
            onTap: () async {
              final picked = await showDatePicker(context: dialogCtx, initialDate: date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setDialogState(() => date = picked);
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Checkbox(value: recurring, onChanged: (v) => setDialogState(() => recurring = v ?? false)),
            const Text('Recurs every year'),
          ]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || date == null) return;
              try {
                await PublicHolidayService.instance.create({
                  'name': nameCtrl.text.trim(),
                  'date': date!.toIso8601String().split('T').first,
                  'recurring': recurring,
                });
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
              } catch (e) {
                if (dialogCtx.mounted) showErrorToast(dialogCtx, e);
              }
            },
            child: const Text('Add'),
          ),
        ],
      )),
    );
    if (created == true) _load();
  }

  Future<void> _deleteHoliday(PublicHoliday h) async {
    try {
      await PublicHolidayService.instance.delete(h.id);
      _load();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  // Positions feed the picker on the Staff/Recruitment "New Vacancy"
  // forms — HR owns this catalog since HR runs recruiting, same authority
  // tier (hasStaffManageAuthority) as everything else on this screen.
  Future<void> _addOrEditPosition({Position? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final deptCtrl = TextEditingController(text: existing?.department ?? '');
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: Text(existing == null ? 'New Position' : 'Edit Position', style: AppTheme.cardTitle),
        content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          LabeledTextField(label: 'Title', controller: titleCtrl),
          const SizedBox(height: 12),
          LabeledTextField(label: 'Department (optional)', controller: deptCtrl),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              try {
                final data = {
                  'title': titleCtrl.text.trim(),
                  'department': deptCtrl.text.trim().isNotEmpty ? deptCtrl.text.trim() : null,
                };
                if (existing == null) {
                  await PositionService.instance.create(data);
                } else {
                  await PositionService.instance.update(existing.id, data);
                }
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
              } catch (e) {
                if (dialogCtx.mounted) showErrorToast(dialogCtx, e);
              }
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
    if (go == true) _load();
  }

  Future<void> _deletePosition(Position p) async {
    try {
      await PositionService.instance.delete(p.id);
      _load();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HR Settings', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Leave allocations, holiday calendar, and general HR defaults', style: AppTheme.bodySub),
            const SizedBox(height: 24),
            _SectionCard(
              title: 'Leave Day Allocations',
              icon: Symbols.event,
              child: Column(children: _leaveTypes.map((t) => _LeaveTypeRow(
                type: t,
                onSave: (days) => _saveLeaveTypeDays(t, days),
              )).toList()),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Public Holiday Calendar',
              icon: Symbols.calendar_month,
              trailing: TextButton.icon(
                onPressed: _addHoliday,
                icon: const Icon(Symbols.add, size: 16),
                label: const Text('Add'),
              ),
              child: _holidays.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No holidays added yet.', style: AppTheme.bodySub))
                  : Column(children: _holidays.map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Icon(Symbols.event_available, size: 15, color: context.pal.textDim),
                        const SizedBox(width: 8),
                        Expanded(child: Text(h.name, style: AppTheme.bodySm)),
                        Text(h.date, style: AppTheme.bodySub.copyWith(fontSize: 12)),
                        if (h.recurring) Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(4)),
                            child: Text('Yearly', style: AppTheme.monoXs.copyWith(color: AppColors.teal, fontSize: 9.5)),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteHoliday(h),
                          icon: Icon(Symbols.delete_outline, size: 16, color: context.pal.textDim),
                          tooltip: 'Remove',
                        ),
                      ]),
                    )).toList()),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Positions',
              icon: Symbols.badge,
              trailing: TextButton.icon(
                onPressed: () => _addOrEditPosition(),
                icon: const Icon(Symbols.add, size: 16),
                label: const Text('Add'),
              ),
              child: _positions.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No positions yet — add one so Staff and Recruitment can assign it.', style: AppTheme.bodySub))
                  : Column(children: _positions.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Icon(Symbols.badge, size: 15, color: context.pal.textDim),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p.title, style: AppTheme.bodySm)),
                        if (p.department != null) Text(p.department!, style: AppTheme.bodySub.copyWith(fontSize: 12)),
                        IconButton(
                          onPressed: () => _addOrEditPosition(existing: p),
                          icon: Icon(Symbols.edit, size: 16, color: context.pal.textDim),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _deletePosition(p),
                          icon: Icon(Symbols.delete_outline, size: 16, color: context.pal.textDim),
                          tooltip: 'Remove',
                        ),
                      ]),
                    )).toList()),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'General',
              icon: Symbols.tune,
              trailing: FilledButton(
                onPressed: _savingSettings ? null : _saveSettings,
                child: _savingSettings
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
              child: Column(children: [
                _SettingField(label: 'Default probation period (days)', ctrl: _settingCtrls['default_probation_days']),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _SettingField(label: 'Expected start time', ctrl: _settingCtrls['expected_start_time'])),
                  const SizedBox(width: 12),
                  Expanded(child: _SettingField(label: 'Expected end time', ctrl: _settingCtrls['expected_end_time'])),
                ]),
                const SizedBox(height: 12),
                _SettingField(label: 'Alert lead time (days before expiry)', ctrl: _settingCtrls['reminder_lead_days']),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child, this.trailing});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 17, color: AppColors.teal),
        const SizedBox(width: 8),
        Text(title, style: AppTheme.bodyStrong.copyWith(fontSize: 14)),
        const Spacer(),
        ?trailing,
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _LeaveTypeRow extends StatefulWidget {
  const _LeaveTypeRow({required this.type, required this.onSave});
  final LeaveTypeCatalogEntry type;
  final ValueChanged<int> onSave;

  @override
  State<_LeaveTypeRow> createState() => _LeaveTypeRowState();
}

class _LeaveTypeRowState extends State<_LeaveTypeRow> {
  late final _ctrl = TextEditingController(text: widget.type.defaultDaysPerYear.toString());

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(flex: 2, child: Text(widget.type.label, style: AppTheme.bodySm)),
      if (widget.type.autoFromCalendar)
        Expanded(flex: 1, child: Text('From calendar', style: AppTheme.bodySub.copyWith(fontSize: 11.5)))
      else if (widget.type.requiresManualDays)
        Expanded(flex: 1, child: Text('Set at approval', style: AppTheme.bodySub.copyWith(fontSize: 11.5)))
      else ...[
        SizedBox(
          width: 70,
          child: TextField(
            controller: _ctrl, keyboardType: TextInputType.number, style: AppTheme.bodySm,
            decoration: const InputDecoration(isDense: true, suffixText: 'days'),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () {
            final v = int.tryParse(_ctrl.text.trim());
            if (v != null) widget.onSave(v);
          },
          icon: Icon(Symbols.check, size: 16, color: AppColors.teal),
          tooltip: 'Save',
        ),
      ],
    ]),
  );
}

class _SettingField extends StatelessWidget {
  const _SettingField({required this.label, required this.ctrl});
  final String label;
  final TextEditingController? ctrl;

  @override
  Widget build(BuildContext context) => LabeledTextField(label: label, controller: ctrl!);
}
