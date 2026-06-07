import '../widgets/common/avatar_widget.dart';

enum AvailStatus { available, assigned, onTask, busy, atDesk, offDuty }

extension AvailStatusX on AvailStatus {
  String get label => switch (this) {
    AvailStatus.available => 'Available',
    AvailStatus.assigned  => 'Assigned',
    AvailStatus.onTask    => 'On task',
    AvailStatus.busy      => 'Busy',
    AvailStatus.atDesk    => 'At desk',
    AvailStatus.offDuty   => 'Off duty',
  };
}

AvailStatus _parseStatus(String s) => switch (s.toLowerCase()) {
  'available'   => AvailStatus.available,
  'assigned'    => AvailStatus.assigned,
  'on_task' || 'on task'  => AvailStatus.onTask,
  'busy'        => AvailStatus.busy,
  'at_desk' || 'at desk'  => AvailStatus.atDesk,
  'off_duty' || 'off duty' => AvailStatus.offDuty,
  _             => AvailStatus.available,
};

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
  return '?';
}

AvatarVariant _variantFromId(int id) {
  const variants = AvatarVariant.values;
  return variants[id % variants.length];
}

class StaffMember {
  final int    id;
  final String name;
  final String initials;
  final String role;
  final String? group;   // 'field' | 'office' | 'admin'
  final String? zone;
  final AvailStatus availStatus;
  final double workload; // 0.0–1.0
  final AvatarVariant variant;
  final String? currentTask;
  final String? email;
  final String? phone;
  final bool? twoFa;
  final DateTime? lastActiveAt;

  const StaffMember({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
    this.group,
    this.zone,
    this.availStatus = AvailStatus.available,
    this.workload = 0.0,
    this.variant = AvatarVariant.teal,
    this.currentTask,
    this.email,
    this.phone,
    this.twoFa,
    this.lastActiveAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) {
    final id   = (j['id'] as num).toInt();
    final name = j['name'] as String? ?? '—';
    return StaffMember(
      id:          id,
      name:        name,
      initials:    j['initials'] as String? ?? _initials(name),
      role:        j['role'] as String? ?? j['job_title'] as String? ?? '—',
      group:       j['group'] as String? ?? _groupFromRole(j['role'] as String? ?? ''),
      zone:        j['zone']  as String? ?? j['region'] as String?,
      availStatus: _parseStatus(j['avail_status'] as String? ?? j['availability'] as String? ?? 'available'),
      workload:    (j['workload'] as num? ?? 0).toDouble(),
      variant:     _variantFromId(id),
      currentTask: j['current_task'] is Map
          ? (j['current_task'] as Map)['title'] as String?
          : j['current_task'] as String?,
      email:       j['email'] as String?,
      phone:       j['phone'] as String?,
      twoFa:       j['two_factor_enabled'] as bool? ?? j['two_fa'] as bool?,
      lastActiveAt: j['last_active_at'] != null
          ? DateTime.tryParse(j['last_active_at'] as String)
          : null,
    );
  }

  bool get isAvailable =>
      availStatus == AvailStatus.available || availStatus == AvailStatus.atDesk;
}

String _groupFromRole(String role) {
  final r = role.toLowerCase();
  if (r.contains('tech')) return 'field';
  if (r.contains('admin') || r.contains('owner')) return 'admin';
  return 'office';
}
