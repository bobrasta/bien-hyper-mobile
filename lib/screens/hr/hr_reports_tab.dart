import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/hr_report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';

class HrReportsTab extends StatefulWidget {
  const HrReportsTab({super.key});

  @override
  State<HrReportsTab> createState() => _HrReportsTabState();
}

class _HrReportsTabState extends State<HrReportsTab> {
  bool _loading = true;
  String? _error;

  HeadcountBreakdown? _headcount;
  HrTurnoverReport? _turnover;
  List<OrgChartEntry> _orgChart = [];
  List<HrLeaveBalanceRow> _leaveBalances = [];
  List<LeaveCalendarEntry> _leaveCalendar = [];
  RecruitmentSummary? _recruitment;
  List<ContractExpiringEntry> _contractsExpiring = [];
  DisciplinarySummary? _discipline;
  List<CareerProgressionEntry> _careerLog = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        HrReportService.instance.headcount(),
        HrReportService.instance.turnover(),
        HrReportService.instance.orgChart(),
        HrReportService.instance.leaveBalances(),
        HrReportService.instance.leaveCalendar(),
        HrReportService.instance.recruitmentSummary(),
        HrReportService.instance.contractsExpiring(),
        HrReportService.instance.disciplinarySummary(),
        HrReportService.instance.careerProgressions(),
      ]);
      if (!mounted) return;
      setState(() {
        _headcount = results[0] as HeadcountBreakdown;
        _turnover = results[1] as HrTurnoverReport;
        _orgChart = results[2] as List<OrgChartEntry>;
        _leaveBalances = results[3] as List<HrLeaveBalanceRow>;
        _leaveCalendar = results[4] as List<LeaveCalendarEntry>;
        _recruitment = results[5] as RecruitmentSummary;
        _contractsExpiring = results[6] as List<ContractExpiringEntry>;
        _discipline = results[7] as DisciplinarySummary;
        _careerLog = results[8] as List<CareerProgressionEntry>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: AppTheme.bodySub),
        const SizedBox(height: 10),
        FilledButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ReportSection(title: 'Staff / Headcount', icon: Symbols.groups, children: [
            _KpiRow(items: [
              ('Total Staff', '${_headcount?.total ?? 0}'),
              ('Turnover Rate (${_turnover?.year})', '${_turnover?.turnoverRate.toStringAsFixed(1) ?? '0.0'}%'),
            ]),
            const SizedBox(height: 10),
            _BreakdownGrid(breakdown: _headcount),
          ]),
          _ReportSection(title: 'Leave', icon: Symbols.event, children: [
            Text('Balance & Utilization', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            _LeaveBalanceTable(rows: _leaveBalances),
            const SizedBox(height: 14),
            Text('Out This Month', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            _leaveCalendar.isEmpty
                ? Text('No one is on approved leave this period.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                : Column(children: _leaveCalendar.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${e.userName} — ${e.leaveTypeLabel} (${e.startDate} to ${e.endDate})', style: AppTheme.bodySm.copyWith(fontSize: 12)),
                  )).toList()),
          ]),
          _ReportSection(title: 'Recruitment', icon: Symbols.person_search, children: [
            _KpiRow(items: [
              ('Open Vacancies', '${_recruitment?.openVacancies ?? 0}'),
              ('Talent Pool', '${_recruitment?.talentPoolCount ?? 0}'),
            ]),
            const SizedBox(height: 10),
            Text('Vacancy Pipeline', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            (_recruitment?.pipeline.isEmpty ?? true)
                ? Text('No open vacancies.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                : Column(children: _recruitment!.pipeline.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${p.positionTitle ?? '—'} — ${p.totalApplications} applicant(s), ${p.daysOpen}d open, stages: ${p.byStage.entries.map((e) => '${e.key}:${e.value}').join(', ')}',
                        style: AppTheme.bodySm.copyWith(fontSize: 12)),
                  )).toList()),
            const SizedBox(height: 10),
            Text('Hires by Source', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            (_recruitment?.hiresBySource.isEmpty ?? true)
                ? Text('No hires recorded yet.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                : Wrap(spacing: 8, runSpacing: 6, children: _recruitment!.hiresBySource.entries
                    .map((e) => _Chip('${e.key}: ${e.value}')).toList()),
          ]),
          _ReportSection(title: 'Contracts & Attendance', icon: Symbols.description, children: [
            Text('Contracts Expiring (next 90 days)', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            _contractsExpiring.isEmpty
                ? Text('No contracts expiring soon.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                : Column(children: _contractsExpiring.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(child: Text('${c.userName} — ${c.contractType}', style: AppTheme.bodySm.copyWith(fontSize: 12))),
                      Text('${c.endDate} (${c.daysRemaining}d)', style: AppTheme.bodySub.copyWith(
                          fontSize: 11.5, color: c.daysRemaining <= 30 ? AppColors.coral : context.pal.textMute)),
                    ]),
                  )).toList()),
            const SizedBox(height: 14),
            const _NotAvailableNote(label: 'Attendance summary (lateness/absenteeism)', reason: 'Attendance module not built yet — pending a sample HIK biometric export.'),
            const SizedBox(height: 8),
            const _NotAvailableNote(label: 'Overtime hours report', reason: 'Feeds from Attendance, not built yet.'),
          ]),
          _ReportSection(title: 'Discipline', icon: Symbols.gavel, children: [
            _KpiRow(items: [('Active Cases', '${_discipline?.activeCount ?? 0}')]),
            const SizedBox(height: 10),
            Text('By Stage', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            (_discipline?.byStage.isEmpty ?? true)
                ? Text('No active cases.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                : Wrap(spacing: 8, runSpacing: 6, children: _discipline!.byStage.entries.map((e) => _Chip('${e.key}: ${e.value}')).toList()),
            const SizedBox(height: 10),
            Text('Repeat Offenders', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            (_discipline?.repeatOffenders.isEmpty ?? true)
                ? Text('None.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                : Column(children: _discipline!.repeatOffenders.map((r) => Text('${r.userName} — ${r.caseCount} cases', style: AppTheme.bodySm.copyWith(fontSize: 12))).toList()),
          ]),
          _ReportSection(title: 'Payroll', icon: Symbols.payments, children: const [
            _NotAvailableNote(label: 'Payroll summary per run', reason: 'Payroll module not built yet — pending current TRA/NSSF/HESLB rate tables.'),
            SizedBox(height: 8),
            _NotAvailableNote(label: 'Statutory remittance report', reason: 'Same as above.'),
            SizedBox(height: 8),
            _NotAvailableNote(label: 'Allowance/overtime cost trend', reason: 'Same as above.'),
          ]),
          _ReportSection(title: 'Career Progression', icon: Symbols.trending_up, children: [
            Text('Promotion / Demotion Log', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            _careerLog.isEmpty
                ? Text('No changes recorded yet.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                : Column(children: _careerLog.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${c.userName}: ${c.fromPosition ?? '—'} → ${c.toPosition ?? '—'} (${c.changeType}, ${c.effectiveDate})',
                        style: AppTheme.bodySm.copyWith(fontSize: 12)),
                  )).toList()),
            const SizedBox(height: 10),
            Row(children: [
              Text('Org Chart Snapshot', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
              const Spacer(),
              TextButton(onPressed: () => showDialog(context: context, builder: (_) => _OrgChartDialog(entries: _orgChart)), child: const Text('View')),
            ]),
          ]),
        ]),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
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
      ]),
      const SizedBox(height: 14),
      ...children,
    ]),
  );
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 20, runSpacing: 10, children: items.map((i) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(i.$2, style: AppTheme.kpiValue.copyWith(fontSize: 20)),
      Text(i.$1.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
    ],
  )).toList());
}

class _BreakdownGrid extends StatelessWidget {
  const _BreakdownGrid({required this.breakdown});
  final HeadcountBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    if (breakdown == null) return const SizedBox.shrink();
    return Wrap(spacing: 24, runSpacing: 14, children: [
      _BreakdownColumn('By Department', breakdown!.byDepartment),
      _BreakdownColumn('By Position', breakdown!.byPosition),
      _BreakdownColumn('By Gender', breakdown!.byGender),
      _BreakdownColumn('By Location', breakdown!.byLocation),
    ]);
  }
}

class _BreakdownColumn extends StatelessWidget {
  const _BreakdownColumn(this.title, this.data);
  final String title;
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5, color: context.pal.textDim)),
      const SizedBox(height: 4),
      ...data.entries.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(children: [
          Expanded(child: Text(e.key, style: AppTheme.bodySm.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
          Text('${e.value}', style: AppTheme.bodySm.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      )),
    ]),
  );
}

class _LeaveBalanceTable extends StatelessWidget {
  const _LeaveBalanceTable({required this.rows});
  final List<HrLeaveBalanceRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Text('No leave balance data.', style: AppTheme.bodySub.copyWith(fontSize: 12));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        columns: const [
          DataColumn(label: Text('Staff')), DataColumn(label: Text('Type')),
          DataColumn(label: Text('Allocated')), DataColumn(label: Text('Used')),
          DataColumn(label: Text('Remaining')), DataColumn(label: Text('Util. %')),
        ],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(Text(r.userName, style: AppTheme.bodySm.copyWith(fontSize: 12))),
          DataCell(Text(r.leaveTypeLabel, style: AppTheme.bodySm.copyWith(fontSize: 12))),
          DataCell(Text(r.allocatedDays.toStringAsFixed(0), style: AppTheme.bodySm.copyWith(fontSize: 12))),
          DataCell(Text(r.usedDays.toStringAsFixed(0), style: AppTheme.bodySm.copyWith(fontSize: 12))),
          DataCell(Text(r.remainingDays.toStringAsFixed(0), style: AppTheme.bodySm.copyWith(fontSize: 12))),
          DataCell(Text('${r.utilizationPct.toStringAsFixed(0)}%', style: AppTheme.bodySm.copyWith(fontSize: 12))),
        ])).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(999), border: Border.all(color: context.pal.border)),
    child: Text(label, style: AppTheme.bodySm.copyWith(fontSize: 11.5)),
  );
}

class _NotAvailableNote extends StatelessWidget {
  const _NotAvailableNote({required this.label, required this.reason});
  final String label, reason;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(Symbols.info, size: 14, color: context.pal.textDim),
    const SizedBox(width: 8),
    Expanded(child: RichText(text: TextSpan(children: [
      TextSpan(text: '$label — ', style: AppTheme.bodySm.copyWith(fontSize: 12, color: context.pal.textMute)),
      TextSpan(text: reason, style: AppTheme.bodySub.copyWith(fontSize: 12)),
    ]))),
  ]);
}

class _OrgChartDialog extends StatelessWidget {
  const _OrgChartDialog({required this.entries});
  final List<OrgChartEntry> entries;

  @override
  Widget build(BuildContext context) {
    final byManager = <int?, List<OrgChartEntry>>{};
    for (final e in entries) { byManager.putIfAbsent(e.managerId, () => []).add(e); }

    List<Widget> renderLevel(int? managerId, int depth) {
      final children = byManager[managerId] ?? [];
      final widgets = <Widget>[];
      for (final e in children) {
        widgets.add(Padding(
          padding: EdgeInsets.only(left: depth * 20.0, top: 6, bottom: 6),
          child: Row(children: [
            Icon(Symbols.person, size: 14, color: context.pal.textDim),
            const SizedBox(width: 8),
            Text(e.name, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
            const SizedBox(width: 8),
            Text(e.positionTitle ?? e.role, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
          ]),
        ));
        if (managerId != e.id) widgets.addAll(renderLevel(e.id, depth + 1));
      }
      return widgets;
    }

    return Dialog(
      backgroundColor: context.pal.surface1,
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Symbols.groups, size: 18, color: AppColors.teal),
            const SizedBox(width: 10),
            Expanded(child: Text('Org Chart Snapshot', style: AppTheme.bodyStrong)),
            GestureDetector(onTap: () => Navigator.of(context).pop(), child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
          ]),
          const Divider(height: 24),
          Flexible(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: renderLevel(null, 0)))),
        ]),
      ),
    );
  }
}
