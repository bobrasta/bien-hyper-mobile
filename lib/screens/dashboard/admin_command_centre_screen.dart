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

String _humanizeStage(String stage) =>
    stage.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

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

  // m7/m5 Materialize-grid proportion (map:rail), same pattern used
  // elsewhere in this app rather than a fixed pixel rail width.
  Widget _mainRow(AdminOverview o) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(flex: 7, child: _MapPanel(hospitals: _hospitals, onNavigateTo: widget.onNavigateTo)),
    const SizedBox(width: 12),
    Expanded(
      flex: 5,
      child: Column(children: [
        Expanded(flex: 6, child: _AttentionPanel(items: o.attention)),
        const SizedBox(height: 12),
        Expanded(flex: 5, child: _TechnicianPanel(techs: o.technicians, onNavigateTo: widget.onNavigateTo)),
      ]),
    ),
  ]);

  Widget _bottomRow(AdminOverview o) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
  ]);

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final o = _overview;
    if (o == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 900 ? 16.0 : 28.0;
      final narrow = cst.maxWidth < 1100;

      // Scrolling is fine — this is the front page of the system, so it
      // should show enough of each department to actually be useful rather
      // than being squeezed to fit whatever the window's height happens to
      // be. Generous fixed heights (not viewport-filling flex) give the map
      // and bar charts real room; narrow windows just stack everything.
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Header(greeting: o.greeting, onRefresh: _load),
            const SizedBox(height: 16),
            _kpiRow(o),
            const SizedBox(height: 16),
            if (narrow) ...[
              // Section 2: "make the map bigger" + "sized for mobile" —
              // taller than before now that the legend/zones/stats bar no
              // longer eat into the map's own visual space.
              SizedBox(height: 560, child: _MapPanel(hospitals: _hospitals, onNavigateTo: widget.onNavigateTo)),
              const SizedBox(height: 16),
              _FleetSummaryCard(hospitals: _hospitals, legend: o.fleetLegend, zones: o.zones, inStock: o.fleetInStock),
              const SizedBox(height: 16),
              SizedBox(height: 340, child: _AttentionPanel(items: o.attention)),
              const SizedBox(height: 16),
              SizedBox(height: 280, child: _TechnicianPanel(techs: o.technicians, onNavigateTo: widget.onNavigateTo)),
            ] else ...[
              SizedBox(height: 680, child: _mainRow(o)),
              const SizedBox(height: 16),
              _FleetSummaryCard(hospitals: _hospitals, legend: o.fleetLegend, zones: o.zones, inStock: o.fleetInStock),
            ],
            const SizedBox(height: 16),
            SizedBox(height: 340, child: _bottomRow(o)),
          ]),
        ),
      );
    });
  }
}

Widget _kpiRow(AdminOverview o) => LayoutBuilder(builder: (ctx, cst) {
  final kpis = o.kpis;
  final operational = o.fleetLegend['operational'] ?? 0;
  final needsService = o.fleetLegend['needs_service'] ?? 0;
  final down = (kpis['machines_down'] as num? ?? 0).toInt();
  final approxTotal = operational + needsService + down;
  final overdue = (kpis['overdue_tickets'] as num? ?? 0).toInt();
  final openLeads = ((o.sales['kpi'] as Map?)?.cast<String, dynamic>()['open_leads'] as num? ?? 0).toInt();

  final tiles = [
    KpiCard(
      label: 'Fleet Uptime', icon: Symbols.monitor_heart, value: '${kpis['fleet_uptime_pct'] ?? 0}', unit: '%',
      deltaValue: '$operational/$approxTotal', deltaUp: true, deltaNote: 'operational now',
    ),
    KpiCard(
      label: 'Machines Down', icon: Symbols.error, value: '$down', accent: KpiAccent.coral,
      deltaValue: '$needsService', deltaUp: false, deltaNote: 'needs service',
    ),
    KpiCard(
      label: 'Open Tickets', icon: Symbols.build, value: '${kpis['open_tickets'] ?? 0}',
      accent: overdue > 0 ? KpiAccent.amber : KpiAccent.teal,
      deltaValue: overdue > 0 ? '$overdue overdue' : 'On track', deltaUp: overdue == 0, deltaNote: overdue > 0 ? 'need attention' : 'no overdue',
    ),
    KpiCard(
      label: 'Cash Position', icon: Symbols.account_balance_wallet,
      value: tshSigned((kpis['cash_position'] as num? ?? 0).toDouble()),
      accent: (kpis['cash_position'] as num? ?? 0) >= 0 ? KpiAccent.teal : KpiAccent.coral,
      deltaValue: (kpis['cash_position'] as num? ?? 0) >= 0 ? 'profit' : 'loss',
      deltaUp: (kpis['cash_position'] as num? ?? 0) >= 0, deltaNote: 'this month',
    ),
    KpiCard(
      label: 'Pipeline', icon: Symbols.trending_up, value: tshFromDouble((kpis['pipeline_value'] as num? ?? 0).toDouble()),
      deltaValue: '$openLeads open', deltaUp: true, deltaNote: 'active deals',
    ),
  ];
  final cols = cst.maxWidth < 480 ? 2 : (cst.maxWidth < 900 ? 3 : 5);
  return Wrap(
    spacing: 10, runSpacing: 10,
    children: tiles.map((t) => SizedBox(width: (cst.maxWidth - (cols - 1) * 10) / cols, child: t)).toList(),
  );
});

class _Header extends StatelessWidget {
  const _Header({required this.greeting, this.onRefresh});
  final AdminGreeting greeting;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final salutation = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 2, height: 34, color: AppColors.teal),
      const SizedBox(width: 11),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$salutation, ${greeting.name}', style: AppTheme.pageTitle),
          const SizedBox(height: 3),
          Text(
            '${greeting.date} · ${greeting.machinesDown} machines down · '
            '${greeting.openTickets} open tickets · ${greeting.techniciansOut} technicians on the road',
            style: AppTheme.bodySub,
          ),
        ]),
      ),
      if (onRefresh != null)
        IconButton(
          icon: const Icon(Symbols.refresh, size: 18),
          tooltip: 'Refresh',
          onPressed: onRefresh,
        ),
    ]);
  }
}

enum _MapLayer { machines, alerts, technicians }

class _MapPanel extends StatefulWidget {
  const _MapPanel({required this.hospitals, this.onNavigateTo});
  final List<Hospital> hospitals;
  final void Function(String key)? onNavigateTo;

  @override
  State<_MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<_MapPanel> {
  _MapLayer _layer = _MapLayer.alerts;

  @override
  Widget build(BuildContext context) {
    // "Alerts" narrows the pins to what actually needs attention; "Machines"
    // shows the full fleet. "Technicians" has no real per-technician
    // location data wired yet (roster only, no hospital coordinate), so it
    // falls back to the full fleet rather than fabricating a filter.
    final shown = _layer == _MapLayer.alerts
        ? widget.hospitals.where((h) => h.machinesOperational < h.machineCount).toList()
        : widget.hospitals;
    final totalMachines = widget.hospitals.fold<int>(0, (a, h) => a + h.machineCount);
    final operational = widget.hospitals.fold<int>(0, (a, h) => a + h.machinesOperational);
    return AppCard(
      padding: EdgeInsets.zero,
      header: Row(children: [
        Icon(Symbols.map, size: 15, color: AppColors.teal),
        const SizedBox(width: 8),
        Text('Fleet & Service Activity', style: AppTheme.cardTitle),
        const SizedBox(width: 8),
        Text('${widget.hospitals.isEmpty ? 0 : totalMachines} machines · ${widget.hospitals.length} hospitals',
            style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _layerPill('Machines', Symbols.memory, _MapLayer.machines),
        const SizedBox(width: 6),
        _layerPill('Alerts', Symbols.warning, _MapLayer.alerts),
        const SizedBox(width: 6),
        _layerPill('Technicians', Symbols.person_pin_circle, _MapLayer.technicians),
        const SizedBox(width: 10),
        TextButton.icon(
          onPressed: () => widget.onNavigateTo?.call('machines_map'),
          icon: const Icon(Symbols.open_in_new, size: 13),
          label: const Text('Open Map'),
          style: TextButton.styleFrom(foregroundColor: AppColors.teal, textStyle: AppTheme.bodySm),
        ),
      ]),
      expandChild: true,
      // Header sits above with its own square top edge, and needs a little
      // breathing room below it before the map starts (was sitting flush
      // against it) — round only the bottom two corners of the map itself
      // to meet the card's bottom edge, matching the reference design's
      // border-radius: 0 0 r r.
      //
      // Section 2: the region breakdown/status legend/bottom stats bar that
      // used to overlay the map itself now live in _FleetSummaryCard below
      // — only the map's own layer switcher (inside FleetMapWidget) and
      // zoom controls stay inside the map.
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(AppColors.rLg),
            bottomRight: Radius.circular(AppColors.rLg),
          ),
          child: FleetMapWidget(
            hospitals: shown,
            totalMachines: totalMachines,
            uptimePct: totalMachines == 0 ? 0 : operational / totalMachines,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AppColors.rLg),
              bottomRight: Radius.circular(AppColors.rLg),
            ),
          ),
        ),
      ),
    );
  }

  Widget _layerPill(String label, IconData icon, _MapLayer layer) {
    final active = _layer == layer;
    return GestureDetector(
      onTap: () => setState(() => _layer = layer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.tealSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? AppColors.teal : context.pal.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: active ? AppColors.teal : context.pal.textMute),
          const SizedBox(width: 5),
          Text(label, style: AppTheme.bodySm.copyWith(fontSize: 11, color: active ? AppColors.teal : context.pal.textMute)),
        ]),
      ),
    );
  }
}

// Section 2: "Create a new card directly below the map card, full width,
// height = fit content, containing the region breakdown, status legend and
// the Hospitals / Machines / Uptime stats" — plus a new "In Stock" tile.
// No expandChild/fixed SizedBox around this one anywhere it's used, so it
// sizes to its own content instead of stretching or clipping.
class _FleetSummaryCard extends StatelessWidget {
  const _FleetSummaryCard({required this.hospitals, required this.legend, required this.zones, required this.inStock});
  final List<Hospital> hospitals;
  final Map<String, int> legend;
  final List<ZoneCount> zones;
  final int inStock;

  @override
  Widget build(BuildContext context) {
    final totalMachines = hospitals.fold<int>(0, (a, h) => a + h.machineCount);
    final operational = hospitals.fold<int>(0, (a, h) => a + h.machinesOperational);
    final uptimePct = totalMachines == 0 ? 0.0 : operational / totalMachines * 100;

    return AppCard(
      header: Row(children: [
        Icon(Symbols.donut_small, size: 14, color: AppColors.teal),
        const SizedBox(width: 8),
        Text('Fleet Summary', style: AppTheme.cardTitle),
      ]),
      child: LayoutBuilder(builder: (ctx, cst) {
        if (cst.maxWidth < 760) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _regionBreakdown(context),
            const SizedBox(height: 16),
            _statusLegend(context),
            const SizedBox(height: 16),
            _statsRow(uptimePct),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: _regionBreakdown(context)),
          const SizedBox(width: 20),
          Expanded(flex: 3, child: _statusLegend(context)),
          const SizedBox(width: 20),
          Expanded(flex: 4, child: _statsRow(uptimePct)),
        ]);
      }),
    );
  }

  Widget _regionBreakdown(BuildContext context) {
    final maxCount = zones.isEmpty ? 1 : zones.first.count.clamp(1, 1 << 30);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('REGION BREAKDOWN', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 10),
      if (zones.isEmpty)
        Text('No regions on record.', style: AppTheme.bodySub.copyWith(fontSize: 12, color: context.pal.textMute))
      else
        ...zones.map((z) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(z.name, style: AppTheme.bodySub.copyWith(fontSize: 11.5), overflow: TextOverflow.ellipsis)),
            SizedBox(
              width: 60, height: 4,
              child: LinearProgressIndicator(
                value: z.count / maxCount, backgroundColor: context.pal.border,
                valueColor: AlwaysStoppedAnimation(AppColors.teal), borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 24, child: Text('${z.count}', style: AppTheme.monoXs.copyWith(fontSize: 11), textAlign: TextAlign.right)),
          ]),
        )),
    ]);
  }

  Widget _statusLegend(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('STATUS', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 10),
    _legendRow(context, 'Operational', AppColors.teal, legend['operational'] ?? 0),
    _legendRow(context, 'Needs Service', AppColors.amber, legend['needs_service'] ?? 0),
    _legendRow(context, 'Down', AppColors.coral, legend['down'] ?? 0),
    _legendRow(context, 'Technician En Route', AppColors.cyan, legend['technician_en_route'] ?? 0),
  ]);

  Widget _legendRow(BuildContext context, String label, Color color, int count) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 11.5))),
      Text('$count', style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: context.pal.text)),
    ]),
  );

  // Plain Column/Row instead of GridView.count — a GridView (even
  // shrinkWrap:true) builds on a lazy Viewport internally, which can't
  // report intrinsic dimensions; harmless on its own, but fatal the
  // moment an ancestor (or a future one) needs this subtree's intrinsic
  // height. Four fixed tiles don't need a scrolling-grid widget anyway.
  Widget _statsRow(double uptimePct) => Column(children: [
    Row(children: [
      Expanded(child: _statTile('Hospitals', '${hospitals.length}', AppColors.teal)),
      const SizedBox(width: 10),
      Expanded(child: _statTile('Machines', '${hospitals.fold<int>(0, (a, h) => a + h.machineCount)}', AppColors.teal)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _statTile('Uptime', '${uptimePct.toStringAsFixed(0)}%', AppColors.teal)),
      const SizedBox(width: 10),
      // Section 13: in-stock/allocated machines are deliberately excluded
      // from the map and every other fleet count above — this is the one
      // place they're surfaced.
      Expanded(child: _statTile('In Stock', '$inStock', AppColors.amber)),
    ]),
  ]);

  Widget _statTile(String label, String value, Color color) => Builder(builder: (context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: context.pal.surface2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9)),
      const SizedBox(height: 2),
      Text(value, style: AppTheme.cardTitle.copyWith(fontSize: 18, color: color)),
    ]),
  ));
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
                    if (a.age != null) ...[
                      const SizedBox(width: 6),
                      Text(a.age!, style: AppTheme.monoXs.copyWith(color: color, fontSize: 10)),
                    ],
                    const SizedBox(width: 4),
                    Icon(Symbols.chevron_right, size: 14, color: context.pal.textDim),
                  ]),
                );
              },
            ),
    );
  }
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.length == 1 ? parts[0].substring(0, 1) : parts[0].substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class _TechnicianPanel extends StatelessWidget {
  const _TechnicianPanel({required this.techs, this.onNavigateTo});
  final List<TechnicianRosterEntry> techs;
  final void Function(String key)? onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final onRoad = techs.where((t) => t.state == 'en_route').length;
    final free = techs.where((t) => t.state == 'available').length;
    final onLeave = techs.where((t) => t.state == 'on_leave').length;
    const previewCount = 4;
    final preview = techs.take(previewCount).toList();
    final more = techs.length - preview.length;

    return AppCard(
      header: Row(children: [
        Icon(Symbols.groups, size: 15, color: AppColors.cyan),
        const SizedBox(width: 8),
        Text('Technicians', style: AppTheme.cardTitle),
      ]),
      trailing: Text('$onRoad on road · $free free · $onLeave leave',
          style: AppTheme.monoXs.copyWith(color: context.pal.textDim, fontSize: 10)),
      expandChild: true,
      padding: EdgeInsets.zero,
      child: techs.isEmpty
          ? Center(child: Text('No technicians on staff.', style: TextStyle(color: context.pal.textMute, fontSize: 12)))
          : Column(children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: preview.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.divider),
                  itemBuilder: (_, i) {
                    final t = preview[i];
                    final (label, color) = switch (t.state) {
                      'en_route' => ('en route', AppColors.cyan),
                      'on_leave' => ('on leave', context.pal.textMute),
                      _          => ('available', AppColors.teal),
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(_initialsOf(t.name),
                              style: AppTheme.monoXs.copyWith(color: const Color(0xFF08090B), fontSize: 9.5, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
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
              ),
              if (more > 0)
                GestureDetector(
                  onTap: () => onNavigateTo?.call('staff'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                      Icon(Symbols.person_search, size: 13, color: AppColors.teal),
                      const SizedBox(width: 6),
                      Text('$more more · open roster', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 11)),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

class _SalesMiniPanel extends StatelessWidget {
  const _SalesMiniPanel({required this.sales});
  final Map<String, dynamic> sales;

  @override
  Widget build(BuildContext context) {
    final kpi = (sales['kpi'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawStages = (sales['pipeline_by_stage'] as List? ?? []).cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
    // Backend groups by stage with no fixed order (Postgres GROUP BY order
    // is arbitrary) — sort into the real funnel sequence rather than
    // whatever order rows happened to come back in.
    const funnelOrder = ['lead', 'qualified', 'demo_scheduled', 'proposal_sent', 'negotiation'];
    final stages = [...rawStages]..sort((a, b) =>
        funnelOrder.indexOf(a['stage']).compareTo(funnelOrder.indexOf(b['stage'])));
    final maxVal = stages.isEmpty ? 1.0 : stages.map((s) => _numField(s['value'])).reduce((a, b) => a > b ? a : b);
    final quotesOpen = (kpi['quotes_open_value'] as num? ?? 0).toDouble();
    final collectedPct = (kpi['collected_pct'] as num? ?? 0).toInt();
    final stalled = (kpi['deals_stalled_90d'] as num? ?? 0).toInt();
    // Dropping the "TSh" prefix here specifically — at this card's actual
    // width the full "TSh 268.0M" pushed past the header and overflowed;
    // the bare figure plus the "pipeline" label next to it still reads fine.
    final pipelineValue = tshFromDouble((kpi['pipeline_value'] as num? ?? 0).toDouble()).replaceFirst('TSh ', '');
    return AppCard(
      header: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Icon(Symbols.trending_up, size: 14, color: AppColors.violet),
        const SizedBox(width: 8),
        Text('Sales', style: AppTheme.cardTitle),
        const Spacer(),
        Text(pipelineValue, style: AppTheme.monoXs.copyWith(fontSize: 12)),
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
                  SizedBox(width: 84, child: Text(_humanizeStage('${s['stage'] ?? ''}'), style: AppTheme.bodySub.copyWith(fontSize: 10.5), overflow: TextOverflow.ellipsis)),
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
        Divider(height: 16, color: context.pal.divider),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _miniStat('Quotes Open', tshFromDouble(quotesOpen)),
          _miniStat('Collected', '$collectedPct%', valueColor: AppColors.teal),
          if (stalled > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(6)),
              child: Text('$stalled deals stalled 90d+', style: AppTheme.monoXs.copyWith(color: AppColors.coral, fontSize: 9.5)),
            ),
        ]),
      ]),
    );
  }

  Widget _miniStat(String label, String value, {Color? valueColor}) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Builder(builder: (context) => Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
      const SizedBox(height: 2),
      Text(value, style: AppTheme.cardTitle.copyWith(fontSize: 16, color: valueColor)),
    ]),
  );
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
    final net = (last['net_profit'] as num? ?? 0).toDouble();
    return AppCard(
      header: Row(children: [
        Icon(Symbols.account_balance, size: 14, color: AppColors.cyan),
        const SizedBox(width: 8),
        Text('Finance', style: AppTheme.cardTitle),
      ]),
      expandChild: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _miniStat('Revenue MTD', tshFromDouble((last['revenue'] as num? ?? 0).toDouble())),
          _miniStat('Expenses', tshFromDouble((last['expenses'] as num? ?? 0).toDouble())),
          _miniStat('Net Result', tshSigned(net), valueColor: net < 0 ? AppColors.coral : null),
        ]),
        const SizedBox(height: 10),
        // Bars were hardcoded to a 34px cap regardless of how much room the
        // card actually had — LayoutBuilder lets them use the real space.
        Expanded(
          child: LayoutBuilder(builder: (ctx, cst) {
            final barMax = (cst.maxHeight - 16).clamp(8.0, double.infinity);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: months.map((m) {
                final rev = (m['revenue'] as num? ?? 0).toDouble();
                final exp = (m['expenses'] as num? ?? 0).toDouble();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(children: [
                      Expanded(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 5, height: (rev / maxVal * barMax).clamp(1, barMax), color: AppColors.cyan),
                          const SizedBox(width: 2),
                          Container(width: 5, height: (exp / maxVal * barMax).clamp(1, barMax), color: AppColors.coral),
                        ]),
                      ),
                      const SizedBox(height: 3),
                      Text('${m['label'] ?? ''}', style: AppTheme.monoXs.copyWith(fontSize: 8.5), textAlign: TextAlign.center),
                    ]),
                  ),
                );
              }).toList(),
            );
          }),
        ),
      ]),
    );
  }

  Widget _miniStat(String label, String value, {Color? valueColor}) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Builder(builder: (context) => Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
      const SizedBox(height: 2),
      Text(value, style: AppTheme.cardTitle.copyWith(fontSize: 18, color: valueColor)),
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
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
      expandChild: true,
      child: Center(
        child: Row(children: [
          _stat('${inventory['total_items'] ?? 0}', 'Items'),
          _stat('${inventory['low_stock_count'] ?? 0}', 'Low Stock', color: AppColors.amber),
          _stat('${inventory['open_purchase_orders'] ?? 0}', 'Open POs'),
        ]),
      ),
    );
  }

  Widget _stat(String value, String label, {Color? color}) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: AppTheme.cardTitle.copyWith(fontSize: 26, color: color)),
      const SizedBox(height: 3),
      Builder(builder: (context) => Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10.5))),
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
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
      expandChild: true,
      child: Center(
        child: Row(children: [
          _stat('${people['active_staff'] ?? 0}', 'Active Staff'),
          _stat('${people['on_leave_today'] ?? 0}', 'On Leave'),
          _stat('${people['pending_approvals'] ?? 0}', 'Approvals', color: AppColors.violet),
        ]),
      ),
    );
  }

  Widget _stat(String value, String label, {Color? color}) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: AppTheme.cardTitle.copyWith(fontSize: 26, color: color)),
      const SizedBox(height: 3),
      Builder(builder: (context) => Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10.5))),
    ]),
  );
}
