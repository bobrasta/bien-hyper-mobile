// lib/screens/dashboard/cto_dashboard_screen.dart — CTO dashboard (design 2a / 2b).
// ≥ 1100 px: desktop layout — KPI row, map + approvals desk, trip calendar /
// SLA / spares. Narrower: mobile home — KPIs, approval cards (inline
// approve/return), SLA watch, on-the-road; detail (2c) and team calendar
// (2d) push as routes.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../data/cto_sample_data.dart';
import '../../models/cto_approval.dart';
import '../../models/cto_overview.dart';
import '../../models/hospital.dart';
import '../../screens/approvals/per_diem_revise_dialog.dart';
import '../../services/cto_dashboard_service.dart';
import '../../services/hospital_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/charts/tanzania_map_widget.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/kpi_card.dart';
import '../../widgets/dashboard/cto_widgets.dart';
import 'cto_approval_detail_screen.dart';
import 'cto_team_calendar_screen.dart';

class CtoDashboardScreen extends StatefulWidget {
  const CtoDashboardScreen({super.key, this.onNavigateTo, this.useSampleData = false});
  final void Function(String key)? onNavigateTo;
  final bool useSampleData;

  @override
  State<CtoDashboardScreen> createState() => _CtoDashboardScreenState();
}

enum _Tab { all, trips, expenses, stock }

class _CtoDashboardScreenState extends State<CtoDashboardScreen> {
  CtoOverview? _o;
  List<CtoApproval> _approvals = const [];
  List<Hospital> _hospitals = const [];
  String? _error;

  // Local decisions — the row stays visible (dimmed) until the next refresh
  // so the CTO sees what he just did; the API call has already happened.
  final Map<String, CtoDecision> _decided = {};
  final Set<String> _busy = {};
  String? _selKey;
  _Tab _tab = _Tab.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    if (widget.useSampleData) {
      setState(() { _o = CtoSampleData.overview(); _approvals = CtoSampleData.approvals(); _decided.clear(); });
      return;
    }
    try {
      final r = await Future.wait([
        CtoDashboardService.instance.loadOverview(),
        CtoDashboardService.instance.loadApprovals(),
        HospitalService.instance.list(hasMachines: true),
      ]);
      if (!mounted) return;
      setState(() {
        _o = r[0] as CtoOverview;
        _approvals = r[1] as List<CtoApproval>;
        _hospitals = r[2] as List<Hospital>;
        _decided.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  // ── Actions ──────────────────────────────────────────────
  Future<void> _approve(CtoApproval a) async {
    setState(() => _busy.add(a.key));
    try {
      if (!widget.useSampleData) await CtoDashboardService.instance.approve(a);
      if (!mounted) return;
      setState(() => _decided[a.key] = CtoDecision.approved);
      showSuccessToast(context, a.kind == CtoApprovalKind.trip ? 'Trip and per diem approved — sent to Finance.' : '${a.nextAfterApprove}.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(a.key));
    }
  }

  Future<void> _return(CtoApproval a) async {
    final reason = await showCtoReturnDialog(context, a);
    if (reason == null || !mounted) return;
    setState(() => _busy.add(a.key));
    try {
      if (!widget.useSampleData) await CtoDashboardService.instance.returnItem(a, reason);
      if (!mounted) return;
      setState(() => _decided[a.key] = CtoDecision.returned);
      showSuccessToast(context, 'Returned to ${a.requester}.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(a.key));
    }
  }

  Future<void> _editDays(CtoApproval a) async {
    if (a.perDiem == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => PerDiemReviseDialog(
        request: a.perDiem!,
        onClose: () => Navigator.pop(ctx),
        onSaved: () { Navigator.pop(ctx); _load(); },
      ),
    );
  }

  Future<void> _technicianEdit(CtoApproval a, bool accept) async {
    try {
      await CtoDashboardService.instance.decideTechnicianEdit(a, accept: accept);
      if (mounted) { showSuccessToast(context, accept ? 'Edit applied.' : 'Edit rejected.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Map<int, CtoDecision> get _tripDecisions => {
        for (final a in _approvals)
          if (a.perDiem != null && _decided[a.key] != null) a.perDiem!.id: _decided[a.key]!,
      };

  List<CtoApproval> get _pending => _approvals.where((a) => _decided[a.key] == null).toList();
  int get _pendingTotal => _pending.fold(0, (s, a) => s + (a.amount ?? 0));

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final o = _o;
    if (o == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return LayoutBuilder(builder: (ctx, cst) {
      final desktop = cst.maxWidth >= 1100;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(desktop ? 18 : 16),
          child: desktop ? _desktop(o) : _mobile(o),
        ),
      );
    });
  }

  String get _salutation {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  Widget _header(CtoOverview o, {required bool compact}) {
    final k = o.kpis;
    final sub = TextSpan(style: AppTheme.bodySub.copyWith(fontSize: compact ? 12 : 11.5), children: [
      TextSpan(text: compact ? '${formatDate(DateTime.now())} · ' : '${formatDate(DateTime.now())} · '),
      TextSpan(text: '${k.machinesDown} ${compact ? 'down' : 'machines down'}', style: TextStyle(color: AppColors.coral)),
      if (k.slaBreached > 0) ...[
        const TextSpan(text: ' · '),
        TextSpan(text: '${k.slaBreached} SLA breached', style: TextStyle(color: AppColors.coral)),
      ],
      if (!compact) TextSpan(text: ' · ${_pending.length} approvals waiting on you'),
    ]);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 2, height: compact ? 40 : 34, color: AppColors.teal),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$_salutation, ${o.name}', style: AppTheme.pageTitle.copyWith(fontSize: compact ? 19 : null)),
        const SizedBox(height: 3),
        Text.rich(sub),
      ])),
      if (!compact) IconButton(icon: const Icon(Symbols.refresh, size: 18), tooltip: 'Refresh', onPressed: _load),
    ]);
  }

  List<KpiCard> _kpiTiles(CtoOverview o, {required bool mobile}) {
    final k = o.kpis;
    final risk = k.slaBreached + k.slaAtRisk;
    final pendingTrips = _pending.where((a) => a.kind == CtoApprovalKind.trip).length;
    return [
      KpiCard(label: 'Fleet Uptime', icon: Symbols.monitor_heart, value: k.fleetUptimePct.toStringAsFixed(1), unit: '%',
          deltaValue: '${k.machinesOperational}/${k.machinesTotal}', deltaUp: true, deltaNote: 'operational now'),
      KpiCard(label: 'Machines Down', icon: Symbols.error, value: '${k.machinesDown}', accent: KpiAccent.coral,
          deltaValue: '+${k.machinesDownToday}', deltaUp: false, deltaNote: '${k.hospitalsAffected} hospitals affected'),
      KpiCard(label: 'SLA At Risk', icon: Symbols.timer, value: '$risk', unit: 'of ${k.openTickets}',
          accent: risk > 0 ? KpiAccent.amber : KpiAccent.teal,
          deltaValue: '${k.slaBreached} breached', deltaUp: k.slaBreached == 0, deltaNote: '48 h target'),
      KpiCard(label: 'Technicians Out', icon: Symbols.directions_car, value: '${k.techniciansOut}', unit: '/ ${k.techniciansTotal}',
          deltaValue: '$pendingTrips trips', deltaUp: true, deltaNote: 'awaiting you'),
      if (!mobile)
        KpiCard(label: 'Awaiting You', icon: Symbols.verified, value: '${_pending.length}', unit: 'approvals',
            deltaValue: tshShort(_pendingTotal), deltaUp: true, deltaNote: 'trips · expenses · stock'),
    ];
  }

  // ── Desktop (2a) ─────────────────────────────────────────
  Widget _desktop(CtoOverview o) {
    final tiles = _kpiTiles(o, mobile: false);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(o, compact: false),
      const SizedBox(height: 14),
      Row(children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 560,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _mapPanel(o)),
          const SizedBox(width: 12),
          SizedBox(width: 468, child: _approvalsDesk()),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 336,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 145, child: _calendarPanel(o)),
          const SizedBox(width: 12),
          Expanded(flex: 100, child: _slaPanel(o)),
          const SizedBox(width: 12),
          SizedBox(width: 268, child: _sparesPanel(o)),
        ]),
      ),
    ]);
  }

  Widget _mapPanel(CtoOverview o) {
    final pal = context.pal;
    final total = _hospitals.fold<int>(0, (a, h) => a + h.machineCount);
    final up = _hospitals.fold<int>(0, (a, h) => a + h.machinesOperational);
    return CtoPanel(
      icon: Symbols.map, iconColor: AppColors.teal, title: 'Fleet & field activity',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${o.kpis.machinesTotal} machines · ${_hospitals.length} hospitals', style: AppTheme.monoXs.copyWith(fontSize: 10, color: pal.textDim)),
        const SizedBox(width: 10),
        TextButton.icon(
          onPressed: () => widget.onNavigateTo?.call('hospitals'),
          icon: const Icon(Symbols.open_in_new, size: 13),
          label: const Text('Open map'),
          style: TextButton.styleFrom(foregroundColor: AppColors.teal, textStyle: AppTheme.bodySm, visualDensity: VisualDensity.compact),
        ),
      ]),
      child: Stack(children: [
        Positioned.fill(
          child: _hospitals.isEmpty && widget.useSampleData
              ? ColoredBox(color: pal.surface2, child: Center(child: Text('Fleet map', style: AppTheme.bodySub)))
              : FleetMapWidget(
                  hospitals: _hospitals.where((h) => h.machinesOperational < h.machineCount).toList(),
                  totalMachines: total,
                  uptimePct: total == 0 ? 0 : up / total,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(AppColors.rMd), bottomRight: Radius.circular(AppColors.rMd)),
                ),
        ),
        Positioned(left: 12, bottom: 12, child: _legend(o)),
        Positioned(right: 12, top: 12, width: 236, child: _downLongest(o)),
      ]),
    );
  }

  Widget _overlayBox({required Widget child, Color? border}) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border ?? context.pal.border),
        ),
        child: child,
      );

  Widget _legend(CtoOverview o) {
    final rows = [
      ('Operational', AppColors.teal, o.fleetLegend['operational'] ?? 0),
      ('Needs service', AppColors.amber, o.fleetLegend['needs_service'] ?? 0),
      ('Down', AppColors.coral, o.fleetLegend['down'] ?? 0),
      ('Technician en route', AppColors.cyan, o.fleetLegend['technician_en_route'] ?? 0),
    ];
    return _overlayBox(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (l, c, n) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              SizedBox(width: 118, child: Text(l, style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: context.pal.textMute))),
              Text('$n', style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: context.pal.text)),
            ]),
          ),
      ]),
    ));
  }

  Widget _downLongest(CtoOverview o) {
    final pal = context.pal;
    return _overlayBox(
      border: AppColors.coral.withValues(alpha: 0.25),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(children: [
            Icon(Symbols.report, size: 13, color: AppColors.coral, fill: 1),
            const SizedBox(width: 7),
            Text('Down longest', style: AppTheme.bodySm.copyWith(fontSize: 10.5, color: pal.text)),
            const Spacer(),
            Text('${o.kpis.machinesDown}', style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: pal.textDim)),
          ]),
        ),
        for (final d in o.downLongest.take(4))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.divider))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d.name} · ${d.hospital}', style: AppTheme.bodySm.copyWith(fontSize: 10.5, color: pal.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(d.note, style: AppTheme.bodySub.copyWith(fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Text(d.ageLabel, style: AppTheme.monoXs.copyWith(fontSize: 10, color: AppColors.coral)),
            ]),
          ),
      ]),
    );
  }

  bool _inTab(CtoApproval a) => switch (_tab) {
        _Tab.all      => true,
        _Tab.trips    => a.kind == CtoApprovalKind.trip,
        _Tab.expenses => a.kind == CtoApprovalKind.expense,
        _Tab.stock    => a.kind == CtoApprovalKind.stock,
      };

  Widget _approvalsDesk() {
    final pal = context.pal;
    final list = _approvals.where(_inTab).toList();
    final sel = list.where((a) => a.key == _selKey).firstOrNull ?? (list.isEmpty ? null : list.first);
    Widget tab(_Tab t, String label) {
      final on = _tab == t;
      final n = _pending.where((a) => switch (t) {
            _Tab.all => true,
            _Tab.trips => a.kind == CtoApprovalKind.trip,
            _Tab.expenses => a.kind == CtoApprovalKind.expense,
            _Tab.stock => a.kind == CtoApprovalKind.stock,
          }).length;
      return InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => setState(() => _tab = t),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: on ? AppColors.violetSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: on ? AppColors.violet.withValues(alpha: 0.45) : pal.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: AppTheme.bodySm.copyWith(fontSize: 11, color: on ? pal.text : pal.textMute)),
            const SizedBox(width: 6),
            Text('$n', style: AppTheme.monoXs.copyWith(fontSize: 10, color: pal.textDim)),
          ]),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rMd),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
          child: Row(children: [
            Icon(Symbols.verified, size: 16, color: AppColors.violet, fill: 1),
            const SizedBox(width: 8),
            Flexible(child: Text('Awaiting your approval', style: AppTheme.cardTitle.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text('${_pending.length} · ${tshShort(_pendingTotal)}', style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: pal.textMute)),
            const Spacer(),
            TextButton(
              onPressed: () => widget.onNavigateTo?.call('approvals'),
              style: TextButton.styleFrom(foregroundColor: AppColors.teal, textStyle: AppTheme.bodySm.copyWith(fontSize: 11), visualDensity: VisualDensity.compact),
              child: const Text('Open queue'),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
          child: Wrap(spacing: 4, children: [
            tab(_Tab.all, 'All'), tab(_Tab.trips, 'Trips'), tab(_Tab.expenses, 'Expenses'), tab(_Tab.stock, 'Stock'),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: list.isEmpty
              ? Padding(padding: const EdgeInsets.all(20), child: Text('Nothing waiting on you.', style: AppTheme.bodySub))
              : ListView(shrinkWrap: true, children: [
                  for (final a in list)
                    CtoApprovalRow(a: a, selected: a.key == sel?.key, decision: _decided[a.key], onTap: () => setState(() => _selKey = a.key)),
                ]),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: pal.surface2.withValues(alpha: 0.5), border: Border(top: BorderSide(color: pal.border))),
            child: sel == null
                ? const SizedBox.shrink()
                : CtoApprovalDetail(
                    a: sel,
                    decision: _decided[sel.key],
                    busy: _busy.contains(sel.key),
                    onApprove: () => _approve(sel),
                    onReturn: () => _return(sel),
                    onEditDays: () => _editDays(sel),
                    onTechnicianEdit: (accept) => _technicianEdit(sel, accept),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _calendarPanel(CtoOverview o) {
    final end = o.calendarStart.add(Duration(days: o.calendarDays - 1));
    return CtoPanel(
      icon: Symbols.calendar_month, iconColor: AppColors.cyan, title: 'Team on the road',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${formatDate(o.calendarStart)} – ${formatDate(end)}',
            style: AppTheme.monoXs.copyWith(fontSize: 10, color: context.pal.textDim)),
        const SizedBox(width: 14),
        const CtoCalendarLegend(),
      ]),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: CtoTripCalendar(
          team: o.team, start: o.calendarStart, days: o.calendarDays, today: DateTime.now(),
          tripDecisions: _tripDecisions, rowHeight: 31,
        ),
      ),
    );
  }

  Widget _slaPanel(CtoOverview o) => CtoPanel(
        icon: Symbols.timer, iconColor: AppColors.amber, title: 'SLA watch',
        trailing: CtoChip('${o.kpis.slaBreached} breached · ${o.kpis.slaAtRisk} at risk', color: AppColors.coral),
        child: ListView(padding: EdgeInsets.zero, children: [
          for (final t in o.tickets)
            CtoSlaRow(t: t, onTap: () => widget.onNavigateTo?.call('service'), onAssign: () => widget.onNavigateTo?.call('service')),
        ]),
      );

  Widget _sparesPanel(CtoOverview o) => CtoPanel(
        icon: Symbols.inventory_2, iconColor: AppColors.amber, title: 'Spares',
        trailing: Text('${o.kpis.lowStockCount} below reorder', style: AppTheme.monoXs.copyWith(fontSize: 10, color: AppColors.amber)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ListView(padding: EdgeInsets.zero, children: [for (final s in o.spares) CtoSpareRow(s: s)])),
          InkWell(
            onTap: () => widget.onNavigateTo?.call('inventory'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.divider))),
              child: Row(children: [
                Icon(Symbols.shopping_cart, size: 13, color: AppColors.teal),
                const SizedBox(width: 6),
                Expanded(child: Text('${o.kpis.openPurchaseOrders} POs raised · open inventory', style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: AppColors.teal), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
        ]),
      );

  // ── Mobile (2b) ──────────────────────────────────────────
  Future<void> _openDetail(CtoApproval a) async {
    var current = a;
    if (!widget.useSampleData && a.kind == CtoApprovalKind.trip) {
      try { current = await CtoDashboardService.instance.refreshTrip(a); } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CtoApprovalDetailScreen(
        approval: current,
        initialDecision: _decided[a.key],
        onApprove: () => _approve(a).then((_) => _decided[a.key]),
        onReturn: () => _return(a).then((_) => _decided[a.key]),
        onEditDays: () => _editDays(current),
      ),
    ));
    if (mounted) setState(() {});
  }

  Widget _mobile(CtoOverview o) {
    final pal = context.pal;
    final tiles = _kpiTiles(o, mobile: true);
    final onRoad = o.team.where((m) => m.state == 'en_route').toList();
    Widget section(String title, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(children: [
            Text(title, style: AppTheme.cardTitle.copyWith(fontSize: 15)),
            const SizedBox(width: 8),
            if (trailing != null) trailing,
          ]),
        );
    Widget box(List<Widget> children) => Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: pal.surface1, borderRadius: BorderRadius.circular(AppColors.rMd), border: Border.all(color: pal.border)),
          child: Column(children: children),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(o, compact: true),
      const SizedBox(height: 14),
      // Fixed tile height: an aspect ratio made the tiles ~280 px tall on
      // tablets (this layout runs up to 1100 px). Four across once there's room.
      LayoutBuilder(builder: (context, cst) => GridView(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cst.maxWidth >= 600 ? 4 : 2,
          mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: cst.maxWidth >= 600 ? 130 : 115),
        children: tiles,
      )),
      const SizedBox(height: 14),
      section('Awaiting you', trailing: Expanded(child: Row(children: [
        CtoChip('${_pending.length}', color: AppColors.violet, size: 10.5),
        const Spacer(),
        Text(tshShort(_pendingTotal), style: AppTheme.monoXs.copyWith(fontSize: 11, color: pal.textMute)),
      ]))),
      if (_approvals.isEmpty)
        Text('Nothing waiting on you.', style: AppTheme.bodySub)
      else
        for (final a in _approvals.take(4)) ...[
          CtoApprovalCard(
            a: a, decision: _decided[a.key], busy: _busy.contains(a.key),
            onOpen: () => _openDetail(a), onApprove: () => _approve(a), onReturn: () => _return(a),
          ),
          const SizedBox(height: 8),
        ],
      if (_approvals.length > 4)
        OutlinedButton(
          onPressed: () => widget.onNavigateTo?.call('approvals'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: AppColors.teal, side: BorderSide(color: pal.border)),
          child: Text('All approvals (${_approvals.length})'),
        ),
      const SizedBox(height: 14),
      section('SLA watch'),
      box([for (final t in o.tickets.take(3)) CtoSlaRow(t: t, mobile: true, onTap: () => widget.onNavigateTo?.call('service'))]),
      const SizedBox(height: 14),
      section('On the road', trailing: Expanded(child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CtoTeamCalendarScreen(overview: o, tripDecisions: _tripDecisions),
          )),
          icon: const Icon(Symbols.calendar_month, size: 15),
          label: const Text('Team calendar'),
          style: TextButton.styleFrom(foregroundColor: AppColors.teal, minimumSize: const Size(44, 44)),
        ),
      ))),
      box([
        for (final m in onRoad)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
            child: Row(children: [
              CtoInitials(m.initials, color: teamColor(m.state, context), size: 28),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m.name} · ${m.where}', style: AppTheme.bodySm.copyWith(fontSize: 12.5, color: pal.text)),
                Text(m.tripNote, style: AppTheme.bodySub.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
      ]),
      const SizedBox(height: 12),
    ]);
  }
}
