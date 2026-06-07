enum NotificationType {
  serviceDue,
  ticketAssigned,
  ticketUpdated,
  paymentOverdue,
  warrantyExpiring,
  dealUpdated,
  system,
}

extension NotificationTypeX on NotificationType {
  String get label => switch (this) {
    NotificationType.serviceDue       => 'Service Due',
    NotificationType.ticketAssigned   => 'Ticket Assigned',
    NotificationType.ticketUpdated    => 'Ticket Updated',
    NotificationType.paymentOverdue   => 'Payment Overdue',
    NotificationType.warrantyExpiring => 'Warranty Expiring',
    NotificationType.dealUpdated      => 'Deal Updated',
    NotificationType.system           => 'System',
  };
}

NotificationType _parseType(String s) => switch (s) {
  'ticket_assigned'   => NotificationType.ticketAssigned,
  'ticket_updated'    => NotificationType.ticketUpdated,
  'payment_overdue'   => NotificationType.paymentOverdue,
  'warranty_expiring' => NotificationType.warrantyExpiring,
  'deal_updated'      => NotificationType.dealUpdated,
  'system'            => NotificationType.system,
  _                   => NotificationType.serviceDue,
};

class AppNotification {
  final int    id;
  final NotificationType type;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final bool   isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.entityType,
    this.entityId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id:         (j['id'] as num).toInt(),
    type:       _parseType(j['type'] as String? ?? 'system'),
    title:      j['title']      as String? ?? '',
    body:       j['body']       as String? ?? j['message'] as String? ?? '',
    entityType: j['entity_type'] as String?,
    entityId:   j['entity_id']?.toString(),
    isRead:     j['is_read'] as bool? ?? j['read'] as bool? ?? false,
    createdAt:  j['created_at'] as String? ?? '',
  );
}
