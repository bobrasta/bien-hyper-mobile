// lib/models/cto_overview.dart — response of GET /dashboard/cto-overview (proposed).
// CTO-only technical-ops snapshot. Approvals are NOT in this payload — they
// come from the existing per-diem / expense / stock-out endpoints (see
// CtoDashboardService.loadApprovals) so there's one source of truth for each.

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
DateTime _date(dynamic v) => DateTime.tryParse('${v ?? ''}') ?? DateTime.now();
List<Map<String, dynamic>> _list(dynamic v) =>
    (v as List? ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

class CtoKpis {
  final double fleetUptimePct;
  final int machinesOperational;
  final int machinesTotal;
  final int machinesDown;
  final int machinesDownToday;
  final int hospitalsAffected;
  final int openTickets;
  final int slaBreached;
  final int slaAtRisk;
  final int techniciansTotal;
  final int techniciansOut;
  final int techniciansOnLeave;
  final int lowStockCount;
  final int openPurchaseOrders;

  const CtoKpis({
    required this.fleetUptimePct, required this.machinesOperational, required this.machinesTotal,
    required this.machinesDown, required this.machinesDownToday, required this.hospitalsAffected,
    required this.openTickets, required this.slaBreached, required this.slaAtRisk,
    required this.techniciansTotal, required this.techniciansOut, required this.techniciansOnLeave,
    required this.lowStockCount, required this.openPurchaseOrders,
  });

  factory CtoKpis.fromJson(Map<String, dynamic> j) => CtoKpis(
        fleetUptimePct:      _d(j['fleet_uptime_pct']),
        machinesOperational: _i(j['machines_operational']),
        machinesTotal:       _i(j['machines_total']),
        machinesDown:        _i(j['machines_down']),
        machinesDownToday:   _i(j['machines_down_today']),
        hospitalsAffected:   _i(j['hospitals_affected']),
        openTickets:         _i(j['open_tickets']),
        slaBreached:         _i(j['sla_breached']),
        slaAtRisk:           _i(j['sla_at_risk']),
        techniciansTotal:    _i(j['technicians_total']),
        techniciansOut:      _i(j['technicians_out']),
        techniciansOnLeave:  _i(j['technicians_on_leave']),
        lowStockCount:       _i(j['low_stock_count']),
        openPurchaseOrders:  _i(j['open_purchase_orders']),
      );
}

class DownMachine {
  final int machineId;
  final String name;      // "MRI scanner"
  final String hospital;  // "Mount Meru RRH"
  final String note;      // "Arusha · unassigned"
  final int downHours;

  const DownMachine({required this.machineId, required this.name, required this.hospital, required this.note, required this.downHours});

  String get ageLabel => downHours >= 24 ? '${downHours ~/ 24} d' : '$downHours h';

  factory DownMachine.fromJson(Map<String, dynamic> j) => DownMachine(
        machineId: _i(j['machine_id']),
        name:      j['name'] as String? ?? '',
        hospital:  j['hospital'] as String? ?? '',
        note:      j['note'] as String? ?? '',
        downHours: _i(j['down_hours']),
      );
}

enum SlaState { breached, atRisk, ok }

class SlaTicket {
  final int id;
  final String number;          // "ST-0921"
  final String title;
  final String hospital;
  final String? assigneeName;   // null → unassigned
  final String? assigneeNote;   // "waiting HV board"
  final int slaTargetHours;     // 48
  final int hoursLeft;          // negative = overdue

  const SlaTicket({
    required this.id, required this.number, required this.title, required this.hospital,
    this.assigneeName, this.assigneeNote, required this.slaTargetHours, required this.hoursLeft,
  });

  bool get unassigned => assigneeName == null;
  // Same thresholds as the mock: breached < 0, at risk < 8 h.
  SlaState get state => hoursLeft < 0 ? SlaState.breached : hoursLeft < 8 ? SlaState.atRisk : SlaState.ok;
  double get usedFraction => hoursLeft < 0 ? 1 : ((slaTargetHours - hoursLeft) / slaTargetHours).clamp(0.0, 1.0);
  String get leftLabel {
    final h = hoursLeft.abs();
    final v = h >= 48 ? '${h ~/ 24} d' : '$h h';
    return hoursLeft < 0 ? '$v over' : '$v left';
  }
  String get whoLabel => unassigned ? 'Unassigned' : [assigneeName, assigneeNote].whereType<String>().join(' · ');

  factory SlaTicket.fromJson(Map<String, dynamic> j) => SlaTicket(
        id:             _i(j['id']),
        number:         j['ticket_number'] as String? ?? '',
        title:          j['title'] as String? ?? '',
        hospital:       j['hospital'] as String? ?? '',
        assigneeName:   j['assignee_name'] as String?,
        assigneeNote:   j['assignee_note'] as String?,
        slaTargetHours: _i(j['sla_target_hours']) == 0 ? 48 : _i(j['sla_target_hours']),
        hoursLeft:      _i(j['sla_hours_left']),
      );
}

enum TripBarKind { approved, pendingCto, leave }

class TripBar {
  final int? perDiemRequestId; // set for trips — lets a local approve/return recolour the bar
  final String label;
  final DateTime start;
  final DateTime end;          // inclusive
  final TripBarKind kind;

  const TripBar({this.perDiemRequestId, required this.label, required this.start, required this.end, required this.kind});

  factory TripBar.fromJson(Map<String, dynamic> j) => TripBar(
        perDiemRequestId: (j['per_diem_request_id'] as num?)?.toInt(),
        label: j['label'] as String? ?? '',
        start: _date(j['start_date']),
        end:   _date(j['end_date']),
        kind: switch (j['kind']) {
          'pending_cto' => TripBarKind.pendingCto,
          'leave'       => TripBarKind.leave,
          _             => TripBarKind.approved,
        },
      );
}

class TeamMember {
  final int userId;
  final String name;
  final String state;   // en_route | base | on_leave
  final String where;   // "Singida RRH"
  final String tripNote;
  final List<TripBar> bars;

  const TeamMember({required this.userId, required this.name, required this.state, required this.where, required this.tripNote, this.bars = const []});

  String get initials {
    final p = name.replaceAll('.', ' ').split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.length == 1 ? p[0][0] : p[0][0] + p.last[0]).toUpperCase();
  }

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        userId:   _i(j['user_id']),
        name:     j['name'] as String? ?? '',
        state:    j['state'] as String? ?? 'base',
        where:    j['where'] as String? ?? '',
        tripNote: j['trip_note'] as String? ?? '',
        bars:     _list(j['bars']).map(TripBar.fromJson).toList(),
      );
}

class SpareAlert {
  final int itemId;
  final String name;
  final int qty;
  final String note;      // "Blocks ST-0918 · request pending you"
  final String severity;  // critical | warning | ok

  const SpareAlert({required this.itemId, required this.name, required this.qty, required this.note, required this.severity});

  factory SpareAlert.fromJson(Map<String, dynamic> j) => SpareAlert(
        itemId:   _i(j['item_id']),
        name:     j['name'] as String? ?? '',
        qty:      _i(j['qty']),
        note:     j['note'] as String? ?? '',
        severity: j['severity'] as String? ?? 'warning',
      );
}

class CtoOverview {
  final String name;
  final CtoKpis kpis;
  final Map<String, int> fleetLegend; // operational | needs_service | down | technician_en_route
  final List<DownMachine> downLongest;
  final List<SlaTicket> tickets;
  final List<TeamMember> team;
  final List<SpareAlert> spares;
  final DateTime calendarStart; // Monday of the current week
  final int calendarDays;       // 14

  const CtoOverview({
    required this.name, required this.kpis, required this.fleetLegend, required this.downLongest,
    required this.tickets, required this.team, required this.spares,
    required this.calendarStart, this.calendarDays = 14,
  });

  factory CtoOverview.fromJson(Map<String, dynamic> j) {
    final legend = (j['fleet_legend'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cal = (j['calendar'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CtoOverview(
      name:          (j['greeting'] as Map?)?['name'] as String? ?? '',
      kpis:          CtoKpis.fromJson((j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {}),
      fleetLegend:   legend.map((k, v) => MapEntry(k, _i(v))),
      downLongest:   _list(j['down_longest']).map(DownMachine.fromJson).toList(),
      tickets:       _list(j['sla_tickets']).map(SlaTicket.fromJson).toList(),
      team:          _list(cal['team']).map(TeamMember.fromJson).toList(),
      spares:        _list(j['spares']).map(SpareAlert.fromJson).toList(),
      calendarStart: _date(cal['start_date']),
      calendarDays:  _i(cal['days']) == 0 ? 14 : _i(cal['days']),
    );
  }
}
