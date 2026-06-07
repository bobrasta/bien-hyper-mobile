import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/service_ticket.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/charts/revenue_line_chart.dart';
import '../../widgets/charts/status_donut_chart.dart';
import '../../widgets/charts/tanzania_map_widget.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/kpi_card.dart';
import '../../widgets/common/status_badge.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showNewTicket = false;

  DashboardData? _data;
  bool    _loading  = true;
  String? _error;
  String  _userName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        DashboardService.instance.load(),
        AuthService.instance.getStoredUserName(),
      ]);
      if (mounted) {
        setState(() {
          _data     = results[0] as DashboardData;
          _userName = results[1] as String? ?? '';
          _loading  = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;

    return Stack(children: [
      LayoutBuilder(builder: (ctx, cst) {
        final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                LayoutBuilder(builder: (ctx, cst) {
                  final narrow = cst.maxWidth < 560;
                  final actions = Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: narrow ? WrapAlignment.start : WrapAlignment.end,
                    children: [
                      AppButton(label: 'Export', icon: Symbols.download, variant: BtnVariant.ghost),
                      AppButton(label: 'Last 30 days', icon: Symbols.date_range, variant: BtnVariant.ghost),
                      AppButton(
                        label: 'New Service Ticket',
                        icon: Symbols.add,
                        variant: BtnVariant.primary,
                        onPressed: () => setState(() => _showNewTicket = true),
                      ),
                    ],
                  );
                  final now   = DateTime.now();
                  final days  = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
                  final mons  = ['January','February','March','April','May','June',
                                  'July','August','September','October','November','December'];
                  final dateStr = '${days[now.weekday - 1]}, ${mons[now.month - 1]} ${now.day}';

                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Breadcrumb(),
                      const SizedBox(height: 4),
                      Text(
                        _userName.isNotEmpty
                            ? '${_greeting()}, ${_userName.split(' ').first}'
                            : _greeting(),
                        style: AppTheme.pageTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Here's what's happening across your fleet today · $dateStr",
                        style: AppTheme.bodySub,
                      ),
                    ],
                  );
                  if (narrow) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      titleBlock, const SizedBox(height: 12), actions,
                    ]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    titleBlock, const Spacer(), actions,
                  ]);
                }),

                const SizedBox(height: 24),

                // Error banner
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ErrorView(message: _error!, onRetry: _load, compact: true),
                  ),

                // KPI row
                if (_loading)
                  const _KpiSkeleton()
                else if (d != null)
                  AdaptiveColumns(
                    wideCols: 4, mediumCols: 2, narrowCols: 2,
                    children: [
                      KpiCard(
                        label: 'Total Machines Installed',
                        icon: Symbols.precision_manufacturing,
                        value: '${d.totalMachines}',
                        deltaValue: '+${d.totalMachines}',
                        deltaUp: true,
                        deltaNote: 'total registered',
                        sparkValues: const [12,18,16,22,20,28,32,30,38,42,40,46],
                      ),
                      KpiCard(
                        label: 'Active / Operational',
                        icon: Symbols.check_circle,
                        value: '${d.operational}',
                        unit: '/ ${d.totalMachines}',
                        deltaValue: '${(d.uptimePct * 100).toStringAsFixed(1)}%',
                        deltaUp: d.uptimePct >= 0.9,
                        deltaNote: 'uptime',
                        sparkValues: const [85,88,84,90,89,92,91,94,93,92,92,92.3],
                      ),
                      KpiCard(
                        label: 'Pending Service',
                        icon: Symbols.build,
                        value: '${d.openTickets}',
                        deltaValue: d.overdueTickets > 0 ? '${d.overdueTickets} overdue' : 'On track',
                        deltaUp: d.overdueTickets == 0,
                        deltaNote: d.overdueTickets > 0 ? 'need attention' : 'no overdue',
                        sparkValues: const [8,12,18,22,20,28,32,30,27,25,23,23],
                        accent: KpiAccent.amber,
                      ),
                      KpiCard(
                        label: 'Revenue This Month',
                        icon: Symbols.payments,
                        value: 'TSh ${(d.revenueThisMonth / 1e6).toStringAsFixed(1)}M',
                        deltaValue: d.revenueGrowth >= 0
                            ? '+${d.revenueGrowth.toStringAsFixed(1)}%'
                            : '${d.revenueGrowth.toStringAsFixed(1)}%',
                        deltaUp: d.revenueGrowth >= 0,
                        deltaNote: 'vs last month',
                        sparkValues: const [180,200,220,240,255,275,290,300,310,308,312,312],
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Map + Hospital ranking
                ResponsiveRow(
                  minChildWidth: 300,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: context.pal.surface1,
                        borderRadius: BorderRadius.circular(AppColors.rLg),
                        border: Border.all(color: context.pal.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _CardHeaderRow(
                          icon: Symbols.public,
                          title: 'Fleet Deployment · Tanzania',
                          trailing: Wrap(spacing: 14, children: [
                            _LegendDot(color: AppColors.teal,  label: 'Operational'),
                            _LegendDot(color: AppColors.amber, label: 'Service'),
                            _LegendDot(color: AppColors.coral, label: 'Down'),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: TanzaniaMapWidget(
                            totalMachines:  d?.totalMachines,
                            totalHospitals: d?.totalHospitals,
                          ),
                        ),
                      ]),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: context.pal.surface1,
                        borderRadius: BorderRadius.circular(AppColors.rLg),
                        border: Border.all(color: context.pal.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _CardHeaderRow(
                          icon: Symbols.local_hospital,
                          title: 'Top Hospitals by Machine Count',
                          trailingText: d != null ? '${d.totalHospitals} TOTAL' : '—',
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: _HospitalRanking(
                            data: d?.topHospitals ?? const [],
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Revenue chart + Status donut
                ResponsiveRow(
                  minChildWidth: 280,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.pal.surface1,
                        borderRadius: BorderRadius.circular(AppColors.rLg),
                        border: Border.all(color: context.pal.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _CardHeaderRow(
                          icon: Symbols.show_chart,
                          title: 'Monthly Revenue Trend',
                          trailing: Wrap(spacing: 6, children: [
                            _PeriodChip('6M'),
                            _PeriodChip('12M', active: true),
                            _PeriodChip('YTD'),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        RevenueLineChart(
                          actual: d?.revenueActual ?? const [],
                          target: d?.revenueTarget ?? const [],
                          months: d?.revenueMonths ?? const [],
                        ),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.pal.surface1,
                        borderRadius: BorderRadius.circular(AppColors.rLg),
                        border: Border.all(color: context.pal.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _CardHeaderRow(
                          icon: Symbols.donut_large,
                          title: 'Machine Status Breakdown',
                          trailingText: d != null ? '${d.totalMachines} TOTAL' : '—',
                        ),
                        const SizedBox(height: 8),
                        StatusDonutChart(
                          breakdown: d?.statusBreakdown,
                          total: d?.totalMachines,
                        ),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Recent tickets
                Container(
                  decoration: BoxDecoration(
                    color: context.pal.surface1,
                    borderRadius: BorderRadius.circular(AppColors.rLg),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LayoutBuilder(builder: (ctx, cst) {
                      final narrow = cst.maxWidth < 520;
                      final actions = Row(mainAxisSize: MainAxisSize.min, children: [
                        AppButton(
                          label: 'New Ticket',
                          icon: Symbols.add,
                          variant: BtnVariant.primary,
                          small: true,
                          onPressed: () => setState(() => _showNewTicket = true),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: d != null ? 'View all ${d.openTickets}' : 'View all',
                          icon: Symbols.arrow_forward,
                          variant: BtnVariant.ghost,
                          small: true,
                        ),
                      ]);
                      if (narrow) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Recent Service Tickets', style: AppTheme.cardTitle),
                            const SizedBox(height: 10),
                            actions,
                          ]),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 16, 12),
                        child: Row(children: [
                          Expanded(child: Text('Recent Service Tickets', style: AppTheme.cardTitle)),
                          actions,
                        ]),
                      );
                    }),
                    _TicketsTable(data: d?.recentTickets ?? const []),
                  ]),
                ),
              ],
            ),
          ),
        );
      }),

      if (_showNewTicket)
        _NewTicketDialog(
          onClose: () => setState(() => _showNewTicket = false),
          onSaved: () { setState(() => _showNewTicket = false); _load(); },
        ),
    ]);
  }
}

// ── Loading skeleton ─────────────────────────────────────────────────────────

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();
  @override
  Widget build(BuildContext context) => AdaptiveColumns(
    wideCols: 4, mediumCols: 2, narrowCols: 2,
    children: List.generate(4, (_) => Container(
      height: 90,
      decoration: BoxDecoration(
        color: context.pal.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.pal.border),
      ),
    )),
  );
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    const SizedBox(width: 6),
    Text('Workspace', style: AppTheme.monoXs),
    const SizedBox(width: 6),
    const SizedBox(width: 6),
    Text('Dashboard', style: AppTheme.monoXs.copyWith(color: context.pal.text)),
  ]);
}

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({
    required this.icon,
    required this.title,
    this.trailing,
    this.trailingText,
  });
  final IconData icon;
  final String title;
  final Widget? trailing;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final narrow = cst.maxWidth < 520;
      final hasExtra = trailing != null || trailingText != null;

      final titleRow = Row(children: [
        Icon(icon, size: 16, color: context.pal.textMute),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppTheme.cardTitle)),
        if (!narrow) ...[
          if (trailingText != null) Text(trailingText!, style: AppTheme.monoXs),
          ?trailing,
        ],
      ]);

      if (narrow && hasExtra) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            titleRow,
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: trailingText != null
                  ? Text(trailingText!, style: AppTheme.monoXs)
                  : trailing!,
            ),
          ]),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
        child: titleRow,
      );
    });
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 6),
    Text(label, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
  ]);
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip(this.label, {this.active = false});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: active ? context.pal.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? AppColors.teal : context.pal.border),
    ),
    child: Text(label, style: AppTheme.bodySm.copyWith(
      color: active ? context.pal.text : context.pal.textMute, fontSize: 12.5,
    )),
  );
}

// ── Hospital ranking ─────────────────────────────────────────────────────────

class _HospitalRanking extends StatelessWidget {
  const _HospitalRanking({required this.data});
  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No data', style: TextStyle(color: context.pal.textDim))),
      );
    }
    final maxCount = data
        .map((h) => (h['machine_count'] as num? ?? h['count'] as num? ?? 1).toInt())
        .fold(1, (a, b) => b > a ? b : a);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      separatorBuilder: (_, _) => Divider(color: context.pal.divider, height: 1),
      itemBuilder: (context, i) {
        final h = data[i];
        final name    = h['name']         as String? ?? '—';
        final city    = h['region']       as String?
            ?? h['city']         as String? ?? '—';
        final count   = (h['machine_count'] as num?
            ?? h['count']        as num? ?? 0).toInt();
        final rev     = (h['revenue_monthly'] as num?
            ?? h['rev']          as num? ?? 0).toDouble();
        final pct     = count / maxCount;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 20,
              child: Text(
                (i + 1).toString().padLeft(2, '0'),
                style: AppTheme.monoXs,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: context.pal.surface3,
                    valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                    minHeight: 4,
                  ),
                )),
                const SizedBox(width: 8),
                Text(city, style: AppTheme.monoXs.copyWith(fontSize: 10)),
              ]),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$count',
                style: AppTheme.bodyStrong.copyWith(
                  fontSize: 13,
                  fontFeatures: [const FontFeature.tabularFigures()],
                )),
              Text(rev >= 1e6
                  ? 'TSh ${(rev / 1e6).toStringAsFixed(1)}M'
                  : 'TSh ${(rev / 1000).toStringAsFixed(0)}K',
                style: AppTheme.monoXs.copyWith(fontSize: 10)),
            ]),
          ]),
        );
      },
    );
  }
}

// ── Tickets table ─────────────────────────────────────────────────────────────

class _TicketsTable extends StatelessWidget {
  const _TicketsTable({required this.data});
  final List<Map<String, dynamic>> data;

  AvatarVariant _variant(int i) =>
      [AvatarVariant.teal, AvatarVariant.amber, AvatarVariant.blue][i % 3];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No recent tickets',
            style: TextStyle(color: context.pal.textDim))),
      );
    }

    // Map raw API data to display fields — handles both nested and flat structures
    ServiceTicket toTicket(Map<String, dynamic> raw) => ServiceTicket(
      dbId:               (raw['id'] as num? ?? 0).toInt(),
      id:                 raw['ticket_number'] as String? ?? '#—',
      machineName:        raw['machine_name']  as String? ?? '—',
      machineType:        raw['machine_type']  as String? ?? '—',
      hospital:           raw['hospital'] is Map
          ? (raw['hospital'] as Map)['name'] as String? ?? '—'
          : raw['hospital'] as String? ?? '—',
      ward:               raw['ward']          as String? ?? '—',
      technicianInitials: raw['technician_initials'] as String? ?? '?',
      technicianName:     raw['technician_name']     as String? ?? '—',
      status:             _parseStatus(raw['status'] as String? ?? 'open'),
      createdAt:          raw['created_at'] as String? ?? '—',
    );

    final tickets = data.map(toTicket).toList();

    return LayoutBuilder(builder: (ctx, cst) {
      if (cst.maxWidth < 640) {
        return Column(children: List.generate(tickets.length, (i) {
          final t = tickets[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: i < tickets.length - 1
                  ? Border(bottom: BorderSide(color: context.pal.divider))
                  : null,
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(t.id, style: AppTheme.monoXs.copyWith(
                      color: AppColors.teal, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  StatusBadge.ticket(t.status),
                ]),
                const SizedBox(height: 4),
                Text(t.machineName,
                    style: AppTheme.bodyStrong.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${t.hospital} · ${t.ward}',
                    style: AppTheme.bodySub.copyWith(fontSize: 11.5),
                    overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                AvatarWidget(initials: t.technicianInitials, size: 26, variant: _variant(i)),
                const SizedBox(height: 4),
                Text(t.createdAt,
                    style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: context.pal.textDim)),
              ]),
            ]),
          );
        }));
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: cst.maxWidth),
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(72),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1.5),
              4: FixedColumnWidth(130),
              5: FixedColumnWidth(90),
              6: FixedColumnWidth(60),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: context.pal.border))),
                children: ['Ticket','Machine','Hospital','Technician','Status','Created','']
                    .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(h.toUpperCase(),
                          style: AppTheme.monoXs.copyWith(
                              fontSize: 10.5, fontWeight: FontWeight.w500, letterSpacing: 0.10)),
                    )).toList(),
              ),
              ...List.generate(tickets.length, (i) {
                final t = tickets[i];
                return TableRow(
                  decoration: i < tickets.length - 1
                      ? BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider)))
                      : null,
                  children: [
                    _Cell(child: Text(t.id,
                        style: AppTheme.monoXs.copyWith(color: context.pal.textMute))),
                    _Cell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.machineName, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                      Text(t.machineType, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                    ])),
                    _Cell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.hospital, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                      Text(t.ward,     style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                    ])),
                    _Cell(child: Row(children: [
                      AvatarWidget(initials: t.technicianInitials, size: 22, variant: _variant(i)),
                      const SizedBox(width: 8),
                      Flexible(child: Text(t.technicianName, style: AppTheme.bodySm)),
                    ])),
                    _Cell(child: StatusBadge.ticket(t.status)),
                    _Cell(child: Text(t.createdAt, style: AppTheme.bodySub)),
                    const _Cell(child: SizedBox()),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    });
  }
}

TicketStatus _parseStatus(String s) => switch (s) {
  'in_progress' => TicketStatus.inProgress,
  'resolved'    => TicketStatus.resolved,
  'overdue'     => TicketStatus.overdue,
  _             => TicketStatus.open,
};

class _Cell extends StatelessWidget {
  const _Cell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: child,
  );
}

// ── New Service Ticket Dialog ─────────────────────────────────────────────────

class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog({required this.onClose, this.onSaved});
  final VoidCallback  onClose;
  final VoidCallback? onSaved;

  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  String _machine  = 'Mindray SV300 · VEN-MNH-001';
  String _type     = 'Corrective';
  String _priority = 'Medium';
  String _tech     = 'Asha Komba';
  final _descCtrl  = TextEditingController();
  bool   _saving   = false;

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await TicketService.instance.create({
        'machine_name': _machine,
        'type':         _type,
        'priority':     _priority.toLowerCase(),
        'description':  _descCtrl.text.trim(),
        'status':       'open',
      });
      widget.onSaved?.call();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 520,
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                const Icon(Symbols.confirmation_number, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('New Service Ticket', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _TField('Machine', _machine, const [
                  'Mindray SV300 · VEN-MNH-001',
                  'Siemens MOBILETT · XRY-MNH-001',
                  'GE Signa 1.5T · MRI-AKH-001',
                  'Hamilton C6 · VEN-KCM-001',
                ], (v) => setState(() => _machine = v)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _TField('Type', _type, const [
                    'Corrective', 'PM', 'Inspection', 'Installation', 'Warranty Claim',
                  ], (v) => setState(() => _type = v))),
                  const SizedBox(width: 14),
                  Expanded(child: _TField('Priority', _priority, const [
                    'Critical', 'High', 'Medium', 'Low',
                  ], (v) => setState(() => _priority = v))),
                ]),
                const SizedBox(height: 14),
                _TField('Assign To', _tech, const [
                  'Asha Komba', 'Elias Mtui', 'Neema Kileo', 'Peter Rwakatare',
                ], (v) => setState(() => _tech = v)),
                const SizedBox(height: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DESCRIPTION', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: context.pal.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.pal.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: _descCtrl,
                      maxLines: null, expands: true,
                      style: AppTheme.bodySm,
                      decoration: InputDecoration(
                        hintText: 'Describe the fault or required work…',
                        hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: context.pal.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: _save,
                  child: Container(height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Ticket', style: AppTheme.bodyStrong.copyWith(
                          color: const Color(0xFF06120F), fontSize: 13)))),
                )),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _TField extends StatelessWidget {
  const _TField(this.label, this.value, this.items, this.onChanged);
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      height: 38,
      decoration: BoxDecoration(
        color: context.pal.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.pal.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        isExpanded: true,
        dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);
}
