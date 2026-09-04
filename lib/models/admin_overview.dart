// Response shape for GET /dashboard/admin-overview — a fixed, admin-only
// "Command Centre" layout, not the generic permission-driven section list
// every other role gets (see UnifiedDashboardSection). Mirrors the backend
// response 1:1 since this screen isn't generic — no dynamic-key dispatch
// needed here.
class AdminGreeting {
  final String name;
  final String date;
  final int machinesDown;
  final int openTickets;
  final int techniciansOut;

  const AdminGreeting({
    required this.name, required this.date, required this.machinesDown,
    required this.openTickets, required this.techniciansOut,
  });

  factory AdminGreeting.fromJson(Map<String, dynamic> j) => AdminGreeting(
        name:           j['name'] as String? ?? '',
        date:           j['date'] as String? ?? '',
        machinesDown:   (j['machines_down'] as num? ?? 0).toInt(),
        openTickets:    (j['open_tickets'] as num? ?? 0).toInt(),
        techniciansOut: (j['technicians_out'] as num? ?? 0).toInt(),
      );
}

class AttentionItem {
  final String title;
  final String meta;
  final String? age;
  final String severity;

  const AttentionItem({required this.title, required this.meta, this.age, required this.severity});

  factory AttentionItem.fromJson(Map<String, dynamic> j) => AttentionItem(
        title:    j['title'] as String? ?? '',
        meta:     j['meta'] as String? ?? '',
        age:      j['age'] as String?,
        severity: j['severity'] as String? ?? 'info',
      );
}

class TechnicianRosterEntry {
  final String name;
  final String state; // en_route | available | on_leave
  final String where;

  const TechnicianRosterEntry({required this.name, required this.state, required this.where});

  factory TechnicianRosterEntry.fromJson(Map<String, dynamic> j) => TechnicianRosterEntry(
        name:  j['name'] as String? ?? '',
        state: j['state'] as String? ?? 'available',
        where: j['where'] as String? ?? '',
      );
}

class ZoneCount {
  final String name;
  final int count;
  const ZoneCount({required this.name, required this.count});

  factory ZoneCount.fromJson(Map<String, dynamic> j) =>
      ZoneCount(name: j['name'] as String? ?? '', count: (j['count'] as num? ?? 0).toInt());
}

class AdminOverview {
  final AdminGreeting greeting;
  final Map<String, dynamic> kpis;
  final Map<String, int> fleetLegend;
  final List<ZoneCount> zones;
  final List<AttentionItem> attention;
  final List<TechnicianRosterEntry> technicians;
  final Map<String, dynamic> sales;
  final Map<String, dynamic> finance;
  final Map<String, dynamic> inventory;
  final Map<String, dynamic> people;

  const AdminOverview({
    required this.greeting, required this.kpis, required this.fleetLegend,
    required this.zones, required this.attention, required this.technicians,
    required this.sales, required this.finance, required this.inventory, required this.people,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> j) {
    final fleet = (j['fleet'] as Map?)?.cast<String, dynamic>() ?? const {};
    final legend = (fleet['legend'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AdminOverview(
      greeting: AdminGreeting.fromJson((j['greeting'] as Map?)?.cast<String, dynamic>() ?? const {}),
      kpis: (j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {},
      fleetLegend: legend.map((k, v) => MapEntry(k, (v as num? ?? 0).toInt())),
      zones: (fleet['zones'] as List? ?? [])
          .map((z) => ZoneCount.fromJson((z as Map).cast<String, dynamic>())).toList(),
      attention: (j['attention'] as List? ?? [])
          .map((a) => AttentionItem.fromJson((a as Map).cast<String, dynamic>())).toList(),
      technicians: (j['technicians'] as List? ?? [])
          .map((t) => TechnicianRosterEntry.fromJson((t as Map).cast<String, dynamic>())).toList(),
      sales:     (j['sales'] as Map?)?.cast<String, dynamic>() ?? const {},
      finance:   (j['finance'] as Map?)?.cast<String, dynamic>() ?? const {},
      inventory: (j['inventory'] as Map?)?.cast<String, dynamic>() ?? const {},
      people:    (j['people'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
