// lib/screens/dashboard/cto_team_calendar_screen.dart — mobile team calendar (design 2d).
// 7-day window over the overview's calendar range, starting today; arrows
// page by a week within that range.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/cto_approval.dart';
import '../../models/cto_overview.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/dashboard/cto_widgets.dart';

class CtoTeamCalendarScreen extends StatefulWidget {
  const CtoTeamCalendarScreen({super.key, required this.overview, this.tripDecisions = const {}});
  final CtoOverview overview;
  final Map<int, CtoDecision> tripDecisions;

  @override
  State<CtoTeamCalendarScreen> createState() => _CtoTeamCalendarScreenState();
}

class _CtoTeamCalendarScreenState extends State<CtoTeamCalendarScreen> {
  static const _window = 7;
  late DateTime _start;

  DateTime get _rangeStart => widget.overview.calendarStart;
  DateTime get _rangeEnd => _rangeStart.add(Duration(days: widget.overview.calendarDays - _window));

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _start = today.isBefore(_rangeStart) ? _rangeStart : (today.isAfter(_rangeEnd) ? _rangeEnd : today);
  }

  void _page(int dir) {
    final next = _start.add(Duration(days: dir * _window));
    setState(() => _start = next.isBefore(_rangeStart) ? _rangeStart : (next.isAfter(_rangeEnd) ? _rangeEnd : next));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final o = widget.overview;
    final onRoad = o.team.where((m) => m.state == 'en_route').length;
    final pending = o.team.expand((m) => m.bars).where((b) =>
        b.kind == TripBarKind.pendingCto && (b.perDiemRequestId == null || widget.tripDecisions[b.perDiemRequestId] == null)).length;
    final end = _start.add(const Duration(days: _window - 1));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(children: [
          Text('Team', style: AppTheme.cardTitle.copyWith(fontSize: 17)),
          const SizedBox(width: 8),
          Text('${formatDate(_start)} – ${formatDate(end)}',
              style: AppTheme.monoXs.copyWith(fontSize: 11, color: pal.textDim)),
        ]),
        actions: [
          IconButton(icon: const Icon(Symbols.chevron_left), onPressed: _start.isAfter(_rangeStart) ? () => _page(-1) : null),
          IconButton(icon: const Icon(Symbols.chevron_right), onPressed: _start.isBefore(_rangeEnd) ? () => _page(1) : null),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: pal.divider)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          CtoChip('$onRoad on the road', color: AppColors.cyan, size: 11.5),
          if (pending > 0) CtoChip('$pending trips awaiting you', color: AppColors.amber, size: 11.5),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          decoration: BoxDecoration(color: pal.surface1, borderRadius: BorderRadius.circular(AppColors.rMd), border: Border.all(color: pal.border)),
          child: CtoTripCalendar(
            team: o.team, start: _start, days: _window, today: DateTime.now(),
            tripDecisions: widget.tripDecisions, rowHeight: 46, nameWidth: 36, showNames: false,
          ),
        ),
        const SizedBox(height: 16),
        Text('TODAY', style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: pal.surface1, borderRadius: BorderRadius.circular(AppColors.rMd), border: Border.all(color: pal.border)),
          child: Column(children: [
            for (final m in o.team)
              Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
                child: Row(children: [
                  CtoInitials(m.initials, color: teamColor(m.state, context), size: 28),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m.name} · ${m.where}', style: AppTheme.bodySm.copyWith(fontSize: 12.5, color: pal.text)),
                    Text(m.tripNote, style: AppTheme.bodySub.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  CtoChip(switch (m.state) { 'en_route' => 'en route', 'on_leave' => 'on leave', _ => 'base' },
                      color: teamColor(m.state, context)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
