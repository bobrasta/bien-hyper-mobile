import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/service_ticket.dart';
import '../../services/machine_service.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/app_button.dart';

import '../../theme/app_palette.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.onNavigateTo});
  final void Function(String key)? onNavigateTo;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _totalMachines    = 0;
  int _openTickets      = 0;
  int _resolvedTickets  = 0;
  int _overdueTickets   = 0;
  bool _loadingKpis = true;

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  Future<void> _loadKpis() async {
    try {
      // Fire both requests concurrently, then await both results
      final machinesFuture = MachineService.instance.list();
      final ticketsFuture  = TicketService.instance.list();
      final machines = await machinesFuture;
      final tickets  = await ticketsFuture;
      if (!mounted) return;
      setState(() {
        _totalMachines   = machines.length;
        _openTickets     = tickets.where((t) =>
            t.status == TicketStatus.open || t.status == TicketStatus.inProgress).length;
        _resolvedTickets = tickets.where((t) => t.status == TicketStatus.resolved).length;
        _overdueTickets  = tickets.where((t) => t.status == TicketStatus.overdue).length;
        _loadingKpis = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingKpis = false);
    }
  }

  static const _categories = [
    {'icon': Symbols.push_pin,   'label': 'Pinned',      'count': '5',  'active': true},
    {'icon': Symbols.history,    'label': 'Recent',      'count': '12', 'active': false},
    {'icon': Symbols.group,      'label': 'Shared',      'count': '8',  'active': false},
    {'icon': Symbols.bar_chart,  'label': 'Operations',  'count': '28', 'active': false},
    {'icon': Symbols.payments,   'label': 'Revenue',     'count': '14', 'active': false},
    {'icon': Symbols.build,      'label': 'Maintenance', 'count': '19', 'active': false},
    {'icon': Symbols.trending_up,'label': 'Sales',       'count': '11', 'active': false},
    {'icon': Symbols.inventory,  'label': 'Inventory',   'count': '9',  'active': false},
    {'icon': Symbols.assessment, 'label': 'Compliance',  'count': '7',  'active': false},
  ];

  static const _pinnedReports = [
    {'title': 'Fleet Health Overview',  'desc': 'Operational status across all machines',            'type': 'line',  'updated': 'Today',      'owner': 'JM', 'route': 'machines'},
    {'title': 'Monthly Revenue Report', 'desc': 'Revenue collected vs outstanding across hospitals',  'type': 'bar',   'updated': '2 days ago', 'owner': 'FM', 'route': 'revenue'},
    {'title': 'Service Ticket Summary', 'desc': 'Open / resolved / overdue tickets this month',      'type': 'donut', 'updated': '5 days ago', 'owner': 'AK', 'route': 'service'},
  ];

  static const _tableReports = [
    {'name': 'Machine Uptime — June 2025',    'category': 'Operations', 'schedule': 'Weekly',   'next': 'Mon 06:00', 'owner': 'JM', 'views': 142, 'draft': false, 'route': 'machines'},
    {'name': 'Hospital Compliance Audit',     'category': 'Compliance', 'schedule': 'Monthly',  'next': 'Jul 1',     'owner': 'FM', 'views': 38,  'draft': false, 'route': 'hospitals'},
    {'name': 'Q2 Revenue Reconciliation',     'category': 'Revenue',    'schedule': 'Quarterly','next': 'Sep 1',     'owner': 'FM', 'views': 24,  'draft': false, 'route': 'revenue'},
    {'name': 'Parts Inventory Status',        'category': 'Inventory',  'schedule': 'Daily',    'next': 'Tomorrow',  'owner': 'NK', 'views': 87,  'draft': false, 'route': 'inventory'},
    {'name': 'Technician Performance Review', 'category': 'Operations', 'schedule': 'Monthly',  'next': 'Jul 1',     'owner': 'JM', 'views': 19,  'draft': false, 'route': 'staff'},
    {'name': 'Warranty Expiry Forecast',      'category': 'Maintenance','schedule': 'Monthly',  'next': 'Jul 1',     'owner': 'PR', 'views': 45,  'draft': false, 'route': 'machines'},
    {'name': 'Sales Pipeline Analysis',       'category': 'Sales',      'schedule': 'Weekly',   'next': 'Mon 06:00', 'owner': 'EM', 'views': 31,  'draft': false, 'route': 'sales'},
    {'name': 'New Machine Integration Draft', 'category': 'Operations', 'schedule': '—',        'next': '—',         'owner': 'JM', 'views': 3,   'draft': true,  'route': 'machines'},
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final narrow = cst.maxWidth < 720;
      final pad    = narrow ? 16.0 : 24.0;

      final mainContent = SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title only shown on narrow (sidebar shows it on wide)
            if (narrow) ...[
              Text('Reports', style: AppTheme.pageTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text('$_totalMachines machines · ${_openTickets + _resolvedTickets + _overdueTickets} tickets', style: AppTheme.bodySub),
              const SizedBox(height: 16),
            ],

            // KPI row — 2-per-row on narrow/medium, 4-across on wide
            AdaptiveColumns(
              wideCols: 4, mediumCols: 2, narrowCols: 2,
              spacing: 12, runSpacing: 12,
              children: [
                _ReportKpi(label: 'Total Machines',  value: _loadingKpis ? '…' : '$_totalMachines', icon: Symbols.medical_services),
                _ReportKpi(label: 'Open Tickets',    value: _loadingKpis ? '…' : '$_openTickets',   icon: Symbols.confirmation_number, color: AppColors.teal),
                _ReportKpi(label: 'Resolved',        value: _loadingKpis ? '…' : '$_resolvedTickets', icon: Symbols.check_circle, color: AppColors.blue),
                _ReportKpi(label: 'Overdue',         value: _loadingKpis ? '…' : '$_overdueTickets', icon: Symbols.pending, color: _overdueTickets > 0 ? AppColors.coral : AppColors.amber),
              ],
            ),
            const SizedBox(height: 20),

            // Pinned reports — 1-col narrow, 2-col medium, 3-col wide
            Text('Pinned Reports', style: AppTheme.cardTitle),
            const SizedBox(height: 12),
            AdaptiveColumns(
              wideCols: 3, mediumCols: 2, narrowCols: 1,
              spacing: 12, runSpacing: 12,
              children: _pinnedReports.map((r) {
                final route = r['route']?.toString();
                return MouseRegion(
                  cursor: route != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  child: GestureDetector(
                    onTap: route != null ? () => widget.onNavigateTo?.call(route) : null,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.pal.surface1,
                        borderRadius: BorderRadius.circular(AppColors.rLg),
                        border: Border.all(color: context.pal.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(_typeIcon(r['type'] as String), size: 16, color: AppColors.teal),
                          const Spacer(),
                          if (route != null)
                            Icon(Symbols.arrow_forward, size: 13, color: context.pal.textDim),
                        ]),
                        const SizedBox(height: 10),
                        Text(r['title'] as String, style: AppTheme.bodyStrong),
                        const SizedBox(height: 4),
                        Text(r['desc'] as String,
                          style: AppTheme.bodySub.copyWith(fontSize: 11.5), maxLines: 2),
                        const SizedBox(height: 12),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.pal.surface2,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('[${r['type']} chart]', style: AppTheme.monoXs),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.tealSoft, shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(r['owner'] as String,
                              style: AppTheme.monoXs.copyWith(color: AppColors.teal, fontSize: 8)),
                          ),
                          const SizedBox(width: 6),
                          Text('Updated ${r['updated']}',
                            style: AppTheme.bodySub.copyWith(fontSize: 11)),
                          const Spacer(),
                        ]),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // All Reports card
            Container(
              decoration: BoxDecoration(
                color: context.pal.surface1,
                borderRadius: BorderRadius.circular(AppColors.rLg),
                border: Border.all(color: context.pal.border),
              ),
              child: Column(children: [
                // Card header — stack on narrow
                LayoutBuilder(builder: (ctx2, cst2) {
                  if (cst2.maxWidth < 520) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const SizedBox(width: 8),
                            Text('All Reports', style: AppTheme.cardTitle),
                          ]),
                          const SizedBox(height: 8),
                          AppButton(
                            label: 'New Report', icon: Symbols.add,
                            variant: BtnVariant.primary, small: true,
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    child: Row(children: [
                      const SizedBox(width: 8),
                      Text('All Reports', style: AppTheme.cardTitle),
                      const Spacer(),
                      AppButton(
                        label: 'New Report', icon: Symbols.add,
                        variant: BtnVariant.primary, small: true,
                      ),
                    ]),
                  );
                }),

                // Table — horizontally scrollable on narrow
                HScrollTable(
                  minWidth: 700,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                      4: FixedColumnWidth(48),
                      5: FixedColumnWidth(60),
                      6: FixedColumnWidth(60),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: context.pal.border))),
                        children: [
                          'Report Name', 'Category', 'Schedule', 'Next Run',
                          'Owner', 'Views', '',
                        ].map((h) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(h.toUpperCase(),
                            style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
                        )).toList(),
                      ),
                      ..._tableReports.map((r) {
                        final rowRoute = r['route']?.toString();
                        void navigate() { if (rowRoute != null) widget.onNavigateTo?.call(rowRoute); }
                        return TableRow(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: context.pal.divider))),
                          children: [
                            _TClickCell(onTap: navigate, child: Row(children: [
                              Flexible(child: Text(r['name'] as String, style: AppTheme.bodySm,
                                  maxLines: 2, overflow: TextOverflow.ellipsis)),
                              if (r['draft'] == true) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.amberSoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Draft', style: AppTheme.bodySub.copyWith(
                                    color: AppColors.amber, fontSize: 10,
                                  )),
                                ),
                              ],
                            ])),
                            _TClickCell(onTap: navigate, child: Text(r['category'] as String, style: AppTheme.bodySub)),
                            _TClickCell(onTap: navigate, child: Text(r['schedule'] as String, style: AppTheme.monoXs)),
                            _TClickCell(onTap: navigate, child: Text(r['next'] as String, style: AppTheme.monoXs)),
                            _TClickCell(onTap: navigate, child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.tealSoft, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(r['owner'] as String,
                                style: AppTheme.monoXs.copyWith(
                                  color: AppColors.teal, fontSize: 8)),
                            )),
                            _TClickCell(onTap: navigate, child: Text('${r['views']}', style: AppTheme.monoXs)),
                            _TClickCell(onTap: navigate, child: Icon(Symbols.arrow_forward, size: 14, color: context.pal.textDim)),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      );

      // Narrow: just main content (no sidebar)
      if (narrow) return mainContent;

      // Wide: sidebar + main
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 220,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.pal.border)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reports', style: AppTheme.pageTitle.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text('$_totalMachines machines', style: AppTheme.bodySub),
                const SizedBox(height: 16),
                ..._categories.map((c) => _CategoryItem(
                  icon: c['icon'] as IconData,
                  label: c['label'] as String,
                  count: c['count'] as String,
                  active: c['active'] as bool,
                )),
              ],
            ),
          ),
          Expanded(child: mainContent),
        ],
      );
    });
  }

  IconData _typeIcon(String type) => switch (type) {
    'bar'   => Symbols.bar_chart,
    'donut' => Symbols.donut_large,
    _       => Symbols.show_chart,
  };
}

// ─── Helper widgets ────────────────────────────────────────────────────────────

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.icon, required this.label,
    required this.count, required this.active,
  });
  final IconData icon; final String label, count; final bool active;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 2),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: active ? context.pal.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: active ? context.pal.text : context.pal.textMute),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: AppTheme.bodySm.copyWith(
        color: active ? context.pal.text : context.pal.textMute, fontSize: 13,
      ))),
      Text(count, style: AppTheme.bodySub.copyWith(fontSize: 11)),
    ]),
  );
}

class _ReportKpi extends StatelessWidget {
  const _ReportKpi({required this.label, required this.value, required this.icon, this.color});
  final String label, value; final IconData icon; final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: context.pal.border),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: color ?? context.pal.textDim),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppTheme.kpiValue.copyWith(
            fontSize: 22, color: color ?? context.pal.text)),
          Text(label.toUpperCase(), style: AppTheme.labelCaps),
        ]),
      ]),
    );
  }
}

class _TClickCell extends StatelessWidget {
  const _TClickCell({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: child,
      ),
    ),
  );
}
