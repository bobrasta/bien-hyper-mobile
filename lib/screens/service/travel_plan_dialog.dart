import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/per_diem_request.dart';
import '../../models/service_ticket.dart';
import '../../services/per_diem_service.dart';
import '../../services/setting_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/labeled_field.dart' show FieldFocusBox;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One day's row in the itinerary — owns its own controllers so rows can be
/// added/removed freely without a shared, index-fragile controller list.
class _PlanLineDraft {
  _PlanLineDraft({required this.date});

  DateTime date;
  final regionCtrl     = TextEditingController();
  final districtCtrl   = TextEditingController();
  final siteCtrl       = TextEditingController();
  final activityCtrl   = TextEditingController();
  final laborCtrl      = TextEditingController();
  final perDiemCtrl    = TextEditingController();
  final transportCtrl  = TextEditingController();

  int get labor     => int.tryParse(laborCtrl.text.trim()) ?? 0;
  int get perDiem   => int.tryParse(perDiemCtrl.text.trim()) ?? 0;
  int get transport => int.tryParse(transportCtrl.text.trim()) ?? 0;
  int get total     => labor + perDiem + transport;

  void dispose() {
    regionCtrl.dispose();
    districtCtrl.dispose();
    siteCtrl.dispose();
    activityCtrl.dispose();
    laborCtrl.dispose();
    perDiemCtrl.dispose();
    transportCtrl.dispose();
  }

  Map<String, dynamic> toLineJson(int seqNo) => PerDiemLine(
    seqNo: seqNo,
    date: _iso(date),
    region:   regionCtrl.text.trim().isEmpty   ? null : regionCtrl.text.trim(),
    district: districtCtrl.text.trim().isEmpty ? null : districtCtrl.text.trim(),
    siteName: siteCtrl.text.trim().isEmpty     ? null : siteCtrl.text.trim(),
    activity: activityCtrl.text.trim().isEmpty ? null : activityCtrl.text.trim(),
    laborCost:     labor,
    perDiemCost:   perDiem,
    transportFare: transport,
  ).toJson();
}

/// Day-by-day travel/activity plan an engineer files for a service trip —
/// modelled directly on the paper itinerary form (region/district/site/
/// activity + per-diem/transport per day) that used to be filled in Excel.
/// Submits as a per-diem request with an itemised itinerary; goes through
/// the existing team-lead → CTO approval chain.
class TravelPlanDialog extends StatefulWidget {
  const TravelPlanDialog({super.key, this.ticket, required this.onClose, this.onSaved});
  final ServiceTicket? ticket;
  final VoidCallback onClose;
  final VoidCallback? onSaved;

  @override
  State<TravelPlanDialog> createState() => _TravelPlanDialogState();
}

class _TravelPlanDialogState extends State<TravelPlanDialog> {
  final _purposeCtrl = TextEditingController();
  final List<_PlanLineDraft> _lines = [];
  bool _saving = false;
  String? _error;
  // Section 15.2: "A default per-diem rate can be configured in Settings
  // and pre-filled." Loaded async so it doesn't block the dialog opening;
  // applied to whatever line(s) already exist once it arrives.
  String? _defaultPerDiemRate;

  @override
  void initState() {
    super.initState();
    final t = widget.ticket;
    if (t != null) {
      _purposeCtrl.text = 'Service visit — ${t.machineName} at ${t.hospital}';
    }
    _lines.add(_PlanLineDraft(date: DateTime.now()));
    _loadDefaultRate();
  }

  Future<void> _loadDefaultRate() async {
    try {
      final settings = await SettingService.instance.all();
      final rate = settings['per_diem_default_daily_rate'];
      if (rate != null && rate.isNotEmpty && mounted) {
        setState(() {
          _defaultPerDiemRate = rate;
          for (final l in _lines) {
            if (l.perDiemCtrl.text.isEmpty) l.perDiemCtrl.text = rate;
          }
        });
      }
    } catch (_) {
      // Non-critical — the field just stays blank if this fails.
    }
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    final lastDate = _lines.isNotEmpty ? _lines.last.date : DateTime.now();
    final line = _PlanLineDraft(date: lastDate.add(const Duration(days: 1)));
    if (_defaultPerDiemRate != null) line.perDiemCtrl.text = _defaultPerDiemRate!;
    setState(() => _lines.add(line));
  }

  void _removeLine(int i) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  Future<void> _pickDate(int i) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lines[i].date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _lines[i].date = picked);
  }

  int get _totalLabor     => _lines.fold(0, (s, l) => s + l.labor);
  int get _totalPerDiem   => _lines.fold(0, (s, l) => s + l.perDiem);
  int get _totalTransport => _lines.fold(0, (s, l) => s + l.transport);
  int get _grandTotal     => _totalLabor + _totalPerDiem + _totalTransport;
  int get _sitesVisited   =>
      _lines.map((l) => l.siteCtrl.text.trim()).where((s) => s.isNotEmpty).toSet().length;
  int get _daysSpent => _lines.map((l) => _iso(l.date)).toSet().length;

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await PerDiemService.instance.create({
        if (widget.ticket != null) 'service_ticket_id': widget.ticket!.dbId,
        'purpose': _purposeCtrl.text.trim().isEmpty ? null : _purposeCtrl.text.trim(),
        'lines': _lines.asMap().entries.map((e) => e.value.toLineJson(e.key + 1)).toList(),
      });
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
    }
  }

  Widget _miniField(String label, TextEditingController ctrl, {bool numeric = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 9)),
        const SizedBox(height: 4),
        FieldFocusBox(
          radius: 6,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          builder: (context, focusNode) => TextField(
            controller: ctrl,
            focusNode: focusNode,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            style: AppTheme.fieldText.copyWith(fontSize: 12),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          ),
        ),
      ]);

  Widget _summaryStat(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
      ]);

  Widget _lineRow(int i) {
    final l = _lines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.pal.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.pal.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Day ${i + 1}', style: AppTheme.bodyStrong.copyWith(fontSize: 12)),
          const Spacer(),
          GestureDetector(
            onTap: () => _pickDate(i),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Symbols.calendar_month, size: 14, color: context.pal.textDim),
              const SizedBox(width: 4),
              Text(formatDate(l.date), style: AppTheme.bodySm.copyWith(fontSize: 11.5)),
            ]),
          ),
          const SizedBox(width: 12),
          if (_lines.length > 1)
            GestureDetector(
              onTap: () => _removeLine(i),
              child: Icon(Symbols.delete_outline, size: 16, color: AppColors.coral),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _miniField('Region', l.regionCtrl)),
          const SizedBox(width: 8),
          Expanded(child: _miniField('District', l.districtCtrl)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _miniField('Site', l.siteCtrl)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _miniField('Activity', l.activityCtrl)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _miniField('Labor (TSh)', l.laborCtrl, numeric: true)),
          const SizedBox(width: 8),
          Expanded(child: _miniField('Per Diem (TSh)', l.perDiemCtrl, numeric: true)),
          const SizedBox(width: 8),
          Expanded(child: _miniField('Transport (TSh)', l.transportCtrl, numeric: true)),
        ]),
      ]),
    );
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
          width: 620,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Icon(Symbols.map, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('Submit Travel Plan', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),

            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(children: [
                if (widget.ticket != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.tealSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Icon(Symbols.confirmation_number, size: 14, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        '${widget.ticket!.id} · ${widget.ticket!.machineName} · ${widget.ticket!.hospital}',
                        style: AppTheme.bodySm.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                  ),

                if (_error != null) ...[
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12)),
                  ),
                ],

                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Description of the trip', style: AppTheme.fieldLabel),
                  const SizedBox(height: 6),
                  FieldFocusBox(builder: (context, focusNode) => TextField(focusNode: focusNode, controller: _purposeCtrl, style: AppTheme.fieldText,
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true,
                            contentPadding: EdgeInsets.zero, hintText: 'What is this trip for?')),),
                ]),
                const SizedBox(height: 16),

                Row(children: [
                  Text('ITINERARY', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _addLine,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Symbols.add, size: 14, color: AppColors.teal),
                      const SizedBox(width: 3),
                      Text('Add Day', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 12)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                ..._lines.asMap().keys.map(_lineRow),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    _summaryStat('Days', '$_daysSpent'),
                    const SizedBox(width: 16),
                    _summaryStat('Sites', '$_sitesVisited'),
                    const SizedBox(width: 16),
                    _summaryStat('Labor', tshShort(_totalLabor)),
                    const SizedBox(width: 16),
                    _summaryStat('Per Diem', tshShort(_totalPerDiem)),
                    const SizedBox(width: 16),
                    _summaryStat('Transport', tshShort(_totalTransport)),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('GRAND TOTAL', style: AppTheme.labelCaps.copyWith(fontSize: 9)),
                      Text(tshShort(_grandTotal),
                          style: AppTheme.bodyStrong.copyWith(color: AppColors.teal, fontSize: 15)),
                    ]),
                  ]),
                ),
              ]),
            )),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(child: AppButton(label: 'Cancel', variant: BtnVariant.ghost, onPressed: widget.onClose)),
                const SizedBox(width: 12),
                Expanded(child: AppButton(
                  label: _saving ? 'Submitting…' : 'Submit for Approval',
                  icon: Symbols.send,
                  variant: BtnVariant.primary,
                  onPressed: _saving ? null : _save,
                )),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}
