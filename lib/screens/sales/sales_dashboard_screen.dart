import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/quotation.dart';
import '../../models/sales_order.dart';
import '../../services/sales_dashboard_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/kpi_card.dart';

String _fmtAmount(int tzs) {
  if (tzs.abs() >= 1000000) return 'TSh ${(tzs / 1e6).toStringAsFixed(1)}M';
  if (tzs.abs() >= 1000)    return 'TSh ${(tzs / 1000).toStringAsFixed(0)}K';
  return 'TSh $tzs';
}

const _stageOrder = ['lead', 'qualified', 'demo_scheduled', 'proposal_sent', 'negotiation'];
Map<String, Color> get _stageColors => {
  'lead':           AppColors.textDim,
  'qualified':      AppColors.blue,
  'demo_scheduled': AppColors.violet,
  'proposal_sent':  AppColors.amber,
  'negotiation':    AppColors.coral,
};

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  SalesDashboardData? _data;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await SalesDashboardService.instance.load();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;

    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sales Dashboard', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text("This month's pipeline, quotations and closed business at a glance",
                style: AppTheme.bodySub),
            const SizedBox(height: 24),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ErrorView(message: _error!, onRetry: _load, compact: true),
              ),

            if (_loading)
              const _KpiSkeleton()
            else if (d != null)
              AdaptiveColumns(
                wideCols: 4, mediumCols: 2, narrowCols: 2,
                children: [
                  KpiCard(
                    label: 'Pipeline Value',
                    icon: Symbols.trending_up,
                    value: _fmtAmount(d.pipelineValue),
                    deltaValue: '${d.openLeads} open',
                    deltaUp: true,
                    deltaNote: 'deals in progress',
                    sparkValues: const [4, 6, 5, 7, 8, 7, 9, 10, 9, 11, 10, 12],
                  ),
                  KpiCard(
                    label: 'Won This Month',
                    icon: Symbols.emoji_events,
                    value: '${d.wonThisMonth}',
                    unit: _fmtAmount(d.wonValueThisMonth),
                    deltaValue: '${d.winRateThisMonth.toStringAsFixed(0)}%',
                    deltaUp: d.winRateThisMonth >= 50,
                    deltaNote: 'win rate',
                    sparkValues: const [1, 2, 1, 3, 2, 4, 3, 5, 4, 5, 6, 6],
                    accent: KpiAccent.teal,
                  ),
                  KpiCard(
                    label: 'Quotations Needing Action',
                    icon: Symbols.request_quote,
                    value: '${d.quotationsPendingApproval + d.quotationsAwaitingResponse}',
                    deltaValue: d.quotationsPendingApproval > 0 ? '${d.quotationsPendingApproval} pending approval' : 'None pending',
                    deltaUp: d.quotationsPendingApproval == 0,
                    deltaNote: '${d.quotationsAwaitingResponse} awaiting client',
                    sparkValues: const [3, 4, 3, 5, 4, 3, 5, 4, 6, 5, 4, 5],
                    accent: KpiAccent.amber,
                  ),
                  KpiCard(
                    label: 'Revenue This Month',
                    icon: Symbols.payments,
                    value: _fmtAmount(d.revenueThisMonth),
                    deltaValue: '${d.salesOrdersThisMonth} orders',
                    deltaUp: true,
                    deltaNote: 'this month',
                    sparkValues: const [10, 14, 12, 18, 16, 22, 20, 26, 24, 28, 27, 30],
                  ),
                ],
              ),

            const SizedBox(height: 16),

            ResponsiveRow(
              minChildWidth: 300,
              children: [
                _Card(
                  icon: Symbols.donut_large,
                  title: 'Pipeline by Stage',
                  child: _PipelineBreakdown(stages: d?.pipelineByStage ?? const []),
                ),
                _Card(
                  icon: Symbols.leaderboard,
                  title: 'Top Sales Reps',
                  trailingText: 'CONFIRMED+ ORDERS',
                  child: _TopRepsList(reps: d?.topReps ?? const []),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ResponsiveRow(
              minChildWidth: 320,
              children: [
                _Card(
                  icon: Symbols.request_quote,
                  title: 'Recent Quotations',
                  child: _RecentQuotationsList(items: d?.recentQuotations ?? const []),
                ),
                _Card(
                  icon: Symbols.shopping_cart,
                  title: 'Recent Sales Orders',
                  child: _RecentOrdersList(items: d?.recentOrders ?? const []),
                ),
              ],
            ),
          ]),
        ),
      );
    });
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

// ── Card shell ───────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.child, this.trailingText});
  final IconData icon;
  final String title;
  final Widget child;
  final String? trailingText;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
        child: Row(children: [
          Icon(icon, size: 16, color: context.pal.textMute),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: AppTheme.cardTitle)),
          if (trailingText != null) Text(trailingText!, style: AppTheme.monoXs),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: child),
    ]),
  );
}

// ── Pipeline breakdown ─────────────────────────────────────────────────────────

class _PipelineBreakdown extends StatelessWidget {
  const _PipelineBreakdown({required this.stages});
  final List<SalesPipelineStage> stages;

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No open deals', style: AppTheme.bodySub)),
      );
    }
    final byStage = {for (final s in stages) s.stage: s};
    final ordered = _stageOrder.map((s) => byStage[s]).whereType<SalesPipelineStage>().toList();
    final maxValue = ordered.fold<int>(1, (a, s) => s.value > a ? s.value : a);

    return Column(children: ordered.map((s) {
      final color = _stageColors[s.stage] ?? AppColors.textDim;
      final pct = s.value / maxValue;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(s.stageLabel, style: AppTheme.bodySm)),
            Text('${s.count} · ${_fmtAmount(s.value)}', style: AppTheme.bodySm.copyWith(color: AppColors.amber)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct, minHeight: 5,
              backgroundColor: context.pal.surface3,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
      );
    }).toList());
  }
}

// ── Top reps ─────────────────────────────────────────────────────────────────

class _TopRepsList extends StatelessWidget {
  const _TopRepsList({required this.reps});
  final List<SalesRep> reps;

  @override
  Widget build(BuildContext context) {
    if (reps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No confirmed orders with a commission agent yet', style: AppTheme.bodySub)),
      );
    }
    final maxValue = reps.fold<int>(1, (a, r) => r.totalValue > a ? r.totalValue : a);
    return Column(children: reps.asMap().entries.map((e) {
      final i = e.key;
      final r = e.value;
      final pct = r.totalValue / maxValue;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 20, child: Text((i + 1).toString().padLeft(2, '0'), style: AppTheme.monoXs)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.repName, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct, minHeight: 4,
                backgroundColor: context.pal.surface3,
                valueColor: AlwaysStoppedAnimation(AppColors.teal),
              ),
            ),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${r.dealCount} deal${r.dealCount == 1 ? '' : 's'}', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
            Text(_fmtAmount(r.totalValue), style: AppTheme.monoXs.copyWith(fontSize: 10)),
          ]),
        ]),
      );
    }).toList());
  }
}

// ── Recent quotations ─────────────────────────────────────────────────────────

class _RecentQuotationsList extends StatelessWidget {
  const _RecentQuotationsList({required this.items});
  final List<Quotation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No quotations yet', style: AppTheme.bodySub)),
      );
    }
    return Column(children: items.map((q) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.pal.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.pal.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q.clientName, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          Text(q.quotationNumber, style: AppTheme.monoXs.copyWith(color: context.pal.textDim, fontSize: 10.5)),
        ])),
        Text(_fmtAmount(q.totalAmount), style: AppTheme.bodySm.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600)),
      ]),
    )).toList());
  }
}

// ── Recent orders ──────────────────────────────────────────────────────────────

class _RecentOrdersList extends StatelessWidget {
  const _RecentOrdersList({required this.items});
  final List<SalesOrder> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No sales orders yet', style: AppTheme.bodySub)),
      );
    }
    return Column(children: items.map((so) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.pal.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.pal.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(so.clientName, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          Text(so.orderNumber, style: AppTheme.monoXs.copyWith(color: context.pal.textDim, fontSize: 10.5)),
        ])),
        Text(_fmtAmount(so.totalAmount), style: AppTheme.bodySm.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600)),
      ]),
    )).toList());
  }
}
