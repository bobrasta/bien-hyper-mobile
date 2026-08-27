import 'package:flutter/material.dart';
import '../../models/chart_of_account.dart';
import '../../services/accounting_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/error_view.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  List<ChartOfAccount> _accounts = [];
  List<LedgerEntry>    _journal  = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        AccountingService.instance.accounts(),
        AccountingService.instance.journal(),
      ]);
      if (!mounted) return;
      setState(() {
        _accounts = results[0] as List<ChartOfAccount>;
        _journal  = results[1] as List<LedgerEntry>;
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
      return Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chart of Accounts & Journal', style: AppTheme.pageTitle),
              const SizedBox(height: 4),
              Text('Ledger accounts and posting history', style: AppTheme.bodySub),
            ])),
          ]),
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
            labelColor: AppColors.teal,
            unselectedLabelColor: context.pal.textMute,
            indicatorColor: AppColors.teal,
            indicatorWeight: 2,
            labelStyle: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
            unselectedLabelStyle: AppTheme.bodySm,
            tabs: const [Tab(text: 'Accounts'), Tab(text: 'Journal')],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tab,
                      children: [
                        _AccountsTab(accounts: _accounts, pad: pad),
                        _JournalTab(entries: _journal, pad: pad),
                      ],
                    ),
        ),
      ]);
    });
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({required this.accounts, required this.pad});
  final List<ChartOfAccount> accounts;
  final double pad;

  static const _order = ['asset', 'liability', 'equity', 'revenue', 'expense'];
  static const _labels = {
    'asset': 'Assets', 'liability': 'Liabilities', 'equity': 'Equity',
    'revenue': 'Revenue', 'expense': 'Expenses',
  };

  Color _colorFor(String type) => switch (type) {
    'asset'     => AppColors.teal,
    'liability' => AppColors.coral,
    'equity'    => AppColors.blue,
    'revenue'   => AppColors.amber,
    'expense'   => AppColors.violet,
    _           => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    final byType = <String, List<ChartOfAccount>>{};
    for (final a in accounts) {
      byType.putIfAbsent(a.categoryType, () => []).add(a);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final type in _order)
            if (byType[type] != null) ...[
              _CategorySection(
                title: _labels[type]!,
                color: _colorFor(type),
                accounts: byType[type]!,
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.title, required this.color, required this.accounts});
  final String title;
  final Color color;
  final List<ChartOfAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<int>(0, (s, a) => s + a.balance);
    return Container(
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(title, style: AppTheme.cardTitle),
            const Spacer(),
            Text(tshFromDouble(total), style: AppTheme.monoSm.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
        ...accounts.map((a) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.divider))),
          child: Row(children: [
            SizedBox(width: 60, child: Text(a.code, style: AppTheme.monoXs.copyWith(color: context.pal.textMute))),
            Expanded(child: Text(a.name, style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
            if (a.status != 'active')
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text('inactive', style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: context.pal.textDim)),
              ),
            Text(tshFromDouble(a.balance), style: AppTheme.monoSm.copyWith(fontSize: 12.5)),
          ]),
        )),
      ]),
    );
  }
}

class _JournalTab extends StatelessWidget {
  const _JournalTab({required this.entries, required this.pad});
  final List<LedgerEntry> entries;
  final double pad;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(child: Text('No postings yet', style: TextStyle(color: context.pal.textMute)));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Container(
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(90),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2.5),
            3: FlexColumnWidth(1.3),
            4: FlexColumnWidth(1.3),
            5: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
              children: ['Account', 'Description', 'Reference', 'Debit', 'Credit', 'Date'].map((h) =>
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(h.toUpperCase(), style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
                )).toList(),
            ),
            ...entries.asMap().entries.map((e) {
              final t = e.value;
              return TableRow(
                decoration: BoxDecoration(
                  border: e.key == entries.length - 1 ? null : Border(bottom: BorderSide(color: context.pal.divider)),
                ),
                children: [
                  _Cell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.accountCode, style: AppTheme.monoXs.copyWith(color: context.pal.textMute)),
                    Text(t.accountName, style: AppTheme.bodySub.copyWith(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                  ])),
                  _Cell(child: Text(t.description ?? '—', style: AppTheme.bodySm.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  _Cell(child: Text(t.reference ?? '—', style: AppTheme.monoXs.copyWith(color: context.pal.textMute))),
                  _Cell(child: Text(t.isDebit ? tshFromDouble(t.amount) : '—',
                      style: AppTheme.monoSm.copyWith(fontSize: 12, color: AppColors.teal))),
                  _Cell(child: Text(!t.isDebit ? tshFromDouble(t.amount) : '—',
                      style: AppTheme.monoSm.copyWith(fontSize: 12, color: AppColors.coral))),
                  _Cell(child: Text(t.createdAt != null ? formatDate(t.createdAt!) : '—', style: AppTheme.monoXs)),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: child,
  );
}
