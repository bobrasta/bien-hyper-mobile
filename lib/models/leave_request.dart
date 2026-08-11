enum LeaveType { sick, vacation, other }

extension LeaveTypeX on LeaveType {
  String get label => switch (this) {
    LeaveType.sick     => 'Sick Leave',
    LeaveType.vacation => 'Vacation',
    LeaveType.other    => 'Other',
  };

  String get apiValue => switch (this) {
    LeaveType.sick     => 'sick',
    LeaveType.vacation => 'vacation',
    LeaveType.other    => 'other',
  };
}

LeaveType _parseLeaveType(String s) => switch (s) {
  'sick'     => LeaveType.sick,
  'vacation' => LeaveType.vacation,
  _          => LeaveType.other,
};

enum LeaveStatus { pending, approved, rejected, cancelled }

extension LeaveStatusX on LeaveStatus {
  String get label => switch (this) {
    LeaveStatus.pending   => 'Pending',
    LeaveStatus.approved  => 'Approved',
    LeaveStatus.rejected  => 'Rejected',
    LeaveStatus.cancelled => 'Cancelled',
  };
}

LeaveStatus _parseLeaveStatus(String s) => switch (s) {
  'approved'  => LeaveStatus.approved,
  'rejected'  => LeaveStatus.rejected,
  'cancelled' => LeaveStatus.cancelled,
  _           => LeaveStatus.pending,
};

class LeaveRequest {
  final int          id;
  final int          userId;
  final String?      userName;
  final String?      userRole;
  final LeaveType    type;
  final String       startDate;
  final String       endDate;
  final int          daysCount;
  final String?      reason;
  final LeaveStatus  status;
  final int?         reviewedBy;
  final String?      reviewerName;
  final String?      reviewedAt;
  final String?      rejectionReason;
  final String?      createdAt;

  const LeaveRequest({
    required this.id,
    required this.userId,
    this.userName,
    this.userRole,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    this.rejectionReason,
    this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
    id:              (j['id'] as num).toInt(),
    userId:          (j['user_id'] as num? ?? 0).toInt(),
    userName:        j['user_name'] as String?,
    userRole:        j['user_role'] as String?,
    type:            _parseLeaveType(j['type'] as String? ?? 'other'),
    startDate:       j['start_date'] as String? ?? '—',
    endDate:         j['end_date'] as String? ?? '—',
    daysCount:       (j['days_count'] as num? ?? 0).toInt(),
    reason:          j['reason'] as String?,
    status:          _parseLeaveStatus(j['status'] as String? ?? 'pending'),
    reviewedBy:      j['reviewed_by'] != null ? (j['reviewed_by'] as num).toInt() : null,
    reviewerName:    j['reviewer_name'] as String?,
    reviewedAt:      j['reviewed_at'] as String?,
    rejectionReason: j['rejection_reason'] as String?,
    createdAt:       j['created_at'] as String?,
  );

  bool get isPending  => status == LeaveStatus.pending;
  bool get canCancel  => status == LeaveStatus.pending || status == LeaveStatus.approved;
}
