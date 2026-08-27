import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/accounting_service.dart';
import '../../services/finance_report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

class FinanceReportsScreen extends StatefulWidget {
  const FinanceReportsScreen({super.key});

  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 8, vsync: this);

  Map<String, dynamic> _vat = {};
  Map<String, dynamic> _pl  = {};
  Map<String, dynamic> _tb  = {};
  Map<String, dynamic> _bs  = {};
  Map<String, dynamic> _ar  = {};
  Map<String, dynamic> _ap  = {};
  Map<String, dynamic> _sv  = {};
  Map<String, dynamic> _cf  = {};
  bool    _loading = true;
  String? _error;
  bool    _closing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        FinanceReportService.instance.vat(),
        FinanceReportService.instance.profitLoss(),
        FinanceReportService.instance.trialBalance(),
        FinanceReportService.instance.balanceSheet(),
        FinanceReportService.instance.arAging(),
        FinanceReportService.instance.apAging(),
        FinanceReportService.instance.stockValuation(),
        FinanceReportService.instance.cashFlow(),
      ]);
      if (!mounted) return;
      setState(() {
        _vat = results[0]; _pl = results[1]; _tb = results[2];
        _bs = results[3]; _ar = results[4]; _ap = results[5];
        _sv = results[6]; _cf = results[7];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _closePeriod() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      final result = await AccountingService.instance.closePeriod();
      if (mounted) {
        showSuccessToast(context, 'Period closed — net income of ${tshFromDouble(result['net_income'] ?? 0)} swept to Retained Earnings.');
        _load();
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
          child: LayoutBuilder(builder: (ctx, cst) {
            final narrow = cst.maxWidth < 560;
            final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Financial Reports', style: AppTheme.pageTitle),
              const SizedBox(height: 4),
              Text('VAT, profitability, and balance-sheet position', style: AppTheme.bodySub),
            ]);
            final action = AppButton(label: _closing ? 'Closing…' : 'Close Period', icon: Symbols.event_repeat,
                variant: BtnVariant.ghost, onPressed: _closing ? null : _closePeriod);
            if (narrow) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                titleBlock, const SizedBox(height: 12), action,
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [titleBlock, const Spacer(), action]);
          }),
        ),
        const SizedBox(height: 16),
        Container(
          margin: EdgeInsets.symmetric(horizontal: pad),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.teal,
            unselectedLabelColor: context.pal.textMute,
            indicatorColor: AppColors.teal,
            indicatorWeight: 2,
            labelStyle: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
            unselectedLabelStyle: AppTheme.bodySm,
            tabs: const [
              Tab(text: 'VAT'), Tab(text: 'Profit & Loss'), Tab(text: 'Trial Balance'),
              Tab(text: 'Balance Sheet'), Tab(text: 'AR Aging'), Tab(text: 'AP Aging'),
              Tab(text: 'Stock Valuation'), Tab(text: 'Cash Flow'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : TabBarView(controller: _tab, children: [
                      _VatTab(data: _vat, pad: pad),
                      _PlTab(data: _pl, pad: pad),
                      _TrialBalanceTab(data: _tb, pad: pad),
                      _BalanceSheetTab(data: _bs, pad: pad),
                      _ArAgingTab(data: _ar, pad: pad),
                      _ApAgingTab(data: _ap, pad: pad),
                      _StockValuationTab(data: _sv, pad: pad),
                      _CashFlowTab(data: _cf, pad: pad),
                    ]),
        ),
      ]);
    });
  }
}

// ── Shared building blocks ─────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
        child: Row(children: [
          Expanded(child: Text(title, style: AppTheme.cardTitle)),
          ?trailing,
        ]),
      ),
      child,
    ]),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.color, this.bold = false, this.big = false});
  final String label, value;
  final Color? color;
  final bool bold, big;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(children: [
      Text(label, style: AppTheme.bodySub.copyWith(fontSize: big ? 13.5 : 12.5)),
      const Spacer(),
      Text(value, style: (big ? AppTheme.kpiValue.copyWith(fontSize: 18) : AppTheme.bodySm).copyWith(
        color: color ?? context.pal.text,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      )),
    ]),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: context.pal.divider);
}

num _n(Map d, String k) => (d[k] as num?) ?? 0;
String _s(Map d, String k) => d[k] as String? ?? '—';

// ── VAT ────────────────────────────────────────────────────────────────────────

class _VatTab extends StatelessWidget {
  const _VatTab({required this.data, required this.pad});
  final Map<String, dynamic> data;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final outputs = (data['output_invoices'] as List? ?? []);
    final expenses = (data['input_expenses'] as List? ?? []);
    final bills = (data['input_bills'] as List? ?? []);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Panel(title: '${_s(data, 'period_from')} → ${_s(data, 'period_to')}', child: Column(children: [
          _SummaryRow('Output VAT (collected on sales)', tshFromDouble(_n(data, 'output_vat')), color: AppColors.teal),
          _SummaryRow('Input VAT (paid on purchases)', tshFromDouble(_n(data, 'input_vat')), color: AppColors.coral),
          _Divider(),
          _SummaryRow('Net VAT Payable', tshFromDouble(_n(data, 'net_vat_payable')), bold: true, big: true,
              color: _n(data, 'net_vat_payable') >= 0 ? AppColors.amber : AppColors.teal),
          const SizedBox(height: 8),
        ])),
        if (outputs.isNotEmpty)
          _Panel(title: 'Output VAT — Invoices (${outputs.length})', child: Column(
            children: outputs.map((i) => _SummaryRow(
              '${i['invoice_number']} · ${i['issue_date']}',
              tshFromDouble((i['tax_amount'] as num?) ?? 0),
            )).toList(),
          )),
        if (expenses.isNotEmpty)
          _Panel(title: 'Input VAT — Expenses (${expenses.length})', child: Column(
            children: expenses.map((i) => _SummaryRow(
              '${i['name']} · ${i['expense_date']}',
              tshFromDouble((i['tax_amount'] as num?) ?? 0),
            )).toList(),
          )),
        if (bills.isNotEmpty)
          _Panel(title: 'Input VAT — Vendor Bills (${bills.length})', child: Column(
            children: bills.map((i) => _SummaryRow(
              '${i['bill_number']} · ${i['issue_date']}',
              tshFromDouble((i['tax_amount'] as num?) ?? 0),
            )).toList(),
          )),
      ]),
    );
  }
}

// ── P&L ────────────────────────────────────────────────────────────────────────

class _PlTab extends StatelessWidget {
  const _PlTab({required this.data, required this.pad});
  final Map<String, dynamic> data;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final byCategory = (data['expenses_by_category'] as List? ?? []);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Panel(title: '${_s(data, 'period_from')} → ${_s(data, 'period_to')}', child: Column(children: [
          _SummaryRow('Revenue', tshFromDouble(_n(data, 'revenue')), color: AppColors.teal),
          _SummaryRow('COGS', tshFromDouble(_n(data, 'cogs')), color: AppColors.coral),
          _Divider(),
          _SummaryRow('Gross Profit', tshFromDouble(_n(data, 'gross_profit')), bold: true),
          _SummaryRow('Total Expenses', tshFromDouble(_n(data, 'total_expenses')), color: AppColors.coral),
          _Divider(),
          _SummaryRow('Net Profit', tshFromDouble(_n(data, 'net_profit')), bold: true, big: true,
              color: _n(data, 'net_profit') >= 0 ? AppColors.teal : AppColors.coral),
          const SizedBox(height: 8),
        ])),
        if (byCategory.isNotEmpty)
          _Panel(title: 'Expenses by Category', child: Column(
            children: byCategory.map((e) => _SummaryRow(e['category'] as String? ?? '—', tshFromDouble((e['total'] as num?) ?? 0))).toList(),
          )),
      ]),
    );
  }
}

// ── Trial Balance ──────────────────────────────────────────────────────────────

class _TrialBalanceTab extends StatelessWidget {
  const _TrialBalanceTab({required this.data, required this.pad});
  final Map<String, dynamic> data;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final accounts = (data['accounts'] as List? ?? []);
    final balanced = data['balanced'] == true;
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Panel(
          title: 'Trial Balance',
          trailing: _BalancedBadge(balanced: balanced),
          child: Table(
            columnWidths: const {0: FixedColumnWidth(70), 1: FlexColumnWidth(2.5), 2: FlexColumnWidth(1.2), 3: FlexColumnWidth(1.2)},
            children: [
              TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
                children: ['Code', 'Account', 'Debit', 'Credit'].map((h) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(h.toUpperCase(), style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
                )).toList(),
              ),
              ...accounts.map((a) => TableRow(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.divider))),
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text(a['code'] as String? ?? '—', style: AppTheme.monoXs)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text(a['name'] as String? ?? '—', style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text(
                    ((a['debit'] as num?) ?? 0) > 0 ? tshFromDouble(a['debit'] as num) : '—', style: AppTheme.monoSm.copyWith(fontSize: 12))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text(
                    ((a['credit'] as num?) ?? 0) > 0 ? tshFromDouble(a['credit'] as num) : '—', style: AppTheme.monoSm.copyWith(fontSize: 12))),
                ],
              )),
              TableRow(children: [
                const SizedBox(), Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('Total', style: AppTheme.bodyStrong)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text(tshFromDouble(_n(data, 'total_debit')), style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text(tshFromDouble(_n(data, 'total_credit')), style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _BalancedBadge extends StatelessWidget {
  const _BalancedBadge({required this.balanced});
  final bool balanced;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (balanced ? AppColors.teal : AppColors.coral).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(balanced ? Symbols.check_circle : Symbols.error, size: 13, color: balanced ? AppColors.teal : AppColors.coral),
      const SizedBox(width: 5),
      Text(balanced ? 'Balanced' : 'Out of balance', style: AppTheme.bodySub.copyWith(
          fontSize: 11.5, color: balanced ? AppColors.teal : AppColors.coral, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Balance Sheet ──────────────────────────────────────────────────────────────

class _BalanceSheetTab extends StatelessWidget {
  const _BalanceSheetTab({required this.data, required this.pad});
  final Map<String, dynamic> data;
  final double pad;

  Widget _accountList(List items) => Column(children: items.map((a) => _SummaryRow(
    '${a['code']}  ${a['name']}', tshFromDouble((a['balance'] as num?) ?? 0),
  )).toList());

  @override
  Widget build(BuildContext context) {
    final assets = (data['assets'] as List? ?? []);
    final liabilities = (data['liabilities'] as List? ?? []);
    final equity = (data['equity'] as List? ?? []);
    final balanced = data['balanced'] == true;
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Panel(title: 'Assets', trailing: _BalancedBadge(balanced: balanced), child: Column(children: [
          _accountList(assets),
          _Divider(),
          _SummaryRow('Total Assets', tshFromDouble(_n(data, 'total_assets')), bold: true, big: true, color: AppColors.teal),
          const SizedBox(height: 8),
        ])),
        _Panel(title: 'Liabilities', child: Column(children: [
          if (liabilities.isEmpty) _SummaryRow('No liabilities recorded', ''),
          _accountList(liabilities),
          _Divider(),
          _SummaryRow('Total Liabilities', tshFromDouble(_n(data, 'total_liabilities')), bold: true, color: AppColors.coral),
          const SizedBox(height: 8),
        ])),
        _Panel(title: 'Equity', child: Column(children: [
          _accountList(equity),
          _SummaryRow('Current Period Earnings (unclosed)', tshFromDouble(_n(data, 'current_period_earnings')), color: AppColors.amber),
          _Divider(),
          _SummaryRow('Total Equity', tshFromDouble(_n(data, 'total_equity')), bold: true, big: true, color: AppColors.blue),
          const SizedBox(height: 8),
        ])),
      ]),
    );
  }
}

// ── AR Aging ───────────────────────────────────────────────────────────────────

class _ArAgingTab extends StatelessWidget {
  const _ArAgingTab({required this.data, required this.pad});
  final Map<String, dynamic> data;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final buckets = (data['buckets'] as Map?) ?? {};
    final invoices = (data['invoices'] as List? ?? []);
    const bucketLabels = {
      'current': 'Current', 'days_1_30': '1-30 days', 'days_31_60': '31-60 days',
      'days_61_90': '61-90 days', 'days_90_plus': '90+ days',
    };
    final bucketColors = {
      'current': AppColors.teal, 'days_1_30': AppColors.blue, 'days_31_60': AppColors.amber,
      'days_61_90': AppColors.coral, 'days_90_plus': AppColors.violet,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Panel(title: 'Outstanding: ${tshFromDouble(_n(data, 'total_outstanding'))}', child: Column(
          children: bucketLabels.entries.map((e) => _SummaryRow(
            e.value, tshFromDouble((buckets[e.key] as num?) ?? 0), color: bucketColors[e.key],
          )).toList(),
        )),
        _Panel(title: 'Outstanding Invoices (${invoices.length})', child: invoices.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20), child: Text('Nothing outstanding', style: TextStyle(color: context.pal.textMute)))
            : Column(children: invoices.map((i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i['invoice_number']}', style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
                    Text('${i['client_name']}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
                  ])),
                  Text('${i['days_overdue']}d', style: AppTheme.monoXs.copyWith(color: bucketColors[i['bucket']] ?? context.pal.textMute)),
                  const SizedBox(width: 12),
                  Text(tshFromDouble((i['balance_due'] as num?) ?? 0), style: AppTheme.monoSm.copyWith(fontSize: 12, color: AppColors.coral)),
                ]),
              )).toList()),
        ),
      ]),
    );
  }
}

// ── AP Aging ───────────────────────────────────────────────────────────────────

class _ApAgingTab extends StatelessWidget {
  const _ApAgingTab({required this.data, required this.pad});
  final Map<String, dynamic> data;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final buckets = (data['buckets'] as Map?) ?? {};
    final bills = (data['bills'] as List? ?? []);
    const bucketLabels = {
      'current': 'Current', 'days_1_30': '1-30 days', 'days_31_60': '31-60 days',
      'days_61_90': '61-90 days', 'days_90_plus': '90+ days',
    };
    final bucketColors = {
      'current': AppColors.teal, 'days_1_30': AppColors.blue, 'days_31_60': AppColors.amber,
      'days_61_90': AppColors.coral, 'days_90_plus': AppColors.violet,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Panel(title: 'Outstanding: ${tshFromDouble(_n(data, 'total_outstanding'))}', child: Column(
          children: bucketLabels.entries.map((e) => _SummaryRow(
            e.value, tshFromDouble((buckets[e.key] as num?) ?? 0), color: bucketColors[e.key],
          )).toList(),
        )),
        _Panel(title: 'Outstanding Bills (${bills.length})', child: bills.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20), child: Text('Nothing outstanding', style: TextStyle(color: context.pal.textMute)))
            : Column(children: bills.map((b) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${b['bill_number']}', style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
                    Text('${b['supplier_name']}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
                  ])),
                  Text('${b['days_overdue']}d', style: AppTheme.monoXs.copyWith(color: bucketColors[b['bucket']] ?? context.pal.textMute)),
                  const SizedBox(width: 12),
                  Text(tshFromDouble((b['balance_due'] as num?) ?? 0), style: AppTheme.monoSm.copyWith(fontSize: 12, color: AppColors.coral)),
                ]),
              )).toList()),
        ),
      ]),
    );
  }
}

// ── Stock Valuation ────────────────────────────────────────────────────────────

class _StockValuationTab extends StatelessWidget {
  const _StockValuationTab({required this.data, required this.pad});
  final Map<String, dynamic> data;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final byCategory = (data['by_category'] as List? ?? []);
    final items = (data['items'] as List? ?? []);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Panel(title: 'Stock Value as at ${_s(data, 'as_of')}', child: Column(children: [
          _SummaryRow('Items in Stock', '${_n(data, 'item_count').toInt()}'),
          _Divider(),
          _SummaryRow('Total Stock Value', tshFromDouble(_n(data, 'total_value')), bold: true, big: true, color: AppColors.teal),
          const SizedBox(height: 8),
        ])),
        if (byCategory.isNotEmpty)
          _Panel(title: 'By Category', child: Column(
            children: byCategory.map((c) => _SummaryRow(
              c['category'] as String? ?? 'Uncategorized', tshFromDouble((c['total'] as num?) ?? 0),
            )).toList(),
          )),
        _Panel(title: 'Items (${items.length})', child: items.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20), child: Text('No stock on hand', style: TextStyle(color: context.pal.textMute)))
            : Column(children: items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i['name']}', style: AppTheme.bodySm.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${i['sku']} · ${i['qty']} ${i['uom'] ?? ''}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
                  ])),
                  Text(tshFromDouble((i['stock_value'] as num?) ?? 0), style: AppTheme.monoSm.copyWith(fontSize: 12)),
                ]),
              )).toList()),
        ),
      ]),
    );
  }
}

// ── Cash Flow ──────────────────────────────────────────────────────────────────

class _CashFlowTab extends StatelessWidget {
  const _CashFlowTab({required this.data, required this.pad});
  final Map<String, dynamic> data;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final byMethod = (data['cash_in_by_method'] as List? ?? []);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Panel(title: '${_s(data, 'period_from')} → ${_s(data, 'period_to')}', child: Column(children: [
          _SummaryRow('Cash In', tshFromDouble(_n(data, 'cash_in')), color: AppColors.teal),
          _SummaryRow('Cash Out — Expenses', tshFromDouble(_n(data, 'cash_out_expenses')), color: AppColors.coral),
          _SummaryRow('Cash Out — Vendor Bills', tshFromDouble(_n(data, 'cash_out_vendor_bills')), color: AppColors.coral),
          _Divider(),
          _SummaryRow('Net Cash Flow', tshFromDouble(_n(data, 'net_cash_flow')), bold: true, big: true,
              color: _n(data, 'net_cash_flow') >= 0 ? AppColors.teal : AppColors.coral),
          const SizedBox(height: 8),
        ])),
        if (byMethod.isNotEmpty)
          _Panel(title: 'Cash In by Method', child: Column(
            children: byMethod.map((m) => _SummaryRow(m['method'] as String? ?? '—', tshFromDouble((m['total'] as num?) ?? 0))).toList(),
          )),
      ]),
    );
  }
}
