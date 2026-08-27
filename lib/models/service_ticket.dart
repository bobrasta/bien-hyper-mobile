import 'staff_member.dart';

class TicketAttachment {
  final int     id;
  final String  name;
  final int     size;
  final String? mimeType;
  final String  url;
  final String  createdAt;

  const TicketAttachment({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
    required this.url,
    required this.createdAt,
  });

  factory TicketAttachment.fromJson(Map<String, dynamic> j) => TicketAttachment(
    id:        (j['id'] as num).toInt(),
    name:      j['name'] as String? ?? '—',
    size:      (j['size'] as num? ?? 0).toInt(),
    mimeType:  j['mime_type'] as String?,
    url:       j['url'] as String? ?? '',
    createdAt: j['created_at'] as String? ?? '',
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

  const ServiceTicket({
    required this.dbId,
    required this.id,
    required this.machineName,
    required this.machineType,
    required this.hospital,
    required this.ward,
    this.assignedToId,
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
