enum PipelineStage { lead, qualified, demoScheduled, proposalSent, negotiation, won, lost }

extension PipelineStageX on PipelineStage {
  String get label {
    switch (this) {
      case PipelineStage.lead:          return 'Lead';
      case PipelineStage.qualified:     return 'Qualified';
      case PipelineStage.demoScheduled: return 'Demo Scheduled';
      case PipelineStage.proposalSent:  return 'Proposal Sent';
      case PipelineStage.negotiation:   return 'Negotiation';
      case PipelineStage.won:           return 'Won';
      case PipelineStage.lost:          return 'Lost';
    }
  }
}

PipelineStage _parseStage(String s) => switch (s) {
  'qualified'      => PipelineStage.qualified,
  'demo_scheduled' => PipelineStage.demoScheduled,
  'proposal_sent'  => PipelineStage.proposalSent,
  'negotiation'    => PipelineStage.negotiation,
  'won'            => PipelineStage.won,
  'lost'           => PipelineStage.lost,
  _                => PipelineStage.lead,
};

class SalesLead {
  final int    id;
  final String hospital;
  final String contact;
  final String machineType;
  final int    dealValue;
  final int    daysInStage;
  final PipelineStage stage;
  final String? demoDate;

  const SalesLead({
    required this.id,
    required this.hospital,
    required this.contact,
    required this.machineType,
    required this.dealValue,
    required this.daysInStage,
    required this.stage,
    this.demoDate,
  });

  factory SalesLead.fromJson(Map<String, dynamic> j) => SalesLead(
    id:          (j['id'] as num? ?? 0).toInt(),
    hospital:    j['hospital'] is Map
        ? (j['hospital'] as Map)['name'] as String? ?? j['hospital_name'] as String? ?? '—'
        : j['hospital'] as String? ?? j['hospital_name'] as String? ?? '—',
    contact:     j['contact']      as String? ?? j['contact_name'] as String? ?? '—',
    machineType: j['machine_type'] as String? ?? '—',
    dealValue:   (j['deal_value']  as num? ?? 0).toInt(),
    daysInStage: (j['days_in_stage'] as num? ?? 0).toInt(),
    stage:       _parseStage(j['stage'] as String? ?? 'lead'),
    demoDate:    j['demo_date']    as String?,
  );
}
