import 'staff_member.dart';

class TicketAttachment {
  final int     id;
  final String  name;
  final int     size;
  final String? mimeType;
  final String  url;
  final String  createdAt;
  // 'service_report' or null (generic attachment) — see Section 3 of
  // hypermed_claude_code_prompt.md.
  final String? category;

  const TicketAttachment({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
    required this.url,
    required this.createdAt,
    this.category,
  });

  bool get isServiceReport => category == 'service_report';

  factory TicketAttachment.fromJson(Map<String, dynamic> j) => TicketAttachment(
    id:        (j['id'] as num).toInt(),
    name:      j['name'] as String? ?? '—',
    size:      (j['size'] as num? ?? 0).toInt(),
    mimeType:  j['mime_type'] as String?,
    url:       j['url'] as String? ?? '',
    createdAt: j['created_at'] as String? ?? '',
    category:  j['category'] as String?,
  );
}

// Section 6 of hypermed_claude_code_prompt.md, generalized to every ticket
// type: one line in a ticket's machine list. status is 'pending' or 'done'
// — for an Installation ticket 'done' means the full Section 13 handover;
// for every other type it's just "this unit's work here is complete."
class TicketMachine {
  final int     id;
  final String  serialNo;
  final String  model;
  final String  status;
  final String? completedAt;

  const TicketMachine({
    required this.id,
    required this.serialNo,
    required this.model,
    required this.status,
    this.completedAt,
  });

  bool get isDone => status == 'done';

  factory TicketMachine.fromJson(Map<String, dynamic> j) => TicketMachine(
    id:          (j['id'] as num).toInt(),
    serialNo:    j['serial_no'] as String? ?? '—',
    model:       j['model'] as String? ?? '—',
    status:      j['status'] as String? ?? 'pending',
    completedAt: j['completed_at'] as String?,
  );
}

enum TicketStatus { open, inProgress, resolved, overdue }

extension TicketStatusX on TicketStatus {
  String get label {
    switch (this) {
      case TicketStatus.open:       return 'Open';
      case TicketStatus.inProgress: return 'In Progress';
      case TicketStatus.resolved:   return 'Resolved';
      case TicketStatus.overdue:    return 'Overdue';
    }
  }
}

// Safe string extraction from dynamic — returns null for non-String or empty values
String? _str(dynamic v) => (v is String && v.isNotEmpty) ? v : null;

// Pull a string field from a nested Map, e.g. j['technician']['name']
String? _nestedStr(dynamic obj, String key) =>
    obj is Map ? _str(obj[key]) : null;

TicketStatus _parseStatus(String s) => switch (s) {
  'in_progress' => TicketStatus.inProgress,
  'resolved'    => TicketStatus.resolved,
  'overdue'     => TicketStatus.overdue,
  _             => TicketStatus.open,
};

class ServiceTicket {
  final int    dbId;
  final String id;
  final String machineName;
  final String machineType;
  final String hospital;
  final String ward;
  final int?         assignedToId;
  // Not in the original spec's field list, but the technician dashboard's
  // revisit-detection logic explicitly needs to match tickets by machine —
  // added alongside the other new fields since there was no other way to
  // compute it. Read from top-level `machine_id` or a nested `machine.id`.
  final int?         machineId;
  final StaffMember? assignee;       // eager-loaded from j['assignee']
  final String       technicianInitials;
  final String       technicianName;
  final TicketStatus status;
  final String createdAt;
  final String? description;
  final String? resolutionNotes;
  final String? acknowledgedAt;
  final List<ChecklistItem>?    checklist;
  final List<PartUsed>?         partsUsed;
  final List<TicketAttachment>? attachments;
  // Priority/stage/SLA fields — used by the technician's personal dashboard
  // (current-assignment SLA badge, stage tracker) and task-history table.
  final String    priority;      // critical | high | medium | low, default 'medium'
  final String    stage;         // assigned | travelling | on_site | repair | signed_off
  final DateTime? travellingAt;
  final DateTime? onSiteAt;
  final DateTime? repairAt;
  final DateTime? signedOffAt;
  final DateTime? resolvedAt;
  final String    type;          // installation | corrective | preventive | ... — 'other' if absent
  // Auto-decided at resolve() from the machine's warranty_expiry; CTO/
  // Director can correct it via TicketService.overrideBilling(). Null until
  // the ticket is resolved.
  final String?   billingStatus; // warranty_covered | billable | goodwill
  final String?   billingDecidedByName;
  final String?   billingOverrideReason;
  final int?      invoiceId;
  // Section 6, generalized to every ticket type — null on a payload that
  // never loaded the relation (list rows still eager-load it; see
  // ServiceTicketController::index()), not on a ticket with zero machines
  // (a ticket always has at least one, backend-enforced).
  final List<TicketMachine>? machines;
  final int?                 machineCount;
  final int?                 pendingMachineCount;

  bool get isMultiMachine => (machineCount ?? 1) > 1;

  const ServiceTicket({
    required this.dbId,
    required this.id,
    required this.machineName,
    required this.machineType,
    required this.hospital,
    required this.ward,
    this.assignedToId,
    this.machineId,
    this.assignee,
    required this.technicianInitials,
    required this.technicianName,
    required this.status,
    required this.createdAt,
    this.description,
    this.resolutionNotes,
    this.acknowledgedAt,
    this.checklist,
    this.partsUsed,
    this.attachments,
    this.priority = 'medium',
    this.stage = 'assigned',
    this.travellingAt,
    this.onSiteAt,
    this.repairAt,
    this.signedOffAt,
    this.resolvedAt,
    this.type = 'other',
    this.billingStatus,
    this.billingDecidedByName,
    this.billingOverrideReason,
    this.invoiceId,
    this.machines,
    this.machineCount,
    this.pendingMachineCount,
  });

  factory ServiceTicket.fromJson(Map<String, dynamic> j) {
    // Parse the eager-loaded assignee object (j['assignee'])
    final assigneeMap = j['assignee'] is Map
        ? j['assignee'] as Map<String, dynamic>
        : null;
    final assignee = assigneeMap != null
        ? StaffMember.fromJson(assigneeMap)
        : null;

    // Machine may be nested under j['machine'] or flat top-level fields
    final machineMap = j['machine'] is Map ? j['machine'] as Map : null;

    return ServiceTicket(
      dbId:        (j['id'] as num).toInt(),
      id:          _str(j['ticket_number']) ?? '#—',
      machineName: _str(j['machine_name'])
                 ?? _nestedStr(machineMap, 'model')
                 ?? '—',
      machineType: _str(j['machine_type'])
                 ?? _nestedStr(machineMap, 'type')
                 ?? '—',
      hospital:    j['hospital'] is Map
                     ? (j['hospital'] as Map)['name'] as String? ?? '—'
                     : _str(j['hospital']) ?? '—',
      ward:        _str(j['ward']) ?? '—',
      assignedToId: j['assigned_to'] is int
                      ? j['assigned_to'] as int
                      : int.tryParse(j['assigned_to']?.toString() ?? ''),
      machineId:   j['machine_id'] is num
                      ? (j['machine_id'] as num).toInt()
                      : (machineMap?['id'] is num ? (machineMap!['id'] as num).toInt() : null),
      assignee:    assignee,
      technicianInitials: assignee?.initials
                        ?? _str(j['technician_initials'])
                        ?? '?',
      technicianName:     assignee?.name
                        ?? _str(j['technician_name'])
                        ?? '—',
      status:      _parseStatus(j['status'] as String? ?? 'open'),
      createdAt:   _str(j['created_at']) ?? '—',
      description: _str(j['description']),
      resolutionNotes: _str(j['resolution_notes']),
      acknowledgedAt: _str(j['acknowledged_at']),
      checklist:   (j['checklist'] as List? ?? j['checklist_items'] as List?)
          ?.map((c) => ChecklistItem(
                label:   c['label']   as String? ?? '',
                checked: c['checked'] as bool? ?? false,
              )).toList(),
      partsUsed:   (j['parts_used'] as List?)
          ?.map((p) => PartUsed.fromJson(p as Map<String, dynamic>)).toList(),
      attachments: (j['attachments'] as List?)
          ?.map((a) => TicketAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      priority:     _str(j['priority']) ?? 'medium',
      stage:        _str(j['stage']) ?? 'assigned',
      travellingAt: j['travelling_at'] != null ? DateTime.tryParse(j['travelling_at'] as String) : null,
      onSiteAt:     j['on_site_at']    != null ? DateTime.tryParse(j['on_site_at']    as String) : null,
      repairAt:     j['repair_at']     != null ? DateTime.tryParse(j['repair_at']     as String) : null,
      signedOffAt:  j['signed_off_at'] != null ? DateTime.tryParse(j['signed_off_at'] as String) : null,
      resolvedAt:   j['resolved_at']   != null ? DateTime.tryParse(j['resolved_at']   as String) : null,
      type:         _str(j['type']) ?? 'other',
      billingStatus:         _str(j['billing_status']),
      billingDecidedByName:  _str(j['billing_decided_by_name']),
      billingOverrideReason: _str(j['billing_override_reason']),
      invoiceId:             j['invoice_id'] is num ? (j['invoice_id'] as num).toInt() : null,
      machines: (j['machines'] as List?)
          ?.map((m) => TicketMachine.fromJson(m as Map<String, dynamic>)).toList(),
      machineCount:        j['machine_count'] is num ? (j['machine_count'] as num).toInt() : null,
      pendingMachineCount: j['pending_machine_count'] is num ? (j['pending_machine_count'] as num).toInt() : null,
    );
  }
}

class ChecklistItem {
  final String label;
  bool checked;
  ChecklistItem({required this.label, this.checked = true});
}

class PartUsed {
  final int?    id;
  final int?    inventoryItemId;
  final String  name;
  final int     qty;
  final int     unitCost;

  const PartUsed({
    this.id,
    this.inventoryItemId,
    required this.name,
    required this.qty,
    required this.unitCost,
  });

  factory PartUsed.fromJson(Map<String, dynamic> j) {
    // Backend nests the item as `inventory_item: {...}` — some older/adjacent
    // payloads may send a flat `name`, so fall back to that too.
    final item = j['inventory_item'] as Map<String, dynamic>?;
    return PartUsed(
      id:              j['id'] != null ? (j['id'] as num).toInt() : null,
      inventoryItemId: item?['id'] != null ? (item!['id'] as num).toInt() : null,
      name:            item?['name'] as String? ?? j['name'] as String? ?? '—',
      qty:             (j['qty'] as num? ?? 1).toInt(),
      unitCost:        (j['unit_cost'] as num? ?? j['cost'] as num? ?? 0).toInt(),
    );
  }
}
