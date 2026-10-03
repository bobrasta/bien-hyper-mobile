// lib/screens/dashboard/cto_approval_detail_screen.dart — mobile approval detail (design 2c).
// The parent dashboard owns the API calls and decision state; this screen
// just renders and reports back, so approving here also updates 2b / 2d.
import 'package:flutter/material.dart';
import '../../models/cto_approval.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard/cto_widgets.dart';

class CtoApprovalDetailScreen extends StatefulWidget {
  const CtoApprovalDetailScreen({
    super.key, required this.approval, this.initialDecision,
    required this.onApprove, required this.onReturn, this.onEditDays,
  });
  final CtoApproval approval;
  final CtoDecision? initialDecision;
  final Future<CtoDecision?> Function() onApprove;
  final Future<CtoDecision?> Function() onReturn;
  final VoidCallback? onEditDays;

  @override
  State<CtoApprovalDetailScreen> createState() => _CtoApprovalDetailScreenState();
}

class _CtoApprovalDetailScreenState extends State<CtoApprovalDetailScreen> {
  late CtoDecision? _decision = widget.initialDecision;
  bool _busy = false;

  Future<void> _run(Future<CtoDecision?> Function() f) async {
    setState(() => _busy = true);
    final d = await f();
    if (mounted) setState(() { _decision = d; _busy = false; });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text('Approval', style: AppTheme.cardTitle.copyWith(fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(widget.approval.ref, style: AppTheme.monoXs.copyWith(fontSize: 11, color: pal.textDim))),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: pal.divider)),
      ),
      body: CtoApprovalDetail(
        a: widget.approval,
        decision: _decision,
        busy: _busy,
        mobile: true,
        onApprove: () => _run(widget.onApprove),
        onReturn: () => _run(widget.onReturn),
        onEditDays: widget.onEditDays,
      ),
    );
  }
}
