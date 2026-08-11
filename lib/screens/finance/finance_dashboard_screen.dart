import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/accounting_service.dart';
import '../../services/finance_report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/error_view.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key, this.onNavigateTo});
  final void Function(String key)? onNavigateTo;

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  Map<String, dynamic> _summary   = {};
  Map<String, dynamic> _balance   = {};
  Map<String, dynamic> _arAging   = {};
  Map<String, dynamic> _cashFlow  = {};
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
      final results = await Future.wait([
        AccountingService.instance.summary(),
        FinanceReportService.instance.balanceSheet(),
        FinanceReportService.instance.arAging(),
        FinanceReportService.instance.cashFlow(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary  = results[0]; _balance = results[1];
        _arAging  = results[2]; _cashFlow = results[3];
        _loading  = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Finance Overview', style: AppTheme.pageTitle),
            const SizedBox(height: 4),
            Text('Ledger position, VAT, and cash movement', style: AppTheme.bodySub),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else ...[
              AdaptiveColumns(
                wideCols: 4, mediumCols: 2, narrowCols: 2,
                children: [
                  _Kpi(label: 'Net Profit (all-time)', value: tshFromDouble((_summary['quick_net_profit'] as num?) ?? 0),
                      icon: Symbols.trending_up, color: AppColors.teal),
                  _Kpi(label: 'Total Assets', value: tshFromDouble((_balance['total_assets'] as num?) ?? 0),
                      icon: Symbols.account_balance, color: AppColors.blue),
                  _Kpi(label: 'AR Outstanding', value: tshFromDouble((_arAging['total_outstanding'] as num?) ?? 0),
                      icon: Symbols.request_quote, color: AppColors.amber),
                  _Kpi(label: 'Cash Flow (this month)', value: tshFromDouble((_cashFlow['net_cash_flow'] as num?) ?? 0),
                      icon: Symbols.payments, color: (((_cashFlow['net_cash_flow'] as num?) ?? 0) >= 0) ? AppColors.teal : AppColors.coral),
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
                child: Row(children: [
                  Icon(_balance['balanced'] == true ? Symbols.check_circle : Symbols.error, size: 18,
                      color: _balance['balanced'] == true ? AppColors.teal : AppColors.coral),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _balance['balanced'] == true
                        ? 'Books are balanced — Assets = Liabilities + Equity'
                        : 'Books are out of balance — check the ledger',
                    style: AppTheme.bodySm,
                  )),
                  Text('Liabilities ${tshFromDouble((_balance['total_liabilities'] as num?) ?? 0)}',
                      style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                  const SizedBox(width: 14),
                  Text('Equity ${tshFromDouble((_balance['total_equity'] as num?) ?? 0)}',
                      style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                ]),
              ),
              const SizedBox(height: 20),
              Text('Quick Links', style: AppTheme.cardTitle),
              const SizedBox(height: 12),
              AdaptiveColumns(
                wideCols: 4, mediumCols: 3, narrowCols: 2,
                children: [
                  _QuickLink(icon: Symbols.receipt_long, label: 'Expenses', onTap: () => widget.onNavigateTo?.call('finance_expenses')),
                  _QuickLink(icon: Symbols.account_balance_wallet, label: 'Vendor Bills', onTap: () => widget.onNavigateTo?.call('finance_bills')),
                  _QuickLink(icon: Symbols.account_balance, label: 'Chart of Accounts', onTap: () => widget.onNavigateTo?.call('finance_ledger')),
                  _QuickLink(icon: Symbols.assessment, label: 'Reports', onTap: () => widget.onNavigateTo?.call('finance_reports')),
                  _QuickLink(icon: Symbols.sync_alt, label: 'Bank Reconciliation', onTap: () => widget.onNavigateTo?.call('finance_bank_rec')),
                ],
              ),
            ],
          ]),
        ),
      );
    });
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
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
        Expanded(child: Text(label.toUpperCase(), style: AppTheme.labelCaps, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 12),
      Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 22, color: color)),
    ]),
  );
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: context.pal.border),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 17, color: AppColors.teal),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTheme.bodySm.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}
