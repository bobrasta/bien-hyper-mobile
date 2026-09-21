class MyServiceReportMachine {
  final int id;
  final String? serialNo;
  final String? model;

  const MyServiceReportMachine({required this.id, this.serialNo, this.model});

  factory MyServiceReportMachine.fromJson(Map<String, dynamic> j) => MyServiceReportMachine(
    id:       (j['id'] as num).toInt(),
    serialNo: j['serial_no'] as String?,
    model:    j['model'] as String?,
  );
}

// Section 7: "My past service reports" — a service_report ticket attachment,
// flattened with enough ticket/hospital/machine context to list, filter and
// jump back to the ticket without a second round-trip per row.
class MyServiceReport {
  final int    id;
  final String name;
  final int    size;
  final String? mimeType;
  final String url;
  final String? createdAt;
  final int    ticketId;
  final String ticketNumber;
  final String ticketType; // repair | installation
  final String? ticketResolvedAt;
  final String? hospitalName;
  final List<MyServiceReportMachine> machines;

  const MyServiceReport({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
    required this.url,
    this.createdAt,
    required this.ticketId,
    required this.ticketNumber,
    required this.ticketType,
    this.ticketResolvedAt,
    this.hospitalName,
    this.machines = const [],
  });

  factory MyServiceReport.fromJson(Map<String, dynamic> j) => MyServiceReport(
    id:               (j['id'] as num).toInt(),
    name:             j['name'] as String? ?? 'Report',
    size:             (j['size'] as num? ?? 0).toInt(),
    mimeType:         j['mime_type'] as String?,
    url:              j['url'] as String? ?? '',
    createdAt:        j['created_at'] as String?,
    ticketId:         (j['ticket_id'] as num).toInt(),
    ticketNumber:     j['ticket_number'] as String? ?? '—',
    ticketType:       j['ticket_type'] as String? ?? 'repair',
    ticketResolvedAt: j['ticket_resolved_at'] as String?,
    hospitalName:     j['hospital_name'] as String?,
    machines: (j['machines'] as List<dynamic>? ?? [])
        .map((m) => MyServiceReportMachine.fromJson(m as Map<String, dynamic>)).toList(),
  );
}
