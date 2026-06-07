import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/sales_lead.dart';
import '../../services/sales_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_button.dart';
import '../../theme/app_palette.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool _showNewDeal = false;
  List<SalesLead> _leads  = [];
  bool            _loading = true;
  String?         _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await SalesService.instance.list();
      if (mounted) setState(() { _leads = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = _leads;

    // Group leads by stage
    Map<PipelineStage, List<SalesLead>> grouped = {};
    for (final stage in PipelineStage.values) {
      grouped[stage] = leads.where((l) => l.stage == stage).toList();
    }

    final totalPipeline = leads.where((l) =>
      l.stage != PipelineStage.lost && l.stage != PipelineStage.won)
        .fold(0, (s, l) => s + l.dealValue);

    return Stack(children: [
      Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.pal.border)),
            ),
            child: LayoutBuilder(builder: (ctx, cst) {
              final narrow = cst.maxWidth < 560;
              final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sales Pipeline', style: AppTheme.pageTitle),
                const SizedBox(height: 4),
                Text('${leads.length} deals · Pipeline value: TSh ${(totalPipeline / 1e6).toStringAsFixed(0)}M',
                  style: AppTheme.bodySub),
              ]);
              final actions = Row(mainAxisSize: MainAxisSize.min, children: [
                AppButton(label: 'New Lead', icon: Symbols.add, variant: BtnVariant.primary,
                    onPressed: () => setState(() => _showNewDeal = true)),
                const SizedBox(width: 8),
                AppButton(label: 'Filter by Rep', icon: Symbols.person, variant: BtnVariant.ghost),
                const SizedBox(width: 8),
                AppButton(label: 'Machine Type', icon: Symbols.category, variant: BtnVariant.ghost),
              ]);
              if (narrow) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  titleBlock, const SizedBox(height: 12), actions,
                ]);
              }
              return Row(children: [titleBlock, const Spacer(), actions]);
            }),
          ),

          // Kanban board
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_error != null)
            Expanded(child: ErrorView(message: _error!, onRetry: _load))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: PipelineStage.values.map((stage) {
                      final stageLeads = grouped[stage] ?? [];
                      return _KanbanColumn(stage: stage, leads: stageLeads);
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),

      // New Deal dialog
      if (_showNewDeal)
        _NewDealDialog(
          onClose: () => setState(() => _showNewDeal = false),
          onSaved: () { setState(() => _showNewDeal = false); _load(); },
        ),
    ]);
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.stage, required this.leads});
  final PipelineStage stage;
  final List<SalesLead> leads;

  Color get _dotColor => switch (stage) {
    PipelineStage.lead          => AppColors.textDim,
    PipelineStage.qualified     => AppColors.blue,
    PipelineStage.demoScheduled => AppColors.violet,
    PipelineStage.proposalSent  => AppColors.amber,
    PipelineStage.negotiation   => AppColors.coral,
    PipelineStage.won           => AppColors.teal,
    PipelineStage.lost          => AppColors.coral,
  };

  Color? get _columnTint => switch (stage) {
    PipelineStage.won  => AppColors.tealSoft,
    PipelineStage.lost => AppColors.coralSoft,
    _                  => null,
  };

  Color? get _columnBorder => switch (stage) {
    PipelineStage.won  => const Color(0x4000D4AA),
    PipelineStage.lost => const Color(0x40FF5252),
    _                  => null,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 540),
      decoration: BoxDecoration(
        color: _columnTint ?? const Color(0x05FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _columnBorder ?? context.pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(stage.label.toUpperCase(),
                style: AppTheme.monoXs.copyWith(
                  fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.08,
                )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: context.pal.surface3, borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${leads.length}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
              ),
            ]),
          ),
          // Cards
          ...leads.map((l) => _KanbanCard(lead: l, dotColor: _dotColor)),
          // Add card placeholder
          if (stage != PipelineStage.won && stage != PipelineStage.lost)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.pal.border, style: BorderStyle.solid),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 4),
                Text('Add deal', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({required this.lead, required this.dotColor});
  final SalesLead lead;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lead.hospital,
            style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Text(lead.contact,
            style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: context.pal.surface3, borderRadius: BorderRadius.circular(4),
            ),
            child: Text(lead.machineType,
              style: AppTheme.monoXs.copyWith(fontSize: 10.5, letterSpacing: 0.04)),
          ),
          const SizedBox(height: 10),
          Text(
            'TSh ${(lead.dealValue / 1e6).toStringAsFixed(0)}M',
            style: AppTheme.kpiValue.copyWith(
              fontSize: 15, color: AppColors.amber,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 4),
            Text('${lead.daysInStage}d in stage',
              style: AppTheme.bodySub.copyWith(fontSize: 11)),
            const Spacer(),
            if (lead.demoDate != null) ...[
              const Icon(Symbols.event, size: 12, color: AppColors.violet),
              const SizedBox(width: 4),
              Text(lead.demoDate!, style: AppTheme.bodySub.copyWith(
                fontSize: 11, color: AppColors.violet,
              )),
            ],
          ]),
        ],
      ),
    );
  }
}

// ── New Deal Dialog ────────────────────────────────────────────────────────────

class _NewDealDialog extends StatefulWidget {
  const _NewDealDialog({required this.onClose, this.onSaved});
  final VoidCallback  onClose;
  final VoidCallback? onSaved;

  @override
  State<_NewDealDialog> createState() => _NewDealDialogState();
}

class _NewDealDialogState extends State<_NewDealDialog> {
  final _hospCtrl  = TextEditingController();
  final _contCtrl  = TextEditingController();
  final _valueCtrl = TextEditingController();
  String _machine  = 'Hematology Analyzer';
  String _stage    = 'lead';
  String _rep      = 'Elias Mtui';
  bool   _saving   = false;

  @override
  void dispose() {
    _hospCtrl.dispose(); _contCtrl.dispose(); _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _hospCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await SalesService.instance.create({
        'hospital':    _hospCtrl.text.trim(),
        'contact':     _contCtrl.text.trim(),
        'machine_type': _machine,
        'deal_value':  int.tryParse(_valueCtrl.text.replaceAll(',', '')) ?? 0,
        'stage':       _stage,
        'assigned_to': _rep,
      });
      widget.onSaved?.call();
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
          width: 500,
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
                const Icon(Symbols.trending_up, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('New Deal', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _SField('Hospital / Client', _hospCtrl, 'e.g. Mwananyamala Regional Hospital'),
                const SizedBox(height: 14),
                _SField('Contact Person', _contCtrl, 'e.g. Dr. James Mbeki'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _SDrop(
                    label: 'Machine Type',
                    value: _machine,
                    items: const ['Hematology Analyzer', 'Ultrasound Unit', 'Ventilator',
                        'ECG Machine', 'Patient Monitor', 'Defibrillator'],
                    onChanged: (v) => setState(() => _machine = v),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _SField('Deal Value (TSh)', _valueCtrl, '150000000', numeric: true)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _SDrop(
                    label: 'Stage',
                    value: _stage,
                    items: const ['lead', 'qualified', 'demo_scheduled', 'proposal_sent', 'negotiation'],
                    display: const ['Lead', 'Qualified', 'Demo Scheduled', 'Proposal Sent', 'Negotiation'],
                    onChanged: (v) => setState(() => _stage = v),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _SDrop(
                    label: 'Sales Rep',
                    value: _rep,
                    items: const ['Elias Mtui', 'Grace Nkomo', 'Joseph Mwakasege'],
                    onChanged: (v) => setState(() => _rep = v),
                  )),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    decoration: BoxDecoration(color: AppColors.teal,
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Deal', style: AppTheme.bodyStrong.copyWith(
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

class _SField extends StatelessWidget {
  const _SField(this.label, this.ctrl, this.hint, {this.numeric = false});
  final String label, hint;
  final TextEditingController ctrl;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      height: 38,
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(child: TextField(controller: ctrl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: AppTheme.bodySm,
        decoration: InputDecoration(hintText: hint,
            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
    ),
  ]);
}

class _SDrop extends StatelessWidget {
  const _SDrop({required this.label, required this.value, required this.items,
      this.display, required this.onChanged});
  final String label, value;
  final List<String> items;
  final List<String>? display;
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
        value: value, isExpanded: true,
        dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.asMap().entries.map((e) =>
            DropdownMenuItem(value: e.value,
                child: Text(display != null ? display![e.key] : e.value))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);
}
