class Delegation {
  final int id;
  final String? delegatorName;
  final int delegateId;
  final String? delegateName;
  final String? reason;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? revokedAt;
  final String? revokedByName;
  final bool isActive;

  const Delegation({
    required this.id,
    this.delegatorName,
    required this.delegateId,
    this.delegateName,
    this.reason,
    this.startsAt,
    this.endsAt,
    this.revokedAt,
    this.revokedByName,
    this.isActive = false,
  });

  factory Delegation.fromJson(Map<String, dynamic> j) => Delegation(
    id: (j['id'] as num).toInt(),
    delegatorName: j['delegator_name'] as String?,
    delegateId: (j['delegate_id'] as num).toInt(),
    delegateName: j['delegate_name'] as String?,
    reason: j['reason'] as String?,
    startsAt: j['starts_at'] != null ? DateTime.tryParse(j['starts_at'] as String) : null,
    endsAt: j['ends_at'] != null ? DateTime.tryParse(j['ends_at'] as String) : null,
    revokedAt: j['revoked_at'] != null ? DateTime.tryParse(j['revoked_at'] as String) : null,
    revokedByName: j['revoked_by_name'] as String?,
    isActive: j['is_active'] as bool? ?? false,
  );
}
