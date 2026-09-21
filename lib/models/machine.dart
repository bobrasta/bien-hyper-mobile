enum MachineStatus { pendingInstallation, pendingSignoff, operational, needsService, down, warranty, idle }

extension MachineStatusX on MachineStatus {
  String get label {
    switch (this) {
      case MachineStatus.pendingInstallation: return 'Pending Installation';
      case MachineStatus.pendingSignoff:      return 'Pending Sign-off';
      case MachineStatus.operational:  return 'Operational';
      case MachineStatus.needsService: return 'Service';
      case MachineStatus.down:         return 'Down';
      case MachineStatus.warranty:     return 'Warranty';
      case MachineStatus.idle:         return 'Idle';
    }
  }
  String get cssClass {
    switch (this) {
      case MachineStatus.pendingInstallation: return 'pending_install';
      case MachineStatus.pendingSignoff:      return 'pending_signoff';
      case MachineStatus.operational:  return 'op';
      case MachineStatus.needsService: return 'svc';
      case MachineStatus.down:         return 'down';
      case MachineStatus.warranty:     return 'claim';
      case MachineStatus.idle:         return 'idle';
    }
  }
}

MachineStatus _parseStatus(String s) => switch (s) {
  'pending_installation' => MachineStatus.pendingInstallation,
  'pending_signoff'      => MachineStatus.pendingSignoff,
  'operational'   => MachineStatus.operational,
  'needs_service' => MachineStatus.needsService,
  'down'          => MachineStatus.down,
  'warranty'      => MachineStatus.warranty,
  _               => MachineStatus.idle,
};

class Machine {
  final int    id;
  final String serialNo;
  final String model;
  final String type;
  final String hospital;
  final String ward;
  final String installDate;
  final String warrantyExpiry;
  final MachineStatus status;
  final int revenuePerMonth;
  final int? hospitalId;
  final String? technicianName;
  final String? technicianInitials;
  final String? notes;
  final Map<String, String> specifications;
  final double? latitude;
  final double? longitude;
  // Section 13: In Stock / Allocated / Installed (+ later Returned/Decommissioned).
  final String lifecycleStage;
  final String? manufacturer;
  final String? condition;
  final String? arrivalDate;
  final int? storeLocationId;
  final String? storeLocationName;
  // Section 12: original currency amount + TSh comparison amount.
  final int? purchaseCost;
  final String? purchaseCostCurrency;
  final int? purchaseCostTsh;
  final String? purchaseCostRecordedAt;

  const Machine({
    required this.id,
    required this.serialNo,
    required this.model,
    required this.type,
    required this.hospital,
    required this.ward,
    required this.installDate,
    required this.warrantyExpiry,
    required this.status,
    required this.revenuePerMonth,
    this.hospitalId,
    this.technicianName,
    this.technicianInitials,
    this.notes,
    this.specifications = const {},
    this.latitude,
    this.longitude,
    this.lifecycleStage = 'installed',
    this.manufacturer,
    this.condition,
    this.arrivalDate,
    this.storeLocationId,
    this.storeLocationName,
    this.purchaseCost,
    this.purchaseCostCurrency,
    this.purchaseCostTsh,
    this.purchaseCostRecordedAt,
  });

  bool get isInstalled => lifecycleStage == 'installed';
  bool get isInStock => lifecycleStage == 'in_stock';

  factory Machine.fromJson(Map<String, dynamic> j) => Machine(
    id:             (j['id'] as num).toInt(),
    serialNo:       j['serial_no']       as String? ?? '—',
    model:          j['model']           as String? ?? '—',
    type:           j['type']            as String? ?? '—',
    hospital:       j['hospital'] is Map
        ? (j['hospital'] as Map)['name'] as String? ?? '—'
        : j['hospital'] as String? ?? j['hospital_name'] as String? ?? '—',
    ward:           j['ward']            as String? ?? '—',
    installDate:    j['install_date']    as String? ?? '—',
    warrantyExpiry: j['warranty_expiry'] as String? ?? '—',
    status:         _parseStatus(j['status'] as String? ?? 'idle'),
    revenuePerMonth:(j['revenue_per_month'] as num? ?? 0).toInt(),
    hospitalId:     j['hospital_id'] as int?
                  ?? (j['hospital'] is Map ? (j['hospital'] as Map)['id'] as int? : null),
    technicianName:     j['technician_name']     as String?
                      ?? (j['technician'] is Map ? (j['technician'] as Map)['name'] as String? : null),
    technicianInitials: j['technician_initials'] as String?
                      ?? (j['technician'] is Map ? (j['technician'] as Map)['initials'] as String? : null),
    notes:          j['notes'] as String?,
    specifications: _parseSpecs(j['specifications']),
    latitude:       (j['latitude']  as num?)?.toDouble()
                  ?? (j['hospital'] is Map ? (j['hospital'] as Map)['latitude']  as num? : null)?.toDouble(),
    longitude:      (j['longitude'] as num?)?.toDouble()
                  ?? (j['hospital'] is Map ? (j['hospital'] as Map)['longitude'] as num? : null)?.toDouble(),
    lifecycleStage:      j['lifecycle_stage'] as String? ?? 'installed',
    manufacturer:        j['manufacturer'] as String?,
    condition:           j['condition'] as String?,
    arrivalDate:         j['arrival_date'] as String?,
    storeLocationId:     j['store_location_id'] as int?,
    storeLocationName:   j['store_location_name'] as String?,
    purchaseCost:        (j['purchase_cost'] as num?)?.toInt(),
    purchaseCostCurrency: j['purchase_cost_currency'] as String?,
    purchaseCostTsh:     (j['purchase_cost_tsh'] as num?)?.toInt(),
    purchaseCostRecordedAt: j['purchase_cost_recorded_at'] as String?,
  );

  static Map<String, String> _parseSpecs(dynamic raw) {
    if (raw == null) return const {};
    final out = <String, String>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.value != null) out[e.key.toString()] = e.value.toString();
      }
    } else if (raw is List) {
      for (final s in raw) {
        if (s is Map && s['key'] != null && s['value'] != null) {
          out[s['key'].toString()] = s['value'].toString();
        }
      }
    }
    return out;
  }
}
