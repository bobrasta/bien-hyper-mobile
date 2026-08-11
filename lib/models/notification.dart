enum NotificationType {
  serviceDue,
  ticketAssigned,
  ticketUpdated,
  paymentOverdue,
  warrantyExpiring,
  dealUpdated,
  leadFollowUp,
  taskAssigned,
  taskCompleted,
  stockPullRequired,
  leaveRequested,
  leaveApproved,
  leaveRejected,
  lateArrival,
  system,
}

extension NotificationTypeX on NotificationType {
  String get label => switch (this) {
    NotificationType.serviceDue         => 'Service Due',
    NotificationType.ticketAssigned     => 'Ticket Assigned',
    NotificationType.ticketUpdated      => 'Ticket Updated',
    NotificationType.paymentOverdue     => 'Payment Overdue',
    NotificationType.warrantyExpiring   => 'Warranty Expiring',
    NotificationType.dealUpdated        => 'Deal Updated',
    NotificationType.leadFollowUp       => 'Follow-up Due',
    NotificationType.taskAssigned       => 'Task Assigned',
    NotificationType.taskCompleted      => 'Task Completed',
    NotificationType.stockPullRequired  => 'Stock Pull Required',
    NotificationType.leaveRequested     => 'Leave Requested',
    NotificationType.leaveApproved      => 'Leave Approved',
    NotificationType.leaveRejected      => 'Leave Rejected',
    NotificationType.lateArrival        => 'Running Late',
    NotificationType.system             => 'System',
  };
}

NotificationType _parseType(String s) => switch (s) {
  'ticket_assigned'      => NotificationType.ticketAssigned,
  'ticket_updated'       => NotificationType.ticketUpdated,
  'payment_overdue'      => NotificationType.paymentOverdue,
  'warranty_expiring'    => NotificationType.warrantyExpiring,
  'deal_updated'         => NotificationType.dealUpdated,
  'lead_follow_up'       => NotificationType.leadFollowUp,
  'task_assigned'        => NotificationType.taskAssigned,
  'task_completed'       => NotificationType.taskCompleted,
  'stock_pull_required'  => NotificationType.stockPullRequired,
  'leave_requested'      => NotificationType.leaveRequested,
  'leave_approved'       => NotificationType.leaveApproved,
  'leave_rejected'       => NotificationType.leaveRejected,
  'late_arrival'         => NotificationType.lateArrival,
  'system'               => NotificationType.system,
  _                      => NotificationType.serviceDue,
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
