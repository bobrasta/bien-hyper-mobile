import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/invoice.dart';
import '../../models/machine.dart';
import '../../services/hospital_service.dart';
import '../../services/invoice_service.dart';
import '../../services/machine_service.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/status_badge.dart';
import '../../theme/app_palette.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  bool _showNewInvoice = false;
  Invoice? _selectedInvoice;

  List<Invoice>              _invoices         = [];
  List<Machine>              _machines         = [];
  List<Map<String, dynamic>> _revenueByHosp    = [];
  List<String>               _revenueMonths    = [];
  List<double>               _revenueActual    = [];
  List<double>               _revenueTarget    = [];
  List<String>               _hospitalNames    = [];
  bool                       _loading          = true;
  String?                    _error;

  // KPI totals derived from invoices
  double get _totalRevenue => _invoices.fold(0, (s, i) => s + i.total);
  double get _collected    => _invoices.fold(0, (s, i) => s + i.amountPaid);
  double get _outstanding  => _invoices.where((i) => i.status == PaymentStatus.pending || i.status == PaymentStatus.partial)
      .fold(0, (s, i) => s + i.balanceDue);
  double get _overdue      => _invoices.where((i) => i.status == PaymentStatus.overdue)
      .fold(0, (s, i) => s + i.balanceDue);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        InvoiceService.instance.list(),
        MachineService.instance.list(),
        InvoiceService.instance.revenueByHospital(),
        InvoiceService.instance.revenueSummary(),
        HospitalService.instance.list(),
      ]);
      if (!mounted) return;
      final invoices  = results[0] as List<Invoice>;
      final machines  = results[1] as List<Machine>;
      final byHosp    = results[2] as List<Map<String, dynamic>>;
      final summary   = results[3] is Map<String, dynamic>
          ? results[3] as Map<String, dynamic>
          : <String, dynamic>{};
      final hospitals = results[4];

      setState(() {
        _invoices      = invoices;
        _machines      = machines;
        _revenueByHosp = byHosp;
        _revenueMonths = (summary['months'] as List? ?? []).cast<String>();
        _revenueActual = (summary['actual'] as List? ?? []).map((e) => (e as num).toDouble()).toList();
        _revenueTarget = (summary['target'] as List? ?? []).map((e) => (e as num).toDouble()).toList();
        _hospitalNames = (hospitals as List).map((h) => (h as dynamic).name as String).toList();
        _loading       = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Revenue Overview', style: AppTheme.pageTitle),
              const SizedBox(height: 4),
              Text('June 2025 · MedEquip Tanzania Ltd', style: AppTheme.bodySub),
            ]);
            final actions = Row(mainAxisSize: MainAxisSize.min, children: [
              AppButton(label: 'Export', icon: Symbols.download, variant: BtnVariant.ghost),
              const SizedBox(width: 8),
              AppButton(label: 'Jun 2025', icon: Symbols.calendar_month, variant: BtnVariant.normal),
            ]);
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

          // Loading / error banner
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_error != null)
            ErrorView(message: _error!, onRetry: _load)
          else ...[

          // KPI row — 4 cols wide, 2 cols medium, 1 narrow
          AdaptiveColumns(
            wideCols: 4, mediumCols: 2, narrowCols: 2,
            children: [
              _RevKpi(label: 'Total Revenue', value: tshFromDouble(_totalRevenue), delta: '${_invoices.length} invoices', up: true, icon: Symbols.payments),
              _RevKpi(label: 'Collected',     value: tshFromDouble(_collected),    delta: _totalRevenue > 0 ? '${(_collected / _totalRevenue * 100).toStringAsFixed(0)}%' : '0%', up: true, icon: Symbols.check_circle, color: AppColors.teal),
              _RevKpi(label: 'Outstanding',   value: tshFromDouble(_outstanding),  delta: 'pending', up: false, icon: Symbols.pending,    color: AppColors.amber),
              _RevKpi(label: 'Overdue',       value: tshFromDouble(_overdue),      delta: 'overdue', up: false, icon: Symbols.warning,    color: AppColors.coral),
            ],
          ),
          const SizedBox(height: 16),

          // Large revenue chart + top-5 panel — side by side on wide, stacked on narrow
          ResponsiveRow(
            minChildWidth: 260,
            children: [
              Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.pal.surface1,
                      borderRadius: BorderRadius.circular(AppColors.rLg),
                      border: Border.all(color: context.pal.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(builder: (ctx, cst) {
                          final narrow = cst.maxWidth < 480;
                          final titleRow = Row(children: [
                            const SizedBox(width: 8),
                            Expanded(child: Text('Revenue Trend — Last 12 Months', style: AppTheme.cardTitle)),
                          ]);
                          final legends = Wrap(spacing: 12, runSpacing: 6, children: [
                            _Legend(color: AppColors.teal,    label: 'Actual'),
                            _Legend(color: AppColors.blue,    label: 'Collected'),
                            _Legend(color: context.pal.textDim, label: 'Target', dashed: true),
                          ]);
                          if (narrow) {
                            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              titleRow, const SizedBox(height: 8), legends,
                            ]);
                          }
                          return Row(children: [
                            const SizedBox(width: 8),
                            Text('Revenue Trend — Last 12 Months', style: AppTheme.cardTitle),
                            const Spacer(),
                            _Legend(color: AppColors.teal,    label: 'Actual'),
                            const SizedBox(width: 12),
                            _Legend(color: AppColors.blue,    label: 'Collected'),
                            const SizedBox(width: 12),
                            _Legend(color: context.pal.textDim, label: 'Target', dashed: true),
                          ]);
                        }),
                        const SizedBox(height: 16),
                        SizedBox(height: 240, child: _RevenueChart(
                          actual: _revenueActual,
                          target: _revenueTarget,
                          months: _revenueMonths,
                        )),
                      ],
                    ),
                  ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.pal.surface1,
                  borderRadius: BorderRadius.circular(AppColors.rLg),
                  border: Border.all(color: context.pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Symbols.star, size: 16, color: AppColors.amber),
                      const SizedBox(width: 8),
                      Text('Top 5 Hospitals', style: AppTheme.cardTitle),
                    ]),
                    const SizedBox(height: 16),
                    ..._revenueByHosp.take(5).toList().asMap().entries.map((e) {
                      final h = e.value;
                      final maxRev = _revenueByHosp.isEmpty ? 1.0
                          : _revenueByHosp.map((x) => (x['revenue_monthly'] as num? ?? x['rev'] as num? ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
                      final rev = (h['revenue_monthly'] as num? ?? h['rev'] as num? ?? 0).toDouble();
                      final pct = maxRev > 0 ? rev / maxRev : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.tealSoft,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: Text('${e.key + 1}',
                                  style: AppTheme.monoXs.copyWith(color: AppColors.teal, fontSize: 9)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(h['name'] as String? ?? '—',
                                style: AppTheme.bodySm.copyWith(fontSize: 12),
                                overflow: TextOverflow.ellipsis)),
                              Text(tshFromDouble(rev),
                                style: AppTheme.monoSm.copyWith(color: AppColors.amber, fontSize: 11)),
                            ]),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: context.pal.surface3,
                                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Per-machine table
          Container(
            decoration: BoxDecoration(
              color: context.pal.surface1,
              borderRadius: BorderRadius.circular(AppColors.rLg),
              border: Border.all(color: context.pal.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(children: [
                    const SizedBox(width: 8),
                    Text('Per-Machine Revenue Breakdown', style: AppTheme.cardTitle),
                  ]),
                ),
                HScrollTable(minWidth: 700, child: _RevTable(machines: _machines)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invoices
          Container(
            decoration: BoxDecoration(
              color: context.pal.surface1,
              borderRadius: BorderRadius.circular(AppColors.rLg),
              border: Border.all(color: context.pal.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (ctx, cst) {
                final narrow = cst.maxWidth < 520;
                final titleRow = Row(children: [
                  const SizedBox(width: 8),
                  Expanded(child: Text('Invoices — June 2025', style: AppTheme.cardTitle)),
                ]);
                final action = AppButton(label: 'New Invoice', icon: Symbols.add, variant: BtnVariant.primary, small: true,
                    onPressed: () => setState(() => _showNewInvoice = true));
                if (narrow) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      titleRow, const SizedBox(height: 10), action,
                    ]),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(children: [
                    const SizedBox(width: 8),
                    Text('Invoices — June 2025', style: AppTheme.cardTitle),
                    const Spacer(),
                    action,
                  ]),
                );
              }),
              HScrollTable(
                minWidth: 750,
                child: _InvoicesTable(
                  invoices: _invoices,
                  onSelectInvoice: (inv) => setState(() => _selectedInvoice = inv),
                ),
              ),
            ]),
          ),

          ], // end else [...] for loading guard
        ],
      ),
    ));  // SingleChildScrollView + RefreshIndicator
    }),   // LayoutBuilder

    // New Invoice dialog
    if (_showNewInvoice)
      _NewInvoiceDialog(
        onClose: () => setState(() => _showNewInvoice = false),
        hospitalNames: _hospitalNames,
        machineModels: _machines.map((m) => m.model).toSet().toList(),
      ),

    // Invoice detail / Record Payment
    if (_selectedInvoice != null)
      _InvoiceDetailSheet(
        invoice: _selectedInvoice!,
        onClose: () => setState(() => _selectedInvoice = null),
      ),
    ]);  // Stack
  }
}

class _RevKpi extends StatelessWidget {
  const _RevKpi({required this.label, required this.value, required this.delta, required this.up, required this.icon, this.color});
  final String label, value, delta;
  final bool up;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.text;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: context.pal.textDim),
          const SizedBox(width: 6),
          Text(label.toUpperCase(), style: AppTheme.labelCaps),
        ]),
        const SizedBox(height: 12),
        Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 26, color: c)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: up ? AppColors.tealSoft : AppColors.coralSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(delta, style: AppTheme.bodySub.copyWith(
            color: up ? AppColors.teal : AppColors.coral,
            fontSize: 11, fontWeight: FontWeight.w500,
          )),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dashed = false});
  final Color color; final String label; final bool dashed;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8,
      decoration: BoxDecoration(
        color: dashed ? null : color,
        borderRadius: BorderRadius.circular(2),
        border: dashed ? Border(top: BorderSide(color: color, width: 1)) : null,
      )),
    const SizedBox(width: 6),
    Text(label, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
  ]);
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.actual, required this.target, required this.months});
  final List<double> actual, target;
  final List<String> months;

  @override
  Widget build(BuildContext context) {
    if (actual.isEmpty) {
      return const Center(child: Text('No revenue data', style: TextStyle(color: AppColors.textMute)));
    }
    final collected = List.generate(actual.length, (i) => actual[i] * 0.88);

    FlSpot s(int i, List<double> d) => FlSpot(i.toDouble(), d[i]);

    return LineChart(LineChartData(
      minX: 0, maxX: 11, minY: 155, maxY: 345,
      gridData: FlGridData(
        show: true, drawVerticalLine: false, horizontalInterval: 40,
        getDrawingHorizontalLine: (_) => const FlLine(color: Color(0x0DFFFFFF), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, interval: 40, reservedSize: 36,
          getTitlesWidget: (v, _) => Text('${v.toInt()}M',
            style: GoogleFonts.jetBrainsMono(fontSize: 9, color: context.pal.textDim)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, interval: 1,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= months.length) return const SizedBox.shrink();
            return Text(months[i], style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: context.pal.textDim));
          },
        )),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(target.length, (i) => s(i, target)),
          color: context.pal.textDim.withValues(alpha: 0.7),
          barWidth: 1.2, dashArray: [4, 4],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        LineChartBarData(
          spots: List.generate(collected.length, (i) => s(i, collected)),
          color: AppColors.blue,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.blue.withValues(alpha: 0.15), AppColors.blue.withValues(alpha: 0)]),
          ),
        ),
        LineChartBarData(
          spots: List.generate(actual.length, (i) => s(i, actual)),
          color: AppColors.teal, barWidth: 2,
          dotData: FlDotData(getDotPainter: (s, p, b, i) => FlDotCirclePainter(
            radius: i == actual.length - 1 ? 4 : 2.5,
            color: AppColors.teal, strokeColor: context.pal.bg,
            strokeWidth: i == actual.length - 1 ? 2 : 1,
          )),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.teal.withValues(alpha: 0.22), AppColors.teal.withValues(alpha: 0)]),
          ),
        ),
      ],
    ));
  }
}

class _RevTable extends StatelessWidget {
  const _RevTable({required this.machines});
  final List<Machine> machines;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
          children: ['Machine', 'Hospital', 'Monthly Fee', 'Last Payment', 'Status'].map((h) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(h.toUpperCase(), style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
          )).toList(),
        ),
        ...machines.map((m) {
          final status = m.status == MachineStatus.operational ? 'paid' : 'pending';
          return TableRow(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider))),
            children: [
              _TCell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.model, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                Text(m.type,  style: AppTheme.bodySub.copyWith(fontSize: 11)),
              ])),
              _TCell(child: Text(m.hospital, style: AppTheme.bodySm.copyWith(fontSize: 12))),
              _TCell(child: Text(tshShort(m.revenuePerMonth),
                style: AppTheme.monoSm.copyWith(color: AppColors.amber))),
              _TCell(child: Text('15 Jun 2025', style: AppTheme.monoXs)),
              _TCell(child: StatusBadge.machine(
                status == 'paid' ? MachineStatus.operational : MachineStatus.needsService)),
            ],
          );
        }),
      ],
    );
  }
}

class _TCell extends StatelessWidget {
  const _TCell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: child,
  );
}

// ── New Invoice Dialog ─────────────────────────────────────────────────────────

class _NewInvoiceDialog extends StatefulWidget {
  const _NewInvoiceDialog({required this.onClose, this.hospitalNames = const [], this.machineModels = const []});
  final VoidCallback  onClose;
  final List<String>  hospitalNames;
  final List<String>  machineModels;

  @override
  State<_NewInvoiceDialog> createState() => _NewInvoiceDialogState();
}

class _NewInvoiceDialogState extends State<_NewInvoiceDialog> {
  late String _hospital = widget.hospitalNames.isNotEmpty ? widget.hospitalNames.first : '';
  late String _machine  = widget.machineModels.isNotEmpty ? widget.machineModels.first : '';
  String _type     = 'Monthly Service';
  final _amountCtrl = TextEditingController();
  bool  _saving    = false;

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;
    setState(() => _saving = true);
    try {
      final subtotal = (amount / 1.18).round();
      await InvoiceService.instance.create({
        'client_name': _hospital,
        'issue_date':  DateTime.now().toIso8601String().substring(0, 10),
        'due_date':    DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10),
        'tax_rate':    18,
        'currency':    'TZS',
        'line_items': [
          {
            'description': _type.isNotEmpty ? _type : 'Service — $_machine',
            'quantity':    1,
            'unit_price':  subtotal,
          }
        ],
      });
      widget.onClose();
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
          width: 480,
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
                const Icon(Symbols.receipt_long, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('New Invoice', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (widget.hospitalNames.isNotEmpty)
                  _RField('Hospital', _hospital, widget.hospitalNames,
                      (v) => setState(() => _hospital = v)),
                const SizedBox(height: 14),
                if (widget.machineModels.isNotEmpty)
                  _RField('Machine', _machine, widget.machineModels,
                      (v) => setState(() => _machine = v)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _RField('Invoice Type', _type,
                      const ['Monthly Service', 'Repair', 'Installation', 'Spare Parts', 'Training'],
                      (v) => setState(() => _type = v))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AMOUNT (TSh)'.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(color: context.pal.surface2,
                          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(child: TextField(controller: _amountCtrl,
                        keyboardType: TextInputType.number, style: AppTheme.bodySm,
                        decoration: InputDecoration(hintText: '0',
                            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
                    ),
                  ])),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(child: GestureDetector(onTap: widget.onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: _save,
                  child: Container(height: 38,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Invoice', style: AppTheme.bodyStrong.copyWith(
                          color: const Color(0xFF06120F), fontSize: 13)))))),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _RField extends StatelessWidget {
  const _RField(this.label, this.value, this.items, this.onChanged);
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      height: 38,
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        isExpanded: true, dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);
}

// ── Invoice Detail / Record Payment Sheet ──────────────────────────────────────

class _InvoiceDetailSheet extends StatelessWidget {
  const _InvoiceDetailSheet({required this.invoice, required this.onClose});
  final Invoice invoice;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 460,
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
                const Icon(Symbols.receipt, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text(invoice.invoiceNumber, style: AppTheme.bodyStrong)),
                GestureDetector(onTap: onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _IRow('Client', invoice.displayName),
                _IRow('Issue Date', invoice.issueDate),
                _IRow('Due Date',   invoice.dueDate),
                _IRow('Subtotal',   tshFromDouble(invoice.subtotal)),
                _IRow('VAT (${invoice.taxRate}%)', tshFromDouble(invoice.taxAmount)),
                _IRow('Total',      tshFromDouble(invoice.total), bold: true),
                _IRow('Paid',       tshFromDouble(invoice.amountPaid),
                    color: AppColors.teal),
                if (invoice.balanceDue > 0)
                  _IRow('Balance Due', tshFromDouble(invoice.balanceDue),
                      color: AppColors.coral, bold: true),
              ]),
            ),
            if (invoice.balanceDue > 0) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: double.infinity, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.teal, borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Symbols.payments, size: 18, color: Color(0xFF06120F)),
                      const SizedBox(width: 8),
                      Text('Record Payment — ${tshFromDouble(invoice.balanceDue)}',
                          style: AppTheme.bodyStrong.copyWith(
                              color: const Color(0xFF06120F), fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    ),
  );
}

class _IRow extends StatelessWidget {
  const _IRow(this.label, this.value, {this.color, this.bold = false});
  final String label, value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12.5))),
      Expanded(child: Text(value, style: AppTheme.bodySm.copyWith(
        color: color ?? context.pal.text,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
      ))),
    ]),
  );
}

class _InvoicesTable extends StatelessWidget {
  const _InvoicesTable({required this.invoices, this.onSelectInvoice});
  final List<Invoice> invoices;
  final ValueChanged<Invoice>? onSelectInvoice;

  Color _statusColor(PaymentStatus s) => switch (s) {
    PaymentStatus.paid      => AppColors.teal,
    PaymentStatus.partial   => AppColors.blue,
    PaymentStatus.pending   => AppColors.amber,
    PaymentStatus.sent      => AppColors.blue,
    PaymentStatus.overdue   => AppColors.coral,
    PaymentStatus.waived    => AppColors.textMute,
    PaymentStatus.cancelled => AppColors.coral,
  };

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No invoices found', style: TextStyle(color: AppColors.textMute))),
      );
    }
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(140),
        1: FlexColumnWidth(2.5),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
        5: FlexColumnWidth(1),
        6: FixedColumnWidth(80),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
          children: ['Invoice No.', 'Hospital', 'Machine', 'Total', 'Due Date', 'Status', ''].map((h) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(h.toUpperCase(), style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
            )
          ).toList(),
        ),
        ...invoices.asMap().entries.map((e) {
          final inv = e.value;
          final isLast = e.key == invoices.length - 1;
          final statusColor = _statusColor(inv.status);
          return TableRow(
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: context.pal.divider)),
            ),
            children: [
              _TCell(child: Text(inv.invoiceNumber,
                style: AppTheme.monoXs.copyWith(color: context.pal.textMute, fontSize: 11))),
              _TCell(child: Text(inv.displayName,
                style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                overflow: TextOverflow.ellipsis)),
              _TCell(child: Text(inv.salesOrderNumber ?? '—',
                style: AppTheme.bodySub.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis)),
              _TCell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tshFromDouble(inv.total),
                  style: AppTheme.monoSm.copyWith(color: AppColors.amber)),
                if (inv.balanceDue > 0)
                  Text('Balance: ${tshFromDouble(inv.balanceDue)}',
                    style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: AppColors.coral)),
              ])),
              _TCell(child: Text(inv.dueDate, style: AppTheme.monoXs)),
              _TCell(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(inv.status.label, style: AppTheme.bodySub.copyWith(
                  color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w500,
                )),
              )),
              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: GestureDetector(
                  onTap: () => onSelectInvoice?.call(inv),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: inv.balanceDue > 0 ? AppColors.teal : context.pal.surface3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      inv.balanceDue > 0 ? 'Pay' : 'View',
                      style: AppTheme.bodySub.copyWith(
                        color: inv.balanceDue > 0 ? Color(0xFF06120F) : context.pal.textMute,
                        fontSize: 11.5, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
