// Five real stages: requester -> team lead -> CTO -> finance (initiates
// payment, doesn't move money on their own authority) -> Director
// (authorizes/actually marks paid). 'approved' is kept only so any old
// cached/offline data still parses to something sane; the backend no
// longer writes it.
enum PerDiemStatus { pendingTeamLead, pendingCto, pendingPayment, pendingDirector, approved, paid, rejected, cancelled }

extension PerDiemStatusX on PerDiemStatus {
  String get label => switch (this) {
    PerDiemStatus.pendingTeamLead => 'Awaiting Team Lead',
    PerDiemStatus.pendingCto      => 'Awaiting CTO',
    PerDiemStatus.pendingPayment  => 'Awaiting Payment Initiation',
    PerDiemStatus.pendingDirector => 'Awaiting Director Authorization',
    PerDiemStatus.approved        => 'Approved',
    PerDiemStatus.paid            => 'Paid',
    PerDiemStatus.rejected        => 'Rejected',
    PerDiemStatus.cancelled       => 'Cancelled',
  };
}

PerDiemStatus _parsePerDiemStatus(String s) => switch (s) {
  'pending_cto'      => PerDiemStatus.pendingCto,
  'pending_payment'  => PerDiemStatus.pendingPayment,
  'pending_director' => PerDiemStatus.pendingDirector,
  'approved'         => PerDiemStatus.approved,
  'paid'             => PerDiemStatus.paid,
  'rejected'         => PerDiemStatus.rejected,
  'cancelled'        => PerDiemStatus.cancelled,
  _                  => PerDiemStatus.pendingTeamLead,
};

class PerDiemLine {
  final int?    id;
  final int     seqNo;
  final String  date;
  final String? region;
  final String? district;
  final String? siteName;
  final String? activity;
  final int     laborCost;
  final int     perDiemCost;
  final int     transportFare;

  const PerDiemLine({
    this.id,
    required this.seqNo,
    required this.date,
    this.region,
    this.district,
    this.siteName,
    this.activity,
    this.laborCost = 0,
    this.perDiemCost = 0,
    this.transportFare = 0,
  });

  int get total => laborCost + perDiemCost + transportFare;

  factory PerDiemLine.fromJson(Map<String, dynamic> j) => PerDiemLine(
    id:            (j['id'] as num?)?.toInt(),
    seqNo:         (j['seq_no'] as num? ?? 0).toInt(),
    date:          j['date'] as String? ?? '',
    region:        j['region'] as String?,
    district:      j['district'] as String?,
    siteName:      j['site_name'] as String?,
    activity:      j['activity'] as String?,
    laborCost:     (j['labor_cost'] as num? ?? 0).toInt(),
    perDiemCost:   (j['per_diem_cost'] as num? ?? 0).toInt(),
    transportFare: (j['transport_fare'] as num? ?? 0).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'date':           date,
    'region':         region,
    'district':       district,
    'site_name':      siteName,
    'activity':       activity,
    'labor_cost':     laborCost,
    'per_diem_cost':  perDiemCost,
    'transport_fare': transportFare,
  };
}

class PerDiemRequest {
  final int             id;
  final int             userId;
  final String?         userName;
  final int?            serviceTicketId;
  final String          destination;
  final String          startDate;
  final String          endDate;
  final int             daysCount;
  final int?            dailyRate;
  final int             amount;
  final String?         purpose;
  final PerDiemStatus   status;
  final int?            teamLeadReviewedBy;
  final String?         teamLeadReviewerName;
  final String?         teamLeadReviewedAt;
  final String?         teamLeadRejectionReason;
  final int?            reviewedBy;
  final String?         reviewerName;
  final String?         reviewedAt;
  final String?         rejectionReason;
  final int?            paymentInitiatedBy;
  final String?         paymentInitiatedByName;
  final String?         paymentInitiatedAt;
  final String?         paymentMethod;
  final String?         paymentReference;
  final String?         paidByName;
  final String?         paidAt;
  final String?         createdAt;
  final List<PerDiemLine> lines;

  const PerDiemRequest({
    required this.id,
    required this.userId,
    this.userName,
    this.serviceTicketId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    this.dailyRate,
    required this.amount,
    this.purpose,
    required this.status,
    this.teamLeadReviewedBy,
    this.teamLeadReviewerName,
    this.teamLeadReviewedAt,
    this.teamLeadRejectionReason,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    this.rejectionReason,
    this.paymentInitiatedBy,
    this.paymentInitiatedByName,
    this.paymentInitiatedAt,
    this.paymentMethod,
    this.paymentReference,
    this.paidByName,
    this.paidAt,
    this.createdAt,
    this.lines = const [],
  });

  factory PerDiemRequest.fromJson(Map<String, dynamic> j) => PerDiemRequest(
    id:                      (j['id'] as num).toInt(),
    userId:                  (j['user_id'] as num? ?? 0).toInt(),
    userName:                j['user_name'] as String?,
    serviceTicketId:         j['service_ticket_id'] != null ? (j['service_ticket_id'] as num).toInt() : null,
    destination:             j['destination'] as String? ?? '—',
    startDate:               j['start_date'] as String? ?? '—',
    endDate:                 j['end_date'] as String? ?? '—',
    daysCount:               (j['days_count'] as num? ?? 0).toInt(),
    dailyRate:               (j['daily_rate'] as num?)?.toInt(),
    amount:                  (j['amount'] as num? ?? 0).toInt(),
    purpose:                 j['purpose'] as String?,
    status:                  _parsePerDiemStatus(j['status'] as String? ?? 'pending_team_lead'),
    teamLeadReviewedBy:      j['team_lead_reviewed_by'] != null ? (j['team_lead_reviewed_by'] as num).toInt() : null,
    teamLeadReviewerName:    j['team_lead_reviewer_name'] as String?,
    teamLeadReviewedAt:      j['team_lead_reviewed_at'] as String?,
    teamLeadRejectionReason: j['team_lead_rejection_reason'] as String?,
    reviewedBy:              j['reviewed_by'] != null ? (j['reviewed_by'] as num).toInt() : null,
    reviewerName:            j['reviewer_name'] as String?,
    reviewedAt:              j['reviewed_at'] as String?,
    rejectionReason:         j['rejection_reason'] as String?,
    paymentInitiatedBy:      j['payment_initiated_by'] != null ? (j['payment_initiated_by'] as num).toInt() : null,
    paymentInitiatedByName:  j['payment_initiated_by_name'] as String?,
    paymentInitiatedAt:      j['payment_initiated_at'] as String?,
    paymentMethod:           j['payment_method'] as String?,
    paymentReference:        j['payment_reference'] as String?,
    paidByName:              j['paid_by_name'] as String?,
    paidAt:                  j['paid_at'] as String?,
    createdAt:               j['created_at'] as String?,
    lines: (j['lines'] as List<dynamic>? ?? [])
        .map((l) => PerDiemLine.fromJson(l as Map<String, dynamic>)).toList(),
  );

  bool get isPendingTeamLead     => status == PerDiemStatus.pendingTeamLead;
  bool get isPendingCto          => status == PerDiemStatus.pendingCto;
  bool get isPendingPayment      => status == PerDiemStatus.pendingPayment;
  bool get isPendingDirector     => status == PerDiemStatus.pendingDirector;
  bool get isPaid                => status == PerDiemStatus.paid;
}
