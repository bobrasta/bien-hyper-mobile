import 'package:file_picker/file_picker.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart' show allowedScreenKeys, hasCtoApprovalAuthority, hasServiceTicketResolveAuthority, userRoleNotifier, userIdNotifier;
import '../../models/hospital.dart';
import '../../utils/csv_export.dart';
import '../../models/inventory_item.dart';
import '../../models/machine.dart';
import '../../models/per_diem_request.dart';
import '../../models/serial_number.dart';
import '../../models/service_ticket.dart';
import '../../models/spare_part.dart';
import '../../services/hospital_service.dart';
import '../../services/inventory_service.dart';
import '../../services/machine_service.dart';
import '../../services/per_diem_service.dart';
import '../../services/serial_number_service.dart';
import '../../services/spare_part_service.dart';
import '../../services/staff_service.dart';
import '../../services/ticket_service.dart';
import 'travel_plan_dialog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/scan_or_type_field.dart';
import '../../widgets/common/shimmer_box.dart';
import '../../widgets/common/status_badge.dart';

Color _availColor(StaffMember s) => switch (s.availStatus) {
  AvailStatus.available => AppColors.teal,
  AvailStatus.atDesk    => AppColors.teal,
  AvailStatus.assigned  => AppColors.violet,
  AvailStatus.onTask    => AppColors.blue,
  AvailStatus.busy      => AppColors.amber,
  AvailStatus.offDuty   => AppColors.textDim,
};

String _tsh(int n) {
  if (n >= 1000000) return 'TSh ${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1000)    return 'TSh ${(n / 1e3).toStringAsFixed(0)}K';
  return 'TSh $n';
}

String _fmtBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024)        return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

IconData _attIcon(String? mime) {
  if (mime == null) return Symbols.attach_file;
  if (mime.startsWith('image/')) return Symbols.image;
  if (mime.contains('pdf')) return Symbols.picture_as_pdf;
  if (mime.contains('sheet') || mime.contains('excel') || mime.contains('csv')) return Symbols.table_chart;
  if (mime.contains('word') || mime.contains('document')) return Symbols.description;
  return Symbols.attach_file;
}
class ServiceTicketScreen extends StatefulWidget {
  const ServiceTicketScreen({super.key, this.initialTicketId});
  final int? initialTicketId;

  @override
  State<ServiceTicketScreen> createState() => _ServiceTicketScreenState();
}

class _ServiceTicketScreenState extends State<ServiceTicketScreen> {
  int _selectedIdx = 0;
  TicketStatus? _filter;
  bool _myAssignmentsOnly = false;
  int? _technicianFilter;
  final _searchCtrl = TextEditingController();
  bool _showNew = false;
  bool _showTravelPlan = false;
  ServiceTicket? _travelPlanTicket;

  List<ServiceTicket> _tickets        = [];
  bool                _loading        = true;
  String?             _loadError;
  bool                _resolving      = false;

  ServiceTicket?               _detailTicket;
  bool                         _loadingDetail = false;
  int?                         _loadedDbId;
  List<Map<String, dynamic>>   _checks       = [];
  List<Map<String, dynamic>>   _parts        = [];
  List<TicketAttachment>       _attachments  = [];
  bool                         _uploadingAttachment = false;
  bool                         _acknowledging = false;

  // Staff —loaded once at screen init; Future is reused by every dialog.
  Map<int, StaffMember>          _staffById     = {};
  late final Future<List<StaffMember>> _staffFuture = _fetchStaff();

  // My own per-diem requests (the backend self-scopes /per-diem-requests to
  // the caller) — loaded once, refreshed after submitting a new travel
  // plan, and looked up per-ticket to show its approval/payment status
  // instead of a "Submit Travel Plan" button once one already exists.
  List<PerDiemRequest> _myPerDiemRequests = [];
  late final Future<List<PerDiemRequest>> _perDiemFuture = _fetchPerDiem();

  @override
  void initState() {
    super.initState();
    _load();
    _staffFuture; // kick off the future
    _perDiemFuture; // kick off the future
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<List<PerDiemRequest>> _fetchPerDiem() async {
    try {
      final list = await PerDiemService.instance.list();
      if (mounted) setState(() => _myPerDiemRequests = list);
      return list;
    } catch (_) {
      return [];
    }
  }

  // Most recent per-diem request filed for this ticket, if any — "most
  // recent" so a resubmission after a rejection shows the new one's
  // status, not the dead one's.
  PerDiemRequest? _travelPlanFor(ServiceTicket t) {
    final matches = _myPerDiemRequests.where((p) => p.serviceTicketId == t.dbId).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return matches.isEmpty ? null : matches.first;
  }

  Future<List<StaffMember>> _fetchStaff() async {
    // GET /staff needs screens.staff (the operational task-board
    // permission) — technician deliberately doesn't have it. Skip the
    // call outright rather than firing a request known to 403; the
    // technician filter dropdown falls back to ticket-embedded assignee
    // data instead (see _technicianOptions).
    if (!(allowedScreenKeys(userRoleNotifier.value)?.contains('staff') ?? true)) return [];
    try {
      final list = await StaffService.instance.list();
      if (mounted) {
        setState(() => _staffById = { for (final s in list) s.id: s });
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  // Returns the full StaffMember: parsed assignee from API first, then staff map fallback
  StaffMember? _resolveTech(ServiceTicket t) =>
      t.assignee ?? (t.assignedToId != null ? _staffById[t.assignedToId] : null);

  String _resolveTechName(ServiceTicket t) =>
      _resolveTech(t)?.name ?? (t.technicianName != '—' ? t.technicianName : '—');

  String _resolveTechInitials(ServiceTicket t) =>
      _resolveTech(t)?.initials ?? (t.technicianInitials != '?' ? t.technicianInitials : '?');

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final data = await TicketService.instance.list();
      if (mounted) {
        final wanted = widget.initialTicketId == null
            ? -1
            : data.indexWhere((t) => t.dbId == widget.initialTicketId);
        final idx = wanted >= 0 ? wanted : 0;
        setState(() { _tickets = data; _loading = false; _selectedIdx = idx; _loadedDbId = null; });
        if (data.isNotEmpty) _loadDetail(data[idx]);
      }
    } catch (e) {
      if (mounted) setState(() { _loadError = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _loadDetail(ServiceTicket ticket) async {
    if (_loadedDbId == ticket.dbId) return;
    setState(() { _loadingDetail = true; _checks = []; _parts = []; _detailTicket = null; });
    try {
      final full = await TicketService.instance.get(ticket.dbId);
      if (!mounted) return;
      setState(() {
        _detailTicket  = full;
        _loadedDbId    = full.dbId;
        _loadingDetail = false;
        _checks = (full.checklist ?? []).map((c) =>
            {'label': c.label, 'on': c.checked}).toList();
        _parts  = (full.partsUsed ?? []).map((p) =>
            {'name': p.name, 'qty': p.qty, 'cost': p.unitCost}).toList();
        _attachments = full.attachments ?? [];
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  void _toggleCheck(int i) {
    final prev = _checks[i]['on'] as bool;
    setState(() { _checks[i]['on'] = !prev; });
    if (_detailTicket != null) {
      final items = _checks
          .map((c) => {'label': c['label'], 'checked': c['on']})
          .toList();
      TicketService.instance
          .update(_detailTicket!.dbId, {'checklist_items': items})
          .then<void>((_) {})
          .catchError((_) {
            if (mounted) setState(() { _checks[i]['on'] = prev; });
          });
    }
  }

  List<ServiceTicket> get _filtered {
    var list = _tickets;
    if (_myAssignmentsOnly) {
      list = list.where((t) => t.assignedToId != null && t.assignedToId == userIdNotifier.value).toList();
    } else if (_filter != null) {
      list = list.where((t) => t.status == _filter).toList();
    }
    if (_technicianFilter != null) {
      list = list.where((t) => t.assignedToId == _technicianFilter).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) =>
          t.id.toLowerCase().contains(q) ||
          t.machineName.toLowerCase().contains(q) ||
          t.hospital.toLowerCase().contains(q) ||
          t.ward.toLowerCase().contains(q) ||
          _resolveTechName(t).toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _resetSelectionAfterFilter() {
    final filtered = _filtered;
    if (filtered.isNotEmpty) _loadDetail(filtered[0]);
  }

  void _setFilter(TicketStatus? f) {
    setState(() { _filter = f; _myAssignmentsOnly = false; _selectedIdx = 0; _loadedDbId = null; });
    _resetSelectionAfterFilter();
  }

  void _setMyAssignmentsOnly() {
    setState(() { _myAssignmentsOnly = true; _filter = null; _selectedIdx = 0; _loadedDbId = null; });
    _resetSelectionAfterFilter();
  }

  void _setTechnicianFilter(int? technicianId) {
    setState(() { _technicianFilter = technicianId; _selectedIdx = 0; _loadedDbId = null; });
    _resetSelectionAfterFilter();
  }

  void _onSearchChanged() {
    setState(() { _selectedIdx = 0; _loadedDbId = null; });
    _resetSelectionAfterFilter();
  }

  // Prefers the full roster (already role-filtered to technician) when
  // available, but falls back to whoever tickets are actually assigned to
  // — works even when this role can't call GET /staff (e.g. the
  // technician role itself, which lost screens.staff this session on
  // purpose: that's the operational task-board permission, a different
  // thing from "who can I filter my own ticket list by").
  Map<int, String> get _technicianOptions {
    final map = <int, String>{};
    for (final s in _staffById.values) {
      if (s.role == 'technician') map[s.id] = s.name;
    }
    for (final t in _tickets) {
      final id = t.assignedToId;
      if (id == null || map.containsKey(id)) continue;
      final name = t.assignee?.name ?? (t.technicianName != '—' ? t.technicianName : null);
      if (name != null) map[id] = name;
    }
    return map;
  }

  Widget _technicianDropdown(BuildContext context) {
    final options = _technicianOptions;
    final technicians = options.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.pal.border),
      ),
      child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
        value: _technicianFilter,
        isExpanded: true,
        isDense: true,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        style: AppTheme.bodySm.copyWith(color: context.pal.text),
        dropdownColor: context.pal.surface1,
        hint: Row(children: [
          Icon(Symbols.engineering, size: 15, color: context.pal.textDim),
          const SizedBox(width: 6),
          Text('All Technicians', style: AppTheme.bodySm.copyWith(color: context.pal.textDim)),
        ]),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text('All Technicians', style: AppTheme.bodySm)),
          ...technicians.map((s) => DropdownMenuItem<int?>(value: s.key, child: Text(s.value, style: AppTheme.bodySm))),
        ],
        onChanged: _setTechnicianFilter,
      )),
    );
  }

  void _selectTicket(int idx) {
    setState(() => _selectedIdx = idx);
    final tickets = _filtered;
    if (idx >= 0 && idx < tickets.length) _loadDetail(tickets[idx]);
  }

  Future<void> _acknowledge(ServiceTicket ticket) async {
    if (_acknowledging) return;
    setState(() => _acknowledging = true);
    try {
      final updated = await TicketService.instance.acknowledge(ticket.dbId);
      if (mounted) {
        setState(() {
          _acknowledging = false;
          if (_detailTicket?.dbId == updated.dbId) _detailTicket = updated;
        });
        showSuccessToast(context, 'Assignment acknowledged');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _acknowledging = false);
        showErrorToast(context, e);
      }
    }
  }

  Future<void> _resolve(ServiceTicket ticket, {String? notes}) async {
    if (_resolving) return;
    setState(() => _resolving = true);
    try {
      await TicketService.instance.resolve(ticket.dbId, resolutionNotes: notes);
      if (mounted) showSuccessToast(context, '${ticket.id} marked resolved');
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _resolving = false);
        showErrorToast(context, e);
      }
    }
  }

  void _showResolveDialog(BuildContext context, ServiceTicket ticket) {
    showDialog<void>(
      context: context,
      builder: (_) => _ResolveDialog(
        ticket: ticket,
        onConfirm: (notes) => _resolve(ticket, notes: notes),
      ),
    );
  }

  void _showTravelPlanDialog(ServiceTicket ticket) {
    setState(() { _travelPlanTicket = ticket; _showTravelPlan = true; });
  }

  void _showAddPartDialog(BuildContext context, ServiceTicket ticket) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddPartDialog(
        onSave: (inventoryItemId, qty, cost, sourceSerialNumberId) async {
          try {
            final updatedTicket = await TicketService.instance.addPart(
              ticket.dbId,
              inventoryItemId: inventoryItemId,
              qty: qty,
              unitCost: cost,
              sourceSerialNumberId: sourceSerialNumberId,
            );
            if (mounted) {
              setState(() => _parts = (updatedTicket.partsUsed ?? [])
                  .map((p) => {'name': p.name, 'qty': p.qty, 'cost': p.unitCost}).toList());
            }
          } catch (e) {
            if (mounted) showErrorToast(this.context, e);
          }
        },
      ),
    );
  }

  Future<void> _exportCsv() async {
    try {
      final data = _filtered;
      final path = await CsvExport.tickets(data);
      if (path != null && mounted) showSuccessToast(context, 'Exported ${data.length} ticket(s) to CSV');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _uploadAttachment(ServiceTicket ticket) async {
    if (Platform.isAndroid) {
      showErrorToast(context, Exception('File attachments aren\'t available on Android in this build —use the desktop app instead.'));
      return;
    }
    final result = await FilePicker.pickFiles(allowMultiple: false, withData: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() => _uploadingAttachment = true);
    try {
      final att = await TicketService.instance.uploadAttachment(ticket.dbId, file.path!, file.name);
      if (mounted) setState(() { _attachments = [..._attachments, att]; _uploadingAttachment = false; });
    } catch (e) {
      if (mounted) { setState(() => _uploadingAttachment = false); showErrorToast(context, e); }
    }
  }

  Future<void> _deleteAttachment(ServiceTicket ticket, int attId) async {
    try {
      await TicketService.instance.deleteAttachment(ticket.dbId, attId);
      if (mounted) setState(() => _attachments = _attachments.where((a) => a.id != attId).toList());
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  void _showAddChecklistItemDialog(BuildContext context, ServiceTicket ticket) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddChecklistItemDialog(
        onSave: (label) async {
          final updated = [..._checks, {'label': label, 'on': false}];
          try {
            await TicketService.instance.update(ticket.dbId, {
              'checklist_items': updated.map((c) =>
                {'label': c['label'], 'checked': c['on']}).toList(),
            });
            if (mounted) setState(() => _checks = updated);
          } catch (_) {}
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, ServiceTicket ticket) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditTicketDialog(
        ticket: _detailTicket ?? ticket,
        onSaved: () { Navigator.of(context).pop(); _load(); },
      ),
    );
  }

  Future<void> _showStatusPicker(BuildContext context, ServiceTicket ticket) async {
    final picked = await showDialog<TicketStatus>(
      context: context,
      builder: (_) => _StatusPickerDialog(current: ticket.status),
    );
    if (picked == null || picked == ticket.status) return;
    final statusStr = switch (picked) {
      TicketStatus.open       => 'open',
      TicketStatus.inProgress => 'in_progress',
      TicketStatus.resolved   => 'resolved',
      TicketStatus.overdue    => 'overdue',
    };
    try {
      await TicketService.instance.update(ticket.dbId, {'status': statusStr});
      if (context.mounted) showSuccessToast(context, 'Status updated to ${picked.label}');
      _load();
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  Widget _buildTicketList(List<ServiceTicket> tickets, int selectedIdx) {
    if (_loading) {
      return shimmerList(count: 10);
    }
    if (_loadError != null) {
      return ErrorView(message: _loadError!, onRetry: _load);
    }
    if (tickets.isEmpty) {
      return Center(child: Text('No tickets match filter', style: AppTheme.bodySub));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: tickets.length,
        itemBuilder: (_, i) => _TicketListRow(
          ticket: tickets[i],
          selected: selectedIdx == i,
          onTap: () => _selectTicket(i),
          techName:     _resolveTechName(tickets[i]),
          techInitials: _resolveTechInitials(tickets[i]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _filtered;
    final idx = tickets.isEmpty ? 0 : _selectedIdx.clamp(0, tickets.length - 1);
    final ticket = tickets.isEmpty ? null : tickets[idx];

    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header ───────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(builder: (ctx, cst) {
              final narrow = cst.maxWidth < 560;
              final titleRow = Row(children: [
                Text('Service Tickets', style: AppTheme.pageTitle),
                const SizedBox(width: 10),
                _Badge('${_tickets.length}', AppColors.tealSoft, AppColors.teal),
              ]);
              final actions = Row(mainAxisSize: MainAxisSize.min, children: [
                AppButton(label: 'New Ticket', icon: Symbols.add, variant: BtnVariant.primary,
                    onPressed: () => setState(() => _showNew = true)),
                const SizedBox(width: 8),
                AppButton(label: 'Export', icon: Symbols.download, variant: BtnVariant.ghost, onPressed: _exportCsv),
              ]);
              if (narrow) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  titleRow, const SizedBox(height: 10), actions,
                ]);
              }
              return Row(children: [titleRow, const Spacer(), actions]);
            }),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (ctx, cst) {
              final narrow = cst.maxWidth < 560;
              final searchBox = AppTextField(
                height: 40,
                controller: _searchCtrl,
                onChanged: (_) => _onSearchChanged(),
                icon: Symbols.search,
                hintText: 'Search by ticket, machine, or hospital…',
              );
              final techDropdown = _technicianDropdown(context);
              if (narrow) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  searchBox, const SizedBox(height: 8), techDropdown,
                ]);
              }
              return Row(children: [
                Expanded(child: searchBox),
                const SizedBox(width: 10),
                SizedBox(width: 220, child: techDropdown),
              ]);
            }),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _FilterTab('All',         active: _filter == null,                       onTap: () => _setFilter(null)),
              _FilterTab('Open',        active: _filter == TicketStatus.open,          onTap: () => _setFilter(TicketStatus.open)),
              _FilterTab('In Progress', active: _filter == TicketStatus.inProgress,    onTap: () => _setFilter(TicketStatus.inProgress)),
              _FilterTab('Resolved',    active: _filter == TicketStatus.resolved,      onTap: () => _setFilter(TicketStatus.resolved)),
              _FilterTab('Overdue',     active: _filter == TicketStatus.overdue,       onTap: () => _setFilter(TicketStatus.overdue), danger: true),
              _FilterTab('My Assignments', active: _myAssignmentsOnly,                 onTap: _setMyAssignmentsOnly),
            ]),
          ]),
        ),

        // ── Two-panel ───────────────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final listWidth = Responsive.isNarrow(constraints.maxWidth) ? constraints.maxWidth
                            : Responsive.isMedium(constraints.maxWidth) ? 260.0 : 340.0;
            final showBothPanels = constraints.maxWidth >= 600;

            // On narrow: show list when no selection (or ticket==null), detail otherwise
            if (!showBothPanels) {
              if (ticket == null || _selectedIdx < 0) {
                return _buildTicketList(tickets, idx);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                GestureDetector(
                  onTap: () => setState(() { _selectedIdx = -1; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
                    child: Row(children: [
                      Icon(Symbols.arrow_back, size: 16, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Text('Back to list', style: AppTheme.bodySm.copyWith(color: AppColors.teal)),
                    ]),
                  ),
                ),
                Expanded(child: _TicketDetailPanel(
                    ticket: ticket,
                    detailTicket: _detailTicket,
                    resolvedTech: _resolveTech(_detailTicket ?? ticket),
                    checks: _checks,
                    parts: _parts,
                    attachments: _attachments,
                    uploadingAttachment: _uploadingAttachment,
                    onToggle: _toggleCheck,
                    loadingDetail: _loadingDetail,
                    onResolve: () => _showResolveDialog(context, ticket),
                    onUpdateStatus: () => _showStatusPicker(context, ticket),
                    onEdit: () => _showEditDialog(context, ticket),
                    onAddPart: () => _showAddPartDialog(context, ticket),
                    onAddChecklistItem: () => _showAddChecklistItemDialog(context, ticket),
                    onUploadAttachment: () => _uploadAttachment(ticket),
                    onDeleteAttachment: (id) => _deleteAttachment(ticket, id),
                    onAcknowledge: () => _acknowledge(ticket),
                    acknowledging: _acknowledging,
                    onSubmitTravelPlan: () => _showTravelPlanDialog(ticket),
                    travelPlan: _travelPlanFor(ticket))),
              ]);
            }

            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left: ticket list
            SizedBox(
              width: listWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: context.pal.border))),
                child: _buildTicketList(tickets, idx),
              ),
            ),
            // Right: detail
            Expanded(
              child: ticket == null
                  ? Center(child: Text('No tickets', style: AppTheme.bodySub))
                  : _TicketDetailPanel(
                      ticket: ticket,
                      detailTicket: _detailTicket,
                      checks: _checks,
                      parts: _parts,
                      attachments: _attachments,
                      uploadingAttachment: _uploadingAttachment,
                      onToggle: _toggleCheck,
                      loadingDetail: _loadingDetail,
                      onResolve: () => _showResolveDialog(context, ticket),
                      onUpdateStatus: () => _showStatusPicker(context, ticket),
                      onEdit: () => _showEditDialog(context, ticket),
                      onAddPart: () => _showAddPartDialog(context, ticket),
                      onAddChecklistItem: () => _showAddChecklistItemDialog(context, ticket),
                      onUploadAttachment: () => _uploadAttachment(ticket),
                      onDeleteAttachment: (id) => _deleteAttachment(ticket, id),
                      onAcknowledge: () => _acknowledge(ticket),
                      acknowledging: _acknowledging,
                      onSubmitTravelPlan: () => _showTravelPlanDialog(ticket),
                      travelPlan: _travelPlanFor(ticket),
                    ),
            ),
          ]);  // Row
        }),    // LayoutBuilder
        ),     // Expanded(child: LayoutBuilder)
      ]),      // Column


      // New Ticket modal
      if (_showNew)
        _NewTicketModal(
          onClose: () => setState(() => _showNew = false),
          onSaved: () { setState(() => _showNew = false); _load(); },
        ),
      if (_showTravelPlan)
        TravelPlanDialog(
          ticket: _travelPlanTicket,
          onClose: () => setState(() => _showTravelPlan = false),
          onSaved: () {
            setState(() => _showTravelPlan = false);
            showSuccessToast(context, 'Travel plan submitted for approval');
            _fetchPerDiem();
          },
        ),
    ]);
  }
}

// ── Ticket list row ─────────────────────────────────────────────────────────
class _TicketListRow extends StatelessWidget {
  const _TicketListRow({
    required this.ticket,
    required this.selected,
    required this.onTap,
    this.techName,
    this.techInitials,
  });
  final ServiceTicket ticket;
  final bool selected;
  final String? techName;
  final String? techInitials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? context.pal.surface2 : Colors.transparent,
        border: Border(bottom: BorderSide(color: context.pal.divider)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(ticket.id, style: AppTheme.monoXs.copyWith(
              color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: Text(ticket.machineName,
              style: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
              overflow: TextOverflow.ellipsis)),
          StatusBadge.ticket(ticket.status),
        ]),
        const SizedBox(height: 3),
        Text(ticket.machineType, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
        const SizedBox(height: 4),
        Row(children: [
          const SizedBox(width: 4),
          Expanded(child: Text('${ticket.hospital} · ${ticket.ward}',
              style: AppTheme.bodySub.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          AvatarWidget(initials: techInitials ?? ticket.technicianInitials, size: 18, variant: AvatarVariant.teal),
          const SizedBox(width: 6),
          Text(techName ?? ticket.technicianName, style: AppTheme.bodySub.copyWith(fontSize: 11)),
          const Spacer(),
          Text(ticket.createdAt, style: AppTheme.monoXs.copyWith(fontSize: 10.5, color: context.pal.textDim)),
        ]),
      ]),
    ),
  );
}

// ── Ticket detail panel ─────────────────────────────────────────────────────
class _TicketDetailPanel extends StatelessWidget {
  const _TicketDetailPanel({
    required this.ticket,
    required this.checks,
    required this.parts,
    required this.attachments,
    required this.onToggle,
    this.detailTicket,
    this.resolvedTech,
    this.loadingDetail = false,
    this.uploadingAttachment = false,
    this.onResolve,
    this.onUpdateStatus,
    this.onEdit,
    this.onAddPart,
    this.onAddChecklistItem,
    this.onUploadAttachment,
    this.onDeleteAttachment,
    this.onAcknowledge,
    this.acknowledging = false,
    this.onSubmitTravelPlan,
    this.travelPlan,
  });
  final ServiceTicket ticket;
  final ServiceTicket? detailTicket;
  final StaffMember? resolvedTech;
  final List<Map<String, dynamic>> checks;
  final List<Map<String, dynamic>> parts;
  final List<TicketAttachment>     attachments;
  final ValueChanged<int> onToggle;
  final bool loadingDetail;
  final bool uploadingAttachment;
  final VoidCallback? onResolve;
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onEdit;
  final VoidCallback? onAddPart;
  final VoidCallback? onAddChecklistItem;
  final VoidCallback?      onUploadAttachment;
  final ValueChanged<int>? onDeleteAttachment;
  final VoidCallback? onAcknowledge;
  final bool acknowledging;
  final VoidCallback? onSubmitTravelPlan;
  // Most recent per-diem request filed for this ticket by its assignee, if
  // any — drives whether we show the "Submit Travel Plan" button or a
  // status banner instead.
  final PerDiemRequest? travelPlan;

  @override
  Widget build(BuildContext context) {
    final t = detailTicket ?? ticket;
    final tech = resolvedTech;
    final techName = tech?.name ?? (t.technicianName != '—' ? t.technicianName : '—');
    final resNotes = t.resolutionNotes;
    final isResolved = t.status == TicketStatus.resolved;
    final isAssignee = t.assignedToId != null && t.assignedToId == userIdNotifier.value;
    final needsAcknowledgement = isAssignee && t.acknowledgedAt == null;
    // A rejected/cancelled plan doesn't block filing a new one — anything
    // else (submitted and still moving through approval/payment, or paid)
    // means there's already an active plan, so show its status instead.
    final resubmittable = travelPlan == null
        || travelPlan!.status == PerDiemStatus.rejected
        || travelPlan!.status == PerDiemStatus.cancelled;
    final canSubmitTravelPlan = isAssignee && t.acknowledgedAt != null && !isResolved && resubmittable;
    final showTravelStatus = isAssignee && t.acknowledgedAt != null && !isResolved && !resubmittable;
    // Read-only for anyone but the assignee or CTO/Director tier — a
    // technician can see every ticket but only act on their own.
    final canAct = isAssignee || hasCtoApprovalAuthority(userRoleNotifier.value);
    final canResolve = hasServiceTicketResolveAuthority(userRoleNotifier.value);

    return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(ticket.id, style: AppTheme.monoXs.copyWith(
                color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 10),
            StatusBadge.ticket(ticket.status, large: true),
          ]),
          const SizedBox(height: 6),
          Text(ticket.machineName, style: AppTheme.pageTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 3),
          Text('${ticket.machineType} · ${ticket.hospital}', style: AppTheme.bodySub),
        ])),
        if (canAct)
          AppButton(label: 'Edit', icon: Symbols.edit, variant: BtnVariant.ghost, onPressed: onEdit),
        const SizedBox(width: 8),
        if (!isResolved && canResolve)
          AppButton(label: 'Resolve', icon: Symbols.check_circle, variant: BtnVariant.normal,
              onPressed: onResolve),
      ]),
      const SizedBox(height: 20),

      // Acknowledge-assignment banner —shown only to the assignee, only
      // until they've acknowledged.
      if (needsAcknowledgement) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(Symbols.notification_important, size: 18, color: AppColors.amber),
            const SizedBox(width: 10),
            Expanded(child: Text(
                "You've been assigned this ticket —acknowledge to confirm you've seen it.",
                style: AppTheme.bodySm.copyWith(color: context.pal.text))),
            const SizedBox(width: 12),
            AppButton(
              label: acknowledging ? 'Acknowledging…' : 'Acknowledge',
              icon: Symbols.done_all,
              variant: BtnVariant.primary,
              onPressed: acknowledging ? null : onAcknowledge,
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],

      // Travel-plan prompt —the next step once the assignee has acknowledged:
      // file the day-by-day itinerary for this trip before heading out. If
      // a previous plan was rejected/cancelled, the prompt says so and
      // this doubles as the resubmit flow.
      if (canSubmitTravelPlan) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Symbols.map, size: 18, color: AppColors.teal),
            const SizedBox(width: 10),
            Expanded(child: Text(
                travelPlan == null
                    ? 'Next: submit a travel plan for this trip — sites, dates, and per-diem/transport costs.'
                    : 'Your previous travel plan was ${travelPlan!.status == PerDiemStatus.rejected ? 'rejected' : 'cancelled'}'
                        '${(travelPlan!.rejectionReason ?? travelPlan!.teamLeadRejectionReason) != null ? ': ${travelPlan!.rejectionReason ?? travelPlan!.teamLeadRejectionReason}' : ''}. '
                        'Submit a new one to try again.',
                style: AppTheme.bodySm.copyWith(color: context.pal.text))),
            const SizedBox(width: 12),
            AppButton(
              label: 'Submit Travel Plan',
              icon: Symbols.send,
              variant: BtnVariant.primary,
              onPressed: onSubmitTravelPlan,
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],

      // Travel-plan status —shown instead of the prompt once a plan is
      // already filed and still active (not rejected/cancelled), so the
      // technician can see where it is in approval/payment rather than
      // being offered to submit a duplicate.
      if (showTravelStatus) ...[
        Builder(builder: (context) {
          final (color, icon, label) = switch (travelPlan!.status) {
            PerDiemStatus.pendingTeamLead => (AppColors.amber, Symbols.hourglass_top, 'Travel plan submitted — awaiting Team Lead approval.'),
            PerDiemStatus.pendingCto      => (AppColors.amber, Symbols.hourglass_top, 'Approved by Team Lead — awaiting CTO approval.'),
            PerDiemStatus.pendingPayment  => (AppColors.violet, Symbols.payments, 'Approved — awaiting payment initiation.'),
            PerDiemStatus.pendingDirector => (AppColors.amber, Symbols.hourglass_bottom, "Payment initiated — awaiting release. Don't travel yet."),
            PerDiemStatus.paid            => (AppColors.teal, Symbols.flight_takeoff, 'Money is out — start your journey!'),
            _ => (context.pal.textDim, Symbols.info, travelPlan!.status.label),
          };
          final emphasize = travelPlan!.status == PerDiemStatus.paid;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: emphasize ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(AppColors.rLg),
              border: Border.all(color: color.withValues(alpha: emphasize ? 0.5 : 0.3)),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(label,
                  style: (emphasize ? AppTheme.bodyStrong : AppTheme.bodySm).copyWith(color: context.pal.text))),
            ]),
          );
        }),
        const SizedBox(height: 16),
      ],

      // Info grid —hospital, ward, reported
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: AdaptiveColumns(
          wideCols: 3, mediumCols: 2, narrowCols: 2,
          spacing: 12, runSpacing: 10,
          children: [
            _InfoCell('Hospital', t.hospital),
            _InfoCell('Ward',     t.ward.isEmpty || t.ward == '—' ? '—' : t.ward),
            _InfoCell('Reported', t.createdAt),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Assigned technician card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Row(children: [
          if (tech != null) ...[
            AvatarWidget(initials: tech.initials, size: 40, variant: tech.variant),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ASSIGNED TECHNICIAN', style: AppTheme.labelCaps),
              const SizedBox(height: 4),
              Text(tech.name, style: AppTheme.bodyStrong.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(tech.role, style: AppTheme.bodySub.copyWith(fontSize: 12)),
              if (tech.zone != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Symbols.location_on, size: 12, color: context.pal.textDim),
                  const SizedBox(width: 4),
                  Text(tech.zone!, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                ]),
              ],
              if (tech.phone != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Symbols.phone, size: 12, color: context.pal.textDim),
                  const SizedBox(width: 4),
                  Text(tech.phone!, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                ]),
              ],
              if (tech.email != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Symbols.mail_outline, size: 12, color: context.pal.textDim),
                  const SizedBox(width: 4),
                  Text(tech.email!, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                ]),
              ],
            ])),
            // Availability status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _availColor(tech).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(tech.availStatus.label,
                style: AppTheme.monoXs.copyWith(
                  color: _availColor(tech), fontSize: 10.5)),
            ),
          ] else ...[
            Icon(Symbols.person_off, size: 20, color: context.pal.textDim),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ASSIGNED TECHNICIAN', style: AppTheme.labelCaps),
              const SizedBox(height: 4),
              Text(techName, style: AppTheme.bodyStrong.copyWith(
                  color: techName == '—' ? context.pal.textDim : context.pal.text)),
            ])),
          ],
        ]),
      ),
      const SizedBox(height: 16),

      // Resolution notes —shown when resolved
      if (isResolved) ...[
        _SectionCard(
          icon: Symbols.check_circle,
          title: 'Resolution Notes',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
            ),
            child: Text(
              resNotes?.isNotEmpty == true ? resNotes! : 'No resolution notes recorded.',
              style: AppTheme.bodySm.copyWith(height: 1.65,
                  color: resNotes?.isNotEmpty == true ? context.pal.text : context.pal.textMute),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],

      // Checklist
      _SectionCard(
        icon: Symbols.checklist,
        title: 'Service Checklist',
        trailing: loadingDetail
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  '${checks.where((c) => c['on'] as bool).length}/${checks.length} complete',
                  style: AppTheme.bodySub.copyWith(fontSize: 12, color: AppColors.teal),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onAddChecklistItem,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Symbols.add, size: 14, color: AppColors.teal),
                    const SizedBox(width: 3),
                    Text('Add', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 12)),
                  ]),
                ),
              ]),
        child: loadingDetail
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : checks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Icon(Symbols.checklist, size: 16, color: context.pal.textDim),
                    const SizedBox(width: 8),
                    Text('No checklist items yet.',
                      style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
                  ]),
                )
              : Column(
                children: checks.asMap().entries.map((e) {
                  final on = e.value['on'] as bool;
                  return GestureDetector(
                    onTap: canAct ? () => onToggle(e.key) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: e.key < checks.length - 1
                          ? BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider)))
                          : null,
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: on ? AppColors.teal : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: on ? AppColors.teal : context.pal.borderStrong),
                          ),
                          child: on ? const Icon(Symbols.check, size: 14, color: Color(0xFF06120F)) : null,
                        ),
                        const SizedBox(width: 12),
                        Text(e.value['label'] as String, style: AppTheme.bodySm.copyWith(
                          color: on ? context.pal.text : context.pal.textMute,
                        )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
      ),
      const SizedBox(height: 16),

      // Parts used
      _SectionCard(
        icon: Symbols.inventory_2,
        title: 'Parts Used',
        trailing: canAct
            ? GestureDetector(
                onTap: onAddPart,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.add, size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text('Add Part', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 12)),
                ]),
              )
            : null,
        child: Column(children: [
          if (parts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Icon(Symbols.inventory_2, size: 16, color: context.pal.textDim),
                const SizedBox(width: 8),
                Text('No parts used yet.',
                  style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
              ]),
            )
          else ...[
            ...parts.asMap().entries.map((e) {
              final p = e.value;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: e.key < parts.length - 1
                    ? BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider)))
                    : null,
                child: Row(children: [
                  const SizedBox(width: 8),
                  Expanded(child: Text(p['name'] as String, style: AppTheme.bodySm)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: context.pal.surface3, borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('×${p['qty']}', style: AppTheme.monoXs),
                  ),
                  const SizedBox(width: 12),
                  Text(_tsh(p['cost'] as int),
                      style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                ]),
              );
            }),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('Total: ', style: AppTheme.bodySub),
              Text(
                _tsh(parts.fold(0, (s, p) => s + ((p['cost'] as int) * (p['qty'] as int)))),
                style: AppTheme.bodyStrong.copyWith(color: AppColors.amber, fontSize: 13),
              ),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 16),

      // Attachments
      _SectionCard(
        icon: Symbols.attach_file,
        title: 'Attachments',
        trailing: uploadingAttachment
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : GestureDetector(
                onTap: onUploadAttachment,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.upload_file, size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text('Attach', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 12)),
                ]),
              ),
        child: attachments.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Icon(Symbols.attach_file, size: 16, color: context.pal.textDim),
                  const SizedBox(width: 8),
                  Text('No attachments yet.', style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
                ]),
              )
            : Column(
                children: attachments.asMap().entries.map((e) {
                  final att = e.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: e.key < attachments.length - 1
                        ? BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider)))
                        : null,
                    child: Row(children: [
                      Icon(_attIcon(att.mimeType), size: 16, color: context.pal.textDim),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(att.name, style: AppTheme.bodySm, overflow: TextOverflow.ellipsis),
                        Text(_fmtBytes(att.size),
                            style: AppTheme.bodySub.copyWith(fontSize: 11)),
                      ])),
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.tryParse(att.url);
                          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        child: Tooltip(
                          message: 'Open',
                          child: Icon(Symbols.download, size: 16, color: AppColors.teal),
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => onDeleteAttachment?.call(att.id),
                        child: Tooltip(
                          message: 'Delete',
                          child: Icon(Symbols.delete_outline, size: 16, color: context.pal.textDim),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
      ),
      const SizedBox(height: 16),

      // Notes & Diagnosis
      _SectionCard(
        icon: Symbols.notes,
        title: 'Notes & Diagnosis',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            t.description?.isNotEmpty == true ? t.description! : 'No notes recorded.',
            style: AppTheme.bodySm.copyWith(height: 1.65, color: context.pal.textMute),
          ),
        ),
      ),
      const SizedBox(height: 24),

      // Action buttons
      if (!isResolved && (canAct || canResolve))
        Row(children: [
          if (canAct) ...[
            Expanded(child: GestureDetector(
              onTap: onUpdateStatus,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  border: Border.all(color: context.pal.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('Update Status',
                    style: AppTheme.bodySm.copyWith(color: context.pal.textMute))),
              ),
            )),
            const SizedBox(width: 12),
          ],
          if (canResolve)
            Expanded(child: GestureDetector(
              onTap: onResolve,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: AppColors.teal.withValues(alpha: 0.3), blurRadius: 12)],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Symbols.check_circle, size: 16, color: Color(0xFF06120F)),
                  const SizedBox(width: 8),
                  Text('Mark Resolved', style: AppTheme.bodyStrong.copyWith(
                      color: const Color(0xFF06120F), fontSize: 13)),
                ]),
              ),
            )),
        ])
      else
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.tealSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Symbols.check_circle, size: 16, color: AppColors.teal),
            const SizedBox(width: 8),
            Text('Resolved', style: AppTheme.bodyStrong.copyWith(
                color: AppColors.teal, fontSize: 13)),
          ]),
        ),
    ]),
  );
  }
}

// ── New Ticket modal ────────────────────────────────────────────────────────
class _NewTicketModal extends StatefulWidget {
  const _NewTicketModal({required this.onClose, this.onSaved});
  final VoidCallback  onClose;
  final VoidCallback? onSaved;

  @override
  State<_NewTicketModal> createState() => _NewTicketModalState();
}

class _NewTicketModalState extends State<_NewTicketModal> {
  String  _type     = 'Corrective';
  String  _priority = 'High';
  final   _descCtrl = TextEditingController();
  bool    _saving   = false;
  String? _error;

  // Staff
  List<StaffMember> _staff        = [];
  StaffMember?      _selectedTech;
  bool              _loadingStaff = true;

  // Hospitals
  List<Hospital> _hospitals        = [];
  Hospital?      _selectedHospital;
  bool           _loadingHospitals = true;

  // Machines (all loaded once; filtered by selected hospital)
  List<Machine> _allMachines     = [];
  Machine?      _selectedMachine;
  bool          _loadingMachines = true;

  List<Machine> get _filteredMachines {
    if (_selectedHospital == null) return const [];
    return _allMachines.where((m) =>
      m.hospitalId == _selectedHospital!.id ||
      m.hospital   == _selectedHospital!.name).toList();
  }

  @override
  void initState() {
    super.initState();
    StaffService.instance.list().then((list) {
      if (!mounted) return;
      setState(() { _staff = list; _loadingStaff = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loadingStaff = false);
    });
    HospitalService.instance.list().then((list) {
      if (!mounted) return;
      setState(() { _hospitals = list; _loadingHospitals = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loadingHospitals = false);
    });
    MachineService.instance.list().then((list) {
      if (!mounted) return;
      setState(() { _allMachines = list; _loadingMachines = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loadingMachines = false);
    });
  }

  void _onHospitalChanged(int? id) {
    setState(() {
      _selectedHospital = id == null ? null : _hospitals.firstWhere((h) => h.id == id);
      // Reset machine when hospital changes; auto-pick first if only one matches
      final filtered = id == null
          ? _allMachines
          : _allMachines.where((m) =>
              m.hospitalId == id || m.hospital == _selectedHospital!.name).toList();
      _selectedMachine = filtered.length == 1 ? filtered.first : null;
    });
  }

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    if (_selectedMachine == null) {
      setState(() => _error = 'Please select a machine.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await TicketService.instance.create({
        'type':         _type,
        'priority':     _priority.toLowerCase(),
        'description':  _descCtrl.text.trim(),
        'status':       'open',
        'machine_id':   _selectedMachine!.id,
        'machine_name': _selectedMachine!.model,
        'machine_type': _selectedMachine!.type,
        if (_selectedMachine!.hospitalId != null)
          'hospital_id': _selectedMachine!.hospitalId,
        'ward':         _selectedMachine!.ward,
        if (_selectedTech != null) 'assigned_to': _selectedTech!.id,
      });
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyError(e); });
    }
  }

  Widget _spinner() => Container(
    height: 38,
    decoration: BoxDecoration(color: context.pal.surface2,
        borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
    child: const Center(child: SizedBox(width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 2))),
  );

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
    decoration: BoxDecoration(color: context.pal.surface2,
        borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: DropdownButtonHideUnderline(child: DropdownButton<T>(
      value: value,
      hint: Text(hint, style: AppTheme.bodySm.copyWith(color: context.pal.textDim)),
      isExpanded: true,
      dropdownColor: context.pal.surface2,
      style: AppTheme.bodySm,
      icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
      items: items,
      onChanged: onChanged,
    )),
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 540,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Icon(Symbols.confirmation_number, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('Create Service Ticket', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),

            // Form body
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(children: [
                // 1. Hospital
                _ModalField(
                  label: 'Hospital',
                  child: _loadingHospitals
                    ? _spinner()
                    : _dropdown<int?>(
                        value: _selectedHospital?.id,
                        hint: 'Select hospital…',
                        items: [
                          DropdownMenuItem<int?>(value: null,
                            child: Text('All hospitals',
                                style: AppTheme.bodySm.copyWith(color: context.pal.textDim))),
                          ..._hospitals.map((h) =>
                              DropdownMenuItem<int?>(value: h.id, child: Text(h.name))),
                        ],
                        onChanged: _onHospitalChanged,
                      ),
                ),
                const SizedBox(height: 14),
                // 2. Machine —filtered by selected hospital
                _ModalField(
                  label: 'Machine',
                  child: _loadingMachines
                    ? _spinner()
                    : _dropdown<int?>(
                        value: _filteredMachines.any((m) => m.id == _selectedMachine?.id)
                            ? _selectedMachine?.id : null,
                        hint: _selectedHospital == null
                            ? 'Select hospital first—'
                            : _filteredMachines.isEmpty
                                ? 'No machines at this hospital'
                                : 'Select machine—',
                        items: _filteredMachines.map((m) => DropdownMenuItem<int?>(
                          value: m.id,
                          child: Text('${m.model} · ${m.serialNo}',
                              overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (id) => setState(() =>
                          _selectedMachine = id == null ? null
                              : _allMachines.firstWhere((m) => m.id == id)),
                      ),
                ),
                // Ward chip —shown once a machine is picked
                if (_selectedMachine != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.tealSoft,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(Symbols.location_on, size: 13, color: AppColors.teal),
                      const SizedBox(width: 7),
                      Expanded(child: Text(
                        'Ward: ${_selectedMachine!.ward}',
                        style: AppTheme.bodySm.copyWith(color: context.pal.text, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                // 3. Ticket type + Priority
                Row(children: [
                  Expanded(child: _ModalField(
                    label: 'Ticket Type',
                    child: _DropdownField(
                      value: _type,
                      items: const ['Corrective', 'Preventive', 'Inspection', 'Installation'],
                      onChanged: (v) => setState(() => _type = v),
                    ),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _ModalField(
                    label: 'Priority',
                    child: _DropdownField(
                      value: _priority,
                      items: const ['Low', 'Medium', 'High', 'Critical'],
                      onChanged: (v) => setState(() => _priority = v),
                    ),
                  )),
                ]),
                const SizedBox(height: 14),
                // 4. Technician —only the CTO/Director can set this at
                // creation time (mirrors ServiceTicketController::store()'s
                // hasCtoApprovalAuthority() gate); everyone else sees it as
                // informational text, not an editable field.
                _ModalField(
                  label: 'Assign Technician',
                  child: !hasCtoApprovalAuthority(userRoleNotifier.value)
                    ? Container(
                        height: 38,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: context.pal.surface2,
                            borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                        child: Text('Unassigned —only CTO/Director can assign at creation',
                            style: AppTheme.bodySm.copyWith(color: context.pal.textDim, fontSize: 11.5)),
                      )
                    : _loadingStaff
                      ? _spinner()
                      : _dropdown<int?>(
                          value: _selectedTech?.id,
                          hint: 'Unassigned',
                          items: [
                            DropdownMenuItem<int?>(value: null,
                              child: Text('Unassigned',
                                  style: AppTheme.bodySm.copyWith(color: context.pal.textDim))),
                            ..._staff.map((s) =>
                                DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (id) => setState(() =>
                            _selectedTech = id == null ? null
                                : _staff.firstWhere((s) => s.id == id)),
                        ),
                ),
                const SizedBox(height: 14),
                // 5. Description
                AppTextField(
                  label: 'Issue Description',
                  controller: _descCtrl,
                  maxLines: null,
                  height: 80,
                  hintText: 'Describe the issue in detail…',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.error_outline, size: 14, color: AppColors.coral),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_error!,
                      style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 12))),
                  ]),
                ],
              ]),
            )),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: context.pal.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.teal,
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Ticket', style: AppTheme.bodyStrong.copyWith(
                          color: const Color(0xFF06120F), fontSize: 13))),
                  ),
                )),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ── Small helpers ───────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  const _Badge(this.text, this.bg, this.fg);
  final String text;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: AppTheme.bodySub.copyWith(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _FilterTab extends StatelessWidget {
  const _FilterTab(this.label, {required this.active, required this.onTap, this.danger = false});
  final String label;
  final bool active, danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? (danger ? AppColors.coralSoft : AppColors.tealSoft)
            : context.pal.surface1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: active
                ? (danger ? AppColors.coral : AppColors.teal)
                : context.pal.border),
      ),
      child: Text(label, style: AppTheme.bodySm.copyWith(
        fontSize: 12.5,
        color: active
            ? (danger ? AppColors.coral : AppColors.teal)
            : context.pal.textMute,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      )),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.child, this.trailing});
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: context.pal.textMute),
        const SizedBox(width: 8),
        Text(title, style: AppTheme.cardTitle),
        const Spacer(),
        ?trailing,
      ]),
      const SizedBox(height: 12),
      const SizedBox(height: 8),
      child,
    ]),
  );
}

class _InfoCell extends StatelessWidget {
  const _InfoCell(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps),
    const SizedBox(height: 3),
    Text(value, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w500)),
  ]);
}

class _ModalField extends StatelessWidget {
  const _ModalField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    child,
  ]);
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.pal.surface2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.pal.border),
    ),
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: context.pal.surface2,
        style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

// ── Status picker dialog ────────────────────────────────────────────────────
class _StatusPickerDialog extends StatefulWidget {
  const _StatusPickerDialog({required this.current});
  final TicketStatus current;

  @override
  State<_StatusPickerDialog> createState() => _StatusPickerDialogState();
}

class _StatusPickerDialogState extends State<_StatusPickerDialog> {
  late TicketStatus _selected = widget.current;

  static const _options = [
    (TicketStatus.open,       'Open'),
    (TicketStatus.inProgress, 'In Progress'),
    (TicketStatus.resolved,   'Resolved'),
    (TicketStatus.overdue,    'Overdue'),
  ];

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: Text('Update Status', style: AppTheme.bodyStrong),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: _options.map((opt) {
        final isSelected = _selected == opt.$1;
        return GestureDetector(
          onTap: () => setState(() => _selected = opt.$1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.teal : context.pal.borderStrong,
                    width: isSelected ? 5 : 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(opt.$2, style: AppTheme.bodySm),
            ]),
          ),
        );
      }).toList(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: AppTheme.bodySm.copyWith(color: context.pal.textMute)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _selected),
        child: Text('Apply', style: AppTheme.bodySm.copyWith(color: AppColors.teal)),
      ),
    ],
  );
}

// ── Resolve Dialog ──────────────────────────────────────────────────────────
class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.ticket, required this.onConfirm});
  final ServiceTicket ticket;
  final void Function(String notes) onConfirm;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  void _submit() {
    if (_saving) return;
    setState(() => _saving = true);
    Navigator.of(context).pop();
    widget.onConfirm(_notesCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
      backgroundColor: context.pal.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      title: Row(children: [
        Icon(Symbols.check_circle, size: 18, color: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(child: Text('Mark Resolved — ${widget.ticket.id}',
            style: AppTheme.bodyStrong, overflow: TextOverflow.ellipsis)),
      ]),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Describe what was done to resolve this ticket. '
               'This will be included in service reports.',
            style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
          const SizedBox(height: 14),
          AppTextField(
            controller: _notesCtrl,
            maxLines: null,
            height: 110,
            autofocus: true,
            hintText: 'e.g. Replaced flow sensor, recalibrated unit, tested 3 cycles — all passed.',
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppTheme.bodySm.copyWith(color: context.pal.textMute)),
        ),
        GestureDetector(
          onTap: _submit,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Symbols.check_circle, size: 14, color: Color(0xFF06120F)),
              const SizedBox(width: 6),
              Text('Resolve Ticket', style: AppTheme.bodyStrong.copyWith(
                  color: const Color(0xFF06120F), fontSize: 13)),
            ]),
          ),
        ),
      ],
    );
}

// ── Add Part Dialog ─────────────────────────────────────────────────────────
class _AddPartDialog extends StatefulWidget {
  const _AddPartDialog({required this.onSave});
  final Future<void> Function(int inventoryItemId, int qty, int cost, int? sourceSerialNumberId) onSave;
  @override
  State<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends State<_AddPartDialog> {
  final _qtyCtrl    = TextEditingController(text: '1');
  final _costCtrl   = TextEditingController();
  final _serialCtrl = TextEditingController();
  bool     _saving      = false;
  String?  _error;

  List<SparePart> _parts        = [];
  int?            _selectedId;
  bool            _loadingParts = true;

  // Quick-add a part that isn't catalogued yet
  bool                      _showQuickAdd  = false;
  final _quickAddCtrl       = TextEditingController();
  bool                      _quickAdding   = false;

  // Cannibalization source: which machine the part was pulled from, then
  // which serial-numbered unit of that machine.
  bool                  _cannibalized     = false;
  List<InventoryItem>   _machines         = [];
  int?                  _selectedMachineId;
  bool                  _loadingMachines  = false;
  List<SerialNumber>    _availableSerials = [];
  int?                  _selectedSerialId;
  bool                  _loadingSerials   = false;

  @override
  void initState() {
    super.initState();
    SparePartService.instance.list().then((list) {
      if (!mounted) return;
      setState(() { _parts = list; _loadingParts = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loadingParts = false);
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose(); _costCtrl.dispose(); _serialCtrl.dispose(); _quickAddCtrl.dispose();
    super.dispose();
  }

  void _onPartSelected(int? id) {
    setState(() {
      _selectedId = id;
      if (id != null) {
        final p = _parts.firstWhere((p) => p.id == id);
        _costCtrl.text = p.unitCost.toInt().toString();
      }
    });
  }

  Future<void> _quickAddPart() async {
    final name = _quickAddCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _quickAdding = true);
    try {
      final item = await InventoryService.instance.quickCreate(name);
      final part = SparePart(
        id: item.id, sku: item.sku, name: item.name, category: item.category,
        unitOfMeasure: item.unitOfMeasure, unitCost: item.unitCost, currency: item.currency,
        stockQty: item.stockQty, reorderLevel: item.reorderLevel, isLowStock: item.isLowStock,
        supplier: item.supplier, isActive: item.isActive, compatibleModels: item.compatibleModels,
      );
      if (!mounted) return;
      setState(() {
        _parts = [..._parts, part];
        _quickAdding = false;
        _showQuickAdd = false;
        _quickAddCtrl.clear();
      });
      _onPartSelected(part.id);
    } catch (e) {
      if (mounted) { setState(() => _quickAdding = false); showErrorToast(context, e); }
    }
  }

  void _toggleCannibalized(bool value) {
    setState(() {
      _cannibalized = value;
      _selectedMachineId = null;
      _selectedSerialId = null;
      _availableSerials = [];
      _serialCtrl.clear();
      if (value && _machines.isEmpty && !_loadingMachines) _loadMachines();
    });
  }

  Future<void> _loadMachines() async {
    setState(() => _loadingMachines = true);
    try {
      final list = await InventoryService.instance.list(createsMachineRecord: true);
      if (mounted) setState(() { _machines = list; _loadingMachines = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMachines = false);
    }
  }

  void _onMachineSelected(int? id) {
    setState(() {
      _selectedMachineId = id;
      _selectedSerialId = null;
      _availableSerials = [];
      _serialCtrl.clear();
      if (id != null) _loadSerials(id);
    });
  }

  Future<void> _loadSerials(int inventoryItemId) async {
    setState(() => _loadingSerials = true);
    try {
      final list = await SerialNumberService.instance.listForItem(inventoryItemId, status: 'available');
      if (mounted) setState(() { _availableSerials = list; _loadingSerials = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSerials = false);
    }
  }

  void _onScannedSerial(String code) {
    final match = _availableSerials.where((s) => s.serialNumber.trim().toLowerCase() == code.trim().toLowerCase()).firstOrNull;
    if (match != null) {
      setState(() => _selectedSerialId = match.id);
    } else {
      setState(() => _error = 'No available unit matches "$code" for this item.');
    }
  }

  Future<void> _submit() async {
    final qty  = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final cost = int.tryParse(_costCtrl.text.trim().replaceAll(',', '')) ?? 0;
    if (_selectedId == null) {
      setState(() => _error = 'Select a part from inventory.');
      return;
    }
    if (qty <= 0) {
      setState(() => _error = 'Quantity must be at least 1.');
      return;
    }
    if (_cannibalized && _selectedSerialId == null) {
      setState(() => _error = 'Select which stocked unit this part was taken from.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await widget.onSave(_selectedId!, qty, cost, _cannibalized ? _selectedSerialId : null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPart = _selectedId != null ? _parts.where((p) => p.id == _selectedId).firstOrNull : null;

    return AlertDialog(
      backgroundColor: context.pal.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      title: Row(children: [
        Icon(Symbols.inventory_2, size: 18, color: AppColors.teal),
        const SizedBox(width: 10),
        Text('Add Part Used', style: AppTheme.bodyStrong),
      ]),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Part selector
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SPARE PART', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            _loadingParts
              ? Container(
                  height: 38,
                  decoration: BoxDecoration(color: context.pal.surface2,
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                  child: const Center(child: SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : Container(
                  decoration: BoxDecoration(color: context.pal.surface2,
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
                    value: _selectedId,
                    hint: Text('Select from inventory…',
                        style: AppTheme.bodySm.copyWith(color: context.pal.textDim)),
                    isExpanded: true,
                    dropdownColor: context.pal.surface2,
                    style: AppTheme.bodySm,
                    icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
                    items: _parts.map((p) => DropdownMenuItem<int?>(
                      value: p.id,
                      child: Row(children: [
                        Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: p.isLowStock
                                ? AppColors.amber.withValues(alpha: 0.15)
                                : AppColors.tealSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${p.stockQty} in stock',
                            style: AppTheme.monoXs.copyWith(
                              fontSize: 9.5,
                              color: p.isLowStock ? AppColors.amber : AppColors.teal)),
                        ),
                      ]),
                    )).toList(),
                    onChanged: _onPartSelected,
                  )),
                ),
            const SizedBox(height: 6),
            if (!_showQuickAdd)
              GestureDetector(
                onTap: () => setState(() => _showQuickAdd = true),
                child: Text('+ Add a new part not in this list',
                    style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 12)),
              )
            else
              Row(children: [
                Expanded(child: _ticketField('New part name', _quickAddCtrl, 'e.g. Power Supply Module', context)),
                const SizedBox(width: 8),
                _quickAdding
                  ? const Padding(padding: EdgeInsets.only(top: 20),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : Padding(padding: const EdgeInsets.only(top: 20), child: GestureDetector(
                      onTap: _quickAddPart,
                      child: Icon(Symbols.check_circle, size: 22, color: AppColors.teal),
                    )),
                Padding(padding: const EdgeInsets.only(top: 20, left: 4), child: GestureDetector(
                  onTap: () => setState(() { _showQuickAdd = false; _quickAddCtrl.clear(); }),
                  child: Icon(Symbols.close, size: 20, color: context.pal.textDim),
                )),
              ]),
          ]),

          // Show selected part info
          if (selectedPart != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Icon(Symbols.info, size: 13, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${selectedPart.partNumber} · ${selectedPart.description.isNotEmpty ? selectedPart.description : selectedPart.supplier}',
                  style: AppTheme.bodySub.copyWith(fontSize: 11.5),
                  overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],

          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ticketField('Quantity', _qtyCtrl, '1', context, numeric: true)),
            const SizedBox(width: 12),
            Expanded(child: _ticketField('Unit Cost (TSh)', _costCtrl, '0', context, numeric: true)),
          ]),

          const SizedBox(height: 14),
          // Source toggle: from generic stock vs cannibalized from a specific unit
          GestureDetector(
            onTap: () => _toggleCannibalized(!_cannibalized),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: _cannibalized ? AppColors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _cannibalized ? AppColors.amber : context.pal.borderStrong),
                ),
                child: _cannibalized ? const Icon(Symbols.check, size: 14, color: Color(0xFF06120F)) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Cannibalized from a stocked unit (not general stock)',
                  style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
            ]),
          ),

          if (_cannibalized) ...[
            const SizedBox(height: 10),
            if (_selectedId == null)
              Text('Select a part above first.', style: AppTheme.bodySub.copyWith(color: AppColors.amber, fontSize: 12))
            else ...[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SOURCE MACHINE', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                const SizedBox(height: 6),
                _loadingMachines
                  ? Container(
                      height: 38,
                      decoration: BoxDecoration(color: context.pal.surface2,
                          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                      child: const Center(child: SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  : Container(
                      decoration: BoxDecoration(color: context.pal.surface2,
                          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
                        value: _selectedMachineId,
                        hint: Text('Which machine model was it taken from—',
                            style: AppTheme.bodySm.copyWith(color: context.pal.textDim)),
                        isExpanded: true,
                        dropdownColor: context.pal.surface2,
                        style: AppTheme.bodySm,
                        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
                        items: _machines.map((m) => DropdownMenuItem<int?>(
                          value: m.id,
                          child: Text(m.name, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: _onMachineSelected,
                      )),
                    ),
              ]),

              if (_selectedMachineId != null) ...[
                const SizedBox(height: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SOURCE UNIT SERIAL', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  ScanOrTypeField(controller: _serialCtrl, hint: 'Scan or type serial number…', onScanned: _onScannedSerial),
                ]),
                const SizedBox(height: 8),
                _loadingSerials
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))))
                  : _availableSerials.isEmpty
                    ? Text('No available tracked units for this machine —cannibalization needs a real serial-tracked unit in stock.',
                        style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 11.5))
                    : Wrap(spacing: 8, runSpacing: 8, children: _availableSerials.map((s) => GestureDetector(
                        onTap: () => setState(() { _selectedSerialId = s.id; _serialCtrl.text = s.serialNumber; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedSerialId == s.id ? AppColors.amberSoft : context.pal.surface2,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: _selectedSerialId == s.id ? AppColors.amber : context.pal.border),
                          ),
                          child: Text(s.serialNumber, style: AppTheme.monoXs.copyWith(
                              color: _selectedSerialId == s.id ? AppColors.amber : context.pal.textMute)),
                        ),
                      )).toList()),
              ],
            ],
          ],

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
          ],
        ])),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppTheme.bodySm.copyWith(color: context.pal.textMute)),
        ),
        GestureDetector(
          onTap: _saving ? null : _submit,
          child: Container(
            height: 36, padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
            child: Center(child: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Add Part', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13))),
          ),
        ),
      ],
    );
  }
}

// ── Add Checklist Item Dialog ───────────────────────────────────────────────
class _AddChecklistItemDialog extends StatefulWidget {
  const _AddChecklistItemDialog({required this.onSave});
  final Future<void> Function(String label) onSave;
  @override
  State<_AddChecklistItemDialog> createState() => _AddChecklistItemDialogState();
}

class _AddChecklistItemDialogState extends State<_AddChecklistItemDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final label = _ctrl.text.trim();
    if (label.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(label);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
    title: Row(children: [
      Icon(Symbols.checklist, size: 18, color: AppColors.teal),
      const SizedBox(width: 10),
      Text('Add Checklist Item', style: AppTheme.bodyStrong),
    ]),
    content: SizedBox(
      width: 380,
      child: _ticketField('Item', _ctrl, 'e.g. Check reagent levels', context),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel', style: AppTheme.bodySm.copyWith(color: context.pal.textMute)),
      ),
      GestureDetector(
        onTap: _saving ? null : _submit,
        child: Container(
          height: 36, padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
          child: Center(child: _saving
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Add Item', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13))),
        ),
      ),
    ],
  );
}

// ── Edit Ticket Dialog ──────────────────────────────────────────────────────
class _EditTicketDialog extends StatefulWidget {
  const _EditTicketDialog({required this.ticket, required this.onSaved});
  final ServiceTicket ticket;
  final VoidCallback  onSaved;
  @override
  State<_EditTicketDialog> createState() => _EditTicketDialogState();
}

class _EditTicketDialogState extends State<_EditTicketDialog> {
  late final _descCtrl = TextEditingController(text: widget.ticket.description ?? '');
  late final _wardCtrl = TextEditingController(text:
      widget.ticket.ward == '—' ? '' : widget.ticket.ward);
  late String _status = switch (widget.ticket.status) {
    TicketStatus.open       => 'open',
    TicketStatus.inProgress => 'in_progress',
    TicketStatus.resolved   => 'resolved',
    TicketStatus.overdue    => 'overdue',
  };
  bool    _saving       = false;
  String? _error;

  List<StaffMember> _staff        = [];
  StaffMember?      _selectedTech;
  bool              _loadingStaff = true;

  @override
  void initState() {
    super.initState();
    _selectedTech = widget.ticket.assignee;
    StaffService.instance.list().then((list) {
      if (!mounted) return;
      setState(() {
        _staff        = list;
        _loadingStaff = false;
        _resolveSelected();
      });
    }).catchError((_) {
      if (mounted) setState(() => _loadingStaff = false);
    });
  }

  // Match ticket's assignee into the loaded _staff list.
  // Never clears _selectedTech —only upgrades it to the list's richer object.
  void _resolveSelected() {
    final currentId = widget.ticket.assignee?.id ?? widget.ticket.assignedToId;
    if (currentId == null) return;

    final match = _staff.where((s) => s.id == currentId).firstOrNull;
    if (match != null) {
      _selectedTech = match;
    } else if (widget.ticket.assignee != null) {
      // Known assignee not in the loaded list —inject them so dropdown value is valid
      _staff = [widget.ticket.assignee!, ..._staff.where((s) => s.id != currentId)];
      _selectedTech = widget.ticket.assignee;
    }
    // currentId set but assignee null and no match: _selectedTech stays null (genuinely unknown)
  }

  @override
  void dispose() { _descCtrl.dispose(); _wardCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; });
    try {
      await TicketService.instance.update(widget.ticket.dbId, {
        'status':      _status,
        'assigned_to': _selectedTech?.id,   // null = unassign
        'ward':        _wardCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyError(e); });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
    title: Row(children: [
      Icon(Symbols.edit, size: 18, color: AppColors.teal),
      const SizedBox(width: 10),
      Expanded(child: Text('Edit Ticket — ${widget.ticket.id}',
          style: AppTheme.bodyStrong, overflow: TextOverflow.ellipsis)),
    ]),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(child: Column(children: [
        // Technician dropdown —reassignment is CTO/Director-only, mirroring
        // ServiceTicketController::update()'s hasCtoApprovalAuthority() gate.
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ASSIGN TECHNICIAN', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          !hasCtoApprovalAuthority(userRoleNotifier.value)
            ? Container(
                height: 38,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: context.pal.surface2,
                    borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                child: Text(
                  _selectedTech?.name ?? 'Unassigned',
                  style: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                ),
              )
            : _loadingStaff
            ? Container(
                height: 38,
                decoration: BoxDecoration(color: context.pal.surface2,
                    borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                child: const Center(child: SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))),
              )
            : Builder(builder: (context) {
                final seen   = <int>{};
                final items  = _staff.where((s) => seen.add(s.id)).toList();
                final techId = items.any((s) => s.id == _selectedTech?.id)
                    ? _selectedTech?.id : null;
                return Container(
                  decoration: BoxDecoration(color: context.pal.surface2,
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
                    value: techId,
                    hint: Text('Unassigned', style: AppTheme.bodySm.copyWith(color: context.pal.textDim)),
                    isExpanded: true,
                    dropdownColor: context.pal.surface2,
                    style: AppTheme.bodySm,
                    icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Unassigned',
                            style: AppTheme.bodySm.copyWith(color: context.pal.textDim)),
                      ),
                      ...items.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (id) => setState(() =>
                      _selectedTech = id == null ? null : items.firstWhere((s) => s.id == id)),
                  )),
                );
              }),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _ticketField('Ward / Location', _wardCtrl, 'e.g. ICU', context)),
        ]),
        const SizedBox(height: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STATUS', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: context.pal.surface2,
                borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _status, isExpanded: true,
              dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
              icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
              items: const [
                DropdownMenuItem(value: 'open',        child: Text('Open')),
                DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                DropdownMenuItem(value: 'resolved',    child: Text('Resolved')),
                DropdownMenuItem(value: 'overdue',     child: Text('Overdue')),
              ],
              onChanged: (v) { if (v != null) setState(() => _status = v); },
            )),
          ),
        ]),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Description / Notes',
          controller: _descCtrl,
          maxLines: null,
          height: 90,
          hintText: 'Describe the issue or work required…',
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
        ],
      ]),    // Column
    )),      // SingleChildScrollView + SizedBox
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel', style: AppTheme.bodySm.copyWith(color: context.pal.textMute)),
      ),
      GestureDetector(
        onTap: _saving ? null : _submit,
        child: Container(
          height: 36, padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
          child: Center(child: _saving
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Save Changes', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13))),
        ),
      ),
    ],
  );
}

// ── Shared field helper ─────────────────────────────────────────────────────
Widget _ticketField(String label, TextEditingController ctrl, String hint,
    BuildContext context, {bool numeric = false}) =>
  AppTextField(
    label: label,
    controller: ctrl,
    hintText: hint,
    keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: false) : TextInputType.text,
  );

