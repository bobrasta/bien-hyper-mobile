import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/payroll_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';

/// Payroll — data model + manual entry (see PayrollController on the
/// backend): the accountant enters gross/allowances/overtime/deductions
/// per staff line by hand each run. No PAYE/NSSF/HESLB auto-calculation
/// engine yet — that needs real current TRA/NSSF/HESLB rate tables, a
/// separate future task.
class HrPayrollScreen extends StatefulWidget {
  const HrPayrollScreen({super.key});

  @override
  State<HrPayrollScreen> createState() => _HrPayrollScreenState();
}

class _HrPayrollScreenState extends State<HrPayrollScreen> {
  List<PayrollRun> _runs = [];
  PayrollRun? _selected;
  bool _loading = true;
  String? _error;

  static const _months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({int? selectId}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final runs = await PayrollService.instance.runs();
      PayrollRun? sel;
      if (selectId != null) {
        sel = await PayrollService.instance.show(selectId);
      } else if (_selected != null) {
        sel = await PayrollService.instance.show(_selected!.id);
      }
      if (mounted) setState(() { _runs = runs; _selected = sel; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _selectRun(PayrollRun r) async {
    try {
      final full = await PayrollService.instance.show(r.id);
      if (mounted) setState(() => _selected = full);
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _newRun() async {
    final now = DateTime.now();
    int month = now.month;
    int year = now.year;
    final go = await showDialog<bool>(context: context, builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        backgroundColor: context.pal.surface1,
        title: Text('New Payroll Run', style: AppTheme.cardTitle),
        content: SizedBox(width: 320, child: Row(children: [
          Expanded(child: LabeledDropdown<int>(
            label: 'Month', value: month,
            items: List.generate(12, (i) => i + 1),
            displayBuilder: (m) => _months[m],
            onChanged: (v) => setDialogState(() => month = v),
          )),
          const SizedBox(width: 10),
          Expanded(child: LabeledDropdown<int>(
            label: 'Year', value: year,
            items: [now.year - 1, now.year, now.year + 1],
            displayBuilder: (y) => '$y',
            onChanged: (v) => setDialogState(() => year = v),
          )),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Create')),
        ],
      ),
    ));
    if (go != true) return;
    try {
      final run = await PayrollService.instance.createRun(month: month, year: year);
      _load(selectId: run.id);
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _addStaffLine() async {
    if (_selected == null) return;
    List<EligibleStaffOption> options = [];
    try { options = await PayrollService.instance.eligibleStaff(_selected!.id); } catch (_) {}
    if (!mounted) return;
    if (options.isEmpty) { showErrorToast(context, 'Every active staff member is already on this run.'); return; }
    final picked = await showDialog<EligibleStaffOption>(context: context, builder: (dialogCtx) => SimpleDialog(
      backgroundColor: context.pal.surface1,
      title: const Text('Add Staff to Run'),
      children: options.map((o) => SimpleDialogOption(onPressed: () => Navigator.of(dialogCtx).pop(o), child: Text(o.name))).toList(),
    ));
    if (picked == null) return;
    if (!mounted) return;
    await _editItem(userId: picked.id, userName: picked.name);
  }

  Future<void> _editItem({required int userId, required String userName, PayrollItem? existing}) async {
    final baseCtrl = TextEditingController(text: existing?.baseSalary.toString() ?? '0');
    final allowCtrl = TextEditingController(text: existing?.allowancesTotal.toString() ?? '0');
    final otCtrl = TextEditingController(text: existing?.overtimeAmount.toString() ?? '0');
    final payeCtrl = TextEditingController(text: existing?.payeAmount.toString() ?? '0');
    final nssfCtrl = TextEditingController(text: existing?.nssfAmount.toString() ?? '0');
    final heslbCtrl = TextEditingController(text: existing?.heslbAmount.toString() ?? '0');
    final otherCtrl = TextEditingController(text: existing?.otherDeductions.toString() ?? '0');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    final go = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      backgroundColor: context.pal.surface1,
      title: Text('Payroll — $userName', style: AppTheme.cardTitle),
      content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: LabeledTextField(label: 'Base Salary', controller: baseCtrl, keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: LabeledTextField(label: 'Allowances', controller: allowCtrl, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: LabeledTextField(label: 'Overtime', controller: otCtrl, keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: LabeledTextField(label: 'PAYE', controller: payeCtrl, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: LabeledTextField(label: 'NSSF', controller: nssfCtrl, keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: LabeledTextField(label: 'HESLB', controller: heslbCtrl, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 12),
        LabeledTextField(label: 'Other Deductions', controller: otherCtrl, keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        LabeledTextField(label: 'Notes (optional)', controller: notesCtrl, maxLines: 2),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Save')),
      ],
    ));
    if (go != true || _selected == null) return;
    try {
      await PayrollService.instance.upsertItem(_selected!.id, {
        'user_id': userId,
        'base_salary': int.tryParse(baseCtrl.text.trim()) ?? 0,
        'allowances_total': int.tryParse(allowCtrl.text.trim()) ?? 0,
        'overtime_amount': int.tryParse(otCtrl.text.trim()) ?? 0,
        'paye_amount': int.tryParse(payeCtrl.text.trim()) ?? 0,
        'nssf_amount': int.tryParse(nssfCtrl.text.trim()) ?? 0,
        'heslb_amount': int.tryParse(heslbCtrl.text.trim()) ?? 0,
        'other_deductions': int.tryParse(otherCtrl.text.trim()) ?? 0,
        'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      });
      _load(selectId: _selected!.id);
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _removeItem(PayrollItem item) async {
    if (_selected == null) return;
    try {
      await PayrollService.instance.deleteItem(_selected!.id, item.id);
      _load(selectId: _selected!.id);
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  Future<void> _advance(Future<PayrollRun> Function() action) async {
    try {
      await action();
      _load(selectId: _selected!.id);
    } catch (e) { if (mounted) showErrorToast(context, e); }
  }

  static String _money(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  Color _statusColor(String s) => switch (s) {
    'draft' => AppColors.textMute, 'reviewed' => AppColors.amber,
    'approved' => AppColors.info, 'paid' => AppColors.teal, _ => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading && _runs.isEmpty) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payroll', style: AppTheme.pageTitle),
              const SizedBox(height: 4),
              Text('Manual pay runs — no auto tax calculation yet', style: AppTheme.bodySub),
            ])),
            FilledButton.icon(onPressed: _newRun, icon: const Icon(Symbols.add, size: 16), label: const Text('New Run')),
          ]),
          const SizedBox(height: 16),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 260, child: _runsList()),
            const SizedBox(width: 16),
            Expanded(child: _selected == null
                ? Center(child: Text('Select a run to view its lines.', style: AppTheme.bodySub))
                : _runDetail(_selected!)),
          ])),
        ]),
      );
    });
  }

  Widget _runsList() => Container(
    decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.pal.border)),
    child: _runs.isEmpty
        ? Padding(padding: const EdgeInsets.all(20), child: Text('No payroll runs yet.', style: AppTheme.bodySub))
        : ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _runs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final r = _runs[i];
              final active = _selected?.id == r.id;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _selectRun(r),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: active ? AppColors.tealSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_months[r.periodMonth]} ${r.periodYear}', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _statusColor(r.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(r.status, style: AppTheme.monoXs.copyWith(color: _statusColor(r.status), fontSize: 9.5)),
                    ),
                  ]),
                ),
              );
            },
          ),
  );

  Widget _runDetail(PayrollRun run) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.pal.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${_months[run.periodMonth]} ${run.periodYear}', style: AppTheme.cardTitle)),
          if (run.status == 'draft') ...[
            TextButton.icon(onPressed: _addStaffLine, icon: const Icon(Symbols.person_add, size: 15), label: const Text('Add Staff')),
            const SizedBox(width: 6),
            FilledButton(onPressed: () => _advance(() => PayrollService.instance.review(run.id)), child: const Text('Mark Reviewed')),
          ] else if (run.status == 'reviewed')
            FilledButton(onPressed: () => _advance(() => PayrollService.instance.approve(run.id)), child: const Text('Approve'))
          else if (run.status == 'approved')
            FilledButton(onPressed: () => _advance(() => PayrollService.instance.markPaid(run.id)), child: const Text('Mark Paid')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _totalChip('Gross', run.grossTotal, AppColors.info),
          const SizedBox(width: 10),
          _totalChip('Deductions', run.deductionsTotal, AppColors.coral),
          const SizedBox(width: 10),
          _totalChip('Net', run.netTotal, AppColors.teal),
        ]),
        const SizedBox(height: 16),
        Expanded(child: run.items.isEmpty
            ? Center(child: Text('No staff lines yet.', style: AppTheme.bodySub))
            : ListView.separated(
                itemCount: run.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = run.items[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.pal.border)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.userName ?? '—', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                        Text('Gross ${_money(item.grossPay)} · Net ${_money(item.netPay)}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
                      ])),
                      if (run.status == 'draft') ...[
                        TextButton(onPressed: () => _editItem(userId: item.userId, userName: item.userName ?? '—', existing: item), child: const Text('Edit')),
                        IconButton(onPressed: () => _removeItem(item), icon: Icon(Symbols.delete, size: 16, color: AppColors.coral)),
                      ],
                    ]),
                  );
                },
              )),
      ]),
    );
  }

  Widget _totalChip(String label, int amount, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.monoXs.copyWith(color: color)),
      Text(_money(amount), style: AppTheme.bodyStrong.copyWith(fontSize: 13, color: color)),
    ]),
  );
}
