import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/chart_of_account.dart';
import '../../services/accounting_service.dart';
import '../../services/finance_report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/csv_export.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/kpi_card.dart';

enum _Period { thisMonth, lastMonth, last7Days, thisQuarter, thisYear }

extension on _Period {
  String get label => switch (this) {
    _Period.thisMonth   => 'This Month',
    _Period.lastMonth   => 'Last Month',
    _Period.last7Days   => 'Last 7 Days',
    _Period.thisQuarter => 'This Quarter',
    _Period.thisYear    => 'This Year',
  };
}

(String?, String?) _dateRangeFor(_Period p) {
  final now = DateTime.now();
  String iso(DateTime d) => d.toIso8601String().substring(0, 10);
  switch (p) {
    case _Period.thisMonth:
      return (null, null); // let the backend default to the current month
    case _Period.lastMonth:
      final firstOfThisMonth = DateTime(now.year, now.month, 1);
      final lastMonthEnd     = firstOfThisMonth.subtract(const Duration(days: 1));
      final lastMonthStart   = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);
      return (iso(lastMonthStart), iso(lastMonthEnd));
    case _Period.last7Days:
      return (iso(now.subtract(const Duration(days: 7))), iso(now));
    case _Period.thisQuarter:
      final qStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      return (iso(DateTime(now.year, qStartMonth, 1)), iso(now));
    case _Period.thisYear:
      return (iso(DateTime(now.year, 1, 1)), iso(now));
  }
}

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key, this.onNavigateTo});
  final void Function(String key)? onNavigateTo;

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  Map<String, dynamic> _profitLoss = {};
  Map<String, dynamic> _balance    = {};
  Map<String, dynamic> _arAging    = {};
  Map<String, dynamic> _cashFlow   = {};
  List<LedgerEntry>    _activity   = [];
  List<Map<String, dynamic>> _trend = [];
  _Period _period  = _Period.thisMonth;
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
      final (from, to) = _dateRangeFor(_period);
      // Fire all six requests immediately, then await each type-homogeneous
      // group together — still fully parallel, just can't share one List.
      final plF = FinanceReportService.instance.profitLoss(dateFrom: from, dateTo: to);
      final cfF = FinanceReportService.instance.cashFlow(dateFrom: from, dateTo: to);
      final bsF = FinanceReportService.instance.balanceSheet();
      final arF = FinanceReportService.instance.arAging();
      final jF  = AccountingService.instance.journal();
      final trF = FinanceReportService.instance.monthlyTrend();

      final results = await Future.wait([plF, cfF, bsF, arF]);
      final activity = await jF;
      final trend    = await trF;

      if (!mounted) return;
      setState(() {
        _profitLoss = results[0]; _cashFlow = results[1];
        _balance    = results[2]; _arAging  = results[3];
        _activity   = activity.take(6).toList();
        _trend      = trend;
        _loading    = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _export() async {
    try {
      final path = await CsvExport.financeSummary(
        periodLabel:  _period.label,
        revenue:          ((_profitLoss['revenue'] as num?) ?? 0).toInt(),
        totalExpenses:    ((_profitLoss['total_expenses'] as num?) ?? 0).toInt(),
        netProfit:        ((_profitLoss['net_profit'] as num?) ?? 0).toInt(),
        netCashFlow:      ((_cashFlow['net_cash_flow'] as num?) ?? 0).toInt(),
        totalOutstanding: ((_arAging['total_outstanding'] as num?) ?? 0).toInt(),
        totalAssets:      ((_balance['total_assets'] as num?) ?? 0).toInt(),
        totalLiabilities: ((_balance['total_liabilities'] as num?) ?? 0).toInt(),
        totalEquity:      ((_balance['total_equity'] as num?) ?? 0).toInt(),
        expensesByCategory: ((_profitLoss['expenses_by_category'] as List?) ?? const [])
            .cast<Map<String, dynamic>>(),
        recentActivity: _activity,
      );
      if (path != null && mounted) showSuccessToast(context, 'Finance report exported to CSV');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final pad    = cst.maxWidth < 560 ? 16.0 : 28.0;
      final narrow = cst.maxWidth < 700;

      final revenue        = (_profitLoss['revenue'] as num?) ?? 0;
      final netProfit      = (_profitLoss['net_profit'] as num?) ?? 0;
      final totalExpenses  = (_profitLoss['total_expenses'] as num?) ?? 0;
      final netMarginPct   = revenue > 0 ? (netProfit / revenue * 100) : 0.0;
      final netCashFlow    = (_cashFlow['net_cash_flow'] as num?) ?? 0;
      final totalOutstanding = (_arAging['total_outstanding'] as num?) ?? 0;
      final overdueCount = ((_arAging['invoices'] as List?) ?? const [])
          .where((i) => (i as Map<String, dynamic>)['bucket'] != 'current')
          .length;
      final totalAssets      = (_balance['total_assets'] as num?) ?? 0;
      final totalLiabilities = (_balance['total_liabilities'] as num?) ?? 0;
      final totalEquity      = (_balance['total_equity'] as num?) ?? 0;
      final balanced          = _balance['balanced'] == true;
      final expensesByCategory = ((_profitLoss['expenses_by_category'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final expenseRatio = revenue > 0 ? (totalExpenses / revenue * 100) : 0.0;

      // Real trailing 12-month series where we have one; KPI cards without a
      // matching field in /finance-reports/monthly-trend keep a decorative spark.
      final revenueTrend = _trend.map((m) => ((m['revenue'] as num?) ?? 0).toDouble()).toList();
      final profitTrend  = _trend.map((m) => ((m['net_profit'] as num?) ?? 0).toDouble()).toList();

      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            narrow
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Finance Overview', style: AppTheme.pageTitle),
                    const SizedBox(height: 4),
                    Text('Ledger position, VAT, and cash movement', style: AppTheme.bodySub),
                    const SizedBox(height: 14),
                    Row(children: [
                      _PeriodSelector(period: _period, onChanged: (p) { setState(() => _period = p); _load(); }),
                      const SizedBox(width: 10),
                      _ExportButton(onTap: _export),
                    ]),
                  ])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Finance Overview', style: AppTheme.pageTitle),
                      const SizedBox(height: 4),
                      Text('Ledger position, VAT, and cash movement', style: AppTheme.bodySub),
                    ])),
                    _PeriodSelector(period: _period, onChanged: (p) { setState(() => _period = p); _load(); }),
                    const SizedBox(width: 10),
                    _ExportButton(onTap: _export),
                  ]),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else ...[
              AdaptiveColumns(
                wideCols: 4, mediumCols: 2, narrowCols: 2,
                children: [
                  KpiCard(
                    label: 'Revenue',
                    icon: Symbols.payments,
                    value: tshFromDouble(revenue),
                    deltaValue: '${netMarginPct.toStringAsFixed(0)}%',
                    deltaUp: netProfit >= 0,
                    deltaNote: 'net margin',
                    sparkValues: revenueTrend.length >= 2
                        ? revenueTrend
                        : const [8, 10, 9, 12, 11, 14, 13, 16, 15, 18, 17, 20],
                    accent: KpiAccent.teal,
                  ),
                  KpiCard(
                    label: 'Net Profit',
                    icon: Symbols.trending_up,
                    value: tshFromDouble(netProfit),
                    deltaValue: netProfit >= 0 ? 'Profitable' : 'Loss',
                    deltaUp: netProfit >= 0,
                    deltaNote: _period.label,
                    sparkValues: profitTrend.length >= 2
                        ? profitTrend
                        : (netProfit >= 0
                            ? const [4, 5, 5, 6, 7, 6, 8, 9, 8, 10, 11, 12]
                            : const [12, 11, 10, 9, 8, 9, 7, 6, 7, 5, 4, 3]),
                    accent: netProfit >= 0 ? KpiAccent.teal : KpiAccent.coral,
                  ),
                  KpiCard(
                    label: 'AR Outstanding',
                    icon: Symbols.request_quote,
                    value: tshFromDouble(totalOutstanding),
                    deltaValue: overdueCount == 0 ? 'None overdue' : '$overdueCount overdue',
                    deltaUp: overdueCount == 0,
                    deltaNote: 'invoices',
                    sparkValues: const [6, 7, 6, 8, 7, 9, 8, 10, 9, 8, 9, 7],
                    accent: KpiAccent.amber,
                  ),
                  KpiCard(
                    label: 'Cash Flow',
                    icon: Symbols.account_balance_wallet,
                    value: tshFromDouble(netCashFlow),
                    deltaValue: netCashFlow >= 0 ? 'Positive' : 'Negative',
                    deltaUp: netCashFlow >= 0,
                    deltaNote: _period.label,
                    sparkValues: netCashFlow >= 0
                        ? const [5, 6, 5, 7, 8, 7, 9, 10, 9, 11, 12, 13]
                        : const [13, 12, 11, 10, 9, 10, 8, 7, 8, 6, 5, 4],
                    accent: netCashFlow >= 0 ? KpiAccent.teal : KpiAccent.coral,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.pal.surface1,
                  borderRadius: BorderRadius.circular(AppColors.rLg),
                  border: Border.all(color: context.pal.border),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14, runSpacing: 6,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(balanced ? Symbols.check_circle : Symbols.error, size: 18,
                          color: balanced ? AppColors.teal : AppColors.coral),
                      const SizedBox(width: 10),
                      Text(
                        balanced ? 'Books are balanced — Assets = Liabilities + Equity' : 'Books are out of balance — check the ledger',
                        style: AppTheme.bodySm,
                      ),
                    ]),
                    Text('Assets ${tshFromDouble(totalAssets)}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                    Text('Liabilities ${tshFromDouble(totalLiabilities)}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                    Text('Equity ${tshFromDouble(totalEquity)}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ResponsiveRow(
                minChildWidth: 300,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Panel(
                    title: 'Expense Breakdown',
                    subtitle: _period.label,
                    child: _ExpenseBreakdownDonut(
                      categories: expensesByCategory,
                      total: totalExpenses.toInt(),
                    ),
                  ),
                  _InsightCard(
                    headline: revenue <= 0
                        ? 'No revenue recorded ${_period.label.toLowerCase()}'
                        : (netProfit >= 0
                            ? 'Profitable ${_period.label.toLowerCase()} — ${netMarginPct.toStringAsFixed(0)}% margin'
                            : 'Running at a loss ${_period.label.toLowerCase()}'),
                    body: expensesByCategory.isNotEmpty
                        ? 'Expenses are ${expenseRatio.toStringAsFixed(0)}% of revenue. '
                          '${expensesByCategory.first['category']} is the largest cost, at '
                          '${tshFromDouble((expensesByCategory.first['total'] as num?) ?? 0)}.'
                        : 'No expenses recorded ${_period.label.toLowerCase()}.',
                    ratioLabel: 'Expense Ratio',
                    ratioPct: expenseRatio,
                    onViewReport: () => widget.onNavigateTo?.call('finance_reports'),
                  ),
                  _Panel(
                    title: 'Recent Activity',
                    subtitle: 'Latest ledger postings',
                    child: _RecentActivityList(entries: _activity),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Panel(
                title: 'Revenue & Expenses',
                subtitle: 'Monthly performance — last 12 months',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _LegendDot(color: AppColors.teal, label: 'Revenue'),
                  const SizedBox(width: 14),
                  _LegendDot(color: AppColors.coral, label: 'Expenses'),
                ]),
                child: _MonthlyTrendChart(trend: _trend),
              ),
            ],
          ]),
        ),
      );
    });
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});
  final _Period period;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_Period>(
    onSelected: onChanged,
    itemBuilder: (_) => _Period.values
        .map((p) => PopupMenuItem(value: p, child: Text(p.label)))
        .toList(),
    color: context.pal.surface2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppColors.rMd),
      side: BorderSide(color: context.pal.border),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rMd),
        border: Border.all(color: context.pal.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.calendar_today, size: 15, color: context.pal.textDim),
        const SizedBox(width: 8),
        Text(period.label, style: AppTheme.bodySm),
        const SizedBox(width: 6),
        Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
      ]),
    ),
  );
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(AppColors.rMd),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.file_download, size: 16, color: AppColors.teal),
        const SizedBox(width: 8),
        Text('Export Report', style: AppTheme.bodySm.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

/// Shared bordered card chrome: title (+ optional subtitle, optional trailing
/// widget) header, then content.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.subtitle, this.trailing, required this.child});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTheme.cardTitle),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: AppTheme.bodySub),
            ],
          ])),
          ?trailing,
        ]),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 6),
    Text(label, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
  ]);
}

class _ExpenseBreakdownDonut extends StatelessWidget {
  const _ExpenseBreakdownDonut({required this.categories, required this.total});
  final List<Map<String, dynamic>> categories; // [{category, total}], backend-sorted desc
  final int total;

  static List<Color> get _palette => [AppColors.teal, AppColors.amber, AppColors.coral, AppColors.violet, AppColors.info];

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty || total <= 0) {
      return SizedBox(
        height: 220,
        child: Center(child: Text('No expenses recorded', style: TextStyle(color: context.pal.textDim))),
      );
    }

    // Fold anything past the top 5 into "Other" so the legend stays readable.
    final top = categories.take(5).toList();
    final restTotal = categories.skip(5).fold<int>(0, (a, c) => a + ((c['total'] as num?)?.toInt() ?? 0));
    final entries = [
      ...top.map((c) => MapEntry(c['category'] as String? ?? '—', (c['total'] as num?)?.toInt() ?? 0)),
      if (restTotal > 0) MapEntry('Other', restTotal),
    ];

    final sections = List.generate(entries.length, (i) => PieChartSectionData(
      value: entries[i].value.toDouble(),
      color: _palette[i % _palette.length],
      radius: 22,
      showTitle: false,
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 170, height: 170,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 60,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(enabled: false),
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tshFromDouble(total),
                    style: AppTheme.cardTitle.copyWith(fontSize: 17, color: context.pal.text)),
                Text('TOTAL SPENT', style: AppTheme.monoXs.copyWith(letterSpacing: 1.2)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(entries.length, (i) {
          final e = entries[i];
          final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : '0.0';
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: i < entries.length - 1
                ? BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider)))
                : null,
            child: Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: _palette[i % _palette.length], borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(e.key, style: AppTheme.bodySm.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
              Text('$pct%', style: AppTheme.monoXs.copyWith(color: context.pal.textDim, fontSize: 11)),
              const SizedBox(width: 8),
              Text(tshFromDouble(e.value),
                  style: AppTheme.bodyStrong.copyWith(fontSize: 12.5, fontFeatures: [const FontFeature.tabularFigures()])),
            ]),
          );
        }),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.headline,
    required this.body,
    required this.ratioLabel,
    required this.ratioPct,
    required this.onViewReport,
  });
  final String headline, body, ratioLabel;
  final double ratioPct;
  final VoidCallback onViewReport;

  @override
  Widget build(BuildContext context) {
    final clamped  = ratioPct.clamp(0, 100) / 100;
    final barColor = ratioPct < 60 ? AppColors.teal : (ratioPct < 85 ? AppColors.amber : AppColors.coral);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(9)),
              child: Icon(Symbols.insights, size: 17, color: AppColors.teal),
            ),
            const SizedBox(width: 10),
            Text('INSIGHT', style: AppTheme.labelCaps),
          ]),
          const SizedBox(height: 12),
          Text(headline, style: AppTheme.cardTitle.copyWith(fontSize: 15.5)),
          const SizedBox(height: 8),
          Text(body, style: AppTheme.bodySub.copyWith(fontSize: 12.5, height: 1.5)),
          const SizedBox(height: 20),
          Row(children: [
            Text(ratioLabel, style: AppTheme.bodySub),
            const Spacer(),
            Text('${ratioPct.toStringAsFixed(0)}%', style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clamped.toDouble(),
              minHeight: 6,
              backgroundColor: context.pal.surface3,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewReport,
              style: OutlinedButton.styleFrom(side: BorderSide(color: context.pal.border)),
              child: const Text('View Full Report'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.trend});
  final List<Map<String, dynamic>> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(child: Text('No trend data yet', style: TextStyle(color: context.pal.textDim))),
      );
    }

    final revenue  = trend.map((m) => ((m['revenue'] as num?) ?? 0).toDouble()).toList();
    final expenses = trend.map((m) => ((m['expenses'] as num?) ?? 0).toDouble()).toList();
    final labels   = trend.map((m) => m['label'] as String? ?? '').toList();

    FlSpot spot(int i, List<double> d) => FlSpot(i.toDouble(), d[i]);
    final revSpots = List.generate(revenue.length, (i) => spot(i, revenue));
    final expSpots = List.generate(expenses.length, (i) => spot(i, expenses));

    final maxVal = [...revenue, ...expenses].fold(0.0, (a, b) => b > a ? b : a);
    final chartMaxY = maxVal <= 0 ? 1.0 : maxVal * 1.15;

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0, maxX: (revenue.length - 1).toDouble(),
          minY: 0, maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMaxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: context.pal.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              interval: chartMaxY / 4,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(tshShort(v.toInt()), style: AppTheme.monoXs),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Text(labels[i], style: AppTheme.monoXs);
              },
            )),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: revSpots,
              color: AppColors.teal,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                  radius: idx == revSpots.length - 1 ? 4 : 2.5,
                  color: AppColors.teal,
                  strokeColor: context.pal.bg,
                  strokeWidth: idx == revSpots.length - 1 ? 2 : 1,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.teal.withValues(alpha: 0.22), AppColors.teal.withValues(alpha: 0)],
                ),
              ),
            ),
            LineChartBarData(
              spots: expSpots,
              color: AppColors.coral,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                  radius: idx == expSpots.length - 1 ? 4 : 2.5,
                  color: AppColors.coral,
                  strokeColor: context.pal.bg,
                  strokeWidth: idx == expSpots.length - 1 ? 2 : 1,
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => context.pal.surface2,
              getTooltipItems: (spots) => spots.map((s) {
                final isRevenue = s.barIndex == 0;
                return LineTooltipItem(
                  '${isRevenue ? 'Revenue' : 'Expenses'} ${tshFromDouble(s.y)}',
                  AppTheme.monoXs.copyWith(color: context.pal.text, fontSize: 11),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.entries});
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(child: Text('No recent activity', style: TextStyle(color: context.pal.textDim))),
      );
    }
    return Column(
      children: List.generate(entries.length, (i) {
        final e = entries[i];
        final inflow = e.type == 'credit';
        final label = (e.description?.isNotEmpty ?? false) ? e.description! : e.accountName;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: i < entries.length - 1
              ? BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider)))
              : null,
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: inflow ? AppColors.tealSoft : AppColors.coralSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                inflow ? Symbols.call_received : Symbols.call_made,
                size: 15,
                color: inflow ? AppColors.teal : AppColors.coral,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(e.accountName, style: AppTheme.bodySub.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(tshFromDouble(e.amount), style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(e.createdAt != null ? timeAgo(e.createdAt!) : '', style: AppTheme.monoXs),
            ]),
          ]),
        );
      }),
    );
  }
}
