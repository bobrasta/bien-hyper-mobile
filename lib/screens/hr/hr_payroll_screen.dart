import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/payroll_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../theme/hr_category_colors.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/hr_empty_state.dart';
import '../../widgets/common/labeled_field.dart';

/// Payroll — ported from HR Redesign spec 1g: run list, a status stepper,
/// and the full item table instead of a summary list. Manual entry (see
/// PayrollController on the backend) — no PAYE/NSSF/HESLB auto-calculation
/// engine yet, that needs real current TRA/NSSF/HESLB rate tables.
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
  static const _stages = ['draft', 'reviewed', 'approved', 'paid'];
  static const _stageLabels = {'draft': 'Draft', 'reviewed': 'Reviewed', 'approved': 'Approved', 'paid': 'Paid'};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({int? selectId}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final runs = await PayrollService.instance.runs();
      PayrollRun? sel;
      final targetId = selectId ?? _selected?.id ?? (runs.isNotEmpty ? runs.first.id : null);
      if (targetId != null) sel = await PayrollService.instance.show(targetId);
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
  static String _thousands(int v) => _money((v / 1000).round());

  Color _statusColor(String s) => switch (s) {
    'draft' => AppColors.textMute, 'reviewed' => AppColors.amber,
    'approved' => AppColors.info, 'paid' => AppColors.green, _ => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading && _runs.isEmpty) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 26.0;
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(),
          const SizedBox(height: 4),
          Container(height: 1, color: context.pal.divider),
          const SizedBox(height: 16),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 250, child: _runsList()),
            const SizedBox(width: 16),
            Expanded(child: _selected == null
                ? Center(child: Text('Select a run to view its lines.', style: AppTheme.bodySub))
                : SingleChildScrollView(child: _runDetail(_selected!))),
          ])),
        ]),
      );
    });
  }

  Widget _header() {
    final now = DateTime.now();
    final draftedThisMonth = _runs.any((r) => r.periodMonth == now.month && r.periodYear == now.year);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 2, height: 32, decoration: BoxDecoration(color: HrCategory.payroll.color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Payroll', style: AppTheme.pageTitle.copyWith(fontSize: 21)),
        const SizedBox(height: 3),
        Text('Manual pay runs · ${draftedThisMonth ? "${_months[now.month]} drafted" : "${_months[now.month]} not yet drafted"}', style: AppTheme.bodySub.copyWith(fontSize: 12)),
      ])),
      FilledButton.icon(onPressed: _newRun, icon: const Icon(Symbols.add, size: 16), label: const Text('New run')),
    ]);
  }

  Widget _runsList() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('RUNS', style: AppTheme.labelCaps.copyWith(fontSize: 10.5)),
    const SizedBox(height: 9),
    Expanded(child: _runs.isEmpty
        ? HrEmptyState(icon: HrCategory.payroll.icon, title: 'No payroll runs yet', message: 'Create a run for a period to start entering pay lines.', actionLabel: 'New run', onAction: _newRun)
        : ListView.separated(
            itemCount: _runs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = _runs[i];
              final active = _selected?.id == r.id;
              final color = _statusColor(r.status);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectRun(r),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: active ? context.pal.surface2 : context.pal.surface1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? AppColors.green.withValues(alpha: 0.4) : context.pal.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${_months[r.periodMonth]} ${r.periodYear}', style: AppTheme.bodySm.copyWith(fontSize: 13, color: active ? context.pal.text : context.pal.textMute))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
                        child: Text(r.status, style: AppTheme.monoXs.copyWith(color: color, fontSize: 9.5)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      Text(_money(r.netTotal), style: AppTheme.monoXs.copyWith(fontSize: 13.5, color: context.pal.text)),
                      const SizedBox(width: 6),
                      Text('net · ${r.itemsCount ?? r.items.length} staff', style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
                    ]),
                  ]),
                ),
              );
            },
          )),
  ]);

  Widget _runDetail(PayrollRun run) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_months[run.periodMonth]} ${run.periodYear}', style: AppTheme.cardTitle.copyWith(fontSize: 18)),
          const SizedBox(height: 3),
          Text(
            [
              run.createdByName != null ? 'Created by ${run.createdByName}' : null,
              run.approvedAt != null ? 'approved ${run.approvedAt!.split('T').first}' : null,
              run.paidAt != null ? 'paid ${run.paidAt!.split('T').first}' : null,
              run.status == 'paid' ? 'posted to expenses' : null,
            ].where((s) => s != null).join(' · '),
            style: AppTheme.bodySub.copyWith(fontSize: 11.5),
          ),
        ])),
        _stepper(run.status),
      ]),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 4, shrinkWrap: true, mainAxisSpacing: 10, crossAxisSpacing: 10,
        childAspectRatio: 2.3, physics: const NeverScrollableScrollPhysics(),
        children: [
          _totalTile('Gross total', run.grossTotal, AppColors.green),
          _totalTile('Deductions', run.deductionsTotal, AppColors.coral),
          _totalTile('Net total', run.netTotal, AppColors.green),
          _totalTile('Statutory due', run.items.fold(0, (a, i) => a + i.payeAmount + i.nssfAmount + i.heslbAmount), AppColors.amber),
        ],
      ),
      const SizedBox(height: 18),
      Row(children: [
        Icon(Symbols.payments, size: 13, color: AppColors.green),
        const SizedBox(width: 8),
        Text('RUN ITEMS', style: AppTheme.labelCaps.copyWith(fontSize: 10.5)),
        const SizedBox(width: 6),
        Text('${run.items.length}', style: AppTheme.monoXs.copyWith(fontSize: 11)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: context.pal.divider)),
        Text('Figures in thousands TZS', style: AppTheme.monoXs.copyWith(fontSize: 10.5)),
        if (run.status == 'draft') ...[
          const SizedBox(width: 10),
          TextButton.icon(onPressed: _addStaffLine, icon: const Icon(Symbols.person_add, size: 14), label: const Text('Add staff')),
        ],
      ]),
      const SizedBox(height: 9),
      run.items.isEmpty
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
              child: HrEmptyState(
                icon: HrCategory.payroll.icon, title: 'No staff lines yet',
                message: run.status == 'draft' ? 'Add staff to start entering their pay for this run.' : 'This run has no staff lines.',
                actionLabel: run.status == 'draft' ? 'Add staff' : null, onAction: run.status == 'draft' ? _addStaffLine : null,
              ),
            )
          : _itemsTable(run),
      const SizedBox(height: 16),
      _remittanceRow(run),
    ]);
  }

  Widget _stepper(String status) {
    final idx = _stages.indexOf(status);
    return Row(children: [
      for (var i = 0; i < _stages.length; i++) ...[
        Container(
          height: 28, padding: const EdgeInsets.symmetric(horizontal: 11), alignment: Alignment.center,
          decoration: BoxDecoration(
            color: i == 3 && idx == 3 ? AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: i <= idx ? AppColors.green.withValues(alpha: i == idx ? 1 : 0.4) : context.pal.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i <= idx ? Symbols.check : Symbols.circle, size: 12, color: i == 3 && idx == 3 ? const Color(0xFF08090B) : (i <= idx ? AppColors.green : context.pal.textDim)),
            const SizedBox(width: 6),
            Text(_stageLabels[_stages[i]]!, style: AppTheme.monoXs.copyWith(fontSize: 11, color: i == 3 && idx == 3 ? const Color(0xFF08090B) : (i <= idx ? context.pal.text : context.pal.textDim))),
          ]),
        ),
        if (i < _stages.length - 1) Container(width: 14, height: 1, color: context.pal.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
      ],
      if (status == 'draft') ...[const SizedBox(width: 12), FilledButton(onPressed: () => _advance(() => PayrollService.instance.review(_selected!.id)), child: const Text('Mark Reviewed'))]
      else if (status == 'reviewed') ...[const SizedBox(width: 12), FilledButton(onPressed: () => _advance(() => PayrollService.instance.approve(_selected!.id)), child: const Text('Approve'))]
      else if (status == 'approved') ...[const SizedBox(width: 12), FilledButton(onPressed: () => _advance(() => PayrollService.instance.markPaid(_selected!.id)), child: const Text('Mark Paid'))],
    ]);
  }

  Widget _totalTile(String label, int amount, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
    clipBehavior: Clip.antiAlias,
    child: Stack(children: [
      Positioned(left: -14, top: -12, bottom: -12, width: 2, child: Container(color: color)),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(_money(amount), style: AppTheme.kpiValue.copyWith(fontSize: 18)),
          const SizedBox(width: 5),
          Text('TZS', style: AppTheme.monoXs.copyWith(fontSize: 10)),
        ]),
      ]),
    ]),
  );

  static const _colLabels = ['Base', 'Allow.', 'OT', 'PAYE', 'NSSF', 'HESLB', 'Gross', 'Net'];

  Widget _itemsTable(PayrollRun run) {
    final canEdit = run.status == 'draft';
    return Container(
      decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          height: 34, padding: const EdgeInsets.symmetric(horizontal: 14),
          color: context.pal.surface2,
          child: Row(children: [
            Expanded(flex: 15, child: Text('STAFF', style: AppTheme.labelCaps.copyWith(fontSize: 10))),
            for (final c in _colLabels) Expanded(flex: 10, child: Text(c.toUpperCase(), textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 10))),
            if (canEdit) const SizedBox(width: 60),
          ]),
        ),
        ...run.items.map((item) {
          final cells = [item.baseSalary, item.allowancesTotal, item.overtimeAmount, item.payeAmount, item.nssfAmount, item.heslbAmount, item.grossPay, item.netPay];
          return Container(
            height: 42, padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider))),
            child: Row(children: [
              Expanded(flex: 15, child: Row(children: [
                _avatar(item.userName ?? '?', item.id),
                const SizedBox(width: 9),
                Expanded(child: Text(item.userName ?? '—', style: AppTheme.bodySm.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ])),
              for (var i = 0; i < cells.length; i++) Expanded(flex: 10, child: Text(
                cells[i] == 0 ? '—' : _thousands(cells[i]),
                textAlign: TextAlign.right,
                style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: cells[i] == 0 ? context.pal.textDim
                    : (i >= 3 && i <= 5) ? AppColors.coral : i == 7 ? AppColors.green : context.pal.text),
              )),
              if (canEdit) SizedBox(width: 60, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(onPressed: () => _editItem(userId: item.userId, userName: item.userName ?? '—', existing: item), icon: Icon(Symbols.edit, size: 14, color: context.pal.textDim), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26, minHeight: 26)),
                IconButton(onPressed: () => _removeItem(item), icon: Icon(Symbols.delete, size: 14, color: AppColors.coral), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26, minHeight: 26)),
              ])),
            ]),
          );
        }),
        Container(
          height: 40, padding: const EdgeInsets.symmetric(horizontal: 14),
          color: context.pal.surface2,
          child: Row(children: [
            Expanded(flex: 15, child: Text('Total', style: AppTheme.bodySub.copyWith(fontSize: 11.5))),
            for (final v in [
              run.items.fold(0, (a, i) => a + i.baseSalary), run.items.fold(0, (a, i) => a + i.allowancesTotal),
              run.items.fold(0, (a, i) => a + i.overtimeAmount), run.items.fold(0, (a, i) => a + i.payeAmount),
              run.items.fold(0, (a, i) => a + i.nssfAmount), run.items.fold(0, (a, i) => a + i.heslbAmount),
              run.items.fold(0, (a, i) => a + i.grossPay), run.items.fold(0, (a, i) => a + i.netPay),
            ].asMap().entries) Expanded(flex: 10, child: Text(_thousands(v.value), textAlign: TextAlign.right,
                style: AppTheme.monoXs.copyWith(fontSize: 12, color: v.key == 7 ? AppColors.green : context.pal.text, fontWeight: FontWeight.w600))),
            if (canEdit) const SizedBox(width: 60),
          ]),
        ),
      ]),
    );
  }

  Widget _avatar(String name, int seed) {
    final palette = [AppColors.cyan, AppColors.amber, AppColors.violet, AppColors.coral, AppColors.info, AppColors.green];
    final initials = name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
    return Container(
      width: 22, height: 22, alignment: Alignment.center,
      decoration: BoxDecoration(color: palette[seed % palette.length], shape: BoxShape.circle),
      child: Text(initials, style: AppTheme.monoXs.copyWith(fontSize: 8.5, fontWeight: FontWeight.w700, color: const Color(0xFF08090B))),
    );
  }

  Widget _remittanceRow(PayrollRun run) {
    final paye = run.items.fold(0, (a, i) => a + i.payeAmount);
    final nssf = run.items.fold(0, (a, i) => a + i.nssfAmount);
    final heslb = run.items.fold(0, (a, i) => a + i.heslbAmount);
    final maxV = [paye, nssf, heslb].fold(0, (a, b) => a > b ? a : b);
    final rows = [('PAYE', paye, AppColors.coral), ('NSSF', nssf, AppColors.amber), ('HESLB', heslb, AppColors.violet)];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Symbols.account_balance, size: 13, color: AppColors.coral),
        const SizedBox(width: 8),
        Text('STATUTORY REMITTANCE', style: AppTheme.labelCaps.copyWith(fontSize: 10.5)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: context.pal.divider)),
      ]),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        child: Column(children: rows.map((r) {
          final pct = maxV > 0 ? (r.$2 / maxV).clamp(0.03, 1.0) : 0.03;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              SizedBox(width: 52, child: Text(r.$1, style: AppTheme.monoXs.copyWith(fontSize: 11.5))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: FractionallySizedBox(
                widthFactor: pct, alignment: Alignment.centerLeft, child: Container(height: 7, color: r.$3),
              ))),
              const SizedBox(width: 10),
              SizedBox(width: 60, child: Text('${_thousands(r.$2)}k', textAlign: TextAlign.right, style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: context.pal.text))),
            ]),
          );
        }).toList()),
      ),
    ]);
  }
}
