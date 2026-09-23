import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/part_cannibalization.dart';
import '../../services/part_cannibalization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/api_error.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/error_view.dart';

class FlaggedUnitsScreen extends StatefulWidget {
  const FlaggedUnitsScreen({super.key});

  @override
  State<FlaggedUnitsScreen> createState() => _FlaggedUnitsScreenState();
}

class _FlaggedUnitsScreenState extends State<FlaggedUnitsScreen> {
  List<PartCannibalization> _all = [];
  bool    _loading = true;
  String? _error;
  bool    _showResolved = false;

  List<PartCannibalization> get _filtered => _showResolved
      ? _all
      : _all.where((c) => c.status != CannibalizationStatus.resolved).toList();

  @override
  void initState() {
    super.initState();
    // Stale-while-revalidate: show the last-known list immediately (if any)
    // instead of blanking to a spinner on every navigation — see
    // MachineService for the full reasoning.
    final cached = PartCannibalizationService.cachedDefaultList;
    if (cached != null) { _all = cached; _loading = false; }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_all.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final list = await PartCannibalizationService.instance.list();
      if (mounted) setState(() { _all = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _orderReplacement(PartCannibalization c) async {
    try {
      await PartCannibalizationService.instance.orderReplacement(c.id);
      if (mounted) { showSuccessToast(context, 'Marked as replacement ordered.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _resolve(PartCannibalization c) async {
    try {
      await PartCannibalizationService.instance.resolve(c.id);
      if (mounted) { showSuccessToast(context, 'Unit marked complete.'); _load(); }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
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
            LayoutBuilder(builder: (ctx, cst) {
              final narrow = cst.maxWidth < 560;
              final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Flagged Units', style: AppTheme.pageTitle),
                const SizedBox(height: 4),
                Text('Stocked units with parts cannibalized for field repairs — cannot ship until repaired', style: AppTheme.bodySub),
              ]);
              final toggle = GestureDetector(
                onTap: () => setState(() => _showResolved = !_showResolved),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_showResolved ? Symbols.check_box : Symbols.check_box_outline_blank, size: 18, color: context.pal.textMute),
                  const SizedBox(width: 6),
                  Text('Show resolved', style: AppTheme.bodySm),
                ]),
              );
              if (narrow) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 12), toggle]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [titleBlock, const Spacer(), toggle]);
            }),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_error != null && _all.isEmpty)
              ErrorView(message: _error!, onRetry: _load)
            else if (_filtered.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No flagged units', style: TextStyle(color: context.pal.textMute))))
            else
              AdaptiveColumns(wideCols: 2, mediumCols: 2, narrowCols: 1, children: _filtered.map((c) => _CannibalizationCard(
                record: c, onOrderReplacement: () => _orderReplacement(c), onResolve: () => _resolve(c),
              )).toList()),
          ]),
        ),
      );
    });
  }
}

class _CannibalizationCard extends StatelessWidget {
  const _CannibalizationCard({required this.record, required this.onOrderReplacement, required this.onResolve});
  final PartCannibalization record;
  final VoidCallback onOrderReplacement;
  final VoidCallback onResolve;

  Color get _statusColor => switch (record.status) {
    CannibalizationStatus.open               => AppColors.coral,
    CannibalizationStatus.replacementOrdered => AppColors.amber,
    CannibalizationStatus.resolved           => AppColors.teal,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Symbols.warning, size: 16, color: _statusColor),
        const SizedBox(width: 8),
        Expanded(child: Text(record.sourceSerialNumber ?? '—', style: AppTheme.monoSm.copyWith(fontWeight: FontWeight.w700, fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
          child: Text(record.status.label, style: AppTheme.bodySub.copyWith(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 6),
      Text(record.sourceItemName ?? '—', style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
      const SizedBox(height: 10),
      _InfoRow('Part taken', '${record.partName ?? '—'}${record.partQty != null ? ' ×${record.partQty}' : ''}'),
      if (record.destinationTicketNumber != null)
        _InfoRow('For ticket', '${record.destinationTicketNumber} · ${record.destinationMachineName ?? ''}'),
      if (record.removedByName != null)
        _InfoRow('Removed by', record.removedByName!),
      if (record.replacementPoNumber != null)
        _InfoRow('Replacement PO', record.replacementPoNumber!),
      if (record.status != CannibalizationStatus.resolved) ...[
        const SizedBox(height: 12),
        Row(children: [
          if (record.status == CannibalizationStatus.open)
            Expanded(child: GestureDetector(
              onTap: onOrderReplacement,
              child: Container(height: 34,
                decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(7)),
                child: Center(child: Text('Order Replacement', style: AppTheme.bodySub.copyWith(fontSize: 11.5)))),
            )),
          if (record.status == CannibalizationStatus.open) const SizedBox(width: 8),
          Expanded(child: GestureDetector(
            onTap: onResolve,
            child: Container(height: 34,
              decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(7)),
              child: Center(child: Text('Mark Repaired', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 11.5)))),
          )),
        ]),
      ],
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 11.5))),
      Expanded(child: Text(value, style: AppTheme.bodySm.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
    ]),
  );
}
