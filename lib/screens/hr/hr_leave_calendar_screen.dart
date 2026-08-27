import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/hr_report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/error_view.dart';

/// Company-wide leave calendar — distinct from "My Leave" (personal
/// self-service, stays in Operations). Renders `/hr-reports/leave-calendar`
/// as a month grid with each approved leave drawn as a bar spanning its
/// date range directly on the cells, per the reference dashboards' calendar
/// treatment, instead of a flat list of rows.
class HrLeaveCalendarScreen extends StatefulWidget {
  const HrLeaveCalendarScreen({super.key});

  @override
  State<HrLeaveCalendarScreen> createState() => _HrLeaveCalendarScreenState();
}

class _HrLeaveCalendarScreenState extends State<HrLeaveCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<LeaveCalendarEntry> _entries = [];
  bool _loading = true;
  String? _error;
  LeaveCalendarEntry? _selected;

  // Not const: AppColors.* are reactive getters (theme-dependent), not
  // compile-time constants — see feedback_theme_porting_approach memory.
  static List<Color> get _lanePalette => [AppColors.teal, AppColors.violet, AppColors.amber, AppColors.info, AppColors.coral];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try {
      final start = DateTime(_month.year, _month.month, 1);
      final end = DateTime(_month.year, _month.month + 1, 0);
      final list = await HrReportService.instance.leaveCalendar(
        start: _fmt(start), end: _fmt(end),
      );
      if (mounted) setState(() { _entries = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  /// Greedy interval-lane assignment so an entry keeps the same vertical
  /// row across every week it spans, instead of re-shuffling week to week.
  Map<LeaveCalendarEntry, int> _assignLanes(List<_ParsedEntry> parsed) {
    final sorted = [...parsed]..sort((a, b) => a.start.compareTo(b.start));
    final laneEnds = <DateTime>[];
    final lanes = <LeaveCalendarEntry, int>{};
    for (final p in sorted) {
      var lane = laneEnds.indexWhere((end) => end.isBefore(p.start));
      if (lane == -1) { lane = laneEnds.length; laneEnds.add(p.end); } else { laneEnds[lane] = p.end; }
      lanes[p.entry] = lane;
    }
    return lanes;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Leave Calendar', style: AppTheme.pageTitle),
              const SizedBox(height: 4),
              Text('Approved leave across the whole team', style: AppTheme.bodySub),
            ])),
            _MonthSwitcher(month: _month, onPrev: () => _changeMonth(-1), onNext: () => _changeMonth(1)),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _calendarGrid(context),
                        if (_selected != null) ...[const SizedBox(height: 16), _detailCard(_selected!)],
                      ])),
          ),
        ]),
      );
    });
  }

  Widget _calendarGrid(BuildContext context) {
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final leadingOffset = (firstOfMonth.weekday - DateTime.monday) % 7; // Monday-first grid
    final gridStart = firstOfMonth.subtract(Duration(days: leadingOffset));
    final days = List.generate(42, (i) => gridStart.add(Duration(days: i)));

    final parsed = _entries.map((e) {
      final s = DateTime.tryParse(e.startDate) ?? firstOfMonth;
      final en = DateTime.tryParse(e.endDate) ?? s;
      return _ParsedEntry(entry: e, start: s, end: en);
    }).toList();
    final lanes = _assignLanes(parsed);

    return Container(
      decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
            .map((d) => Expanded(child: Center(child: Text(d, style: AppTheme.labelCaps))))
            .toList()),
        const SizedBox(height: 8),
        for (var w = 0; w < 6; w++) ...[
          _weekRow(context, days.sublist(w * 7, w * 7 + 7), parsed, lanes),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }

  Widget _weekRow(BuildContext context, List<DateTime> weekDays, List<_ParsedEntry> parsed, Map<LeaveCalendarEntry, int> lanes) {
    final weekStart = weekDays.first;
    final weekEnd = weekDays.last;
    final overlapping = parsed.where((p) => !p.end.isBefore(weekStart) && !p.start.isAfter(weekEnd)).toList();
    final maxLane = overlapping.isEmpty ? 0 : overlapping.map((p) => lanes[p.entry]!).reduce((a, b) => a > b ? a : b);
    final barsHeight = (maxLane + 1) * 20.0;

    return LayoutBuilder(builder: (ctx, cst) {
      final colW = cst.maxWidth / 7;
      return SizedBox(
        height: 26 + barsHeight + 6,
        child: Stack(children: [
          Row(children: weekDays.map((d) {
            final inMonth = d.month == _month.month;
            final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
            return Expanded(child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${d.day}', textAlign: TextAlign.center, style: AppTheme.bodySm.copyWith(
                color: !inMonth ? context.pal.textDim.withValues(alpha: 0.4) : isWeekend ? AppColors.coral : context.pal.text,
              )),
            ));
          }).toList()),
          for (final p in overlapping)
            Positioned(
              top: 26 + lanes[p.entry]! * 20.0,
              left: (p.start.isBefore(weekStart) ? 0 : weekDays.indexWhere((d) => _sameDay(d, p.start))) * colW + 2,
              width: ((p.end.isAfter(weekEnd) ? 6 : weekDays.indexWhere((d) => _sameDay(d, p.end))) -
                      (p.start.isBefore(weekStart) ? 0 : weekDays.indexWhere((d) => _sameDay(d, p.start))) + 1) * colW - 4,
              height: 17,
              child: GestureDetector(
                onTap: () => setState(() => _selected = p.entry),
                child: Container(
                  decoration: BoxDecoration(
                    color: _lanePalette[lanes[p.entry]! % _lanePalette.length].withValues(alpha: _selected == p.entry ? 1 : 0.85),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  child: Text('${p.entry.userName} · ${p.entry.leaveTypeLabel}',
                      overflow: TextOverflow.ellipsis, maxLines: 1,
                      style: AppTheme.monoXs.copyWith(color: Colors.white, fontSize: 9.5)),
                ),
              ),
            ),
        ]),
      );
    });
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _detailCard(LeaveCalendarEntry e) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Symbols.event_note, size: 20, color: AppColors.teal),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.userName, style: AppTheme.cardTitle),
        const SizedBox(height: 4),
        Text('${e.leaveTypeLabel} · ${e.startDate} – ${e.endDate}', style: AppTheme.bodySub),
      ])),
      GestureDetector(onTap: () => setState(() => _selected = null), child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
    ]),
  );
}

class _ParsedEntry {
  const _ParsedEntry({required this.entry, required this.start, required this.end});
  final LeaveCalendarEntry entry;
  final DateTime start;
  final DateTime end;
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _names = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(999), border: Border.all(color: context.pal.border)),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _btn(context, Symbols.chevron_left, onPrev),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('${_names[month.month]} ${month.year}', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
      _btn(context, Symbols.chevron_right, onNext),
    ]),
  );

  Widget _btn(BuildContext context, IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26, height: 26, alignment: Alignment.center,
      decoration: BoxDecoration(color: context.pal.surface3, shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: context.pal.textDim),
    ),
  );
}
