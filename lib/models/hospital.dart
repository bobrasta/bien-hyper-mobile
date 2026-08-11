class Hospital {
  final int    id;
  final String name;
  final String shortCode;
  final String type;
  final String region;
  final String district;
  final double latitude;
  final double longitude;
  final int    machineCount;
  final int    machinesOperational;
  final double revenueMonthly;
  final int?   creditLimit;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final String? notes;

  const Hospital({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.type,
    required this.region,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.machineCount,
    required this.machinesOperational,
    required this.revenueMonthly,
    this.creditLimit,
    required this.contactName,
    required this.contactPhone,
    required this.contactEmail,
    this.notes,
  });

  factory Hospital.fromJson(Map<String, dynamic> j) => Hospital(
    id:                  (j['id']   as num).toInt(),
    name:                j['name']        as String?  ?? '—',
    shortCode:           j['short_code']  as String?  ?? j['code'] as String? ?? '??',
    type:                j['type']        as String?  ?? 'public',
    region:              j['region']      as String?  ?? '—',
    district:            j['district']    as String?  ?? '—',
    latitude:            (j['latitude']   as num?  ?? 0).toDouble(),
    longitude:           (j['longitude']  as num?  ?? 0).toDouble(),
    machineCount:        (j['machine_count']        as num? ?? 0).toInt(),
    machinesOperational: (j['machines_operational'] as num? ?? 0).toInt(),
    revenueMonthly:      (j['revenue_monthly']      as num? ?? 0).toDouble(),
    creditLimit:         (j['credit_limit'] as num?)?.toInt(),
    contactName:         j['contact_name']  as String? ?? '—',
    contactPhone:        j['contact_phone'] as String? ?? '—',
    contactEmail:        j['contact_email'] as String? ?? '—',
    notes:               j['notes'] as String?,
  );

  double get uptimePct =>
      machineCount == 0 ? 0 : machinesOperational / machineCount;
}
