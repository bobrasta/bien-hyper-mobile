import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show userRoleNotifier, hasAccountantAuthority;
import '../../services/receivables_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/phone_layout.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';
import '../../widgets/common/period_filter.dart';
import '../../widgets/common/sliver_table.dart';

// Credit sales / hire purchase tracking, the way Clickhuduma did it: a credit
// sale is an invoice that isn't fully paid (its payment term sets the due
// date) and instalments are payments recorded as they come in. This screen
// is Clickhuduma's Customer report (who owes what) with a statement per
// customer (its contact ledger) and a lump "Pay due".

String _d(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _i(dynamic v) => (v as num? ?? 0).toInt();

Color _overdueColor(int days) => days == 0 ? AppColors.green : days <= 30 ? AppColors.amber : AppColors.coral;

class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key});
  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  Map<String, dynamic>? _data = ReceivablesService.cachedDefault;
  bool _loading = ReceivablesService.cachedDefault == null;
  String? _error;
  String _search = '';
  Period _period = Period.defaultPeriod;
  static const _batch = 120;
  int _showCount = _batch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { if (_data == null) _loading = true; _error = null; });
    try {
      final d = await ReceivablesService.instance.list(dateFrom: _period.fromIso, dateTo: _period.toIso);
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _rows {
    final all = ((_data?['data'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) => '${c['client_name']}'.toLowerCase().contains(q) || '${c['tin'] ?? ''}'.contains(q)).toList();
  }

  Future<void> _openStatement(Map<String, dynamic> c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerStatementScreen(
      hospitalId: c['hospital_id'] == null ? null : _i(c['hospital_id']),
      clientName: '${c['client_name']}',
    )));
    _load();
  }

  Future<void> _payDue(Map<String, dynamic> c) async {
    final paid = await showPayDueDialog(context,
        hospitalId: c['hospital_id'] == null ? null : _i(c['hospital_id']),
        clientName: '${c['client_name']}', owed: _i(c['balance']));
    if (paid == true) _load();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, cst) {
    final pad = cst.maxWidth < 560 ? 16.0 : 26.0;
    final phone = isPhoneWidth(cst.maxWidth);
    final s = (_data?['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rows = _rows;
    final rate = s['collection_rate'];
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(width: 2, height: 36, decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Credit & Receivables', style: AppTheme.pageTitle.copyWith(fontSize: 23)),
            const SizedBox(height: 3),
            Text('Credit sales and hire purchase — who owes what, and every payment against it',
                style: AppTheme.bodySub.copyWith(fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 16),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null && _data == null
                ? ErrorView(message: _error!, onRetry: _load)
                : CustomScrollView(slivers: [
                    SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Container(
                        decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
                        child: phone ? PhoneStatGrid(children: [
                          _stat('Outstanding', tshFromDouble(_i(s['outstanding']).toDouble()), AppColors.amber,
                              '${_i(s['open_invoices'])} open · ${_i(s['customers_owing'])} customers'),
                          _stat('Overdue', tshFromDouble(_i(s['overdue']).toDouble()), AppColors.coral,
                              'past due date', border: true),
                          _stat('No payment yet', '${_i(s['no_payment_invoices'])}', context.pal.text,
                              'never paid anything'),
                          _stat('Collected · ${_period.label}', tshFromDouble(_i(s['collected']).toDouble()), AppColors.green,
                              rate == null ? 'nothing billed' : '$rate% of billed', border: true),
                        ]) : Row(children: [
                          Expanded(child: _stat('Outstanding', tshFromDouble(_i(s['outstanding']).toDouble()), AppColors.amber,
                              '${_i(s['open_invoices'])} open invoices · ${_i(s['customers_owing'])} customers')),
                          Expanded(child: _stat('Overdue', tshFromDouble(_i(s['overdue']).toDouble()), AppColors.coral,
                              'past their due date', border: true)),
                          Expanded(child: _stat('No payment yet', '${_i(s['no_payment_invoices'])}', context.pal.text,
                              'credit invoices never paid anything', border: true)),
                          Expanded(child: _stat('Collected · ${_period.label}', tshFromDouble(_i(s['collected']).toDouble()), AppColors.green,
                              rate == null ? 'nothing billed in period' : '$rate% of ${tshFromDouble(_i(s['billed']).toDouble())} billed', border: true)),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      if (phone) ...[
                        SearchField(hint: 'Search customer or TIN…',
                            onChanged: (v) => setState(() { _search = v; _showCount = _batch; })),
                        const SizedBox(height: 10),
                        Row(children: [
                          PeriodSelector(value: _period, onChanged: (p) { setState(() => _period = p); _load(); }),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Period applies to “Collected”; balances are as of today',
                              style: AppTheme.bodySub.copyWith(fontSize: 11))),
                        ]),
                      ] else Row(children: [
                        PeriodSelector(value: _period, onChanged: (p) { setState(() => _period = p); _load(); }),
                        const SizedBox(width: 8),
                        SearchField(width: 280, hint: 'Search customer or TIN…',
                            onChanged: (v) => setState(() { _search = v; _showCount = _batch; })),
                        const Spacer(),
                        Text('Period applies to “Collected”; balances are always as of today',
                            style: AppTheme.bodySub.copyWith(fontSize: 11)),
                      ]),
                      const SizedBox(height: 14),
                    ])),
                    if (phone) ..._phoneCards(context, rows) else ..._table(context, rows, pad: 0),
                  ])),
      ]),
    );
  });

  Widget _stat(String label, String value, Color color, String note, {bool border = false}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: border ? BoxDecoration(border: Border(left: BorderSide(color: context.pal.divider))) : null,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 7),
      Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 19, color: color)),
      const SizedBox(height: 6),
      Text(note, style: AppTheme.bodySub.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );

  static const _fName = 5, _fNum = 2, _fMoney = 3, _fDue = 3;

  Widget _h(String t, {TextAlign a = TextAlign.left}) =>
      Text(t, textAlign: a, maxLines: 1, style: AppTheme.labelCaps.copyWith(fontSize: 10, letterSpacing: 1.1));

  /// Phone list: one card per customer — balance as the headline, overdue
  /// days as the badge, the rest as meta; tap opens the statement.
  List<Widget> _phoneCards(BuildContext context, List<Map<String, dynamic>> rows) {
    final canPay = hasAccountantAuthority(userRoleNotifier.value);
    final shown = _showCount < rows.length ? _showCount : rows.length;
    if (rows.isEmpty) {
      return [SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Nobody owes anything 🎉', style: AppTheme.bodySub))))];
    }
    return [
      SliverList(delegate: SliverChildBuilderDelegate((context, i) {
        final c = rows[i];
        final days = _i(c['max_days_overdue']);
        return PhoneRecordCard(
          margin: const EdgeInsets.only(bottom: 8),
          title: '${c['client_name']}',
          subtitle: c['tin'] != null ? 'TIN ${c['tin']}' : (c['phone'] ?? '').toString(),
          badge: PhonePill(days == 0 ? 'Not yet due' : '$days days late', _overdueColor(days)),
          meta: [
            '${_i(c['open_invoices'])} open',
            'paid ${tshFromDouble(_i(c['paid']).toDouble())}',
            'last ${_d(c['last_payment_at'] as String?)}',
          ],
          onTap: () => _openStatement(c),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(tshFromDouble(_i(c['balance']).toDouble()),
                style: AppTheme.bodyStrong.copyWith(fontSize: 14, color: AppColors.amber)),
            if (canPay) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _payDue(c),
                style: OutlinedButton.styleFrom(minimumSize: const Size(64, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('Pay', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ]),
        );
      }, childCount: shown)),
      if (rows.length > shown)
        SliverToBoxAdapter(child: LoadMoreRow(
          shown: shown, total: rows.length, step: _batch,
          onTap: () => setState(() => _showCount += _batch))),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  List<Widget> _table(BuildContext context, List<Map<String, dynamic>> rows, {required double pad}) {
    final canPay = hasAccountantAuthority(userRoleNotifier.value);
    final shown = _showCount < rows.length ? _showCount : rows.length;
    return sliverTable(
      context,
      pad: pad,
      headerHeight: 42,
      header: Container(
        height: 42, padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(children: [
          Expanded(flex: _fName, child: _h('CUSTOMER')),
          Expanded(flex: _fNum, child: _h('OPEN', a: TextAlign.right)),
          Expanded(flex: _fMoney, child: _h('BILLED', a: TextAlign.right)),
          Expanded(flex: _fMoney, child: _h('PAID', a: TextAlign.right)),
          Expanded(flex: _fMoney, child: _h('BALANCE', a: TextAlign.right)),
          const SizedBox(width: 18),
          Expanded(flex: _fDue, child: _h('OVERDUE')),
          Expanded(flex: _fDue, child: _h('LAST PAYMENT')),
          SizedBox(width: canPay ? 96 : 0),
        ]),
      ),
      itemCount: shown,
      totalCount: rows.length,
      loadStep: _batch,
      onLoadMore: () => setState(() => _showCount += _batch),
      emptyText: 'Nobody owes anything 🎉',
      itemBuilder: (context, i) {
        final c = rows[i];
        final days = _i(c['max_days_overdue']);
        final money = AppTheme.monoSm.copyWith(fontSize: 12.5);
        return InkWell(
          onTap: () => _openStatement(c),
          child: Container(
            height: 60, padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              Expanded(flex: _fName, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c['client_name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(fontSize: 13.5, color: context.pal.text)),
                Text(c['tin'] != null ? 'TIN ${c['tin']}' : (c['phone'] ?? '—').toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: context.pal.textMute)),
              ])),
              Expanded(flex: _fNum, child: Text('${_i(c['open_invoices'])}', textAlign: TextAlign.right, style: money)),
              Expanded(flex: _fMoney, child: Text(tshFromDouble(_i(c['billed']).toDouble()), textAlign: TextAlign.right, style: money.copyWith(color: context.pal.textDim))),
              Expanded(flex: _fMoney, child: Text(tshFromDouble(_i(c['paid']).toDouble()), textAlign: TextAlign.right, style: money.copyWith(color: AppColors.green))),
              Expanded(flex: _fMoney, child: Text(tshFromDouble(_i(c['balance']).toDouble()), textAlign: TextAlign.right,
                  style: money.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600))),
              const SizedBox(width: 18),
              Expanded(flex: _fDue, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(days == 0 ? 'Not yet due' : '$days days', style: AppTheme.bodySm.copyWith(fontSize: 12, color: _overdueColor(days))),
                if (_i(c['overdue_balance']) > 0)
                  Text(tshFromDouble(_i(c['overdue_balance']).toDouble()), style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: context.pal.textMute)),
              ])),
              Expanded(flex: _fDue, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_d(c['last_payment_at'] as String?), style: AppTheme.bodySm.copyWith(fontSize: 12)),
                if (_i(c['no_payment_invoices']) > 0)
                  Text('${_i(c['no_payment_invoices'])} never paid', style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: AppColors.coral)),
              ])),
              if (canPay)
                SizedBox(width: 96, child: Align(alignment: Alignment.centerRight, child: OutlinedButton(
                  onPressed: () => _payDue(c),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(80, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: const Text('Pay due', style: TextStyle(fontSize: 12)),
                ))),
            ]),
          ),
        );
      },
    );
  }
}

// ── Customer statement (Clickhuduma's contact ledger) ─────────────────────────

class CustomerStatementScreen extends StatefulWidget {
  const CustomerStatementScreen({super.key, this.hospitalId, required this.clientName});
  final int? hospitalId;
  final String clientName;
  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  Period _period = Period.defaultPeriod;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _data == null; _error = null; });
    try {
      final d = await ReceivablesService.instance.statement(
          hospitalId: widget.hospitalId, clientName: widget.clientName, dateFrom: _period.fromIso, dateTo: _period.toIso);
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _payDue() async {
    final paid = await showPayDueDialog(context, hospitalId: widget.hospitalId,
        clientName: widget.clientName, owed: _i(_data?['balance_due']));
    if (paid == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final cust = (d?['customer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final canPay = hasAccountantAuthority(userRoleNotifier.value) && _i(d?['balance_due']) > 0;
    return Scaffold(
      backgroundColor: context.pal.bg,
      appBar: AppBar(
        backgroundColor: context.pal.surface1, foregroundColor: context.pal.text, elevation: 0,
        surfaceTintColor: Colors.transparent, titleSpacing: 4,
        title: Text('Statement · ${widget.clientName}', style: AppTheme.bodyStrong.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis),
        actions: [
          PeriodSelector(value: _period, onChanged: (p) { setState(() => _period = p); _load(); }),
          const SizedBox(width: 8),
          if (canPay) FilledButton.icon(onPressed: _payDue, icon: const Icon(Symbols.payments, size: 15), label: const Text('Pay due')),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null && d == null
              ? ErrorView(message: _error!, onRetry: _load)
              : ListView(padding: const EdgeInsets.all(20), children: [
                  _customerCard(context, cust, d!),
                  const SizedBox(height: 14),
                  _openInvoices(context, ((d['open_invoices'] as List?) ?? const []).cast<Map<String, dynamic>>()),
                  const SizedBox(height: 14),
                  _ledger(context, d),
                ]),
    );
  }

  BoxDecoration _card(BuildContext context) => BoxDecoration(
      color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border));

  Widget _customerCard(BuildContext context, Map<String, dynamic> c, Map<String, dynamic> d) {
    Widget kv(String k, String? v) => Padding(
      padding: const EdgeInsets.only(right: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
        const SizedBox(height: 4),
        Text(v == null || v.isEmpty ? '—' : v, style: AppTheme.bodySm.copyWith(fontSize: 12.5, color: context.pal.text)),
      ]),
    );
    Widget money(String k, int v, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(k.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
      const SizedBox(height: 4),
      Text(tshFromDouble(v.toDouble()), style: AppTheme.kpiValue.copyWith(fontSize: 17, color: color)),
    ]);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(context),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Wrap(runSpacing: 10, children: [
          kv('TIN', c['tin'] as String?), kv('Phone', c['phone'] as String?),
          kv('Email', c['email'] as String?), kv('Address', c['address'] as String?),
        ])),
        money('Opening', _i(d['opening_balance']), context.pal.textDim),
        const SizedBox(width: 22),
        money('Invoiced', _i(d['total_invoiced']), context.pal.text),
        const SizedBox(width: 22),
        money('Paid', _i(d['total_paid']), AppColors.green),
        const SizedBox(width: 22),
        money('Balance due', _i(d['balance_due']), AppColors.amber),
      ]),
    );
  }

  Widget _openInvoices(BuildContext context, List<Map<String, dynamic>> rows) => Container(
    decoration: _card(context),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Text('OPEN CREDIT INVOICES · ${rows.length}', style: AppTheme.labelCaps.copyWith(fontSize: 11)),
      ),
      if (rows.isEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: Text('Everything is paid.', style: AppTheme.bodySub)),
      for (final r in rows)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.divider))),
          child: Row(children: [
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['invoice_number']}', style: AppTheme.monoSm.copyWith(fontSize: 12.5, color: context.pal.text)),
              Text('Issued ${_d(r['issue_date'] as String?)}${r['pay_term'] != null ? ' · ${r['pay_term']}' : ''}',
                  style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
            ])),
            Expanded(flex: 3, child: _progress(context, _i(r['paid']), _i(r['total']))),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: Text(tshFromDouble(_i(r['balance']).toDouble()), textAlign: TextAlign.right,
                style: AppTheme.monoSm.copyWith(fontSize: 12.5, color: AppColors.amber))),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_i(r['days_overdue']) == 0 ? 'Due ${_d(r['due_date'] as String?)}' : '${_i(r['days_overdue'])} days overdue',
                  style: AppTheme.bodySm.copyWith(fontSize: 12, color: _overdueColor(_i(r['days_overdue'])))),
              Text(_i(r['payments_count']) == 0
                      ? 'No payment yet'
                      : '${_i(r['payments_count'])} instalment${_i(r['payments_count']) == 1 ? '' : 's'} · last ${_d(r['last_payment_at'] as String?)}',
                  style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
            ])),
          ]),
        ),
    ]),
  );

  Widget _progress(BuildContext context, int paid, int total) {
    final pct = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${tshFromDouble(paid.toDouble())} of ${tshFromDouble(total.toDouble())} · ${(pct * 100).toStringAsFixed(0)}%',
          style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
      const SizedBox(height: 5),
      ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
        value: pct, minHeight: 5, backgroundColor: context.pal.surface3, valueColor: AlwaysStoppedAnimation(AppColors.green))),
    ]);
  }

  Widget _ledger(BuildContext context, Map<String, dynamic> d) {
    final entries = ((d['entries'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final money = AppTheme.monoSm.copyWith(fontSize: 12);
    Widget row(String date, String ref, String desc, String dr, String cr, String bal, {bool bold = false, Color? refColor}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.divider))),
      child: Row(children: [
        SizedBox(width: 96, child: Text(date, style: AppTheme.bodySm.copyWith(fontSize: 12))),
        SizedBox(width: 140, child: Text(ref, style: AppTheme.monoXs.copyWith(fontSize: 11, color: refColor ?? context.pal.text))),
        Expanded(child: Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.bodySub.copyWith(fontSize: 11.5))),
        SizedBox(width: 130, child: Text(dr, textAlign: TextAlign.right, style: money)),
        SizedBox(width: 130, child: Text(cr, textAlign: TextAlign.right, style: money.copyWith(color: AppColors.green))),
        SizedBox(width: 140, child: Text(bal, textAlign: TextAlign.right,
            style: money.copyWith(color: AppColors.amber, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
      ]),
    );
    String t(int v) => v == 0 ? '' : tshFromDouble(v.toDouble());
    return Container(
      decoration: _card(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('STATEMENT · ${_period.label.toUpperCase()}', style: AppTheme.labelCaps.copyWith(fontSize: 11)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            SizedBox(width: 96, child: Text('DATE', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            SizedBox(width: 140, child: Text('REF', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            Expanded(child: Text('DETAILS', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            SizedBox(width: 130, child: Text('INVOICED', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            SizedBox(width: 130, child: Text('PAID', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            SizedBox(width: 140, child: Text('BALANCE', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
          ]),
        ),
        row(_d(d['period']?['from'] as String?), '', 'Opening balance', '', '', tshFromDouble(_i(d['opening_balance']).toDouble()), bold: true),
        for (final e in entries)
          row(_d(e['date'] as String?), '${e['ref']}', '${e['description']}', t(_i(e['debit'])), t(_i(e['credit'])),
              tshFromDouble(_i(e['balance']).toDouble()),
              refColor: e['type'] == 'invoice' ? null : AppColors.green),
        row('', '', 'Closing balance', tshFromDouble(_i(d['total_invoiced']).toDouble()), tshFromDouble(_i(d['total_paid']).toDouble()),
            tshFromDouble(_i(d['closing_balance']).toDouble()), bold: true),
      ]),
    );
  }
}

// ── Lump "Pay due" (oldest invoices first) ────────────────────────────────────

Future<bool?> showPayDueDialog(BuildContext context, {int? hospitalId, required String clientName, required int owed}) =>
    showDialog<bool>(context: context, builder: (_) => _PayDueDialog(hospitalId: hospitalId, clientName: clientName, owed: owed));

class _PayDueDialog extends StatefulWidget {
  const _PayDueDialog({this.hospitalId, required this.clientName, required this.owed});
  final int? hospitalId;
  final String clientName;
  final int owed;
  @override
  State<_PayDueDialog> createState() => _PayDueDialogState();
}

class _PayDueDialogState extends State<_PayDueDialog> {
  late final _amountCtrl = TextEditingController(text: '${widget.owed}');
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _method = 'bank_transfer';
  DateTime _paidAt = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _amountCtrl.dispose(); _refCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) { setState(() => _error = 'Enter the amount received'); return; }
    if (amount > widget.owed) { setState(() => _error = 'They only owe ${tshFromDouble(widget.owed.toDouble())}'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await ReceivablesService.instance.pay(
        hospitalId: widget.hospitalId, clientName: widget.clientName, amount: amount, method: _method,
        paidAt: _iso(_paidAt), reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      final n = ((res['data'] as List?) ?? const []).length;
      if (mounted) {
        showSuccessToast(context, 'Payment applied to $n invoice${n == 1 ? '' : 's'} · ${tshFromDouble(_i(res['remaining_balance']).toDouble())} still owed');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyError(e); });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    title: Text('Pay due · ${widget.clientName}', style: AppTheme.bodyStrong),
    content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Owes ${tshFromDouble(widget.owed.toDouble())}. The payment is applied to their oldest invoices first.',
          style: AppTheme.bodySub.copyWith(fontSize: 12)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: LabeledTextField(label: 'Amount received *', controller: _amountCtrl, keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: LabeledDateField(label: 'Date *', date: _paidAt, onTap: () async {
          final d = await showDatePicker(context: context, initialDate: _paidAt, firstDate: DateTime(2020), lastDate: DateTime.now());
          if (d != null) setState(() => _paidAt = d);
        })),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: LabeledDropdown<String>(label: 'Method', value: _method,
          items: const ['bank_transfer', 'cash', 'mobile_money', 'cheque'],
          displayBuilder: (v) => const {'bank_transfer': 'Bank transfer', 'cash': 'Cash', 'mobile_money': 'Mobile money', 'cheque': 'Cheque'}[v]!,
          onChanged: (v) => setState(() => _method = v))),
        const SizedBox(width: 12),
        Expanded(child: LabeledTextField(label: 'Reference', controller: _refCtrl, hint: 'Bank ref / cheque no.')),
      ]),
      const SizedBox(height: 12),
      LabeledTextField(label: 'Notes', controller: _notesCtrl, maxLines: 2),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.coral)),
      ],
    ])),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _saving ? null : _save, child: _saving
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('Record payment')),
    ],
  );
}
