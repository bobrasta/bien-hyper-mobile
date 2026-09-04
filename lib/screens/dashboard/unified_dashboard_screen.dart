import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/unified_dashboard_section.dart';
import '../../services/unified_dashboard_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/charts/revenue_line_chart.dart';
import '../../widgets/charts/status_donut_chart.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/kpi_card.dart';

/// Replaces the old one-size-fits-all Dashboard. Renders whatever ordered
/// section list `GET /dashboard/unified` returns — section presence there
/// IS the permission gate (screens.machines/service/inventory/sales/
/// revenue/finance/hr_dashboard), so this screen has no role/permission
/// logic of its own. Admin/CTO see every section because they hold every
/// permission; a single-department role sees only its own section(s).
class UnifiedDashboardScreen extends StatefulWidget {
  const UnifiedDashboardScreen({super.key, this.onNavigateTo});
  final void Function(String key)? onNavigateTo;

  @override
  State<UnifiedDashboardScreen> createState() => _UnifiedDashboardScreenState();
}

class _UnifiedDashboardScreenState extends State<UnifiedDashboardScreen> {
  List<UnifiedDashboardSection>? _sections;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final sections = await UnifiedDashboardService.instance.load();
      if (mounted) setState(() => _sections = sections);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_sections == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_sections!.isEmpty) {
      return Center(child: Text('No dashboard sections available', style: TextStyle(color: context.pal.textMute)));
    }

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dashboard', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Relevant to your role — nothing else.', style: AppTheme.bodySub),
            const SizedBox(height: 20),
            for (final section in _sections!) ...[
              _SectionCard(section: section, onNavigateTo: widget.onNavigateTo),
              const SizedBox(height: 16),
            ],
          ]),
        ),
      );
    });
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, this.onNavigateTo});
  final UnifiedDashboardSection section;
  final void Function(String key)? onNavigateTo;

  // Which existing nav key "View full dashboard" lands on, per section.
  static const _detailScreenKey = {
    'fleet':     'machines',
    'service':   'service',
    'inventory': 'inventory',
    'sales':     'sales_dashboard',
    'revenue':   'revenue',
    'finance':   'finance_dashboard',
    'hr':        'hr_dashboard',
  };

  static const _icons = {
    'fleet':     Symbols.precision_manufacturing,
    'service':   Symbols.build_circle,
    'inventory': Symbols.inventory_2,
    'sales':     Symbols.trending_up,
    'revenue':   Symbols.payments,
    'finance':   Symbols.account_balance,
    'hr':        Symbols.badge,
  };

  @override
  Widget build(BuildContext context) {
    final detailKey = _detailScreenKey[section.key];
    return AppCard(
      header: Row(children: [
        Icon(_icons[section.key] ?? Symbols.dashboard, size: 17, color: AppColors.teal),
        const SizedBox(width: 8),
        Text(section.title, style: AppTheme.cardTitle),
      ]),
      trailing: detailKey == null
          ? null
          : TextButton.icon(
              onPressed: () => onNavigateTo?.call(detailKey),
              icon: const Icon(Symbols.open_in_new, size: 14),
              label: const Text('View full dashboard'),
              style: TextButton.styleFrom(foregroundColor: AppColors.teal, textStyle: AppTheme.bodySm),
            ),
      child: _sectionBody(context),
    );
  }

  Widget _sectionBody(BuildContext context) {
    final d = section.data;
    return switch (section.key) {
      'fleet'     => _FleetSection(d),
      'service'   => _ServiceSection(d),
      'inventory' => _InventorySection(d),
      'sales'     => _SalesSection(d),
      'revenue'   => _TrendSection(months: d['months'] as List? ?? const [], primaryKey: 'actual', secondaryKey: 'target', primaryLabel: 'Actual', secondaryLabel: 'Target'),
      'finance'   => _TrendSection(months: d['months'] as List? ?? const [], primaryKey: 'revenue', secondaryKey: 'expenses', primaryLabel: 'Revenue', secondaryLabel: 'Expenses'),
      'hr'        => _HrSection(d),
      _           => const SizedBox.shrink(), // forward-compatible: unrecognized section renders nothing
    };
  }
}

Widget _kpiRow(List<Widget> tiles) => LayoutBuilder(builder: (ctx, cst) {
  final cols = cst.maxWidth < 420 ? 2 : (cst.maxWidth < 760 ? 3 : tiles.length);
  return Wrap(
    spacing: 12, runSpacing: 12,
    children: tiles.map((t) => SizedBox(width: (cst.maxWidth - (cols - 1) * 12) / cols, child: t)).toList(),
  );
});

class _FleetSection extends StatelessWidget {
  const _FleetSection(this.d);
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final total = (d['total_machines'] as num? ?? 0).toInt();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _kpiRow([
        KpiCard(label: 'Total Machines', icon: Symbols.precision_manufacturing, value: '$total'),
        KpiCard(label: 'Operational', icon: Symbols.check_circle, value: '${d['operational'] ?? 0}', unit: '/ $total', accent: KpiAccent.teal),
        KpiCard(label: 'Down', icon: Symbols.error, value: '${d['down'] ?? 0}', accent: KpiAccent.coral),
        KpiCard(label: 'Hospitals', icon: Symbols.local_hospital, value: '${d['total_hospitals'] ?? 0}'),
      ]),
      const SizedBox(height: 16),
      StatusDonutChart(
        breakdown: {
          'Operational':   (d['operational'] as num? ?? 0).toInt(),
          'Needs Service': (d['needs_service'] as num? ?? 0).toInt(),
          'Down':          (d['down'] as num? ?? 0).toInt(),
          'Warranty':      (d['warranty'] as num? ?? 0).toInt(),
        },
        total: total,
      ),
    ]);
  }
}

class _ServiceSection extends StatelessWidget {
  const _ServiceSection(this.d);
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final overdue = (d['overdue_tickets'] as num? ?? 0).toInt();
    return _kpiRow([
      KpiCard(label: 'Open Tickets', icon: Symbols.build, value: '${d['open_tickets'] ?? 0}'),
      KpiCard(
        label: 'Overdue', icon: Symbols.warning, value: '$overdue',
        accent: overdue > 0 ? KpiAccent.coral : KpiAccent.teal,
      ),
    ]);
  }
}

class _InventorySection extends StatelessWidget {
  const _InventorySection(this.d);
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final lowStock = (d['low_stock_count'] as num? ?? 0).toInt();
    return _kpiRow([
      KpiCard(label: 'Stock Value', icon: Symbols.inventory_2, value: tshFromDouble((d['total_stock_value'] as num? ?? 0).toDouble())),
      KpiCard(label: 'Items', icon: Symbols.list_alt, value: '${d['total_items'] ?? 0}'),
      KpiCard(
        label: 'Low Stock', icon: Symbols.warning, value: '$lowStock',
        accent: lowStock > 0 ? KpiAccent.amber : KpiAccent.teal,
      ),
      KpiCard(label: 'Open POs', icon: Symbols.receipt_long, value: '${d['open_purchase_orders'] ?? 0}'),
    ]);
  }
}

class _SalesSection extends StatelessWidget {
  const _SalesSection(this.d);
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final kpi = (d['kpi'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _kpiRow([
      KpiCard(label: 'Pipeline Value', icon: Symbols.trending_up, value: tshFromDouble((kpi['pipeline_value'] as num? ?? 0).toDouble())),
      KpiCard(label: 'Open Leads', icon: Symbols.groups, value: '${kpi['open_leads'] ?? 0}'),
      KpiCard(label: 'Won This Month', icon: Symbols.emoji_events, value: '${kpi['won_this_month'] ?? 0}'),
      KpiCard(label: 'Revenue MTD', icon: Symbols.payments, value: tshFromDouble((kpi['revenue_this_month'] as num? ?? 0).toDouble())),
    ]);
  }
}

class _HrSection extends StatelessWidget {
  const _HrSection(this.d);
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final byDept = (d['by_department'] as Map?)?.cast<String, dynamic>() ?? const {};
    final topDept = byDept.entries.isEmpty
        ? '—'
        : (byDept.entries.toList()..sort((a, b) => (b.value as num).compareTo(a.value as num))).first.key;
    return _kpiRow([
      KpiCard(label: 'Active Staff', icon: Symbols.badge, value: '${d['total'] ?? 0}'),
      KpiCard(label: 'Largest Dept.', icon: Symbols.groups, value: topDept),
    ]);
  }
}

// Shared by Revenue (actual vs target) and Finance (revenue vs expenses) —
// both are a 12-month trend of two numeric series, just different keys.
class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.months, required this.primaryKey, required this.secondaryKey,
    required this.primaryLabel, required this.secondaryLabel,
  });
  final List months;
  final String primaryKey;
  final String secondaryKey;
  final String primaryLabel;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final rows = months.cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
    return RevenueLineChart(
      months: rows.map((m) => m['label'] as String? ?? '').toList(),
      actual: rows.map((m) => (m[primaryKey] as num? ?? 0).toDouble()).toList(),
      target: rows.map((m) => (m[secondaryKey] as num? ?? 0).toDouble()).toList(),
      latestValue: rows.isEmpty ? null : tshFromDouble((rows.last[primaryKey] as num? ?? 0).toDouble()),
      latestLabel: primaryLabel,
    );
  }
}
