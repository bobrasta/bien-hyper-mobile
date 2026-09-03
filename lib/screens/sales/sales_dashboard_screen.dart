import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/invoice.dart';
import '../../models/sales_lead.dart';
import '../../services/invoice_service.dart';
import '../../services/sales_dashboard_service.dart';
import '../../services/sales_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/error_view.dart';

const _stageOrder = ['lead', 'qualified', 'demo_scheduled', 'proposal_sent', 'negotiation'];
Map<String, Color> get _stageColors => {
  'lead':           AppColors.textMute,
  'qualified':      AppColors.green,
  'demo_scheduled': AppColors.violet,
  'proposal_sent':  AppColors.amber,
  'negotiation':    AppColors.coral,
};

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key, this.onNavigateTo});
  final void Function(String key)? onNavigateTo;

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  SalesDashboardData? _data;
  List<Invoice> _invoices = [];
  List<SalesLead> _leads = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        SalesDashboardService.instance.load(),
        InvoiceService.instance.list(),
        SalesService.instance.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as SalesDashboardData;
        _invoices = results[1] as List<Invoice>;
        _leads = results[2] as List<SalesLead>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final d = _data!;

    final invoicedTotal = _invoices.fold<int>(0, (s, i) => s + i.total);
    final collectedTotal = _invoices.fold<int>(0, (s, i) => s + i.amountPaid);
    final collectionPct = invoicedTotal > 0 ? (collectedTotal / invoicedTotal * 100) : 0.0;
    final outstanding = invoicedTotal - collectedTotal;
    final openQuotationValue = d.recentQuotations.where((q) => q.status == 'sent').fold<int>(0, (s, q) => s + q.totalAmount);
    final openLeads = _leads.where((l) => l.stage != PipelineStage.won && l.stage != PipelineStage.lost).toList();
    final stalled = openLeads.where((l) => l.daysInStage >= 90).length;
    final avgDeal = openLeads.isEmpty ? 0 : d.pipelineValue ~/ openLeads.length;
    final weighted = (d.pipelineValue * (d.winRateThisMonth / 100)).round();

    final machineMix = <String, int>{};
    for (final l in _leads) { machineMix[l.machineType] = (machineMix[l.machineType] ?? 0) + l.dealValue; }
    final topMachines = machineMix.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxMachine = topMachines.isEmpty ? 1 : topMachines.first.value;

    return LayoutBuilder(builder: (ctx, cst) {
      final pad  = cst.maxWidth < 560 ? 16.0 : 26.0;
      final wide = cst.maxWidth >= 1100;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(width: 2, height: 36, decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sales Dashboard', style: AppTheme.pageTitle.copyWith(fontSize: 23)),
                const SizedBox(height: 3),
                Text('${formatDate(DateTime.now())} · ${openLeads.length} open deals · ${d.quotationsAwaitingResponse} quotation${d.quotationsAwaitingResponse == 1 ? '' : 's'} awaiting the client', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              ])),
              FilledButton.icon(onPressed: () => widget.onNavigateTo?.call('sales_quotations'), icon: const Icon(Symbols.add, size: 16), label: const Text('New quotation')),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
              child: Row(children: [
                Expanded(child: _kpiTile('Pipeline value', Symbols.filter_alt, AppColors.cyan, tshFromDouble(d.pipelineValue), '${openLeads.length} open', 'across 5 stages')),
                Expanded(child: _kpiTile('Won this month', Symbols.emoji_events, AppColors.green, tshFromDouble(d.wonValueThisMonth), '${d.wonThisMonth} deal${d.wonThisMonth == 1 ? '' : 's'}', 'win rate ${d.winRateThisMonth.toStringAsFixed(0)}%', border: true)),
                Expanded(child: _kpiTile('Quotations open', Symbols.description, AppColors.amber, tshFromDouble(openQuotationValue), '${d.quotationsAwaitingResponse} sent', 'awaiting client', border: true)),
                Expanded(child: _kpiTile('Invoiced', Symbols.receipt_long, AppColors.violet, tshFromDouble(invoicedTotal), '${_invoices.length} invoices', '${d.salesOrdersThisMonth} orders raised', border: true)),
                Expanded(child: _kpiTile('Collected', Symbols.payments, AppColors.green, tshFromDouble(collectedTotal), '${collectionPct.toStringAsFixed(0)}%', '${tshFromDouble(outstanding)} outstanding', border: true)),
              ]),
            ),
            const SizedBox(height: 16),
            wide
                ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(flex: 15, child: _pipelineCard(context, openLeads, avgDeal, weighted, stalled)),
                    const SizedBox(width: 16),
                    Expanded(flex: 10, child: Column(children: [
                      SizedBox(height: 220, child: _feedCard(context, 'Quotations to chase', Symbols.description, AppColors.amber, d.recentQuotations.map((q) => _FeedItem(
                        client: q.clientName, sub: '${q.quotationNumber} · ${q.status}', value: tshFromDouble(q.totalAmount),
                        status: q.statusLabel, color: q.status == 'sent' ? AppColors.amber : (q.status == 'converted' ? AppColors.violet : AppColors.green),
                      )).toList())),
                      const SizedBox(height: 14),
                      SizedBox(height: 220, child: _feedCard(context, 'Orders in flight', Symbols.shopping_cart, AppColors.green, d.recentOrders.map((o) => _FeedItem(
                        client: o.clientName, sub: '${o.orderNumber} · ${o.statusLabel}', value: tshFromDouble(o.totalAmount),
                        status: o.statusLabel, color: o.status == 'pending' ? AppColors.amber : (o.status == 'confirmed' ? AppColors.cyan : AppColors.green),
                      )).toList())),
                    ])),
                    const SizedBox(width: 16),
                    SizedBox(width: 244, child: Column(children: [
                      _repsCard(context, d.topReps),
                      const SizedBox(height: 16),
                      Expanded(child: _machineMixCard(context, topMachines, maxMachine)),
                    ])),
                  ]))
                : Column(children: [
                    _pipelineCard(context, openLeads, avgDeal, weighted, stalled),
                    const SizedBox(height: 16),
                    _repsCard(context, d.topReps),
                  ]),
          ]),
        ),
      );
    });
  }

  Widget _kpiTile(String label, IconData icon, Color color, String value, String chip, String note, {bool border = false}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: border ? BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.06)))) : null,
    child: Builder(builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 7),
        Expanded(child: Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 9),
      Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 21)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
          child: Text(chip, style: AppTheme.monoXs.copyWith(fontSize: 10, color: color)),
        ),
        Text(note, style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
      ]),
    ])),
  );

  Widget _sectionHeader(BuildContext context, IconData icon, Color color, String title, {Widget? trailing}) => Row(children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 8),
    Text(title.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10.5)),
    const SizedBox(width: 8),
    Expanded(child: Container(height: 1, color: context.pal.divider)),
    if (trailing != null) ...[const SizedBox(width: 8), trailing],
  ]);

  Widget _pipelineCard(BuildContext context, List<SalesLead> openLeads, int avgDeal, int weighted, int stalled) {
    final byStage = <String, List<SalesLead>>{};
    for (final l in openLeads) { byStage.putIfAbsent(l.stage.name, () => []).add(l); }
    final stageKeyMap = {'lead': 'lead', 'qualified': 'qualified', 'demoScheduled': 'demo_scheduled', 'proposalSent': 'proposal_sent', 'negotiation': 'negotiation'};
    final maxValue = openLeads.isEmpty ? 1 : openLeads.fold<int>(0, (a, l) => a + l.dealValue);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader(context, Symbols.filter_alt, AppColors.cyan, 'Pipeline by stage', trailing: Text(tshFromDouble(maxValue), style: AppTheme.monoXs.copyWith(fontSize: 11, color: context.pal.text))),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final key in _stageOrder) ...[
            Builder(builder: (context) {
              final stageEnumName = stageKeyMap.entries.firstWhere((e) => e.value == key).key;
              final deals = byStage[stageEnumName] ?? [];
              final value = deals.fold<int>(0, (a, l) => a + l.dealValue);
              final pct = maxValue > 0 ? value / maxValue : 0.0;
              final color = _stageColors[key]!;
              final avgAge = deals.isEmpty ? 0 : deals.fold<int>(0, (a, l) => a + l.daysInStage) ~/ deals.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 9),
                    Text(_PipelineStageLabels.of(key), style: AppTheme.bodySm.copyWith(fontSize: 12)),
                    const SizedBox(width: 7),
                    Text('${deals.length} deal${deals.length == 1 ? '' : 's'}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
                    const Spacer(),
                    Text(tshFromDouble(value), style: AppTheme.monoSm.copyWith(fontSize: 12)),
                    const SizedBox(width: 10),
                    SizedBox(width: 46, child: Text(deals.isEmpty ? '—' : '$avgAge d', textAlign: TextAlign.right, style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: context.pal.textDim))),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: context.pal.surface3, valueColor: AlwaysStoppedAnimation(color))),
                ]),
              );
            }),
          ],
          Container(height: 1, color: context.pal.divider),
          const SizedBox(height: 13),
          Row(children: [
            _pipelineStat('Weighted value', tshFromDouble(weighted), context.pal.text),
            const SizedBox(width: 22),
            _pipelineStat('Avg deal', tshFromDouble(avgDeal), context.pal.text),
            const Spacer(),
            _pipelineStat('Stalled 90 d +', '$stalled deal${stalled == 1 ? '' : 's'}', stalled > 0 ? AppColors.coral : context.pal.text, alignEnd: true),
          ]),
        ]),
      ),
    ]);
  }

  Widget _pipelineStat(String label, String value, Color color, {bool alignEnd = false}) => Column(
    crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9)),
      const SizedBox(height: 3),
      Text(value, style: AppTheme.monoSm.copyWith(fontSize: 15, color: color)),
    ],
  );

  Widget _feedCard(BuildContext context, String title, IconData icon, Color color, List<_FeedItem> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader(context, icon, color, title),
      const SizedBox(height: 9),
      Expanded(child: Container(
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        clipBehavior: Clip.antiAlias,
        child: items.isEmpty
            ? Center(child: Text('Nothing here.', style: AppTheme.bodySub.copyWith(fontSize: 12)))
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, _) => Container(height: 1, color: context.pal.divider),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return Container(
                    height: 52, padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(children: [
                      Container(width: 3, height: 26, decoration: BoxDecoration(color: it.color, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(it.client, style: AppTheme.bodySm.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(it.sub, style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: context.pal.textDim)),
                      ])),
                      Text(it.value, style: AppTheme.monoSm.copyWith(fontSize: 12.5)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: it.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
                        child: Text(it.status.toUpperCase(), style: AppTheme.monoXs.copyWith(fontSize: 9, color: it.color)),
                      ),
                    ]),
                  );
                },
              ),
      )),
    ]);
  }

  Widget _repsCard(BuildContext context, List<SalesRep> reps) {
    final maxValue = reps.isEmpty ? 1 : reps.fold<int>(1, (a, r) => r.totalValue > a ? r.totalValue : a);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader(context, Symbols.emoji_events, AppColors.violet, 'Reps · ${_MonthName.current()}'),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        child: reps.isEmpty
            ? Text('No confirmed orders yet.', style: AppTheme.bodySub.copyWith(fontSize: 12))
            : Column(children: reps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text((e.key + 1).toString().padLeft(2, '0'), style: AppTheme.monoXs.copyWith(fontSize: 10, color: context.pal.textDim)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.value.repName, style: AppTheme.bodySm.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(tshFromDouble(e.value.totalValue), style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: context.pal.text)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: e.value.totalValue / maxValue, minHeight: 6, backgroundColor: context.pal.surface3, valueColor: AlwaysStoppedAnimation(AppColors.violet))),
                  const SizedBox(height: 4),
                  Text('${e.value.dealCount} deal${e.value.dealCount == 1 ? '' : 's'}', style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
                ]),
              )).toList()),
      ),
    ]);
  }

  Widget _machineMixCard(BuildContext context, List<MapEntry<String, int>> topMachines, int maxMachine) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader(context, Symbols.medical_services, AppColors.cyan, 'Machine mix'),
      const SizedBox(height: 9),
      Expanded(child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
        child: topMachines.isEmpty
            ? Text('No deals on file yet.', style: AppTheme.bodySub.copyWith(fontSize: 12))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: topMachines.take(5).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(child: Text(e.key, style: AppTheme.bodySub.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 56, child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: e.value / maxMachine, minHeight: 6, backgroundColor: context.pal.surface3, valueColor: AlwaysStoppedAnimation(AppColors.cyan)))),
                  const SizedBox(width: 10),
                  SizedBox(width: 44, child: Text(tshFromDouble(e.value), textAlign: TextAlign.right, style: AppTheme.monoXs.copyWith(fontSize: 11, color: context.pal.text))),
                ]),
              )).toList()),
      )),
    ]);
  }
}

class _FeedItem {
  const _FeedItem({required this.client, required this.sub, required this.value, required this.status, required this.color});
  final String client, sub, value, status;
  final Color color;
}

class _PipelineStageLabels {
  static String of(String apiStage) => switch (apiStage) {
    'lead' => 'Lead', 'qualified' => 'Qualified', 'demo_scheduled' => 'Demo scheduled',
    'proposal_sent' => 'Proposal sent', 'negotiation' => 'Negotiation', _ => apiStage,
  };
}

class _MonthName {
  static const _names = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static String current() => _names[DateTime.now().month];
}
