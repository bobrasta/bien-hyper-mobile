import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show hasMachineCostsViewAuthority, hasMachineAllocateAuthority, userRoleNotifier;
import '../../models/invoice.dart';
import '../../models/machine.dart';
import '../../models/service_ticket.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/error_view.dart';
import '../../services/hospital_service.dart';
import '../../services/invoice_service.dart';
import '../../services/machine_service.dart';
import '../../services/staff_service.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dropdown.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/labeled_field.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/email/compose_modal.dart';

import '../../theme/app_palette.dart';
class MachineDetailScreen extends StatefulWidget {
  const MachineDetailScreen({super.key, this.machineId = 0, this.onBack});
  final int machineId;
  final VoidCallback? onBack;

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  int _tab = 0;
  bool _showEdit        = false;
  bool _showLogService  = false;
  bool _showRaiseTicket = false;
  bool _showEditSpecs   = false;
  bool _showAllocate    = false;

  // Section 12: Service Costs is visible only to Admin/Director/CTO/finance
  // (server-enforced too — this only toggles the tab's visibility).
  List<String> get _tabs => [
    'Overview', 'Service History',
    if (hasMachineCostsViewAuthority(userRoleNotifier.value)) 'Service Costs',
    'Revenue', 'Documents', 'Notes',
  ];

  Machine? _machine;
  bool     _loading = true;
  String?  _loadError;

  @override
  void initState() {
    super.initState();
    // Stale-while-revalidate — same reasoning as MachineListScreen's own
    // fix: show the last-known version of this exact machine instantly if
    // we have one cached, then quietly refresh, instead of blanking to a
    // spinner on every navigation regardless of how fast the underlying
    // fetch resolves.
    final cached = MachineService.cachedById[widget.machineId];
    if (cached != null) { _machine = cached; _loading = false; }
    _load();
  }

  @override
  void didUpdateWidget(MachineDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.machineId != widget.machineId) {
      // A different machine — must not keep showing the previous one's
      // data under the new ID. Seed from that ID's own cache entry (which
      // may be null), then refresh.
      final cached = MachineService.cachedById[widget.machineId];
      setState(() { _machine = cached; _loading = cached == null; _loadError = null; });
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      if (_machine == null) _loading = true;
      _loadError = null;
    });
    try {
      final m = await MachineService.instance.get(widget.machineId);
      if (mounted) setState(() { _machine = m; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loadError = friendlyError(e); _loading = false; });
    }
  }

  // showDialog gives the modal the whole window as its route, not just this
  // screen's own content pane — stacking it as a bare Stack child (the old
  // approach) only got it this screen's own bounds, so it rendered cramped
  // and undimmed instead of as a real full-screen overlay.
  void _openCompose() {
    final m = _machine;
    if (m == null) return;
    showDialog(
      context: context,
      builder: (_) => ComposeModal(
        initialSubject: 'RE: ${m.model} (${m.serialNo})',
        onClose: () => Navigator.of(context).pop(),
        onSent:  () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    // A background refresh erroring while stale-but-valid cached data is
    // already showing shouldn't blow that away — only the "genuinely
    // nothing to show" case surfaces the error screen.
    if (_machine == null) {
      return Center(child: Text(_loadError ?? 'Not found',
          style: TextStyle(color: AppColors.coral)));
    }
    final m = _machine!;

    return Stack(children: [
      LayoutBuilder(builder: (ctx, cst) {
      final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
      return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          Row(children: [
            const SizedBox(width: 6),
            Text('Workspace', style: AppTheme.monoXs),
            const SizedBox(width: 6),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onBack,
              child: Text('Machines', style: AppTheme.monoXs.copyWith(
                  color: widget.onBack != null ? AppColors.teal : context.pal.textMute,
                  decoration: widget.onBack != null ? TextDecoration.underline : null)),
            ),
            const SizedBox(width: 6),
            const SizedBox(width: 6),
            Text(m.serialNo, style: AppTheme.monoXs.copyWith(color: context.pal.text)),
          ]),
          const SizedBox(height: 16),

          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.pal.surface1,
              borderRadius: BorderRadius.circular(AppColors.rLg),
              border: Border.all(color: context.pal.border),
            ),
            child: LayoutBuilder(builder: (ctx2, cst2) {
              final narrow = cst2.maxWidth < 560;
              final photo = Container(
                width: narrow ? 80 : 120,
                height: narrow ? 68 : 100,
                decoration: BoxDecoration(
                  color: context.pal.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.pal.borderStrong),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Symbols.precision_manufacturing, size: narrow ? 26 : 36, color: context.pal.textDim),
                  const SizedBox(height: 4),
                  Text('MACHINE PHOTO', style: AppTheme.monoXs.copyWith(fontSize: 9)),
                ]),
              );
              final infoBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.model, style: AppTheme.pageTitle.copyWith(fontSize: narrow ? 16 : 20)),
                    const SizedBox(height: 2),
                    Text(m.type, style: AppTheme.bodySub),
                  ])),
                  StatusBadge.machine(m.status, large: true),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24, runSpacing: 8,
                  children: [
                    _InfoItem(label: 'Serial No',    value: m.serialNo),
                    _InfoItem(label: 'Manufacturer', value: m.model.split(' ').first),
                    _InfoItem(label: 'Hospital',     value: m.hospital),
                    _InfoItem(label: 'Ward',         value: m.ward),
                    _InfoItem(label: 'Installed',    value: m.installDate),
                    _InfoItem(label: 'Warranty',     value: '${m.warrantyExpiry} · Active'),
                  ],
                ),
              ]);
              // Section 13: Raise Ticket/Log Service are for Installed
              // machines only (server-enforced too, ServiceTicketController::
              // store()); an In Stock machine gets Allocate instead.
              final actionButtons = Wrap(spacing: 8, runSpacing: 8, children: [
                if (m.isInstalled) ...[
                  AppButton(label: 'Log Service',  icon: Symbols.build,               variant: BtnVariant.primary,
                      onPressed: () => setState(() => _showLogService = true)),
                  AppButton(label: 'Raise Ticket', icon: Symbols.confirmation_number, variant: BtnVariant.normal,
                      onPressed: () => setState(() => _showRaiseTicket = true)),
                ],
                if (m.isInStock && hasMachineAllocateAuthority(userRoleNotifier.value))
                  AppButton(label: 'Allocate', icon: Symbols.local_shipping, variant: BtnVariant.primary,
                      onPressed: () => setState(() => _showAllocate = true)),
                AppButton(label: 'Edit Machine', icon: Symbols.edit,                variant: BtnVariant.normal,
                    onPressed: () => setState(() => _showEdit = true)),
                AppButton(label: 'Send Email',   icon: Symbols.mail,                variant: BtnVariant.normal,
                    onPressed: _openCompose),
              ]);

              if (narrow) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    photo,
                    const SizedBox(width: 14),
                    Expanded(child: infoBlock),
                  ]),
                  const SizedBox(height: 16),
                  actionButtons,
                ]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                photo,
                const SizedBox(width: 20),
                Expanded(child: infoBlock),
                const SizedBox(width: 20),
                actionButtons,
              ]);
            }),
          ),
          const SizedBox(height: 16),

          // Tab bar
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: List.generate(_tabs.length, (i) => GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(
                    color: _tab == i ? AppColors.teal : Colors.transparent, width: 2,
                  ))),
                  child: Text(_tabs[i], style: AppTheme.bodySm.copyWith(
                    color: _tab == i ? context.pal.text : context.pal.textMute,
                    fontWeight: FontWeight.w500, fontSize: 13,
                  )),
                ),
              ))),
            ),  // SingleChildScrollView
          ),
          const SizedBox(height: 20),

          // Tab content — matched by label, not fixed index, since the tab
          // list itself shrinks/grows per role (Service Costs).
          if (_tabs[_tab] == 'Overview') _OverviewContent(
            machine: m,
            onEditSpecs: () => setState(() => _showEditSpecs = true),
          ),
          if (_tabs[_tab] == 'Service History') _ServiceHistoryContent(
            machineId: widget.machineId,
            onLogService: () => setState(() => _showLogService = true),
          ),
          if (_tabs[_tab] == 'Service Costs') _ServiceCostsContent(machine: m),
          if (_tabs[_tab] == 'Revenue') _RevenueTabContent(machine: m),
          if (_tabs[_tab] == 'Documents') const _DocumentsContent(),
          if (_tabs[_tab] == 'Notes') _NotesContent(machine: m),
        ],
      ),
    );  // SingleChildScrollView
    }),   // LayoutBuilder

      // Overlays
      if (_showEdit)
        _EditMachineDialog(machine: m, onClose: () => setState(() => _showEdit = false)),
      if (_showLogService)
        _LogServiceDialog(machine: m, onClose: () => setState(() => _showLogService = false)),
      if (_showRaiseTicket)
        _RaiseTicketDialog(machine: m, onClose: () => setState(() => _showRaiseTicket = false)),
      if (_showAllocate)
        _AllocateMachineDialog(
          machine: m,
          onClose: () => setState(() => _showAllocate = false),
          onSaved: () { setState(() => _showAllocate = false); _load(); },
        ),
      if (_showEditSpecs)
        _EditSpecsDialog(
          machine: m,
          onClose: () => setState(() => _showEditSpecs = false),
          onSaved: () { setState(() => _showEditSpecs = false); _load(); },
        ),
    ]);  // Stack
  }
}

// ── Overview ────────────────────────────────────────────────────────────────
class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps),
    const SizedBox(height: 3),
    Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
  ]);
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.machine, this.onEditSpecs});
  final Machine machine;
  final VoidCallback? onEditSpecs;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: Column(children: [
        // Service snapshot
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.pal.surface1, borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Service Snapshot', style: AppTheme.cardTitle),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _SnapItem(icon: Symbols.event,    label: 'Last Service',    value: '12 May 2025', sub: '42 days ago')),
              Expanded(child: _SnapItem(icon: Symbols.schedule, label: 'Next Scheduled',  value: '12 Aug 2025', sub: '50 days away', valueColor: AppColors.amber)),
              Expanded(child: _SnapItem(icon: Symbols.build,    label: 'Total Services',  value: '8',           sub: 'since install')),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // Revenue mini chart
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.pal.surface1, borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Revenue', style: AppTheme.cardTitle),
              const Spacer(),
              Text('TSh ${(machine.revenuePerMonth / 1e6).toStringAsFixed(1)}M / month',
                style: AppTheme.bodySub.copyWith(color: AppColors.teal)),
            ]),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end,
              children: [4.0, 3.8, 4.1, 3.9, 4.2, 4.0].asMap().entries.map((e) {
                final isLast = e.key == 5;
                return Column(children: [
                  Container(
                    width: 32, height: e.value * 16,
                    decoration: BoxDecoration(
                      color: isLast ? AppColors.teal : context.pal.surface3,
                      borderRadius: BorderRadius.circular(4),
                      border: isLast ? null : Border.all(color: context.pal.border),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(['Jan','Feb','Mar','Apr','May','Jun'][e.key],
                    style: AppTheme.monoXs.copyWith(fontSize: 9)),
                ]);
              }).toList(),
            ),
          ]),
        ),
      ])),
      const SizedBox(width: 16),
      Expanded(flex: 1, child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.pal.surface1, borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Assigned Technician', style: AppTheme.cardTitle),
            const SizedBox(height: 16),
            machine.technicianName != null
              ? Row(children: [
                  AvatarWidget(
                    initials: machine.technicianInitials ?? machine.technicianName![0],
                    size: 40,
                    variant: AvatarVariant.teal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(machine.technicianName!,
                    style: AppTheme.bodyStrong)),
                ])
              : Row(children: [
                  Icon(Symbols.person_off, size: 20, color: context.pal.textDim),
                  const SizedBox(width: 10),
                  Text('No technician assigned',
                    style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
                ]),
          ]),
        ),
        const SizedBox(height: 16),
        // Specs card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.pal.surface1, borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Specifications', style: AppTheme.cardTitle),
              const Spacer(),
              GestureDetector(
                onTap: onEditSpecs,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.edit, size: 13, color: context.pal.textMute),
                  const SizedBox(width: 4),
                  Text('Edit', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            if (machine.specifications.isEmpty)
              Row(children: [
                Icon(Symbols.info, size: 14, color: context.pal.textDim),
                const SizedBox(width: 8),
                Text('No specifications recorded.',
                  style: AppTheme.bodySub.copyWith(fontSize: 12)),
              ])
            else
              ...machine.specifications.entries.map(
                (e) => _SpecRow(e.key, e.value)),
          ]),
        ),
      ])),
    ]);
  }
}

class _SnapItem extends StatelessWidget {
  const _SnapItem({required this.icon, required this.label, required this.value, required this.sub, this.valueColor});
  final IconData icon; final String label, value, sub; final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(icon, size: 14, color: context.pal.textDim),
      const SizedBox(width: 6),
      Text(label.toUpperCase(), style: AppTheme.labelCaps),
    ]),
    const SizedBox(height: 6),
    Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 16, color: valueColor ?? context.pal.text)),
    Text(sub, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
  ]);
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12))),
      Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 12)),
    ]),
  );
}

// ── Service History ─────────────────────────────────────────────────────────
class _ServiceHistoryContent extends StatefulWidget {
  const _ServiceHistoryContent({required this.machineId, this.onLogService});
  final int machineId;
  final VoidCallback? onLogService;

  @override
  State<_ServiceHistoryContent> createState() => _ServiceHistoryContentState();
}

class _ServiceHistoryContentState extends State<_ServiceHistoryContent> {
  List<ServiceTicket> _history = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await TicketService.instance.list(machineId: widget.machineId);
      if (mounted) setState(() { _history = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Color _statusColor(TicketStatus s) => switch (s) {
    TicketStatus.inProgress => AppColors.amber,
    TicketStatus.resolved   => AppColors.teal,
    TicketStatus.overdue    => AppColors.coral,
    _                       => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${_history.length} service records', style: AppTheme.bodySub),
        const Spacer(),
        AppButton(label: 'Log New Service', icon: Symbols.add, variant: BtnVariant.primary, small: true,
            onPressed: widget.onLogService),
      ]),
      const SizedBox(height: 14),
      if (_loading)
        const Center(child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(strokeWidth: 2),
        ))
      else if (_error != null)
        ErrorView(message: _error!, onRetry: _load)
      else if (_history.isEmpty)
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text('No service history for this machine.',
              style: TextStyle(color: context.pal.textMute)),
        ))
      else
        Container(
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
              child: Row(children: [
                _SHTh('Ticket',      w: 76),
                _SHTh('Date',        w: 110),
                _SHTh('Technician',  flex: 2),
                _SHTh('Ward',        flex: 1),
                _SHTh('Description', flex: 3),
                _SHTh('Status',      w: 100),
              ]),
            ),
            ..._history.asMap().entries.map((e) {
              final t = e.value;
              final isLast = e.key == _history.length - 1;
              final sc = _statusColor(t.status);
              return Container(
                decoration: BoxDecoration(
                  border: isLast ? null : Border(bottom: BorderSide(color: context.pal.divider)),
                ),
                child: Row(children: [
                  SizedBox(width: 76, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text(t.id, style: AppTheme.monoXs.copyWith(color: AppColors.teal)),
                  )),
                  SizedBox(width: 110, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(t.createdAt, style: AppTheme.monoXs,
                        overflow: TextOverflow.ellipsis),
                  )),
                  Expanded(flex: 2, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.technicianName == '—' ? 'Unassigned' : t.technicianName,
                        style: AppTheme.bodySm.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                      if (t.technicianInitials.isNotEmpty && t.technicianInitials != '?')
                        Text(t.technicianInitials,
                          style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
                    ]),
                  )),
                  Expanded(flex: 1, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(t.ward == '—' ? '' : t.ward,
                      style: AppTheme.bodySub.copyWith(fontSize: 11.5),
                      overflow: TextOverflow.ellipsis),
                  )),
                  Expanded(flex: 3, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(t.description ?? '—',
                        style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  SizedBox(width: 110, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(t.status.label, style: AppTheme.bodySub.copyWith(
                        color: sc, fontSize: 11.5, fontWeight: FontWeight.w500)),
                    ),
                  )),
                ]),
              );
            }),
          ]),
        ),
    ]);
  }
}

class _SHTh extends StatelessWidget {
  const _SHTh(this.label, {this.w, this.flex});
  final String label;
  final double? w;
  final int? flex;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(label.toUpperCase(),
        style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.10)),
    );
    if (w != null) return SizedBox(width: w, child: child);
    return Expanded(flex: flex ?? 1, child: child);
  }
}

// ── Revenue Tab ─────────────────────────────────────────────────────────────
class _RevenueTabContent extends StatefulWidget {
  const _RevenueTabContent({required this.machine});
  final Machine machine;

  @override
  State<_RevenueTabContent> createState() => _RevenueTabContentState();
}

class _RevenueTabContentState extends State<_RevenueTabContent> {
  List<Invoice> _invoices = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await InvoiceService.instance.list(machineId: widget.machine.id);
      if (mounted) setState(() { _invoices = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    final monthlyFee = widget.machine.revenuePerMonth / 1e6;
    final ytd = _invoices.fold(0.0, (s, i) => s + i.total) / 1e6;
    final lastPaid = _invoices.where((i) => i.status == PaymentStatus.paid).isNotEmpty
        ? _invoices.where((i) => i.status == PaymentStatus.paid).last.issueDate
        : '—';

    // Build bar chart data from invoices (group by month label)
    final chartInvoices = _invoices.take(6).toList();
    final chartValues = chartInvoices.map((i) => i.total / 1e6).toList();
    final maxV = chartValues.isEmpty ? 1.0 : chartValues.reduce((a, b) => a > b ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _RevKpi(label: 'Monthly Fee',   value: 'TSh ${monthlyFee.toStringAsFixed(1)}M', color: AppColors.teal),
        const SizedBox(width: 16),
        _RevKpi(label: 'YTD Revenue',   value: 'TSh ${ytd.toStringAsFixed(1)}M'),
        const SizedBox(width: 16),
        _RevKpi(label: 'Last Payment',  value: lastPaid, color: context.pal.text),
        const SizedBox(width: 16),
        _RevKpi(label: 'Invoices',      value: '${_invoices.length}', color: AppColors.teal),
      ]),
      const SizedBox(height: 16),

      if (chartValues.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Recent Invoice Amounts', style: AppTheme.cardTitle),
            const SizedBox(height: 20),
            SizedBox(
              // A few px taller than the 120 max bar height + its two text
              // labels need at default scale — headroom for the Text Size
              // setting (Settings → Preferences) going up to Large.
              height: 176,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: chartInvoices.asMap().entries.map((e) {
                  final isLast = e.key == chartInvoices.length - 1;
                  final barHeight = maxV > 0 ? (chartValues[e.key] / maxV) * 120 : 0.0;
                  return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${chartValues[e.key].toStringAsFixed(1)}M',
                      style: AppTheme.monoXs.copyWith(
                        color: isLast ? AppColors.teal : context.pal.textDim, fontSize: 9.5)),
                    const SizedBox(height: 4),
                    Container(
                      width: 40, height: barHeight,
                      decoration: BoxDecoration(
                        color: isLast ? AppColors.teal : context.pal.surface3,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        border: isLast ? null : Border.all(color: context.pal.border),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(e.value.issueDate.length >= 3 ? e.value.issueDate.substring(0, 3) : e.value.issueDate,
                      style: AppTheme.monoXs.copyWith(fontSize: 9.5)),
                  ]);
                }).toList(),
              ),
            ),
          ]),
        ),

      const SizedBox(height: 16),

      Container(
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(children: [
              const SizedBox(width: 8),
              Text('Payment History', style: AppTheme.cardTitle),
            ]),
          ),
          if (_invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No invoices for this machine.',
                  style: TextStyle(color: context.pal.textMute))),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
                  children: ['Invoice', 'Issue Date', 'Amount', 'Status'].map((h) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(h.toUpperCase(), style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
                    )
                  ).toList(),
                ),
                ..._invoices.asMap().entries.map((e) {
                  final inv = e.value;
                  final isLast = e.key == _invoices.length - 1;
                  final sc = inv.status == PaymentStatus.paid ? AppColors.teal
                      : inv.status == PaymentStatus.overdue ? AppColors.coral
                      : AppColors.amber;
                  return TableRow(
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(bottom: BorderSide(color: context.pal.divider)),
                    ),
                    children: [
                      _TC(Text(inv.invoiceNumber, style: AppTheme.monoXs.copyWith(fontSize: 11))),
                      _TC(Text(inv.issueDate, style: AppTheme.bodySub)),
                      _TC(Text('TSh ${(inv.total / 1e6).toStringAsFixed(1)}M',
                        style: AppTheme.monoSm.copyWith(color: AppColors.amber))),
                      _TC(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sc.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(inv.status.label, style: AppTheme.bodySub.copyWith(
                          color: sc, fontSize: 11.5, fontWeight: FontWeight.w500,
                        )),
                      )),
                    ],
                  );
                }),
              ],
            ),
        ]),
      ),
    ]);
  }
}

class _RevKpi extends StatelessWidget {
  const _RevKpi({required this.label, required this.value, this.color});
  final String label, value; final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps),
      const SizedBox(height: 6),
      Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 16, color: color ?? context.pal.text)),
    ]),
  ));
}

class _TC extends StatelessWidget {
  const _TC(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: child);
}

// ── Documents ───────────────────────────────────────────────────────────────
class _DocumentsContent extends StatelessWidget {
  const _DocumentsContent();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('0 documents', style: AppTheme.bodySub),
        const Spacer(),
        AppButton(label: 'Upload Document', icon: Symbols.upload_file, variant: BtnVariant.primary, small: true),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Center(child: Column(children: [
          Icon(Symbols.folder_open, size: 32, color: context.pal.textDim),
          const SizedBox(height: 10),
          Text('No documents uploaded yet.',
            style: AppTheme.bodySub.copyWith(fontSize: 13)),
        ])),
      ),
    ]);
  }
}

// ── Notes ───────────────────────────────────────────────────────────────────
class _NotesContent extends StatefulWidget {
  const _NotesContent({required this.machine});
  final Machine machine;

  @override
  State<_NotesContent> createState() => _NotesContentState();
}

class _NotesContentState extends State<_NotesContent> {
  late final _controller = TextEditingController(text: widget.machine.notes ?? '');
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await MachineService.instance.update(widget.machine.id, {
        'notes': _controller.text.trim(),
      });
      if (!mounted) return;
      setState(() => _saving = false);
      showSuccessToast(context, 'Notes saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Machine notes', style: AppTheme.bodySub),
        const Spacer(),
        AppButton(label: 'Save Notes', icon: Symbols.save, variant: BtnVariant.primary, small: true,
            onPressed: _saving ? null : _save),
      ]),
      const SizedBox(height: 14),
      FieldFocusBox(builder: (context, focusNode) => TextField(focusNode: focusNode, controller: _controller,
          maxLines: null,
          minLines: 12,
          style: AppTheme.fieldText.copyWith(height: 1.7),
          decoration: InputDecoration(
            hintText: 'Add notes about this machine—',
            hintStyle: AppTheme.fieldText.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
          ),
        ),),
    ]);
  }
}

// ── Shared modal helpers ────────────────────────────────────────────────────
class _MField extends StatelessWidget {
  const _MField(this.label, this.ctrl, this.hint);
  final String label, hint;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.fieldLabel),
    const SizedBox(height: 6),
    FieldFocusBox(
      builder: (context, focusNode) => TextField(controller: ctrl, focusNode: focusNode, style: AppTheme.fieldText,
        decoration: InputDecoration(hintText: hint,
            hintStyle: AppTheme.fieldText.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),
    ),
  ]);
}

Widget _mLoadingField(String label) => Builder(builder: (context) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(label, style: AppTheme.fieldLabel),
    const SizedBox(height: 6),
    Container(
      height: 38,
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      child: const Center(child: SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2))),
    ),
  ],
));

class _MDrop extends StatelessWidget {
  const _MDrop({required this.label, required this.value, required this.items,
      this.display, required this.onChanged});
  final String label, value;
  final List<String> items;
  final List<String>? display;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.fieldLabel),
    const SizedBox(height: 6),
    Container(
      decoration: BoxDecoration(color: context.pal.bg,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: context.pal.borderStrong, width: 1.2)),
      height: kFieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isExpanded: true,
        dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.asMap().entries.map((e) => DropdownMenuItem(
            value: e.value,
            child: Text(display != null ? display![e.key] : e.value))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);
}

Widget _modalShell(
  BuildContext context, {
  required VoidCallback onClose,
  required IconData icon,
  required String title,
  required Widget body,
  required String saveLabel,
  VoidCallback? onSave,
  bool saving = false,
  double width = 500,
}) => GestureDetector(
  onTap: onClose,
  child: Container(
    color: const Color(0xAA06070A),
    alignment: Alignment.center,
    child: GestureDetector(
      onTap: () {},
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.pal.borderStrong),
          boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 18, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTheme.bodyStrong, overflow: TextOverflow.ellipsis)),
              GestureDetector(onTap: onClose,
                  child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: body),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: onClose,
                child: Container(height: 38,
                  decoration: BoxDecoration(border: Border.all(color: context.pal.border),
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('Cancel', style: AppTheme.bodySm))),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: onSave ?? onClose,
                child: Container(height: 38,
                  decoration: BoxDecoration(color: AppColors.teal,
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(child: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(saveLabel, style: AppTheme.bodyStrong.copyWith(
                        color: const Color(0xFF06120F), fontSize: 13)))),
              )),
            ]),
          ),
        ]),
      ),
    ),
  ),
);

// ── Edit Machine Dialog ─────────────────────────────────────────────────────
class _EditMachineDialog extends StatefulWidget {
  const _EditMachineDialog({required this.machine, required this.onClose});
  final Machine machine;
  final VoidCallback onClose;
  @override
  State<_EditMachineDialog> createState() => _EditMachineDialogState();
}

class _EditMachineDialogState extends State<_EditMachineDialog> {
  late final _modelCtrl    = TextEditingController(text: widget.machine.model);
  late final _serialCtrl   = TextEditingController(text: widget.machine.serialNo);
  late final _wardCtrl     = TextEditingController(text: widget.machine.ward);
  late final _warrantyCtrl = TextEditingController(text: widget.machine.warrantyExpiry);
  late final _purchaseCostCtrl = TextEditingController(text: widget.machine.purchaseCost?.toString() ?? '');
  late final _fxRateCtrl   = TextEditingController();
  late String _status = widget.machine.status.name;
  late String _currency = widget.machine.purchaseCostCurrency ?? 'TZS';
  bool    _saving = false;
  String? _error;

  // Was: fetch up to 500 hospitals and name-match against them, falling
  // back to `list.first` (an arbitrary, likely-wrong hospital) whenever the
  // machine's real hospital fell outside that batch — silently reassigning
  // the machine to the wrong facility on save. The hospital directory is
  // 13,000+ rows since the national facility registry import, so that
  // fallback was no longer a rare edge case. Fixed by trusting the id
  // already on the Machine record instead of re-deriving it from a name
  // lookup over a truncated list.
  late int?    _hospitalId   = widget.machine.hospitalId;
  late String? _hospitalName = widget.machine.hospital;

  @override
  void dispose() {
    _modelCtrl.dispose(); _serialCtrl.dispose();
    _wardCtrl.dispose(); _warrantyCtrl.dispose();
    _purchaseCostCtrl.dispose(); _fxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      final purchaseCostText = _purchaseCostCtrl.text.trim();
      await MachineService.instance.update(widget.machine.id, {
        'model':           _modelCtrl.text.trim(),
        'serial_no':       _serialCtrl.text.trim(),
        'hospital_id':     _hospitalId,
        'ward':            _wardCtrl.text.trim(),
        'warranty_expiry': _warrantyCtrl.text.trim(),
        'status':          _status,
        'purchase_cost': purchaseCostText.isEmpty ? null : int.tryParse(purchaseCostText),
        if (purchaseCostText.isNotEmpty) 'purchase_cost_currency': _currency,
        if (purchaseCostText.isNotEmpty && _currency != 'TZS')
          'purchase_cost_fx_rate': double.tryParse(_fxRateCtrl.text.trim()),
      });
      widget.onClose();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error  = _apiError(e);
        });
      }
    }
  }

  String _apiError(Object e) {
    final msg = e.toString();
    if (msg.contains('422')) return 'Validation failed —check all fields.';
    if (msg.contains('401') || msg.contains('403')) return 'Not authorised.';
    if (msg.contains('500')) return 'Server error —try again.';
    if (msg.contains('SocketException') || msg.contains('connection')) return 'No connection to server.';
    return 'Failed to save. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return _modalShell(
      context,
      onClose: widget.onClose,
      onSave: _save,
      saving: _saving,
      icon: Symbols.edit,
      title: 'Edit Machine — ${widget.machine.serialNo}',
      saveLabel: 'Save Changes',
      body: Column(children: [
        Row(children: [
          Expanded(flex: 2, child: _MField('Model', _modelCtrl, '')),
          const SizedBox(width: 14),
          Expanded(flex: 1, child: _MField('Serial no', _serialCtrl, '')),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AppSearchableSelectField<int>(
            label: 'Hospital',
            selectedLabel: _hospitalName,
            asyncSearch: (q) async {
              final results = await HospitalService.instance.search(q);
              return results.map((h) => AppSelectItem(value: h.id, label: h.name)).toList();
            },
            onSelected: (item) => setState(() {
              _hospitalId   = item?.value;
              _hospitalName = item?.label;
            }),
          )),
          const SizedBox(width: 14),
          Expanded(child: _MField('Ward', _wardCtrl, '')),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _MDrop(
            label: 'Status',
            value: _status,
            items: MachineStatus.values.map((s) => s.name).toList(),
            display: MachineStatus.values.map((s) => s.label).toList(),
            onChanged: (v) => setState(() => _status = v),
          )),
          const SizedBox(width: 14),
          Expanded(child: _MField('Warranty expiry', _warrantyCtrl, 'YYYY-MM-DD')),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _MField('Purchase cost', _purchaseCostCtrl, 'e.g. 25000000')),
          const SizedBox(width: 14),
          Expanded(child: _MDrop(
            label: 'Currency',
            value: _currency,
            items: const ['TZS', 'USD', 'EUR', 'GBP'],
            onChanged: (v) => setState(() => _currency = v),
          )),
        ]),
        if (_currency != 'TZS') ...[
          const SizedBox(height: 14),
          _MField('Exchange Rate (to TZS)', _fxRateCtrl, 'e.g. 2600'),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.error_outline, size: 14, color: AppColors.coral),
            const SizedBox(width: 6),
            Expanded(child: Text(_error!,
              style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 12))),
          ]),
        ],
      ]),
    );
  }
}

// ── Log Service Dialog ──────────────────────────────────────────────────────
class _LogServiceDialog extends StatefulWidget {
  const _LogServiceDialog({required this.machine, required this.onClose});
  final Machine machine;
  final VoidCallback onClose;
  @override
  State<_LogServiceDialog> createState() => _LogServiceDialogState();
}

class _LogServiceDialogState extends State<_LogServiceDialog> {
  String  _type   = 'PM';
  bool    _saving = false;
  String? _error;
  final _issueCtrl = TextEditingController();
  final _dateCtrl  = TextEditingController();

  List<StaffMember> _staff        = [];
  StaffMember?      _selectedTech;
  bool              _loadingStaff = true;
  int?              _hospitalId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Was: also fetch up to 500 hospitals to name-match a fallback for
      // when machine.hospitalId is null — that id is reliably populated by
      // the backend already, and the fallback list is now 13,000+ rows, so
      // fetching it just for a redundant `??` fallback isn't worth it.
      final staff = await StaffService.instance.list();
      if (mounted) {
        setState(() {
          _staff        = staff;
          _selectedTech = staff.isNotEmpty ? staff.first : null;
          _loadingStaff = false;
          _hospitalId   = widget.machine.hospitalId;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  @override
  void dispose() { _issueCtrl.dispose(); _dateCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await TicketService.instance.create({
        'machine_id':         widget.machine.id,
        'machine_name':       widget.machine.model,
        'machine_type':       widget.machine.type,
        'hospital_id':        _hospitalId,
        'ward':        widget.machine.ward,
        'type':        _type,
        'priority':    'medium',
        'status':      'resolved',
        'assigned_to': _selectedTech?.id,
        'description': _issueCtrl.text.trim(),
        if (_dateCtrl.text.trim().isNotEmpty)
          'next_service_date': _dateCtrl.text.trim(),
      });
      widget.onClose();
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; _error = _friendlyError(e); });
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('422')) return 'Validation failed —check all fields.';
    if (s.contains('500')) return 'Server error —try again.';
    if (s.contains('SocketException') || s.contains('connection')) return 'No connection to server.';
    return 'Failed to save. Please try again.';
  }

  @override
  Widget build(BuildContext context) => _modalShell(
    context,
    onClose: widget.onClose,
    onSave: _save,
    saving: _saving,
    icon: Symbols.build,
    title: 'Log Service — ${widget.machine.serialNo}',
    saveLabel: 'Log Service',
    body: Column(children: [
      Row(children: [
        Expanded(child: _MDrop(
          label: 'Service Type',
          value: _type,
          items: const ['PM', 'Corrective', 'Installation', 'Inspection', 'Calibration'],
          onChanged: (v) => setState(() => _type = v),
        )),
        const SizedBox(width: 14),
        Expanded(child: _loadingStaff
          ? _mLoadingField('Technician')
          : _MDrop(
              label: 'Technician',
              value: _selectedTech?.name ?? (_staff.isNotEmpty ? _staff.first.name : '—'),
              items: _staff.isNotEmpty ? _staff.map((s) => s.name).toList() : const ['—'],
              onChanged: _staff.isEmpty ? (_) {} : (v) => setState(() =>
                _selectedTech = _staff.firstWhere((s) => s.name == v)),
            )),
      ]),
      const SizedBox(height: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Issue / work done', style: AppTheme.fieldLabel),
        const SizedBox(height: 6),
        FieldFocusBox(height: 72, builder: (context, focusNode) => TextField(focusNode: focusNode, controller: _issueCtrl, maxLines: null, expands: true,
            style: AppTheme.fieldText,
            decoration: InputDecoration(hintText: 'Describe the work performed—',
                hintStyle: AppTheme.fieldText.copyWith(color: context.pal.textDim),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),),
      ]),
      const SizedBox(height: 14),
      _MField('Next service date', _dateCtrl, 'YYYY-MM-DD'),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.error_outline, size: 14, color: AppColors.coral),
          const SizedBox(width: 6),
          Expanded(child: Text(_error!,
            style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 12))),
        ]),
      ],
    ]),
  );
}

// ── Raise Ticket Dialog ─────────────────────────────────────────────────────
class _RaiseTicketDialog extends StatefulWidget {
  const _RaiseTicketDialog({required this.machine, required this.onClose});
  final Machine machine;
  final VoidCallback onClose;
  @override
  State<_RaiseTicketDialog> createState() => _RaiseTicketDialogState();
}

class _RaiseTicketDialogState extends State<_RaiseTicketDialog> {
  String  _priority = 'Medium';
  String  _type     = 'Corrective';
  bool    _saving   = false;
  String? _error;
  final _descCtrl = TextEditingController();

  List<StaffMember> _staff        = [];
  StaffMember?      _selectedTech;
  bool              _loadingStaff = true;
  int?              _hospitalId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Was: also fetch up to 500 hospitals to name-match a fallback for
      // when machine.hospitalId is null — that id is reliably populated by
      // the backend already, and the fallback list is now 13,000+ rows, so
      // fetching it just for a redundant `??` fallback isn't worth it.
      final staff = await StaffService.instance.list();
      if (mounted) {
        setState(() {
          _staff        = staff;
          _selectedTech = staff.isNotEmpty ? staff.first : null;
          _loadingStaff = false;
          _hospitalId   = widget.machine.hospitalId;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await TicketService.instance.create({
        'machine_id':         widget.machine.id,
        'machine_name':       widget.machine.model,
        'machine_type':       widget.machine.type,
        'hospital_id':        _hospitalId,
        'ward':        widget.machine.ward,
        'type':        _type,
        'priority':    _priority.toLowerCase(),
        'status':      'open',
        'assigned_to': _selectedTech?.id,
        'description': _descCtrl.text.trim(),
      });
      widget.onClose();
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; _error = _friendlyError(e); });
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('422')) return 'Validation failed —check all fields.';
    if (s.contains('500')) return 'Server error —try again.';
    if (s.contains('SocketException') || s.contains('connection')) return 'No connection to server.';
    return 'Failed to save. Please try again.';
  }

  @override
  Widget build(BuildContext context) => _modalShell(
    context,
    onClose: widget.onClose,
    onSave: _save,
    saving: _saving,
    icon: Symbols.confirmation_number,
    title: 'Raise Ticket — ${widget.machine.model}',
    saveLabel: 'Create Ticket',
    body: Column(children: [
      Row(children: [
        Expanded(child: _MDrop(
          label: 'Type',
          value: _type,
          items: const ['Corrective', 'PM', 'Inspection', 'Installation', 'Warranty Claim'],
          onChanged: (v) => setState(() => _type = v),
        )),
        const SizedBox(width: 14),
        Expanded(child: _MDrop(
          label: 'Priority',
          value: _priority,
          items: const ['Critical', 'High', 'Medium', 'Low'],
          onChanged: (v) => setState(() => _priority = v),
        )),
      ]),
      const SizedBox(height: 14),
      _loadingStaff
        ? _mLoadingField('Assign To')
        : _MDrop(
            label: 'Assign To',
            value: _selectedTech?.name ?? (_staff.isNotEmpty ? _staff.first.name : '—'),
            items: _staff.isNotEmpty ? _staff.map((s) => s.name).toList() : const ['—'],
            onChanged: _staff.isEmpty ? (_) {} : (v) => setState(() =>
              _selectedTech = _staff.firstWhere((s) => s.name == v)),
          ),
      const SizedBox(height: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Description', style: AppTheme.fieldLabel),
        const SizedBox(height: 6),
        FieldFocusBox(height: 80, builder: (context, focusNode) => TextField(focusNode: focusNode, controller: _descCtrl, maxLines: null, expands: true,
            style: AppTheme.fieldText,
            decoration: InputDecoration(hintText: 'Describe the fault or required work—',
                hintStyle: AppTheme.fieldText.copyWith(color: context.pal.textDim),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),),
      ]),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.error_outline, size: 14, color: AppColors.coral),
          const SizedBox(width: 6),
          Expanded(child: Text(_error!,
            style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 12))),
        ]),
      ],
    ]),
  );
}

// ── Edit Specifications Dialog ──────────────────────────────────────────────
class _EditSpecsDialog extends StatefulWidget {
  const _EditSpecsDialog({required this.machine, required this.onClose, this.onSaved});
  final Machine      machine;
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  @override
  State<_EditSpecsDialog> createState() => _EditSpecsDialogState();
}

class _EditSpecsDialogState extends State<_EditSpecsDialog> {
  late final List<_SpecEntry> _rows;
  bool    _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rows = widget.machine.specifications.entries
        .map((e) => _SpecEntry(e.key, e.value))
        .toList();
    if (_rows.isEmpty) _rows.add(_SpecEntry('', ''));
  }

  Future<void> _save() async {
    final specs = <String, String>{};
    for (final r in _rows) {
      final k = r.keyCtrl.text.trim();
      final v = r.valCtrl.text.trim();
      if (k.isNotEmpty) specs[k] = v;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await MachineService.instance.update(widget.machine.id, {
        'specifications': specs,
      });
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error  = e.toString().contains('422')
              ? 'Validation failed.'
              : 'Failed to save. Try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final r in _rows) { r.keyCtrl.dispose(); r.valCtrl.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _modalShell(
    context,
    onClose: widget.onClose,
    onSave:  _save,
    saving:  _saving,
    icon:    Symbols.tune,
    title:   'Machine Specifications',
    saveLabel: 'Save Specs',
    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('PARAMETER', style: AppTheme.labelCaps.copyWith(fontSize: 10))),
        const SizedBox(width: 10),
        Expanded(child: Text('VALUE', style: AppTheme.labelCaps.copyWith(fontSize: 10))),
        const SizedBox(width: 28),
      ]),
      const SizedBox(height: 6),
      ..._rows.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: _specField(e.value.keyCtrl, 'e.g. Throughput', context)),
          const SizedBox(width: 10),
          Expanded(child: _specField(e.value.valCtrl, 'e.g. 80 tests/hr', context)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _rows.removeAt(e.key)),
            child: Icon(Symbols.close, size: 16, color: context.pal.textDim),
          ),
        ]),
      )),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () => setState(() => _rows.add(_SpecEntry('', ''))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Symbols.add, size: 14, color: AppColors.teal),
          const SizedBox(width: 4),
          Text('Add row', style: AppTheme.bodySm.copyWith(color: AppColors.teal, fontSize: 12)),
        ]),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.error_outline, size: 14, color: AppColors.coral),
          const SizedBox(width: 6),
          Expanded(child: Text(_error!,
            style: AppTheme.bodySub.copyWith(color: AppColors.coral, fontSize: 12))),
        ]),
      ],
    ]),
  );

  Widget _specField(TextEditingController ctrl, String hint, BuildContext context) =>
    FieldFocusBox(builder: (context, focusNode) => TextField(focusNode: focusNode, controller: ctrl,
        style: AppTheme.fieldText,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.fieldText.copyWith(color: context.pal.textDim),
          border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
        ),
      ),);
}

class _SpecEntry {
  _SpecEntry(String key, String val)
      : keyCtrl = TextEditingController(text: key),
        valCtrl = TextEditingController(text: val);
  final TextEditingController keyCtrl;
  final TextEditingController valCtrl;
}

// ── Allocate Machine Dialog (Section 13) ────────────────────────────────────
// In Stock -> Allocated: reserves the machine for a hospital ahead of
// installation. Handover (Allocated -> Installed) happens automatically
// through the existing sign-off flow once an installation ticket resolves.
class _AllocateMachineDialog extends StatefulWidget {
  const _AllocateMachineDialog({required this.machine, required this.onClose, this.onSaved});
  final Machine machine;
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  @override
  State<_AllocateMachineDialog> createState() => _AllocateMachineDialogState();
}

class _AllocateMachineDialogState extends State<_AllocateMachineDialog> {
  final _reasonCtrl = TextEditingController();
  int? _hospitalId;
  String? _hospitalName;
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving || _hospitalId == null) {
      setState(() => _error = 'Select a hospital.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await MachineService.instance.allocate(widget.machine.id,
          hospitalId: _hospitalId!, reason: _reasonCtrl.text.trim());
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyError(e); });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    title: Row(children: [
      Icon(Symbols.local_shipping, size: 18, color: AppColors.teal),
      const SizedBox(width: 10),
      const Text('Allocate Machine'),
    ]),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${widget.machine.model} · ${widget.machine.serialNo}', style: AppTheme.bodySub),
      const SizedBox(height: 14),
      Text('HOSPITAL', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 6),
      AppSearchableSelectField<int>(
        hint: 'Search hospitals…',
        selectedLabel: _hospitalName,
        asyncSearch: (q) async {
          final results = await HospitalService.instance.search(q);
          return results.map((h) => AppSelectItem(value: h.id, label: h.name)).toList();
        },
        onSelected: (item) => setState(() { _hospitalId = item?.value; _hospitalName = item?.label; }),
      ),
      const SizedBox(height: 14),
      AppTextField(controller: _reasonCtrl, label: 'Reason (optional)', hintText: 'e.g. Sold via Quotation Q-100'),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12)),
      ],
    ])),
    actions: [
      TextButton(onPressed: widget.onClose, child: const Text('Cancel')),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Allocate'),
      ),
    ],
  );
}

// ── Service Costs tab content (Section 12) ──────────────────────────────────
class _ServiceCostsContent extends StatefulWidget {
  const _ServiceCostsContent({required this.machine});
  final Machine machine;
  @override
  State<_ServiceCostsContent> createState() => _ServiceCostsContentState();
}

class _ServiceCostsContentState extends State<_ServiceCostsContent> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await MachineService.instance.costs(widget.machine.id);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  String _tsh(num n) {
    if (n >= 1000000) return 'TSh ${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000)    return 'TSh ${(n / 1e3).toStringAsFixed(0)}K';
    return 'TSh $n';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    if (_error != null) return Padding(padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(_error!, style: TextStyle(color: AppColors.coral)));

    final d = _data!;
    final viability = d['viability'] as Map<String, dynamic>;
    final rows = (d['rows'] as List).cast<Map<String, dynamic>>();
    final hasPurchaseCost = viability['has_purchase_cost'] == true;
    final exceeds = viability['exceeds_threshold'] == true;
    final percent = (viability['percent_of_purchase_cost'] as num?)?.toDouble();
    final thresholdPercent = (viability['threshold_percent'] as num).toDouble();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Based on recorded costs only.', style: AppTheme.bodySub.copyWith(fontSize: 12, color: context.pal.textDim)),
      const SizedBox(height: 14),

      if (hasPurchaseCost) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: exceeds ? AppColors.coralSoft : context.pal.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: exceeds ? AppColors.coral.withValues(alpha: 0.4) : context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (exceeds)
              Row(children: [
                Icon(Symbols.warning, size: 16, color: AppColors.coral),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Service cost has exceeded ${(thresholdPercent * 100).toStringAsFixed(0)}% of the original purchase cost. Consider replacing this machine.',
                  style: AppTheme.bodySm.copyWith(color: AppColors.coral, fontWeight: FontWeight.w600))),
              ]),
            if (exceeds) const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percent == null ? 0 : percent.clamp(0, 1.5) / 1.5,
                minHeight: 8,
                backgroundColor: context.pal.surface1,
                color: exceeds ? AppColors.coral : AppColors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 20, runSpacing: 6, children: [
              Text('Spent: ${_tsh(viability['total_service_cost'] as num)}', style: AppTheme.bodySm),
              Text('Purchase cost: ${_tsh(viability['purchase_cost_tsh'] as num)}', style: AppTheme.bodySm),
              if (percent != null) Text('${(percent * 100).toStringAsFixed(0)}% of purchase cost', style: AppTheme.bodySm),
              Text('Threshold: ${(thresholdPercent * 100).toStringAsFixed(0)}%', style: AppTheme.bodySub.copyWith(fontSize: 12)),
            ]),
          ]),
        ),
      ] else ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(10)),
          child: const Text('Set the purchase cost to enable the replacement analysis. Edit Machine to add it.'),
        ),
      ],
      const SizedBox(height: 16),

      Wrap(spacing: 24, runSpacing: 10, children: [
        _StatBlock('Lifetime total', _tsh(d['grand_total'] as num)),
        _StatBlock('Last 12 months', _tsh(d['last_12_months_total'] as num)),
        _StatBlock('Services', '${d['service_count']}'),
        _StatBlock('Avg / service', _tsh(d['average_cost_per_service'] as num)),
      ]),
      const SizedBox(height: 20),

      Text('Expense History', style: AppTheme.cardTitle),
      const SizedBox(height: 10),
      if (rows.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No recorded service costs yet.', style: AppTheme.bodySub))
      else
        Column(children: rows.map((r) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider))),
          child: Row(children: [
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${r['ticket_number']}', style: AppTheme.bodySm),
              Text('${r['date'] ?? '—'} · ${r['ticket_type'] ?? '—'}', style: AppTheme.bodySub.copyWith(fontSize: 11)),
            ])),
            Expanded(flex: 2, child: Text(r['technician'] as String? ?? '—', style: AppTheme.bodySub)),
            Expanded(child: Text(_tsh(r['parts'] as num), style: AppTheme.bodySm)),
            Expanded(child: Text(_tsh(r['labor'] as num), style: AppTheme.bodySm)),
            Expanded(child: Text(_tsh(r['travel'] as num), style: AppTheme.bodySm)),
            Expanded(child: Text(_tsh(r['total'] as num), style: AppTheme.bodyStrong.copyWith(fontSize: 13))),
          ]),
        )).toList()),
    ]);
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 3),
    Text(value, style: AppTheme.cardTitle),
  ]);
}
