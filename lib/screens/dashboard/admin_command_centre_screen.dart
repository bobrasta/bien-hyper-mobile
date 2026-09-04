import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/admin_overview.dart';
import '../../models/hospital.dart';
import '../../services/admin_overview_service.dart';
import '../../services/hospital_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/charts/tanzania_map_widget.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/kpi_card.dart';

// Postgres COALESCE(SUM(...))/COUNT(...) columns come back through PDO as
// strings, not numbers, whenever they're forwarded to JSON raw (e.g.
// DashboardController::buildSales()'s pipeline_by_stage) instead of being
// explicitly (int)/(float) cast in PHP first — unlike this screen's KPI
// fields, which already get that cast server-side. Handles both shapes.
double _numField(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

/// Admin/Director-only "Command Centre" — a fixed bespoke layout (map,
/// cross-department exception feed, technician roster, compact per-
/// department mini-panels), matching the reference design supplied by the
/// user rather than the generic permission-driven section list every
/// other role sees (UnifiedDashboardScreen). Fed by GET
/// /dashboard/admin-overview, a separate admin-only endpoint — not
/// composed from the generic sections since the layout itself is
/// different, not just which sections show.
class AdminCommandCentreScreen extends StatefulWidget {
  const AdminCommandCentreScreen({super.key, this.onNavigateTo});
  final void Function(String key)? onNavigateTo;

  @override
  State<AdminCommandCentreScreen> createState() => _AdminCommandCentreScreenState();
}

class _AdminCommandCentreScreenState extends State<AdminCommandCentreScreen> {
  AdminOverview? _overview;
  List<Hospital> _hospitals = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        AdminOverviewService.instance.load(),
        HospitalService.instance.list(),
      ]);
      if (mounted) {
        setState(() {
          _overview = results[0] as AdminOverview;
          _hospitals = results[1] as List<Hospital>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final o = _overview;
    if (o == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 900 ? 16.0 : 28.0;
      final narrow = cst.maxWidth < 1100;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Header(greeting: o.greeting),
            const SizedBox(height: 16),
            _kpiRow(o.kpis),
            const SizedBox(height: 16),
            if (narrow) ...[
              SizedBox(height: 420, child: _MapPanel(hospitals: _hospitals, legend: o.fleetLegend, zones: o.zones)),
              const SizedBox(height: 16),
              SizedBox(height: 340, child: _AttentionPanel(items: o.attention)),
              const SizedBox(height: 16),
              SizedBox(height: 280, child: _TechnicianPanel(techs: o.technicians)),
            ] else ...[
              SizedBox(
                height: 420,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _MapPanel(hospitals: _hospitals, legend: o.fleetLegend, zones: o.zones)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 340,
                    child: Column(children: [
                      Expanded(flex: 6, child: _AttentionPanel(items: o.attention)),
                      const SizedBox(height: 12),
                      Expanded(flex: 5, child: _TechnicianPanel(techs: o.technicians)),
                    ]),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 11, child: _SalesMiniPanel(sales: o.sales)),
                const SizedBox(width: 12),
                Expanded(flex: 11, child: _FinanceMiniPanel(finance: o.finance)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 8,
                  child: Column(children: [
                    Expanded(child: _InventoryMiniPanel(inventory: o.inventory)),
                    const SizedBox(height: 12),
                    Expanded(child: _PeopleMiniPanel(people: o.people)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

Widget _kpiRow(Map<String, dynamic> kpis) => LayoutBuilder(builder: (ctx, cst) {
  final tiles = [
    KpiCard(label: 'Fleet Uptime', icon: Symbols.monitor_heart, value: '${kpis['fleet_uptime_pct'] ?? 0}', unit: '%'),
    KpiCard(label: 'Machines Down', icon: Symbols.error, value: '${kpis['machines_down'] ?? 0}', accent: KpiAccent.coral),
    KpiCard(label: 'Open Tickets', icon: Symbols.build, value: '${kpis['open_tickets'] ?? 0}',
        accent: (kpis['overdue_tickets'] as num? ?? 0) > 0 ? KpiAccent.amber : KpiAccent.teal),
    KpiCard(label: 'Cash Position', icon: Symbols.account_balance_wallet,
        value: tshSigned((kpis['cash_position'] as num? ?? 0).toDouble()),
        accent: (kpis['cash_position'] as num? ?? 0) >= 0 ? KpiAccent.teal : KpiAccent.coral),
    KpiCard(label: 'Pipeline', icon: Symbols.trending_up, value: tshFromDouble((kpis['pipeline_value'] as num? ?? 0).toDouble())),
  ];
  final cols = cst.maxWidth < 480 ? 2 : (cst.maxWidth < 900 ? 3 : 5);
  return Wrap(
    spacing: 10, runSpacing: 10,
    children: tiles.map((t) => SizedBox(width: (cst.maxWidth - (cols - 1) * 10) / cols, child: t)).toList(),
  );
});

class _Header extends StatelessWidget {
  const _Header({required this.greeting});
  final AdminGreeting greeting;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final salutation = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 2, height: 34, color: AppColors.teal),
      const SizedBox(width: 11),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$salutation, ${greeting.name}', style: AppTheme.pageTitle),
        const SizedBox(height: 3),
        Text(
          '${greeting.date} · ${greeting.machinesDown} machines down · '
          '${greeting.openTickets} open tickets · ${greeting.techniciansOut} technicians on the road',
          style: AppTheme.bodySub,
        ),
      ]),
    ]);
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.hospitals, required this.legend, required this.zones});
  final List<Hospital> hospitals;
  final Map<String, int> legend;
  final List<ZoneCount> zones;

  @override
  Widget build(BuildContext context) {
    final totalMachines = hospitals.fold<int>(0, (a, h) => a + h.machineCount);
    final operational = hospitals.fold<int>(0, (a, h) => a + h.machinesOperational);
    return AppCard(
      padding: EdgeInsets.zero,
      header: Row(children: [
        Icon(Symbols.map, size: 15, color: AppColors.teal),
        const SizedBox(width: 8),
        Text('Fleet & Service Activity', style: AppTheme.cardTitle),
      ]),
      expandChild: true,
      child: Stack(children: [
        Positioned.fill(
          child: FleetMapWidget(
            hospitals: hospitals,
            totalMachines: totalMachines,
            uptimePct: totalMachines == 0 ? 0 : operational / totalMachines,
          ),
        ),
        Positioned(
          left: 12, bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.pal.surface1.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.pal.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _legendRow('Operational', AppColors.teal, legend['operational'] ?? 0),
              _legendRow('Needs Service', AppColors.amber, legend['needs_service'] ?? 0),
              _legendRow('Down', AppColors.coral, legend['down'] ?? 0),
              _legendRow('Technician En Route', AppColors.cyan, legend['technician_en_route'] ?? 0),
            ]),
          ),
        ),
        Positioned(
          right: 12, top: 12, width: 176,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.pal.surface1.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.pal.border),
            ),
            child: Column(children: zones.map((z) {
              final maxCount = zones.isEmpty ? 1 : zones.first.count.clamp(1, 1 << 30);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(z.name, style: AppTheme.bodySub.copyWith(fontSize: 10.5), overflow: TextOverflow.ellipsis)),
                  SizedBox(
                    width: 44, height: 3,
                    child: LinearProgressIndicator(
                      value: z.count / maxCount, backgroundColor: context.pal.border,
                      valueColor: AlwaysStoppedAnimation(AppColors.teal), borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(width: 20, child: Text('${z.count}', style: AppTheme.monoXs.copyWith(fontSize: 10), textAlign: TextAlign.right)),
                ]),
              );
            }).toList()),
          ),
        ),
      ]),
    );
  }

  Widget _legendRow(String label, Color color, int count) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      SizedBox(width: 130, child: Builder(builder: (context) => Text(label, style: AppTheme.bodySub.copyWith(fontSize: 10.5)))),
      Builder(builder: (context) => Text('$count', style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: context.pal.text))),
    ]),
  );
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.items});
  final List<AttentionItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      header: Row(children: [
        Icon(Symbols.warning, size: 15, color: AppColors.coral),
        const SizedBox(width: 8),
        Text('Needs You Today', style: AppTheme.cardTitle),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(5)),
          child: Text('${items.length}', style: AppTheme.monoXs.copyWith(color: AppColors.coral, fontSize: 10)),
        ),
      ]),
      expandChild: true,
      child: items.isEmpty
          ? Center(child: Text('Nothing needs attention right now.', style: TextStyle(color: context.pal.textMute, fontSize: 12)))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.divider),
              itemBuilder: (_, i) {
                final a = items[i];
                final color = switch (a.severity) {
                  'critical' => AppColors.coral,
                  'warning'  => AppColors.amber,
                  _          => AppColors.violet,
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 3, height: 26, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 9),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: AppTheme.bodySm.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(a.meta, style: AppTheme.bodySub.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    if (a.age != null) Text(a.age!, style: AppTheme.monoXs.copyWith(color: color, fontSize: 10)),
                  ]),
                );
              },
            ),
    );
  }
}

class _TechnicianPanel extends StatelessWidget {
  const _TechnicianPanel({required this.techs});
  final List<TechnicianRosterEntry> techs;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      header: Row(children: [
        Icon(Symbols.groups, size: 15, color: AppColors.cyan),
        const SizedBox(width: 8),
        Text('Technicians', style: AppTheme.cardTitle),
      ]),
      expandChild: true,
      child: techs.isEmpty
          ? Center(child: Text('No technicians on staff.', style: TextStyle(color: context.pal.textMute, fontSize: 12)))
          : ListView.separated(
              itemCount: techs.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.divider),
              itemBuilder: (_, i) {
                final t = techs[i];
                final (label, color) = switch (t.state) {
                  'en_route' => ('En Route', AppColors.cyan),
                  'on_leave' => ('On Leave', context.pal.textMute),
                  _          => ('Available', AppColors.teal),
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.name, style: AppTheme.bodySm.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(t.where, style: AppTheme.bodySub.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
                      child: Text(label, style: AppTheme.monoXs.copyWith(color: color, fontSize: 9.5)),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}

class _SalesMiniPanel extends StatelessWidget {
  const _SalesMiniPanel({required this.sales});
  final Map<String, dynamic> sales;

  @override
  Widget build(BuildContext context) {
    final kpi = (sales['kpi'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stages = (sales['pipeline_by_stage'] as List? ?? []).cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
    final maxVal = stages.isEmpty ? 1.0 : stages.map((s) => _numField(s['value'])).reduce((a, b) => a > b ? a : b);
    return AppCard(
      header: Row(children: [
        Icon(Symbols.trending_up, size: 14, color: AppColors.violet),
        const SizedBox(width: 8),
        Text('Sales', style: AppTheme.cardTitle),
        const Spacer(),
        Text(tshFromDouble((kpi['pipeline_value'] as num? ?? 0).toDouble()), style: AppTheme.monoXs),
        const SizedBox(width: 4),
        Text('pipeline', style: AppTheme.bodySub.copyWith(fontSize: 10)),
      ]),
      expandChild: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ListView(
            children: stages.map((s) {
              final v = _numField(s['value']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 84, child: Text('${s['stage'] ?? ''}', style: AppTheme.bodySub.copyWith(fontSize: 10.5), overflow: TextOverflow.ellipsis)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: v / maxVal, backgroundColor: context.pal.border,
                      valueColor: AlwaysStoppedAnimation(AppColors.violet), minHeight: 5, borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 56, child: Text(tshFromDouble(v), style: AppTheme.monoXs.copyWith(fontSize: 10.5), textAlign: TextAlign.right)),
                ]),
              );
            }).toList(),
          ),
        ),
        Divider(height: 14, color: context.pal.divider),
        Row(children: [
          Text('Open leads ${kpi['open_leads'] ?? 0}', style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
          const SizedBox(width: 12),
          Text('Won MTD ${kpi['won_this_month'] ?? 0}', style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
        ]),
      ]),
    );
  }
}

class _FinanceMiniPanel extends StatelessWidget {
  const _FinanceMiniPanel({required this.finance});
  final Map<String, dynamic> finance;

  @override
  Widget build(BuildContext context) {
    final months = (finance['months'] as List? ?? []).cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
    final last = months.isEmpty ? const {} : months.last;
    final maxVal = months.isEmpty ? 1.0 : months.expand((m) => [
      (m['revenue'] as num? ?? 0).toDouble(), (m['expenses'] as num? ?? 0).toDouble(),
    ]).fold(1.0, (a, b) => b > a ? b : a);
    return AppCard(
      header: Row(children: [
        Icon(Symbols.account_balance, size: 14, color: AppColors.cyan),
        const SizedBox(width: 8),
        Text('Finance', style: AppTheme.cardTitle),
      ]),
      expandChild: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _miniStat('Revenue', tshFromDouble((last['revenue'] as num? ?? 0).toDouble())),
          _miniStat('Expenses', tshFromDouble((last['expenses'] as num? ?? 0).toDouble())),
          _miniStat('Net', tshSigned((last['net_profit'] as num? ?? 0).toDouble())),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: months.map((m) {
              final rev = (m['revenue'] as num? ?? 0).toDouble();
              final exp = (m['expenses'] as num? ?? 0).toDouble();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 4, height: (rev / maxVal * 44).clamp(1, 44), color: AppColors.cyan),
                    const SizedBox(width: 1),
                    Container(width: 4, height: (exp / maxVal * 44).clamp(1, 44), color: AppColors.coral),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _miniStat(String label, String value) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Builder(builder: (context) => Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9))),
      Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
    ]),
  );
}

class _InventoryMiniPanel extends StatelessWidget {
  const _InventoryMiniPanel({required this.inventory});
  final Map<String, dynamic> inventory;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      header: Row(children: [
        Icon(Symbols.inventory_2, size: 14, color: AppColors.amber),
        const SizedBox(width: 8),
        Text('Inventory', style: AppTheme.cardTitle),
        const Spacer(),
        Text(tshFromDouble((inventory['total_stock_value'] as num? ?? 0).toDouble()), style: AppTheme.monoXs),
      ]),
      child: Row(children: [
        _stat('${inventory['total_items'] ?? 0}', 'Items'),
        _stat('${inventory['low_stock_count'] ?? 0}', 'Low Stock', color: AppColors.amber),
        _stat('${inventory['open_purchase_orders'] ?? 0}', 'Open POs'),
      ]),
    );
  }

  Widget _stat(String value, String label, {Color? color}) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: AppTheme.cardTitle.copyWith(fontSize: 17, color: color)),
      Builder(builder: (context) => Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9))),
    ]),
  );
}

class _PeopleMiniPanel extends StatelessWidget {
  const _PeopleMiniPanel({required this.people});
  final Map<String, dynamic> people;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      header: Row(children: [
        Icon(Symbols.badge, size: 14, color: AppColors.teal),
        const SizedBox(width: 8),
        Text('People', style: AppTheme.cardTitle),
      ]),
      child: Row(children: [
        _stat('${people['active_staff'] ?? 0}', 'Active Staff'),
        _stat('${people['on_leave_today'] ?? 0}', 'On Leave'),
        _stat('${people['pending_approvals'] ?? 0}', 'Approvals', color: AppColors.violet),
      ]),
    );
  }

  Widget _stat(String value, String label, {Color? color}) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: AppTheme.cardTitle.copyWith(fontSize: 17, color: color)),
      Builder(builder: (context) => Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9))),
    ]),
  );
}
