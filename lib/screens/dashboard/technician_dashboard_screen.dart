import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show userIdNotifier;
import '../../models/service_ticket.dart';
import '../../models/staff_member.dart';
import '../../models/task_item.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/contract_service.dart';
import '../../services/payroll_service.dart';
import '../../services/position_change_service.dart';
import '../../services/spare_part_service.dart';
import '../../services/task_service.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/kpi_card.dart';
import '../../widgets/common/shimmer_box.dart';

// ── Small pure helpers ──────────────────────────────────────────────────────

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

int _priorityHours(String priority) => switch (priority.toLowerCase()) {
  'critical' => 4,
  'high' => 8,
  'medium' => 24,
  'low' => 72,
  _ => 24,
};

int _priorityRank(String priority) => switch (priority.toLowerCase()) {
  'critical' => 0,
  'high' => 1,
  'medium' => 2,
  'low' => 3,
  _ => 2,
};

// "Repair" tickets, for first-time-fix % and revisit detection — the
// backend's `type` column only ever holds 'repair' or 'installation'
// (ServiceTicketController's validation: 'in:repair,installation'), so
// "did we have to come back?" only applies to the repair type.
bool _isRepairType(String type) => type.toLowerCase() == 'repair';

DateTime? _parseCreated(ServiceTicket t) => DateTime.tryParse(t.createdAt);

/// A resolved repair ticket counts as a "revisit" if the same machine has
/// another resolved repair ticket in the 30 days before this one's
/// createdAt — i.e. we'd already been out to fix the same machine recently.
bool isRevisit(ServiceTicket t, List<ServiceTicket> all) {
  if (t.machineId == null || t.resolvedAt == null || !_isRepairType(t.type))
    return false;
  final created = _parseCreated(t);
  if (created == null) return false;
  return all.any((o) {
    if (o.dbId == t.dbId || o.machineId != t.machineId) return false;
    if (o.resolvedAt == null || !_isRepairType(o.type)) return false;
    final oCreated = _parseCreated(o);
    if (oCreated == null) return false;
    return oCreated.isBefore(created) &&
        created.difference(oCreated).inDays <= 30;
  });
}

String _fmtDuration(Duration d, {bool days = false}) {
  final neg = d.isNegative;
  final abs = d.abs();
  final String out;
  if (days) {
    final dd = abs.inDays;
    final hh = abs.inHours % 24;
    out = dd > 0 ? '$dd d ${hh}h' : '${abs.inHours} h';
  } else {
    final hh = abs.inHours;
    final mm = abs.inMinutes % 60;
    out = hh > 0 ? '$hh h ${mm}m' : '$mm m';
  }
  return neg ? '-$out' : out;
}

String _tenure(DateTime hireDate) {
  final now = DateTime.now();
  var months = (now.year - hireDate.year) * 12 + (now.month - hireDate.month);
  if (now.day < hireDate.day) months -= 1;
  if (months < 0) months = 0;
  final years = months ~/ 12;
  final rem = months % 12;
  if (years == 0) return '$rem mo';
  return rem == 0 ? '$years yr' : '$years yr $rem mo';
}

// ── Screen ───────────────────────────────────────────────────────────────────

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key, this.onNavigateTo});
  final void Function(String key)? onNavigateTo;

  @override
  State<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen> {
  bool _loading = true;
  String? _loadError;

  StaffMember? _me;
  String? _managerName;

  List<ServiceTicket> _myTickets = [];

  List<Contract> _contracts = [];

  // General (non-ticket) tasks assigned to this technician — the /tasks
  // endpoint, unrelated to service tickets. This technician role has no
  // 'staff' screen access (that's the task-assignment board), so the
  // dashboard is the only place these are visible/actionable.
  List<TaskItem> _myTasks = [];
  bool _tasksActionBusy = false;

  List<PayrollHistoryItem> _payrollHistory = [];
  bool _payrollLoading = true;
  bool _payrollForbidden = false;

  List<AttendanceRecord> _attendance = [];
  bool _attendanceLoading = true;
  bool _attendanceForbidden = false;

  List<PositionChange> _positionChanges = [];

  bool _advancingStage = false;
  String _historyFilter = 'all'; // all | installation | corrective | preventive

  @override
  void initState() {
    super.initState();
    // Stale-while-revalidate: seed every independently-cacheable piece
    // from its service's own cache so this dashboard doesn't blank to a
    // full shimmer list on every return visit — same reasoning as
    // MachineListScreen, applied per-piece since this is a dashboard of
    // several independent fetches. Tickets has no matching cache —
    // TicketService.cachedDefaultList only covers the fully unfiltered
    // call, and this screen always fetches assignedTo: me — so that
    // piece always starts empty until its own fetch resolves, same as
    // before.
    final me = userIdNotifier.value;
    final profile = AuthService.cachedProfile;
    if (profile != null) {
      _me = StaffMember.fromJson(profile);
      _managerName = profile['manager_name'] as String?;
    }
    if (me != null) {
      final contracts = ContractService.cachedByUserId[me];
      if (contracts != null) _contracts = contracts;
      final positionChanges = PositionChangeService.cachedByUserId[me];
      if (positionChanges != null) _positionChanges = positionChanges;
      final tasks = TaskService.cachedByAssignee[me];
      if (tasks != null) _myTasks = tasks;
      final payroll = PayrollService.cachedHistoryForUser[me];
      if (payroll != null) { _payrollHistory = payroll; _payrollLoading = false; }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      final attendance = AttendanceService.cachedByQuery['${_fmtDate(start)}|${_fmtDate(end)}|$me'];
      if (attendance != null) { _attendance = attendance; _attendanceLoading = false; }
    }
    if (profile != null) _loading = false;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_me == null) _loading = true;
      _loadError = null;
    });
    final me = userIdNotifier.value;
    try {
      await Future.wait([
        _loadProfile(),
        _loadTickets(me),
        _loadContracts(me),
        _loadPositionChanges(me),
        _loadTasks(me),
      ]);
      // Payroll/attendance may 403 until the backend self-access relaxation
      // lands — kept separate so a failure there never blocks the rest.
      unawaited(_loadPayroll(me));
      unawaited(_loadAttendance(me));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _loadError = friendlyError(e);
          _loading = false;
        });
    }
  }

  Future<void> _loadProfile() async {
    final data = await AuthService.instance.getProfile();
    if (!mounted || data == null) return;
    setState(() {
      _me = StaffMember.fromJson(data);
      _managerName = data['manager_name'] as String?;
    });
  }

  Future<void> _loadTickets(int? me) async {
    if (me == null) return;
    final list = await TicketService.instance.list(
      assignedTo: me,
      noCache: true,
    );
    if (mounted) setState(() => _myTickets = list);
  }

  Future<void> _loadContracts(int? me) async {
    if (me == null) return;
    try {
      final list = await ContractService.instance.list(me);
      if (mounted) setState(() => _contracts = list);
    } catch (_) {
      // Non-critical — the profile card just shows "—" for CONTRACT.
    }
  }

  Future<void> _loadPositionChanges(int? me) async {
    if (me == null) return;
    try {
      final list = await PositionChangeService.instance.list(me);
      if (mounted) setState(() => _positionChanges = list);
    } catch (_) {}
  }

  Future<void> _loadTasks(int? me) async {
    if (me == null) return;
    try {
      final list = await TaskService.instance.list(assignedTo: me);
      if (mounted) setState(() => _myTasks = list);
    } catch (_) {
      // Non-critical — the card just shows nothing if this 403s/fails.
    }
  }

  Future<void> _setTaskStatus(TaskItem task, String status) async {
    setState(() => _tasksActionBusy = true);
    try {
      final updated = await TaskService.instance.update(task.id, {
        'status': status,
      });
      if (mounted) {
        setState(() {
          _myTasks = _myTasks.map((t) => t.id == task.id ? updated : t).toList();
          _tasksActionBusy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _tasksActionBusy = false);
        showErrorToast(context, e);
      }
    }
  }

  Future<void> _loadPayroll(int? me) async {
    if (me == null) {
      if (mounted) setState(() => _payrollLoading = false);
      return;
    }
    setState(() {
      if (_payrollHistory.isEmpty) _payrollLoading = true;
      _payrollForbidden = false;
    });
    try {
      final list = await PayrollService.instance.historyForUser(me);
      if (mounted)
        setState(() {
          _payrollHistory = list;
          _payrollLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _payrollForbidden = true;
          _payrollLoading = false;
        });
    }
  }

  Future<void> _loadAttendance(int? me) async {
    if (me == null) {
      if (mounted) setState(() => _attendanceLoading = false);
      return;
    }
    setState(() {
      if (_attendance.isEmpty) _attendanceLoading = true;
      _attendanceForbidden = false;
    });
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    try {
      final list = await AttendanceService.instance.list(
        start: _fmtDate(start),
        end: _fmtDate(end),
        userId: me,
      );
      if (mounted)
        setState(() {
          _attendance = list;
          _attendanceLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _attendanceForbidden = true;
          _attendanceLoading = false;
        });
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Derived ticket data ────────────────────────────────────────────────────

  List<ServiceTicket> get _activeTickets =>
      _myTickets.where((t) => t.status != TicketStatus.resolved).toList();

  ServiceTicket? get _currentTicket {
    final active = _activeTickets;
    if (active.isEmpty) return null;
    final sorted = [...active]
      ..sort((a, b) {
        final pr = _priorityRank(
          a.priority,
        ).compareTo(_priorityRank(b.priority));
        if (pr != 0) return pr;
        final ac = _parseCreatedOrMax(a);
        final bc = _parseCreatedOrMax(b);
        return ac.compareTo(bc);
      });
    return sorted.first;
  }

  static DateTime _parseCreatedOrMax(ServiceTicket t) =>
      _parseCreated(t) ?? DateTime(9999);

  int get _closedMtd {
    final now = DateTime.now();
    return _myTickets
        .where(
          (t) =>
              t.resolvedAt != null &&
              t.resolvedAt!.year == now.year &&
              t.resolvedAt!.month == now.month,
        )
        .length;
  }

  List<ServiceTicket> get _resolvedRepairs => _myTickets
      .where((t) => t.resolvedAt != null && _isRepairType(t.type))
      .toList();

  int get _revisitsCount =>
      _resolvedRepairs.where((t) => isRevisit(t, _myTickets)).length;

  double? get _firstTimeFixPct {
    final repairsResolved = _resolvedRepairs;
    if (repairsResolved.isEmpty) return null;
    return (1 - _revisitsCount / repairsResolved.length) * 100;
  }

  double? get _attendancePct {
    if (_attendance.isEmpty) return null;
    final present = _attendance
        .where((r) => r.status == 'present' || r.status == 'late')
        .length;
    return present / _attendance.length * 100;
  }

  ({int installed, int serviced}) get _fleetTotals {
    var installed = 0, serviced = 0;
    for (final t in _myTickets) {
      if (t.resolvedAt == null) continue;
      if (t.type.toLowerCase() == 'installation') {
        installed++;
      } else {
        serviced++;
      }
    }
    return (installed: installed, serviced: serviced);
  }

  // ── KPI sub-metric chips — all derived from data already fetched, never
  // fabricated (e.g. no cross-technician "zone" comparison, since there's
  // no data source for that here). ─────────────────────────────────────────

  int get _closedLastMonth {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    return _myTickets
        .where(
          (t) =>
              t.resolvedAt != null &&
              t.resolvedAt!.year == prev.year &&
              t.resolvedAt!.month == prev.month,
        )
        .length;
  }

  Duration? get _avgResolutionThisMonth {
    final now = DateTime.now();
    final durations = <Duration>[];
    for (final t in _myTickets) {
      final r = t.resolvedAt;
      if (r == null || r.year != now.year || r.month != now.month) continue;
      final ack = t.acknowledgedAt != null
          ? DateTime.tryParse(t.acknowledgedAt!)
          : null;
      if (ack != null) durations.add(r.difference(ack));
    }
    if (durations.isEmpty) return null;
    final totalMinutes =
        durations.fold<int>(0, (s, d) => s + d.inMinutes) ~/ durations.length;
    return Duration(minutes: totalMinutes);
  }

  ({int active, int queued}) get _activeAndQueuedCounts {
    final active = _activeTickets.where((t) => t.stage != 'assigned').length;
    return (active: active, queued: _activeTickets.length - active);
  }

  ({int present, int total, int late}) get _attendanceSummary => (
    present: _attendance
        .where((r) => r.status == 'present' || r.status == 'late')
        .length,
    total: _attendance.length,
    late: _attendance.where((r) => r.status == 'late').length,
  );

  int get _sitesServiced => _myTickets
      .map((t) => t.hospital)
      .where((h) => h.isNotEmpty)
      .toSet()
      .length;

  List<ServiceTicket> get _last30Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final list =
        _myTickets.where((t) {
          final c = _parseCreated(t);
          return c != null && c.isAfter(cutoff);
        }).toList()..sort(
          (a, b) => (_parseCreated(b) ?? DateTime(0)).compareTo(
            _parseCreated(a) ?? DateTime(0),
          ),
        );
    return list;
  }

  List<ServiceTicket> get _filteredHistory {
    final base = _last30Days;
    if (_historyFilter == 'all') return base;
    return base.where((t) => t.type.toLowerCase() == _historyFilter).toList();
  }

  String _statusLine(ServiceTicket? t) {
    if (t == null) return 'available at the office';
    return switch (t.stage) {
      'travelling' => 'on the road to ${t.hospital}',
      'on_site' => 'on site at ${t.hospital}',
      'repair' => 'repairing at ${t.hospital}',
      'signed_off' => 'wrapping up at ${t.hospital}',
      // Assigned but not yet dispatched — still at the office.
      _ => 'available at the office',
    };
  }

  String? get _todayClockIn {
    final today = _fmtDate(DateTime.now());
    for (final r in _attendance) {
      if (r.date == today && r.clockIn != null) return r.clockIn;
    }
    return null;
  }

  Future<void> _advanceStage(ServiceTicket t, String next) async {
    if (_advancingStage) return;
    setState(() => _advancingStage = true);
    try {
      await TicketService.instance.advanceStage(t.dbId, next);
      if (mounted)
        showSuccessToast(context, 'Advanced to ${next.replaceAll('_', ' ')}');
      await _loadTickets(userIdNotifier.value);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _advancingStage = false);
    }
  }

  void _showAddPartDialog(ServiceTicket t) {
    showDialog<void>(
      context: context,
      builder: (_) => _QuickAddPartDialog(
        onSave: (inventoryItemId, qty, cost) async {
          try {
            await TicketService.instance.addPart(
              t.dbId,
              inventoryItemId: inventoryItemId,
              qty: qty,
              unitCost: cost,
            );
            if (mounted) {
              Navigator.of(context).pop();
              await _loadTickets(userIdNotifier.value);
            }
          } catch (e) {
            if (mounted) showErrorToast(context, e);
          }
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: shimmerList(count: 8),
      );
    }
    // A background refresh failing while stale-but-valid cached data is
    // already showing shouldn't blow that away — only surface the error
    // when there's genuinely nothing else to show.
    if (_loadError != null && _me == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, style: AppTheme.bodySub),
            const SizedBox(height: 12),
            AppButton(label: 'Retry', icon: Symbols.refresh, onPressed: _load),
          ],
        ),
      );
    }

    final firstName = (_me?.name ?? 'Technician').split(' ').first;
    final current = _currentTicket;

    return LayoutBuilder(
      builder: (ctx, cst) {
        final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, firstName, current),
                const SizedBox(height: 20),
                _kpiStrip(context),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (ctx2, cst2) {
                    final narrow = cst2.maxWidth < 900;
                    final left = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _currentAssignmentCard(context, current),
                        if (_myTasks.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _myTasksCard(context),
                        ],
                        const SizedBox(height: 20),
                        _taskHistorySection(context),
                      ],
                    );
                    final right = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _employeeProfileCard(context),
                        const SizedBox(height: 20),
                        _statutoryPayCard(context),
                        const SizedBox(height: 20),
                        _careerCard(context),
                      ],
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [left, const SizedBox(height: 20), right],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: left),
                        const SizedBox(width: 20),
                        Expanded(flex: 1, child: right),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                _bottomRow(context),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 1. Header ────────────────────────────────────────────────────────────

  Widget _header(
    BuildContext context,
    String firstName,
    ServiceTicket? current,
  ) {
    final now = DateTime.now();
    final clockIn = _todayClockIn;
    final statusText = _statusLine(current);
    final tailText =
        ' · ${_activeTickets.length} tasks today · '
        '${clockIn != null ? 'clocked in $clockIn' : 'not clocked in'}';

    return LayoutBuilder(
      builder: (ctx, cst) {
        final narrow = cst.maxWidth < 640;
        final titleBlock = Row(
          children: [
            Container(
              // height: 70,
              padding: EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Color.fromRGBO(34, 197, 94, 1),
                    width: 4.0,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $firstName',
                    style: AppTheme.pageTitle.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: AppTheme.bodySub.copyWith(fontSize: 14),
                      children: [
                        TextSpan(text: '${formatDate(now)} · '),
                        TextSpan(
                          text: statusText,
                          style: const TextStyle(
                            color: Color.fromRGBO(45, 212, 191, 1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: tailText),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.pal.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.pal.border),
              ),
              child: Text(
                'This Month',
                style: AppTheme.bodySub.copyWith(fontSize: 11.5),
              ),
            ),
            const SizedBox(width: 10),
            AppButton(
              label: 'Clock out',
              icon: Symbols.logout,
              variant: BtnVariant.normal,
              onPressed: () => showSuccessToast(
                context,
                "Clock-out isn't wired to attendance yet — this button is a placeholder.",
              ),
            ),
          ],
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleBlock),
            actions,
          ],
        );
      },
    );
  }

  // ── 2. KPI strip ─────────────────────────────────────────────────────────

  Widget _kpiStrip(BuildContext context) {
    final ftf = _firstTimeFixPct;
    final att = _attendancePct;
    final fleet = _fleetTotals;
    final aq = _activeAndQueuedCounts;
    final delta = _closedMtd - _closedLastMonth;
    final avgRes = _avgResolutionThisMonth;
    final attnSum = _attendanceSummary;

    return AdaptiveColumns(
      wideCols: 5,
      mediumCols: 3,
      narrowCols: 2,
      spacing: 12,
      runSpacing: 12,
      children: [
        _TechKpiTile(
          label: 'Tasks Today',
          icon: Symbols.format_list_bulleted_rounded,
          value: '${_activeTickets.length}',
          addedvalue: "Assigned",
          chips: [
            '${aq.active} active',
            if (aq.queued > 0) '${aq.queued} queued after',
          ],
          chipscolors: [
            Color.fromRGBO(45, 212, 191, 1),
            Color.fromRGBO(45, 212, 191, .14),
            
          ],
        ),
        _TechKpiTile(
          label: 'Closed MTD',
          icon: Symbols.check_circle,
          value: '$_closedMtd',
          addedvalue: "Tasks",
          accent: KpiAccent.teal,
          chips: [
            '${delta >= 0 ? '+' : ''}$delta vs last mo',
            if (avgRes != null) 'avg ${_fmtDuration(avgRes)}',
          ],
        ),
        _TechKpiTile(
          label: 'First-time fix %',
          icon: Symbols.build_circle,
          value: ftf == null ? '—' : '${ftf.toStringAsFixed(0)}%',
          addedvalue: "%",
          accent: ftf != null && ftf < 70 ? KpiAccent.amber : KpiAccent.teal,
          chips: [
            if (_resolvedRepairs.isNotEmpty)
              '$_revisitsCount revisit${_revisitsCount == 1 ? '' : 's'}',
          ],
        ),
        _TechKpiTile(
          label: 'Attendance',
          icon: Symbols.fingerprint,
          value: _attendanceForbidden
              ? '—'
              : (att == null ? '—' : att.toStringAsFixed(0)),
          addedvalue: "%",
          chips: _attendanceForbidden || attnSum.total == 0
              ? const []
              : [
                  '${attnSum.present}/${attnSum.total} d',
                  if (attnSum.late > 0) '${attnSum.late} late',
                ],
        ),
        _TechKpiTile(
          label: 'Fleet',
          icon: Symbols.precision_manufacturing,
          value: '${fleet.installed + fleet.serviced}',
          addedvalue: "Installed and Serviced",
          chips: [
            '${fleet.installed} installed',
            '${fleet.serviced} serviced',
            if (_sitesServiced > 0) '$_sitesServiced sites',
          ],

        ),
      ],
    );
  }

  // ── 3. Current assignment ───────────────────────────────────────────────

  Widget _currentAssignmentCard(BuildContext context, ServiceTicket? t) {
    if (t == null) {
      return AppCard(
        header: Text('Current assignment', style: AppTheme.cardTitle),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(Symbols.check_circle, size: 18, color: AppColors.teal),
              const SizedBox(width: 10),
              Text(
                'No active assignment right now.',
                style: AppTheme.bodySub.copyWith(
                  color: Color.fromRGBO(45, 212, 191, 1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final created = _parseCreated(t);
    final now = DateTime.now();
    final priorityH = _priorityHours(t.priority);
    final deadline = created?.add(Duration(hours: priorityH));
    final remaining = deadline?.difference(now);
    final (slaColor, slaText) = _slaBadge(remaining, priorityH);

    final downtime = created != null ? now.difference(created) : null;
    final isAssignee =
        t.assignedToId != null && t.assignedToId == userIdNotifier.value;

    const stages = [
      'assigned',
      'travelling',
      'on_site',
      'repair',
      'signed_off',
    ];
    final currentIdx = stages.indexOf(t.stage).clamp(0, stages.length - 1);
    final nextStage = currentIdx < stages.length - 1
        ? stages[currentIdx + 1]
        : null;

    final parts = t.partsUsed ?? const [];

    return AppCard(
      header: Row(
        children: [
          Text('Current assignment', style: AppTheme.cardTitle),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t.id,
              style: AppTheme.monoXs.copyWith(
                color: AppColors.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: slaColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: slaColor.withValues(alpha: 0.35)),
        ),
        child: Text(
          slaText,
          style: AppTheme.bodySub.copyWith(
            color: slaColor,
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t.machineType} — ${t.machineName}',
            style: AppTheme.bodyStrong.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 3),
          Text('${t.hospital} · ${t.ward}', style: AppTheme.bodySub),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillTag(
                context,
                t.type.isEmpty
                    ? '—'
                    : t.type[0].toUpperCase() + t.type.substring(1),
                AppColors.blue,
              ),
              _pillTag(
                context,
                t.priority.isEmpty
                    ? '—'
                    : t.priority[0].toUpperCase() + t.priority.substring(1),
                switch (t.priority.toLowerCase()) {
                  'critical' => AppColors.coral,
                  'high' => AppColors.amber,
                  _ => AppColors.textDim,
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metaChip(
                context,
                Symbols.event,
                'Assigned',
                created != null ? formatDate(created) : '—',
              ),
              const SizedBox(width: 18),
              _metaChip(
                context,
                Symbols.hourglass_bottom,
                'Downtime',
                downtime != null ? _fmtDuration(downtime, days: true) : '—',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StageTracker(
            currentStage: t.stage,
            canAdvance: isAssignee && nextStage != null && !_advancingStage,
            onAdvance: nextStage == null
                ? null
                : () => _advanceStage(t, nextStage),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Parts used', style: AppTheme.labelCaps),
              const Spacer(),
              if (isAssignee)
                GestureDetector(
                  onTap: () => _showAddPartDialog(t),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.add, size: 14, color: AppColors.teal),
                      const SizedBox(width: 3),
                      Text(
                        'Add Part',
                        style: AppTheme.bodySub.copyWith(
                          color: AppColors.teal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (parts.isEmpty)
            Text(
              'No parts used yet.',
              style: AppTheme.bodySub.copyWith(fontSize: 12.5),
            )
          else
            Column(
              children: parts
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(p.name, style: AppTheme.bodySm)),
                          Text('×${p.qty}', style: AppTheme.monoXs),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Log service report',
            icon: Symbols.description,
            variant: BtnVariant.primary,
            onPressed: () => widget.onNavigateTo?.call('service'),
          ),
        ],
      ),
    );
  }

  (Color, String) _slaBadge(Duration? remaining, int totalHours) {
    if (remaining == null) return (AppColors.textDim, 'SLA —');
    if (remaining.isNegative) {
      return (AppColors.coral, 'SLA overdue by ${_fmtDuration(remaining)}');
    }
    final fracLeft = remaining.inMinutes / (totalHours * 60);
    final color = fracLeft <= 0.25
        ? AppColors.coral
        : (fracLeft <= 0.5 ? AppColors.amber : AppColors.teal);
    return (color, 'SLA ${_fmtDuration(remaining)} left');
  }

  Widget _pillTag(BuildContext context, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: AppTheme.bodySub.copyWith(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _metaChip(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: context.pal.textDim),
      const SizedBox(width: 6),
      Text('$label: ', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
      Text(
        value,
        style: AppTheme.bodySm.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  // ── 3b. My Tasks (general, non-ticket assignments) ──────────────────────

  Widget _myTasksCard(BuildContext context) {
    final open = _myTasks.where((t) => t.status != 'completed').toList();
    return AppCard(
      header: Text('My Tasks (${open.length})', style: AppTheme.cardTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in open) ...[
            _myTaskRow(context, t),
            if (t != open.last) Container(width: double.infinity, height: 1, color: context.pal.divider),
          ],
        ],
      ),
    );
  }

  Widget _myTaskRow(BuildContext context, TaskItem t) {
    final priorityColor = switch (t.priority.toLowerCase()) {
      'critical' => AppColors.coral,
      'high' => AppColors.amber,
      _ => AppColors.textDim,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: AppTheme.bodyStrong.copyWith(fontSize: 13.5)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pillTag(context, t.taskType, AppColors.blue),
                    _pillTag(
                      context,
                      t.priority.isEmpty
                          ? '—'
                          : t.priority[0].toUpperCase() + t.priority.substring(1),
                      priorityColor,
                    ),
                    if (t.dueDate != null)
                      Text('Due ${t.dueDate}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (t.status == 'assigned')
            AppButton(
              label: 'Start',
              icon: Symbols.play_arrow,
              variant: BtnVariant.normal,
              small: true,
              onPressed: _tasksActionBusy ? null : () => _setTaskStatus(t, 'in_progress'),
            )
          else if (t.status == 'in_progress' || t.status == 'overdue')
            AppButton(
              label: 'Complete',
              icon: Symbols.check_circle,
              variant: BtnVariant.primary,
              small: true,
              onPressed: _tasksActionBusy ? null : () => _setTaskStatus(t, 'completed'),
            ),
        ],
      ),
    );
  }

  // ── 4. Employee profile ─────────────────────────────────────────────────

  Widget _employeeProfileCard(BuildContext context) {
    final me = _me;
    final activeContract = _contracts
        .where((c) => c.status == 'active')
        .toList();
    final contractType = activeContract.isNotEmpty
        ? activeContract.first.contractType
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                initials: me?.initials ?? '?',
                size: 48,
                variant: me?.variant ?? AvatarVariant.teal,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me?.name ?? '—',
                      style: AppTheme.bodyStrong.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${me?.positionTitle ?? '—'} · ${me?.zone ?? '—'}',
                      style: AppTheme.bodySub.copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.pal.surface2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        me != null
                            ? 'EMP-${me.id.toString().padLeft(3, '0')}'
                            : 'EMP-—',
                        style: AppTheme.monoXs,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 1, color: context.pal.divider),
          const SizedBox(height: 14),
          _profileField(context, 'NSSF NO.', me?.nssfNumber ?? '—'),
          _profileField(context, 'TIN', me?.tinNumber ?? '—'),
          _profileField(
            context,
            'JOINED',
            me?.hireDate != null ? formatDate(me!.hireDate!) : '—',
          ),
          _profileField(context, 'MANAGER', _managerName ?? '—'),
          _profileField(context, 'CONTRACT', contractType ?? '—', last: true),
        ],
      ),
    );
  }

  Widget _profileField(
    BuildContext context,
    String label,
    String value, {
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 10),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppTheme.labelCaps)),
        Text(
          value,
          style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  // ── 5. Statutory & pay ──────────────────────────────────────────────────

  Widget _statutoryPayCard(BuildContext context) {
    final now = DateTime.now();
    final title = 'Statutory & pay — ${_monthNames[now.month - 1]} ${now.year}';

    if (_payrollLoading) {
      return AppCard(
        header: Text(title, style: AppTheme.cardTitle),
        child: shimmerList(count: 2),
      );
    }
    if (_payrollForbidden || _payrollHistory.isEmpty) {
      return AppCard(
        header: Text(title, style: AppTheme.cardTitle),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Not available.', style: AppTheme.bodySub),
        ),
      );
    }

    final sorted = [..._payrollHistory]
      ..sort((a, b) {
        final ay = a.periodYear * 12 + a.periodMonth;
        final by = b.periodYear * 12 + b.periodMonth;
        return by.compareTo(ay);
      });
    final latest = sorted.first;

    return AppCard(
      header: Text(title, style: AppTheme.cardTitle),
      trailing: GestureDetector(
        onTap: () =>
            showSuccessToast(context, "Payslip download isn't available yet."),
        child: Text(
          'Payslip',
          style: AppTheme.bodySub.copyWith(
            color: AppColors.teal,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _statBox(
                  context,
                  'NSSF (You)',
                  tshShort(latest.nssfAmount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  context,
                  'NSSF (Co.)',
                  latest.nssfEmployerAmount != null
                      ? tshShort(latest.nssfEmployerAmount!)
                      : '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(context, 'PAYE', tshShort(latest.payeAmount)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(width: double.infinity, height: 1, color: context.pal.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Net pay', style: AppTheme.bodySub),
              const Spacer(),
              Text(
                tshShort(latest.netPay),
                style: AppTheme.bodyStrong.copyWith(
                  color: AppColors.teal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context, String label, String value) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.pal.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
          ],
        ),
      );

  // ── 6. Career & promotions ──────────────────────────────────────────────

  Widget _careerCard(BuildContext context) {
    final hire = _me?.hireDate;
    return AppCard(
      header: Row(
        children: [
          Text('Career & promotions', style: AppTheme.cardTitle),
          const SizedBox(width: 8),
          if (hire != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _tenure(hire),
                style: AppTheme.monoXs.copyWith(color: AppColors.teal),
              ),
            ),
        ],
      ),
      child: _positionChanges.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No position changes recorded.',
                style: AppTheme.bodySub,
              ),
            )
          : _CareerTimeline(changes: _positionChanges),
    );
  }

  // ── 7. Task history ─────────────────────────────────────────────────────

  Widget _taskHistorySection(BuildContext context) {
    final filtered = _filteredHistory;
    final total = _last30Days.length;
    return AppCard(
      header: Text(
        'Task history ${filtered.length} of $total · last 30 days',
        style: AppTheme.cardTitle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _historyTab('All', 'all'),
              _historyTab('Installations', 'installation'),
              _historyTab('Repairs', 'repair'),
            ],
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No tasks in this window.', style: AppTheme.bodySub),
            )
          else
            HScrollTable(
              minWidth: 700,
              child: Column(
                children: [
                  Row(
                    children: const [
                      SizedBox(width: 240, child: _ColHeader('TASK & SITE')),
                      SizedBox(width: 110, child: _ColHeader('TYPE')),
                      SizedBox(width: 110, child: _ColHeader('DURATION')),
                      SizedBox(width: 110, child: _ColHeader('DATE')),
                      SizedBox(width: 110, child: _ColHeader('OUTCOME')),
                    ],
                  ),
                  Container(width: double.infinity, height: 1, color: context.pal.divider),
                  ...filtered.map((t) => _historyRow(context, t)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyTab(String label, String value) {
    final active = _historyFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _historyFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.tealSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.teal.withValues(alpha: 0.4)
                : context.pal.border,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodySub.copyWith(
            color: active ? AppColors.teal : context.pal.textMute,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _historyRow(BuildContext context, ServiceTicket t) {
    final created = _parseCreated(t);
    Duration? dur;
    final ack = t.acknowledgedAt != null
        ? DateTime.tryParse(t.acknowledgedAt!)
        : null;
    if (ack != null && t.resolvedAt != null)
      dur = t.resolvedAt!.difference(ack);

    final resolved = t.resolvedAt != null;
    final revisit = resolved && isRevisit(t, _myTickets);
    final (outcomeColor, outcomeLabel) = resolved
        ? (
            revisit ? AppColors.amber : AppColors.teal,
            revisit ? 'revisit' : 'closed',
          )
        : (AppColors.blue, t.status.label.toLowerCase());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.machineName,
                  style: AppTheme.bodySm,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.hospital,
                  style: AppTheme.bodySub.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              t.type,
              style: AppTheme.bodySub.copyWith(fontSize: 11.5),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              dur != null ? _fmtDuration(dur) : '—',
              style: AppTheme.monoXs,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              created != null ? formatDate(created) : '—',
              style: AppTheme.bodySub.copyWith(fontSize: 11.5),
            ),
          ),
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: outcomeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                outcomeLabel,
                style: AppTheme.bodySub.copyWith(
                  color: outcomeColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 8. Bottom row ────────────────────────────────────────────────────────

  Widget _bottomRow(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cst) {
        final narrow = cst.maxWidth < 900;
        final cards = [
          SizedBox(height: 320, child: _attendanceCard(context)),
          SizedBox(height: 320, child: _fleetBarChartCard(context)),
          SizedBox(height: 320, child: _upNextCard(context)),
        ];
        if (narrow) {
          return Column(
            children: [
              for (final c in cards) ...[c, const SizedBox(height: 20)],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 20),
            Expanded(child: cards[1]),
            const SizedBox(width: 20),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }

  Widget _attendanceCard(BuildContext context) {
    if (_attendanceLoading) {
      return AppCard(
        header: Text('Attendance', style: AppTheme.cardTitle),
        expandChild: true,
        child: shimmerList(count: 3),
      );
    }
    if (_attendanceForbidden) {
      return AppCard(
        header: Text('Attendance', style: AppTheme.cardTitle),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Not available.', style: AppTheme.bodySub),
        ),
      );
    }
    return AppCard(
      header: Text('Attendance', style: AppTheme.cardTitle),
      expandChild: true,
      child: _AttendanceMonthRow(records: _attendance),
    );
  }

  Widget _fleetBarChartCard(BuildContext context) {
    final months = List.generate(6, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - 5 + i, 1);
    });
    final installed = <int>[];
    final serviced = <int>[];
    for (final m in months) {
      var inst = 0, serv = 0;
      for (final t in _myTickets) {
        final r = t.resolvedAt;
        if (r == null || r.year != m.year || r.month != m.month) continue;
        if (t.type.toLowerCase() == 'installation') {
          inst++;
        } else {
          serv++;
        }
      }
      installed.add(inst);
      serviced.add(serv);
    }
    return AppCard(
      header: Text('Machines installed & serviced', style: AppTheme.cardTitle),
      expandChild: true,
      child: _MonthBarChart(
        months: months,
        installed: installed,
        serviced: serviced,
      ),
    );
  }

  Widget _upNextCard(BuildContext context) {
    final current = _currentTicket;
    final upcoming =
        _activeTickets.where((t) => t.dbId != current?.dbId).toList()
          ..sort((a, b) {
            final ac =
                _parseCreated(
                  a,
                )?.add(Duration(hours: _priorityHours(a.priority))) ??
                DateTime(9999);
            final bc =
                _parseCreated(
                  b,
                )?.add(Duration(hours: _priorityHours(b.priority))) ??
                DateTime(9999);
            return ac.compareTo(bc);
          });

    return AppCard(
      header: Text('Up next', style: AppTheme.cardTitle),
      expandChild: true,
      child: upcoming.isEmpty
          ? Center(
              child: Text('Nothing else queued up.', style: AppTheme.bodySub),
            )
          : ListView.separated(
              itemCount: upcoming.length,
              separatorBuilder: (_, _) =>
                  Container(width: double.infinity, height: 1, color: context.pal.divider),
              itemBuilder: (_, i) {
                final t = upcoming[i];
                final created = _parseCreated(t);
                final due = created?.add(
                  Duration(hours: _priorityHours(t.priority)),
                );
                return GestureDetector(
                  onTap: () => widget.onNavigateTo?.call('service'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            due != null ? formatTime(due) : '—',
                            style: AppTheme.monoXs,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.machineName,
                                style: AppTheme.bodySm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                t.hospital,
                                style: AppTheme.bodySub.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Symbols.chevron_right,
                          size: 16,
                          color: context.pal.textDim,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── KPI tile with sub-metric chips ────────────────────────────────────────
// Same container styling as the shared KpiCard, but with room for 1-2 small
// plain-text chips under the value (e.g. "1 active" / "2 queued after") —
// KpiCard's own delta slot always renders a trend arrow, which is wrong for
// non-trend context like this, so this stays local to this screen.

class _TechKpiTile extends StatelessWidget {
  const _TechKpiTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.addedvalue,
    this.chipscolors = const [],
    this.chips = const [],
    this.accent = KpiAccent.teal,
  });
  final String label;
  final IconData icon;
  final String value;
  final String addedvalue;
  final List<String> chips;
  final List<Color> chipscolors;
  final KpiAccent accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (accent) {
      KpiAccent.teal => AppColors.teal,
      KpiAccent.amber => AppColors.amber,
      KpiAccent.coral => AppColors.coral,
    };
    return LayoutBuilder(
      builder: (ctx, cst) {
        final narrow = cst.maxWidth < 180;
        return Container(
          padding: EdgeInsets.all(narrow ? 12 : 18),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: narrow ? 20 : 24,
                    color: context.pal.textDim,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: narrow ? 12 : 14,
                      ),
                      maxLines: narrow ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: narrow ? 8 : 12),
              RichText(
                text: TextSpan(
                  text: value,
                  style: AppTheme.kpiValue.copyWith(
                    fontSize: narrow ? 24 : 34,
                    color: accentColor,
                  ),
                  children: [
                    TextSpan(
                      text: ' $addedvalue',
                      style: AppTheme.bodySub.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (chips.isNotEmpty && !narrow) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: chips
                      .map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.pal.surface2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            c,
                            style: AppTheme.bodySub.copyWith(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Column header for the task-history table ────────────────────────────────

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 10)),
  );
}

// ── Stage tracker: 5 dots + connecting line ──────────────────────────────────

class _StageTracker extends StatelessWidget {
  const _StageTracker({
    required this.currentStage,
    required this.canAdvance,
    this.onAdvance,
  });
  final String currentStage;
  final bool canAdvance;
  final VoidCallback? onAdvance;

  static const _stages = [
    'assigned',
    'travelling',
    'on_site',
    'repair',
    'signed_off',
  ];
  static const _labels = [
    'Assigned',
    'Travelling',
    'On site',
    'Repair',
    'Signed off',
  ];

  @override
  Widget build(BuildContext context) {
    final idx = _stages.indexOf(currentStage).clamp(0, _stages.length - 1);
    return Row(
      children: List.generate(_stages.length * 2 - 1, (i) {
        if (i.isOdd) {
          final segDone = (i - 1) ~/ 2 < idx;
          return Expanded(
            child: Container(
              height: 2,
              color: segDone ? AppColors.teal : context.pal.border,
            ),
          );
        }
        final stageIdx = i ~/ 2;
        final done = stageIdx < idx;
        final isCurrent = stageIdx == idx;
        final isNext = stageIdx == idx + 1;
        final color = done || isCurrent ? AppColors.teal : context.pal.border;
        final dot = Container(
          width: isCurrent ? 16 : 12,
          height: isCurrent ? 16 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.teal
                : (isCurrent ? AppColors.teal : Colors.transparent),
            border: Border.all(color: color, width: 2),
          ),
          child: done
              ? const Icon(Symbols.check, size: 9, color: Color(0xFF06120F))
              : null,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: isNext && canAdvance ? onAdvance : null,
              child: dot,
            ),
            const SizedBox(height: 6),
            Text(
              _labels[stageIdx],
              style: AppTheme.monoXs.copyWith(
                fontSize: 9.5,
                color: done || isCurrent
                    ? context.pal.text
                    : context.pal.textDim,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Career progression timeline ──────────────────────────────────────────────

class _CareerTimeline extends StatelessWidget {
  const _CareerTimeline({required this.changes});
  final List<PositionChange> changes;

  @override
  Widget build(BuildContext context) {
    final sorted = [...changes]
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return Column(
      children: sorted.asMap().entries.map((e) {
        final isLast = e.key == sorted.length - 1;
        final c = e.value;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: context.pal.divider),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.fromPositionTitle ?? '—'} → ${c.toPositionTitle ?? '—'}',
                        style: AppTheme.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.effectiveDate} · approved by ${c.approvedByName ?? '—'}',
                        style: AppTheme.bodySub.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Hand-rolled month bar-chart (installed vs serviced) ──────────────────────

class _MonthBarChart extends StatelessWidget {
  const _MonthBarChart({
    required this.months,
    required this.installed,
    required this.serviced,
  });
  final List<DateTime> months;
  final List<int> installed;
  final List<int> serviced;

  static const _mon = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final maxTotal = List.generate(
      months.length,
      (i) => installed[i] + serviced[i],
    ).fold(1, (a, b) => a > b ? a : b);
    final allZero =
        maxTotal <= 1 &&
        installed.every((v) => v == 0) &&
        serviced.every((v) => v == 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: allZero
              ? Center(
                  child: Text(
                    'No completed jobs in this window.',
                    style: AppTheme.bodySub.copyWith(fontSize: 12),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(months.length, (i) {
                    final inst = installed[i];
                    final serv = serviced[i];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (inst > 0)
                                    Expanded(
                                      flex: inst,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: AppColors.violet,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(3),
                                              ),
                                        ),
                                      ),
                                    ),
                                  if (serv > 0)
                                    Expanded(
                                      flex: serv,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: AppColors.teal.withValues(
                                            alpha: 0.85,
                                          ),
                                          borderRadius: inst == 0
                                              ? BorderRadius.circular(3)
                                              : const BorderRadius.vertical(
                                                  bottom: Radius.circular(3),
                                                ),
                                        ),
                                      ),
                                    ),
                                  if (inst == 0 && serv == 0)
                                    Container(
                                      height: 3,
                                      width: double.infinity,
                                      color: context.pal.surface3,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _mon[months[i].month - 1],
                              style: AppTheme.monoXs.copyWith(
                                fontSize: 9.5,
                                color: context.pal.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          children: [
            _legend(AppColors.violet, 'Installed'),
            _legend(AppColors.teal, 'Serviced'),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppTheme.monoXs.copyWith(fontSize: 11)),
    ],
  );
}

// ── Single-technician attendance month row ────────────────────────────────────

class _AttendanceMonthRow extends StatelessWidget {
  const _AttendanceMonthRow({required this.records});
  final List<AttendanceRecord> records;

  Color _statusColor(String status) => switch (status) {
    'present' => AppColors.green,
    'late' => AppColors.amber,
    'absent' => AppColors.coral,
    'leave' => AppColors.amber,
    _ => AppColors.textDim,
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final byDate = {for (final r in records) r.date: r};
    final present = records.where((r) => r.status == 'present').length;
    final late = records.where((r) => r.status == 'late').length;
    final absent = records.where((r) => r.status == 'absent').length;

    final withClockIn = records.where((r) => r.clockIn != null).toList();
    String avgClockIn = '—';
    if (withClockIn.isNotEmpty) {
      final totalMinutes = withClockIn.fold<int>(0, (sum, r) {
        final parts = r.clockIn!.split(':');
        if (parts.length < 2) return sum;
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return sum + h * 60 + m;
      });
      final avg = totalMinutes ~/ withClockIn.length;
      avgClockIn =
          '${(avg ~/ 60).toString().padLeft(2, '0')}:${(avg % 60).toString().padLeft(2, '0')}';
    }
    final overtimeTotal = records.fold<double>(
      0,
      (s, r) => s + (r.overtimeHours ?? 0),
    );

    if (records.isEmpty) {
      return Center(
        child: Text(
          'No attendance marked this month.',
          style: AppTheme.bodySub.copyWith(fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(daysInMonth, (i) {
            final date = DateTime(now.year, now.month, i + 1);
            final key =
                '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final rec = byDate[key];
            final color = rec != null
                ? _statusColor(rec.status)
                : context.pal.surface3;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _legendDot(AppColors.green, 'Present'),
            _legendDot(AppColors.amber, 'Late'),
            _legendDot(AppColors.coral, 'Absent'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCol(context, 'Present', '$present', AppColors.green),
            ),
            Expanded(
              child: _statCol(context, 'Late', '$late', AppColors.amber),
            ),
            Expanded(
              child: _statCol(context, 'Absent', '$absent', AppColors.coral),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(width: double.infinity, height: 1, color: context.pal.divider),
        const SizedBox(height: 10),
        Text(
          'Avg clock-in $avgClockIn · overtime ${overtimeTotal.toStringAsFixed(1)}h',
          style: AppTheme.bodySub.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  Widget _statCol(BuildContext context, String label, String n, Color c) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n, style: AppTheme.bodyStrong.copyWith(fontSize: 15, color: c)),
          Text(label, style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
        ],
      );

  Widget _legendDot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: AppTheme.monoXs.copyWith(fontSize: 10.5)),
    ],
  );
}

// ── Minimal add-part dialog ───────────────────────────────────────────────────
// A trimmed-down version of ServiceTicketScreen's private _AddPartDialog
// (same TicketService.addPart call, same catalog source) — that class is
// private to service_ticket_screen.dart so it can't be imported directly;
// this reuses its data flow rather than its cannibalization/quick-add extras,
// which aren't relevant from the dashboard's compact card.
class _QuickAddPartDialog extends StatefulWidget {
  const _QuickAddPartDialog({required this.onSave});
  final Future<void> Function(int inventoryItemId, int qty, int cost) onSave;

  @override
  State<_QuickAddPartDialog> createState() => _QuickAddPartDialogState();
}

class _QuickAddPartDialogState extends State<_QuickAddPartDialog> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  List<dynamic> _parts = [];
  int? _selectedId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SparePartService.instance
        .list()
        .then((list) {
          if (mounted)
            setState(() {
              _parts = list;
              _loading = false;
            });
        })
        .catchError((_) {
          if (mounted) setState(() => _loading = false);
        });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final cost = int.tryParse(_costCtrl.text.trim()) ?? 0;
    if (_selectedId == null || qty <= 0) {
      setState(() => _error = 'Select a part and a valid quantity.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.onSave(_selectedId!, qty, cost);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Part', style: AppTheme.bodyStrong),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            // Spare-parts catalog can run to hundreds of SKUs — client-side
            // combobox per Section 4 of hypermed_claude_code_prompt.md.
            AppSearchableSelectField<int>(
              hint: 'Select part…',
              selectedLabel: _selectedId == null
                  ? null
                  : (_parts.firstWhere((p) => p.id == _selectedId).name as String),
              items: _parts
                  .map<AppSelectItem<int>>(
                    (p) => AppSelectItem(value: p.id as int, label: p.name as String),
                  )
                  .toList(),
              onSelected: (item) => setState(() {
                _selectedId = item?.value;
                if (item != null) {
                  final p = _parts.firstWhere((p) => p.id == item.value);
                  _costCtrl.text = (p.unitCost as num).toInt().toString();
                }
              }),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Unit cost'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTheme.bodySub.copyWith(color: AppColors.coral),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Cancel',
                variant: BtnVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: _saving ? 'Saving…' : 'Save',
                variant: BtnVariant.primary,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
