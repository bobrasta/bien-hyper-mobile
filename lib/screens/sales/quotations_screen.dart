import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show userRoleNotifier, hasSalesApprovalAuthority;
import '../../models/inventory_item.dart';
import '../../models/location.dart';
import '../../models/quotation.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';
import '../../services/location_service.dart';
import '../../services/quotation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../utils/pdf_download.dart';
import '../../utils/whatsapp_share.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_view.dart';

// ── Status colours ─────────────────────────────────────────────────────────────
Color _statusColor(String status) => switch (status) {
  'draft'     => AppColors.textDim,
  'sent'      => AppColors.blue,
  'accepted'  => AppColors.teal,
  'rejected'  => AppColors.coral,
  'expired'   => AppColors.amber,
  'converted' => AppColors.violet,
  _           => AppColors.textDim,
};

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtAmount(int tzs) {
  if (tzs >= 1000000) return 'TSh ${(tzs / 1e6).toStringAsFixed(1)}M';
  if (tzs >= 1000)    return 'TSh ${(tzs / 1000).toStringAsFixed(0)}K';
  return 'TSh $tzs';
}

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  List<Quotation> _all      = [];
  List<Quotation> _filtered = [];
  bool            _loading  = true;
  String?         _error;
  String?         _statusFilter;
  bool            _showForm = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await QuotationService.instance.list();
      if (!mounted) return;
      setState(() { _all = data; _loading = false; });
      _applyFilter();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((qt) {
        final matchStatus = _statusFilter == null || qt.status == _statusFilter;
        final matchSearch = q.isEmpty ||
            qt.clientName.toLowerCase().contains(q) ||
            qt.quotationNumber.toLowerCase().contains(q);
        return matchStatus && matchSearch;
      }).toList();
    });
  }

  Future<void> _showDetailModal(Quotation qt) async {
    Quotation full;
    try {
      full = qt.items.isEmpty ? await QuotationService.instance.get(qt.id) : qt;
    } catch (e) {
      if (mounted) showErrorToast(context, e);
      return;
    }
    if (!mounted) return;
    final reload = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _QuotationDetailDialog(qt: full),
    );
    if (reload == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      LayoutBuilder(builder: (ctx, cst) {
        final pad = cst.maxWidth < 560 ? 16.0 : 26.0;
        final converted = _all.where((q) => q.status == 'converted').length;
        final totalQuoted = _all.fold<int>(0, (s, q) => s + q.totalAmount);
        final openValue = _all.where((q) => q.status == 'sent' || q.status == 'accepted').fold<int>(0, (s, q) => s + q.totalAmount);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(width: 2, height: 36, decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Quotations', style: AppTheme.pageTitle.copyWith(fontSize: 23)),
                const SizedBox(height: 3),
                Text('${_all.length} quotations · ${tshFromDouble(totalQuoted)} quoted · $converted converted to orders', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              ])),
              SizedBox(
                width: 220, height: 32,
                child: TextField(
                  controller: _searchCtrl,
                  style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Client or QT number…',
                    hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim, fontSize: 12),
                    prefixIcon: Icon(Symbols.search, size: 15, color: context.pal.textDim),
                    filled: true, fillColor: context.pal.surface1,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: context.pal.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: context.pal.border)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: () => setState(() => _showForm = true), icon: const Icon(Symbols.add, size: 16), label: const Text('New quotation')),
            ]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: _StatusChips(
              current: _statusFilter,
              counts: {for (final s in ['draft', 'sent', 'accepted', 'rejected', 'converted']) s: _all.where((q) => q.status == s).length},
              total: _all.length,
              onChanged: (s) { setState(() { _statusFilter = s; _applyFilter(); }); },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? ErrorView(message: _error!, onRetry: _load)
                      : _QuotationTable(items: _filtered, onSelect: _showDetailModal, openValue: openValue, convertedCount: converted, totalCount: _all.length),
            ),
          ),
        ]);
      }),

      if (_showForm)
        _QuotationFormModal(
          onClose: () => setState(() => _showForm = false),
          onSaved: () { setState(() => _showForm = false); _load(); },
        ),
    ]);
  }
}

// ── Status filter chips ────────────────────────────────────────────────────────

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.current, required this.counts, required this.total, required this.onChanged});
  final String? current;
  final Map<String, int> counts;
  final int total;
  final ValueChanged<String?> onChanged;

  static const _statuses = [
    ('draft', 'Draft'), ('sent', 'Sent'), ('accepted', 'Accepted'),
    ('rejected', 'Rejected'), ('converted', 'Converted'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _chip(context, null, 'All', total),
        const SizedBox(width: 8),
        ...(_statuses.expand((s) => [_chip(context, s.$1, s.$2, counts[s.$1] ?? 0), const SizedBox(width: 8)])),
      ],
    ),
  );

  Widget _chip(BuildContext ctx, String? value, String label, int count) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onChanged(active ? null : value),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.green.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? AppColors.green.withValues(alpha: 0.5) : ctx.pal.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AppTheme.bodySm.copyWith(fontSize: 12, color: active ? AppColors.green : ctx.pal.textMute)),
          const SizedBox(width: 6),
          Text('$count', style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: active ? AppColors.green : ctx.pal.textDim)),
        ]),
      ),
    );
  }
}

// ── Quotation table ────────────────────────────────────────────────────────────

class _QuotationTable extends StatelessWidget {
  const _QuotationTable({required this.items, required this.onSelect, required this.openValue, required this.convertedCount, required this.totalCount});
  final List<Quotation> items;
  final ValueChanged<Quotation> onSelect;
  final int openValue;
  final int convertedCount;
  final int totalCount;

  String _validNote(Quotation qt) {
    if (qt.status == 'converted') return 'order raised';
    if (qt.validUntil == null) return '';
    final d = DateTime.tryParse(qt.validUntil!);
    if (d == null) return '';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return 'expired';
    return 'in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (s, q) => s + q.totalAmount);
    return Container(
      decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          height: 38, padding: const EdgeInsets.symmetric(horizontal: 16),
          color: context.pal.surface2,
          child: Row(children: [
            SizedBox(width: 130, child: Text('QT NUMBER', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            Expanded(flex: 3, child: Text('CLIENT', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            Expanded(child: Text('AMOUNT', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            Expanded(child: Text('STATUS', textAlign: TextAlign.right, style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            Expanded(child: Text('CREATED', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            Expanded(child: Text('VALID UNTIL', style: AppTheme.labelCaps.copyWith(fontSize: 9.5))),
            const SizedBox(width: 56),
          ]),
        ),
        Expanded(child: items.isEmpty
            ? Center(child: Text('No quotations found', style: AppTheme.bodySub))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => Container(height: 1, color: context.pal.divider),
                itemBuilder: (_, i) {
                  final qt = items[i];
                  final color = _statusColor(qt.status);
                  final note = _validNote(qt);
                  return GestureDetector(
                    onTap: () => onSelect(qt),
                    child: Container(
                      height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        SizedBox(width: 130, child: Row(children: [
                          Container(width: 3, height: 26, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 9),
                          Expanded(child: Text(qt.quotationNumber, style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: context.pal.textMute))),
                        ])),
                        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [
                            if (qt.needsApproval) ...[Icon(Symbols.hourglass_top, size: 12, color: AppColors.amber), const SizedBox(width: 4)],
                            Flexible(child: Text(qt.clientName, style: AppTheme.bodySm.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                          if (qt.clientContact != null) Text(qt.clientContact!, style: AppTheme.bodySub.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                        Expanded(child: Text(tshFromDouble(qt.totalAmount), textAlign: TextAlign.right, style: AppTheme.monoSm.copyWith(fontSize: 13))),
                        Expanded(child: Align(alignment: Alignment.centerRight, child: _StatusBadge(qt.status, qt.statusLabel))),
                        Expanded(child: Text(qt.createdAt.length >= 10 ? qt.createdAt.substring(0, 10) : qt.createdAt, style: AppTheme.monoXs.copyWith(fontSize: 11, color: context.pal.textDim))),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(qt.validUntil ?? '—', style: AppTheme.monoXs.copyWith(fontSize: 11)),
                          if (note.isNotEmpty) Text(note, style: AppTheme.bodySub.copyWith(fontSize: 10, color: note == 'expired' ? AppColors.coral : context.pal.textDim)),
                        ])),
                        SizedBox(width: 56, child: Align(alignment: Alignment.centerRight, child: OutlinedButton(
                          onPressed: () => onSelect(qt),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 26)),
                          child: Text(qt.status == 'sent' ? 'Chase' : 'View', style: const TextStyle(fontSize: 11)),
                        ))),
                      ]),
                    ),
                  );
                },
              )),
        Container(
          height: 46, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: context.pal.surface2, border: Border(top: BorderSide(color: context.pal.divider))),
          child: Row(children: [
            SizedBox(width: 130, child: Text('TOTAL QUOTED', style: AppTheme.labelCaps.copyWith(fontSize: 10))),
            Expanded(flex: 3, child: Text('$convertedCount of $totalCount converted · ${tshFromDouble(openValue)} of pipeline still open', style: AppTheme.bodySub.copyWith(fontSize: 11))),
            Expanded(child: Text(tshFromDouble(total), textAlign: TextAlign.right, style: AppTheme.bodyStrong.copyWith(fontSize: 13.5))),
            const Expanded(child: SizedBox()), const Expanded(child: SizedBox()), const Expanded(child: SizedBox()), const SizedBox(width: 56),
          ]),
        ),
      ]),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status, this.label);
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Approval banner ──────────────────────────────────────────────────────────

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({
    required this.status, required this.reason, required this.approvedByName,
    required this.onApprove, required this.onReject,
  });
  final String status;
  final String? reason;
  final String? approvedByName;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending'  => AppColors.amber,
      'approved' => AppColors.teal,
      'rejected' => AppColors.coral,
      _          => context.pal.textDim,
    };
    final label = switch (status) {
      'pending'  => 'Awaiting Manager Approval',
      'approved' => 'Approved${approvedByName != null ? ' by $approvedByName' : ''}',
      'rejected' => 'Rejected${approvedByName != null ? ' by $approvedByName' : ''}',
      _          => status,
    };
    final isAdmin = hasSalesApprovalAuthority(userRoleNotifier.value);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(status == 'pending' ? Symbols.hourglass_top
              : status == 'approved' ? Symbols.check_circle : Symbols.cancel,
              size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: AppTheme.bodyStrong.copyWith(color: color, fontSize: 12.5)),
        ]),
        if (reason != null) ...[
          const SizedBox(height: 4),
          Text(reason!, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
        ],
        if (status == 'pending' && isAdmin) ...[
          const SizedBox(height: 10),
          Row(children: [
            AppButton(label: 'Approve', icon: Symbols.check, variant: BtnVariant.primary, onPressed: onApprove),
            const SizedBox(width: 8),
            AppButton(label: 'Reject', icon: Symbols.close, variant: BtnVariant.ghost, onPressed: onReject),
          ]),
        ],
      ]),
    );
  }
}

// ── Quotation detail dialog ────────────────────────────────────────────────────

class _QuotationDetailDialog extends StatefulWidget {
  const _QuotationDetailDialog({required this.qt});
  final Quotation qt;

  @override
  State<_QuotationDetailDialog> createState() => _QuotationDetailDialogState();
}

class _QuotationDetailDialogState extends State<_QuotationDetailDialog> {
  bool _acting = false;
  bool _sharing = false;

  Future<void> _viewPdf() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    await downloadPdf(context, () => QuotationService.instance.pdfBytes(widget.qt.id), '${widget.qt.quotationNumber}.pdf');
    if (mounted) setState(() => _sharing = false);
  }

  Future<void> _shareWhatsApp() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final qt = widget.qt;
      final url = await QuotationService.instance.shareLink(qt.id);
      final message = 'Hello, here is your quotation ${qt.quotationNumber} from Hypermed Health Care.\n'
          'Total: ${_fmtAmount(qt.totalAmount)}\n\nView / download: $url';
      await shareViaWhatsApp(phone: phoneDigitsFrom(qt.clientContact), message: message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _act(Future<dynamic> Function() fn) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await fn();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _convert() async {
    DateTime? deliveryDate;
    int? locationId;
    List<Location> locations = [];
    String? loadError;
    try {
      locations = await LocationService.instance.list();
      if (locations.isNotEmpty) locationId = locations.first.id;
    } catch (e) {
      loadError = friendlyError(e);
    }
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: ctx.pal.surface1,
          title: Text('Convert to Sales Order', style: AppTheme.bodyStrong),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Convert ${widget.qt.quotationNumber} into a Sales Order?',
                style: AppTheme.bodySm),
            const SizedBox(height: 12),
            if (loadError != null)
              Text(loadError, style: AppTheme.bodySub.copyWith(color: AppColors.coral))
            else ...[
              Text('SHIP FROM LOCATION', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
              const SizedBox(height: 6),
              Container(height: 38,
                decoration: BoxDecoration(color: ctx.pal.surface2,
                    borderRadius: BorderRadius.circular(8), border: Border.all(color: ctx.pal.border)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                  value: locationId, isExpanded: true,
                  dropdownColor: ctx.pal.surface2, style: AppTheme.bodySm,
                  items: locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
                  onChanged: (v) => setS(() => locationId = v),
                )),
              ),
            ],
            const SizedBox(height: 12),
            _DatePickerField(
              label: 'Expected Delivery Date',
              selected: deliveryDate,
              firstDate: DateTime.now(),
              onPicked: (d) => setS(() => deliveryDate = d),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: locationId == null ? null : () => Navigator.pop(ctx, true),
                child: Text('Convert',
                    style: TextStyle(color: AppColors.teal))),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted || locationId == null) return;
    await _act(() => QuotationService.instance.convert(
          widget.qt.id,
          locationId: locationId!,
          expectedDeliveryDate:
              deliveryDate != null ? _isoDate(deliveryDate!) : null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final qt = widget.qt;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 560,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.pal.borderStrong),
          boxShadow: const [
            BoxShadow(
                color: Color(0x55000000), blurRadius: 60, offset: Offset(0, 20))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              Icon(Symbols.request_quote,
                  size: 18, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(qt.quotationNumber,
                      style: AppTheme.pageTitle.copyWith(fontSize: 16)),
                  const SizedBox(height: 4),
                  _StatusBadge(qt.status, qt.statusLabel),
                ]),
              ),
              if (_sharing)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                Tooltip(
                  message: 'Download PDF',
                  child: GestureDetector(
                    onTap: _viewPdf,
                    child: Icon(Symbols.download, size: 18, color: context.pal.textDim),
                  ),
                ),
                const SizedBox(width: 14),
                Tooltip(
                  message: 'Share via WhatsApp',
                  child: GestureDetector(
                    onTap: _shareWhatsApp,
                    child: Icon(Symbols.share, size: 18, color: AppColors.teal),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.pal.surface2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Symbols.close,
                      size: 15, color: context.pal.textDim),
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: context.pal.border),

          // ── Scrollable body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (qt.approvalStatus != 'not_required')
                  _ApprovalBanner(
                    status: qt.approvalStatus,
                    reason: qt.approvalStatus == 'rejected' ? qt.rejectionReason : qt.approvalReason,
                    approvedByName: qt.approvedByName,
                    onApprove: () => _act(() => QuotationService.instance.approve(qt.id)),
                    onReject: () => _act(() => QuotationService.instance.rejectApproval(qt.id)),
                  ),
                // Info 2-col grid
                Wrap(children: [
                  _infoTile('Client', qt.clientName),
                  if (qt.clientContact != null)
                    _infoTile('Contact', qt.clientContact!),
                  if (qt.clientEmail != null)
                    _infoTile('Email', qt.clientEmail!),
                  if (qt.validUntil != null)
                    _infoTile('Valid Until', qt.validUntil!),
                  _infoTile('Currency', qt.currency),
                  if (qt.createdByName != null)
                    _infoTile('Created By', qt.createdByName!),
                ]),
                const SizedBox(height: 16),

                // Financials
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.pal.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: Column(children: [
                    _finRow('Subtotal', qt.subtotal),
                    if (qt.discountAmount > 0)
                      _finRow('Discount', -qt.discountAmount,
                          isDiscount: true),
                    if (qt.taxAmount > 0) _finRow('Tax', qt.taxAmount),
                    const Divider(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: AppTheme.bodyStrong),
                          Text(_fmtAmount(qt.totalAmount),
                              style: AppTheme.bodyStrong.copyWith(
                                  color: AppColors.amber, fontSize: 15)),
                        ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // Line items
                if (qt.items.isNotEmpty) ...[
                  Text('Line Items', style: AppTheme.bodyStrong),
                  const SizedBox(height: 8),
                  ...qt.items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.pal.surface2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.pal.border),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.description,
                                  style: AppTheme.bodySm
                                      .copyWith(fontWeight: FontWeight.w500)),
                              if (item.itemSku != null)
                                Text(item.itemSku!,
                                    style: AppTheme.monoXs.copyWith(
                                        color: context.pal.textDim)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '${item.quantity} × ${_fmtAmount(item.unitPrice)}',
                              style: AppTheme.bodySub.copyWith(fontSize: 11)),
                          const SizedBox(width: 12),
                          Text(_fmtAmount(item.totalPrice),
                              style: AppTheme.bodySm.copyWith(
                                  color: AppColors.amber,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      )),
                ],

                if (qt.notes != null) ...[
                  const SizedBox(height: 16),
                  Text('Notes', style: AppTheme.bodyStrong),
                  const SizedBox(height: 4),
                  Text(qt.notes!, style: AppTheme.bodySub),
                ],
              ]),
            ),
          ),

          // ── Action footer ──
          if (qt.status == 'draft' ||
              qt.status == 'sent' ||
              qt.status == 'accepted') ...[
            Divider(height: 1, color: context.pal.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _acting
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : Wrap(spacing: 8, runSpacing: 8, children: [
                      if (qt.status == 'draft') ...[
                        AppButton(
                          label: 'Send to Client',
                          icon: Symbols.send,
                          variant: BtnVariant.primary,
                          onPressed: () =>
                              _act(() => QuotationService.instance.send(qt.id)),
                        ),
                        AppButton(
                          label: 'Delete',
                          icon: Symbols.delete,
                          variant: BtnVariant.ghost,
                          onPressed: () => _act(
                              () => QuotationService.instance.delete(qt.id)),
                        ),
                      ],
                      if (qt.status == 'sent') ...[
                        AppButton(
                          label: 'Mark Accepted',
                          icon: Symbols.check_circle,
                          variant: BtnVariant.primary,
                          onPressed: () => _act(
                              () => QuotationService.instance.accept(qt.id)),
                        ),
                        AppButton(
                          label: 'Mark Rejected',
                          icon: Symbols.cancel,
                          variant: BtnVariant.ghost,
                          onPressed: () => _act(
                              () => QuotationService.instance.reject(qt.id)),
                        ),
                      ],
                      if (qt.status == 'accepted')
                        AppButton(
                          label: 'Convert to Sales Order',
                          icon: Symbols.swap_horiz,
                          variant: BtnVariant.primary,
                          onPressed: _convert,
                        ),
                    ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _infoTile(String label, String value) => SizedBox(
        width: 250,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: AppTheme.labelCaps),
            const SizedBox(height: 2),
            Text(value,
                style: AppTheme.bodySm, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  Widget _finRow(String label, int amount, {bool isDiscount = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: AppTheme.bodySub),
          Text(
            isDiscount ? '-${_fmtAmount(-amount)}' : _fmtAmount(amount),
            style: AppTheme.bodySub
                .copyWith(color: isDiscount ? AppColors.coral : null),
          ),
        ]),
      );
}

// ── Quotation form modal ───────────────────────────────────────────────────────

class _QuotationFormModal extends StatefulWidget {
  const _QuotationFormModal({required this.onClose, required this.onSaved});
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_QuotationFormModal> createState() => _QuotationFormModalState();
}

class _QuotationFormModalState extends State<_QuotationFormModal> {
  final _clientCtrl  = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _notesCtrl   = TextEditingController();
  DateTime? _validUntil;
  String _currency   = 'TZS';
  bool   _saving     = false;
  final _lines = [_LineItemEntry(), _LineItemEntry()];
  List<InventoryItem> _invItems = [];
  Map<String, String> _errors  = {};
  // The creator's own discount ceiling — mirrors ApprovalService::evaluate()
  // server-side, which compares this same field against the quotation's
  // overall effective discount (discountAmount/subtotal), not any single
  // line's percentage. Null while loading or if the account has no ceiling
  // set (max_discount_percent nullable = no cap).
  double? _maxDiscountPercent;

  @override
  void initState() {
    super.initState();
    InventoryService.instance.list().then((items) {
      if (mounted) setState(() => _invItems = items);
    });
    AuthService.instance.getProfile().then((profile) {
      final v = profile?['max_discount_percent'];
      if (mounted && v != null) setState(() => _maxDiscountPercent = (v as num).toDouble());
    });
    for (final l in _lines) { _attachLineListeners(l); }
  }

  // Fields don't otherwise trigger a rebuild as you type (the onChanged
  // passed into _LineItemRow is only wired to the item picker) — attach
  // listeners so the discount-ceiling banner and totals stay live.
  void _attachLineListeners(_LineItemEntry l) {
    l.qtyCtrl.addListener(_recalc);
    l.priceCtrl.addListener(_recalc);
    l.discCtrl.addListener(_recalc);
  }

  void _recalc() { if (mounted) setState(() {}); }

  int get _subtotal => _lines.fold(0, (s, l) {
    final qty = int.tryParse(l.qtyCtrl.text) ?? 0;
    final price = int.tryParse(l.priceCtrl.text.replaceAll(',', '')) ?? 0;
    return s + (qty * price);
  });

  int get _discountAmount => _lines.fold(0, (s, l) {
    final qty = int.tryParse(l.qtyCtrl.text) ?? 0;
    final price = int.tryParse(l.priceCtrl.text.replaceAll(',', '')) ?? 0;
    final disc = double.tryParse(l.discCtrl.text) ?? 0;
    return s + ((qty * price) * disc / 100).round();
  });

  double get _effectiveDiscountPercent => _subtotal > 0 ? (_discountAmount / _subtotal * 100) : 0;

  bool get _overDiscountCeiling =>
      _maxDiscountPercent != null && _effectiveDiscountPercent > _maxDiscountPercent!;

  @override
  void dispose() {
    _clientCtrl.dispose(); _contactCtrl.dispose();
    _emailCtrl.dispose();  _notesCtrl.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  bool _validate() {
    final errs = <String, String>{};
    if (_clientCtrl.text.trim().isEmpty) errs['client'] = 'Client name is required';
    final validLines = _lines.where((l) => l.descCtrl.text.trim().isNotEmpty).toList();
    if (validLines.isEmpty) errs['items'] = 'Add at least one line item with a description';
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.descCtrl.text.trim().isEmpty) continue; // empty rows are ignored
      final price = int.tryParse(l.priceCtrl.text.replaceAll(',', ''));
      if (price == null || price <= 0) errs['price_$i'] = 'Enter a valid price for item ${i + 1}';
      final qty = int.tryParse(l.qtyCtrl.text);
      if (qty == null || qty <= 0) errs['qty_$i'] = 'Enter a valid quantity for item ${i + 1}';
    }
    setState(() => _errors = errs);
    return errs.isEmpty;
  }

  // Live preview of ApprovalService::evaluate()'s discount check — issuing
  // still works either way, this just tells the rep up front whether it'll
  // go out immediately or need sales_manager sign-off first, instead of
  // that being a surprise after they hit Save.
  Widget _discountCeilingBanner(BuildContext context) {
    final over = _overDiscountCeiling;
    final color = over ? AppColors.amber : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: over ? 0.4 : 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(over ? Symbols.warning : Symbols.check_circle, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Discount ${_effectiveDiscountPercent.toStringAsFixed(1)}% of ${_maxDiscountPercent!.toStringAsFixed(1)}% ceiling',
            style: AppTheme.bodySm.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            over
                ? 'Over your ceiling by ${(_effectiveDiscountPercent - _maxDiscountPercent!).toStringAsFixed(1)} points. '
                  'Issuing still works, but this quotation will need sales_manager approval before the client can accept it.'
                : 'Within your ceiling — this quotation will issue straight to the client with no approval step.',
            style: AppTheme.bodySub.copyWith(fontSize: 11.5),
          ),
        ])),
      ]),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validate()) return;

    final validLines = _lines.where((l) => l.descCtrl.text.trim().isNotEmpty).toList();
    setState(() => _saving = true);
    try {
      await QuotationService.instance.create({
        'client_name':    _clientCtrl.text.trim(),
        'client_contact': _contactCtrl.text.trim().isNotEmpty ? _contactCtrl.text.trim() : null,
        'client_email':   _emailCtrl.text.trim().isNotEmpty   ? _emailCtrl.text.trim()   : null,
        'valid_until':    _validUntil != null ? _isoDate(_validUntil!) : null,
        'currency':       _currency,
        'notes':          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        'items': validLines.map((l) => {
          'inventory_item_id': l.selectedItem?.id,
          'description':       l.descCtrl.text.trim(),
          'unit_of_measure':   l.uomCtrl.text.trim().isNotEmpty ? l.uomCtrl.text.trim() : 'pcs',
          'quantity':          int.tryParse(l.qtyCtrl.text) ?? 1,
          'unit_price':        int.tryParse(l.priceCtrl.text.replaceAll(',', '')) ?? 0,
          'discount_percent':  double.tryParse(l.discCtrl.text) ?? 0,
        }).toList(),
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) {
        // Parse Laravel 422 field errors into the inline map; fall back to snackbar for server errors
        final msg = e.toString();
        if (msg.contains('422') || msg.toLowerCase().contains('validation')) {
          setState(() => _errors = {'_server': 'Please check your inputs and try again.'});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
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
          width: 640,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                Icon(Symbols.request_quote, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('New Quotation', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),

            // Body
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Client info row
                Row(children: [
                  Expanded(child: _formField('Client Name *', _clientCtrl, 'Hospital or company', context,
                      error: _errors['client'],
                      onChanged: (_) { if (_errors.containsKey('client')) setState(() => _errors.remove('client')); })),
                  const SizedBox(width: 12),
                  Expanded(child: _formField('Contact Person', _contactCtrl, 'Dr. Name', context)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _formField('Email', _emailCtrl, 'client@hospital.tz', context)),
                  const SizedBox(width: 12),
                  Expanded(child: _DatePickerField(
                    label: 'Valid Until',
                    selected: _validUntil,
                    firstDate: DateTime.now(),
                    onPicked: (d) => setState(() => _validUntil = d),
                  )),
                  const SizedBox(width: 12),
                  SizedBox(width: 100, child: _dropField('Currency', _currency,
                    ['TZS', 'USD', 'EUR', 'KES'],
                    (v) => setState(() => _currency = v), context,
                  )),
                ]),
                const SizedBox(height: 20),

                // Server-level error banner
                if (_errors.containsKey('_server')) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      Icon(Symbols.error_outline, size: 14, color: AppColors.coral),
                      const SizedBox(width: 8),
                      Text(_errors['_server']!, style: TextStyle(fontSize: 12, color: AppColors.coral)),
                    ]),
                  ),
                ],

                // Line items
                Row(children: [
                  Text('Line Items', style: AppTheme.bodyStrong),
                  const SizedBox(width: 8),
                  Text('(${_lines.length})', style: AppTheme.bodySub.copyWith(fontSize: 12)),
                  if (_errors.containsKey('items')) ...[
                    const SizedBox(width: 8),
                    Text(_errors['items']!, style: TextStyle(fontSize: 11, color: AppColors.coral)),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      final l = _LineItemEntry();
                      _attachLineListeners(l);
                      _lines.add(l);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.teal),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Symbols.add, size: 14, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Text('Add Item', style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                ..._lines.asMap().entries.map((e) => _LineItemRow(
                  entry: e.value,
                  index: e.key,
                  invItems: _invItems,
                  onRemove: _lines.length > 1
                      ? () => setState(() { _lines[e.key].dispose(); _lines.removeAt(e.key); })
                      : null,
                  onChanged: () => setState(() {}),
                )),
                if (_maxDiscountPercent != null && _subtotal > 0) ...[
                  const SizedBox(height: 4),
                  _discountCeilingBanner(context),
                ],
                const SizedBox(height: 12),
                _formField('Notes', _notesCtrl, 'Payment terms, delivery notes…', context, maxLines: 2),
              ]),
            )),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(border: Border.all(color: context.pal.border),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: _save,
                  child: Container(height: 38,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Quotation', style: AppTheme.bodyStrong.copyWith(
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

// ── Line item entry (mutable state for form) ───────────────────────────────────

class _LineItemEntry {
  final descCtrl  = TextEditingController();
  final uomCtrl   = TextEditingController(text: 'pcs');
  final qtyCtrl   = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final discCtrl  = TextEditingController(text: '0');
  InventoryItem? selectedItem;

  void dispose() {
    descCtrl.dispose(); uomCtrl.dispose();
    qtyCtrl.dispose();  priceCtrl.dispose(); discCtrl.dispose();
  }
}

// ── Line item row in form ──────────────────────────────────────────────────────

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({
    required this.entry,
    required this.index,
    required this.invItems,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineItemEntry entry;
  final int index;
  final List<InventoryItem> invItems;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.pal.surface2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          flex: 3,
          child: _InvItemPicker(
            items: invItems,
            selected: entry.selectedItem,
            onSelected: (item) {
              entry.selectedItem = item;
              if (item != null) {
                entry.descCtrl.text  = item.name;
                entry.uomCtrl.text   = item.unitOfMeasure;
                entry.priceCtrl.text = item.unitCost.toStringAsFixed(0);
              }
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 8),
        if (onRemove != null)
          GestureDetector(onTap: onRemove,
            child: Icon(Symbols.close, size: 16, color: context.pal.textDim)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(flex: 3, child: _miniField('Description *', entry.descCtrl, context)),
        const SizedBox(width: 6),
        Expanded(flex: 1, child: _miniField('UOM', entry.uomCtrl, context)),
        const SizedBox(width: 6),
        Expanded(flex: 1, child: _miniField('Qty', entry.qtyCtrl, context, numeric: true)),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _miniField('Unit Price', entry.priceCtrl, context, numeric: true)),
        const SizedBox(width: 6),
        Expanded(flex: 1, child: _miniField('Disc%', entry.discCtrl, context, numeric: true)),
      ]),
    ]),
  );
}

class _InvItemPicker extends StatelessWidget {
  const _InvItemPicker({required this.items, required this.selected, required this.onSelected});
  final List<InventoryItem> items;
  final InventoryItem? selected;
  final ValueChanged<InventoryItem?> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: context.pal.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<InventoryItem?>(
        value: selected,
        isExpanded: true,
        hint: Text('Link inventory item (optional)', style: AppTheme.bodySub.copyWith(fontSize: 11)),
        dropdownColor: context.pal.surface2,
        style: AppTheme.bodySm.copyWith(fontSize: 12),
        icon: Icon(Symbols.expand_more, size: 14, color: context.pal.textDim),
        items: [
          const DropdownMenuItem<InventoryItem?>(value: null, child: Text('— None —')),
          ...items.map((item) => DropdownMenuItem<InventoryItem?>(
            value: item,
            child: Text('${item.sku} · ${item.name}',
                overflow: TextOverflow.ellipsis),
          )),
        ],
        onChanged: onSelected,
      ),
    ),
  );
}

// ── Small field helpers ────────────────────────────────────────────────────────

Widget _formField(String label, TextEditingController ctrl, String hint, BuildContext ctx,
    {int maxLines = 1, String? error, ValueChanged<String>? onChanged}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 5),
      Container(
        constraints: BoxConstraints(minHeight: maxLines > 1 ? 60 : 36),
        decoration: BoxDecoration(
          color: ctx.pal.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: error != null ? AppColors.coral : ctx.pal.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: TextField(
          controller: ctrl, maxLines: maxLines,
          onChanged: onChanged,
          style: AppTheme.bodySm,
          decoration: InputDecoration(
            hintText: hint, border: InputBorder.none, isDense: true,
            contentPadding: EdgeInsets.zero,
            hintStyle: AppTheme.bodySm.copyWith(color: ctx.pal.textDim),
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 3),
        Text(error, style: TextStyle(fontSize: 11, color: AppColors.coral)),
      ],
    ]);

Widget _miniField(String label, TextEditingController ctrl, BuildContext ctx, {bool numeric = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 9, letterSpacing: 0.05)),
      const SizedBox(height: 3),
      Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: ctx.pal.surface1,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ctx.pal.border),
        ),
        child: Center(child: TextField(
          controller: ctrl,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          style: AppTheme.bodySm.copyWith(fontSize: 12),
          decoration: const InputDecoration(
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
          ),
        )),
      ),
    ]);

// ── Date picker field ──────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.selected,
    required this.onPicked,
    this.firstDate,
  });
  final String label;
  final DateTime? selected;
  final ValueChanged<DateTime?> onPicked;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 5),
      GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: selected ?? now.add(const Duration(days: 30)),
            firstDate: firstDate ?? now,
            lastDate: now.add(const Duration(days: 365 * 5)),
          );
          if (picked != null) onPicked(picked);
        },
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: context.pal.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: context.pal.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            Icon(Symbols.calendar_today, size: 14, color: context.pal.textDim),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected != null ? _isoDate(selected!) : 'Pick a date',
                style: AppTheme.bodySm.copyWith(
                  color: selected != null ? null : context.pal.textDim,
                ),
              ),
            ),
            if (selected != null)
              GestureDetector(
                onTap: () => onPicked(null),
                child: Icon(Symbols.close, size: 13, color: context.pal.textDim),
              ),
          ]),
        ),
      ),
    ],
  );
}

Widget _dropField(String label, String value, List<String> items,
    ValueChanged<String> onChanged, BuildContext ctx) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 5),
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ctx.pal.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: ctx.pal.border),
        ),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: value, isExpanded: true,
          dropdownColor: ctx.pal.surface2,
          style: AppTheme.bodySm,
          icon: Icon(Symbols.expand_more, size: 14, color: ctx.pal.textDim),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        )),
      ),
    ]);
