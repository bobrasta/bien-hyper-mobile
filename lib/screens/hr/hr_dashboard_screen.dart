import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/leave_request.dart';
import '../../services/hr_report_service.dart';
import '../../services/leave_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/error_view.dart';

/// HR's landing page — a glanceable overview assembled entirely from
/// existing `/hr-reports/*` + leave-request endpoints (no new backend).
/// Mirrors the reference dashboards' composition: a KPI row, a composition
/// ring, and a few compact list widgets, rather than one dense table.
class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  HeadcountBreakdown? _headcount;
  RecruitmentSummary? _recruitment;
  List<ContractExpiringEntry> _expiring = [];
  List<LeaveRequest> _pendingLeave = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        HrReportService.instance.headcount(),
        HrReportService.instance.recruitmentSummary(),
        HrReportService.instance.contractsExpiring(withinDays: 90),
        LeaveService.instance.list(status: 'pending'),
      ]);
      if (!mounted) return;
      setState(() {
        _headcount   = results[0] as HeadcountBreakdown;
        _recruitment = results[1] as RecruitmentSummary;
        _expiring    = results[2] as List<ContractExpiringEntry>;
        _pendingLeave = results[3] as List<LeaveRequest>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      final wide = cst.maxWidth >= 980;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HR Dashboard', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Headcount, recruitment, contracts, and leave at a glance', style: AppTheme.bodySub),
            const SizedBox(height: 20),
            _kpiRow(wide),
            const SizedBox(height: 16),
            if (wide)
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 4, child: _compositionCard()),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: _pipelineCard()),
              ]))
            else Column(children: [_compositionCard(), const SizedBox(height: 16), _pipelineCard()]),
            const SizedBox(height: 16),
            if (wide)
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _expiringCard()),
                const SizedBox(width: 16),
                Expanded(child: _pendingLeaveCard()),
              ]))
            else Column(children: [_expiringCard(), const SizedBox(height: 16), _pendingLeaveCard()]),
          ]),
        ),
      );
    });
  }

  Widget _kpiRow(bool wide) {
    final tiles = [
      _KpiTile(icon: Symbols.groups, label: 'Headcount', value: '${_headcount?.total ?? 0}'),
      _KpiTile(icon: Symbols.person_search, label: 'Open Vacancies', value: '${_recruitment?.openVacancies ?? 0}'),
      _KpiTile(icon: Symbols.event_busy, label: 'Pending Leave', value: '${_pendingLeave.length}'),
      _KpiTile(icon: Symbols.badge, label: 'Contracts Expiring (90d)', value: '${_expiring.length}',
          accent: _expiring.isNotEmpty ? AppColors.coral : null),
    ];
    return wide
        ? Row(children: [for (final t in tiles) ...[Expanded(child: t), const SizedBox(width: 14)]]..removeLast())
        : Wrap(spacing: 14, runSpacing: 14, children: tiles.map((t) => SizedBox(width: 220, child: t)).toList());
  }

  Widget _compositionCard() {
    final byGender = _headcount?.byGender ?? {};
    final total = _headcount?.total ?? 0;
    final female = byGender['female'] ?? 0;
    final male = byGender['male'] ?? 0;
    final femalePct = total > 0 ? female / total : 0.0;
    return _Card(title: 'Employee Composition', icon: Symbols.pie_chart, child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        _DonutRing(value: femalePct, total: total, color: AppColors.teal),
        const SizedBox(width: 24),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _LegendRow(color: AppColors.teal, label: 'Female', count: female, total: total),
          const SizedBox(height: 10),
          _LegendRow(color: AppColors.violet, label: 'Male', count: male, total: total),
        ])),
      ]),
    ));
  }

  Widget _pipelineCard() {
    final pipeline = _recruitment?.pipeline ?? [];
    return _Card(title: 'Recruitment Pipeline', icon: Symbols.timeline, child: pipeline.isEmpty
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No open vacancies.', style: AppTheme.bodySub)))
        : Column(children: pipeline.take(4).map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(v.positionTitle ?? 'Vacancy #${v.vacancyId}', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
                Text('${v.totalApplications} applicant(s) · ${v.daysOpen}d open', style: AppTheme.monoXs),
              ]),
              const SizedBox(height: 6),
              _StageBar(byStage: v.byStage),
            ]),
          )).toList()),
    );
  }

  Widget _expiringCard() {
    return _Card(title: 'Contracts Expiring Soon', icon: Symbols.event_upcoming, child: _expiring.isEmpty
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Nothing expiring in the next 90 days.', style: AppTheme.bodySub)))
        : Column(children: _expiring.take(6).map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(Symbols.badge, size: 15, color: context.pal.textDim),
              const SizedBox(width: 8),
              Expanded(child: Text(e.userName, style: AppTheme.bodySm)),
              Text('${e.daysRemaining}d', style: AppTheme.monoXs.copyWith(
                  color: e.daysRemaining <= 14 ? AppColors.coral : context.pal.textDim)),
            ]),
          )).toList()),
    );
  }

  Widget _pendingLeaveCard() {
    return _Card(title: 'Pending Leave Requests', icon: Symbols.event_busy, child: _pendingLeave.isEmpty
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Nothing awaiting review.', style: AppTheme.bodySub)))
        : Column(children: _pendingLeave.take(6).map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(Symbols.event, size: 15, color: context.pal.textDim),
              const SizedBox(width: 8),
              Expanded(child: Text(r.userName ?? '—', style: AppTheme.bodySm)),
              Text(r.leaveTypeLabel ?? '—', style: AppTheme.monoXs),
              const SizedBox(width: 8),
              Text('${r.daysCount}d', style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
            ]),
          )).toList()),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.icon, required this.label, required this.value, this.accent});
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: accent ?? AppColors.teal),
      const SizedBox(height: 10),
      Text(value, style: AppTheme.kpiValue.copyWith(color: accent ?? context.pal.text, fontSize: 26)),
      const SizedBox(height: 2),
      Text(label, style: AppTheme.bodySub),
    ]),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: context.pal.textDim),
        const SizedBox(width: 8),
        Text(title, style: AppTheme.cardTitle),
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

/// Composite-score ring with the number centered inside — the reference
/// dashboards' "Employee Composition"/"Total score" treatment, applied here
/// to gender split (%female of total headcount).
class _DonutRing extends StatelessWidget {
  const _DonutRing({required this.value, required this.total, required this.color});
  final double value; // 0..1
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 92, height: 92,
    child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(92, 92), painter: _RingPainter(
        value: value, trackColor: context.pal.surface3, valueColor: color,
      )),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$total', style: AppTheme.kpiValue.copyWith(fontSize: 20)),
        Text('Total', style: AppTheme.monoXs),
      ]),
    ]),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.trackColor, required this.valueColor});
  final double value;
  final Color trackColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    final fg = Paint()..color = valueColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * value.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.valueColor != valueColor;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.count, required this.total});
  final Color color;
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: AppTheme.bodySm),
      const Spacer(),
      Text('$count · $pct%', style: AppTheme.monoXs),
    ]);
  }
}

/// Segmented, colored bar (one block per pipeline stage) — the reference
/// dashboards' "match rate" bar pattern, applied here to hiring-stage counts.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.byStage});
  final Map<String, int> byStage;

  // Not const: AppColors.* are reactive getters (theme-dependent), not
  // compile-time constants — see feedback_theme_porting_approach memory.
  static List<Color> get _stageColors => [AppColors.info, AppColors.teal, AppColors.amber, AppColors.violet, AppColors.coral];

  @override
  Widget build(BuildContext context) {
    final total = byStage.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return ClipRRect(borderRadius: BorderRadius.circular(4),
          child: Container(height: 7, color: context.pal.surface3));
    }
    final entries = byStage.entries.where((e) => e.value > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(children: [
        for (var i = 0; i < entries.length; i++)
          Expanded(
            flex: entries[i].value,
            child: Container(height: 7, color: _stageColors[i % _stageColors.length]),
          ),
      ]),
    );
  }
}
