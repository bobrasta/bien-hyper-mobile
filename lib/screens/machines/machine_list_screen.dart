import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show hasMachineReceiveAuthority, userRoleNotifier;
import '../../models/location.dart';
import '../../models/machine.dart';
import '../../services/hospital_service.dart';
import '../../services/location_service.dart';
import '../../services/machine_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/responsive.dart';
import '../../utils/zones.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dropdown.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';
import '../../widgets/common/shimmer_box.dart';
import '../../widgets/common/status_badge.dart';
import 'machine_map_screen.dart';

import '../../theme/app_palette.dart';

class MachineListScreen extends StatefulWidget {
  const MachineListScreen({super.key, this.onMachineSelected, this.initialMapView = false});
  final ValueChanged<int>? onMachineSelected;
  // Lets a caller (e.g. the admin dashboard's "Open Map" link) land
  // straight on the map view instead of the default list.
  final bool initialMapView;

  @override
  State<MachineListScreen> createState() => _MachineListScreenState();
}

class _MachineListScreenState extends State<MachineListScreen> {
  MachineStatus? _statusFilter;
  String? _hospitalFilter;
  int? _hospitalId;
  String? _typeFilter;
  String? _modelFilter;
  String? _zoneFilter; // stores the display label; resolved to a key via _zoneKey
  final _search = TextEditingController();
  bool _showAdd = false;
  bool _showReceive = false;
  bool _mapView = false;
  // Section 12: server-computed, one aggregate query — not a per-row lookup.
  bool _replacementRecommended = false;

  List<Machine> _machines = [];
  List<String> _allTypes = [];
  List<String> _allModels = [];
  bool _loading = true;
  String? _loadError;
  int _showCount = 25;
  static const _pageSize = 25;

  String? get _zoneKey => zoneKeyForLabel(_zoneFilter);

  @override
  void initState() {
    super.initState();
    _mapView = widget.initialMapView;
    // Stale-while-revalidate: a fresh instance of this screen (every time
    // it's navigated to — this widget isn't kept alive across navigation)
    // used to blank to a shimmer every single time even though the
    // underlying HTTP call was often already cache-fast. Showing the last
    // default-view list immediately, then quietly refreshing, fixes the
    // "go back to the list → blanks again" symptom directly — see
    // MachineService.cachedDefaultList's own doc comment for the full
    // reasoning and why it's scoped to the unfiltered view only.
    final cached = MachineService.cachedDefaultList;
    if (cached != null) {
      _machines = cached;
      _allTypes = cached.map((m) => m.type).toSet().toList()..sort();
      _allModels = cached.map((m) => m.model).toSet().toList()..sort();
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      // Only show the blank/shimmer state when there's genuinely nothing
      // to show yet — a background refresh of an already-populated list
      // (or a return visit seeded from the cache above) updates silently.
      if (_machines.isEmpty) _loading = true;
      _loadError = null;
    });
    try {
      // Status filter is sent to the API; hospital + type stay client-side
      // (hospital needs ID lookup; type may not be a supported API param)
      final statusStr = _statusFilter == null
          ? null
          : switch (_statusFilter!) {
              MachineStatus.pendingInstallation => 'pending_installation',
              MachineStatus.pendingSignoff => 'pending_signoff',
              MachineStatus.operational => 'operational',
              MachineStatus.needsService => 'needs_service',
              MachineStatus.down => 'down',
              MachineStatus.warranty => 'warranty',
              MachineStatus.idle => 'idle',
            };
      final data = await MachineService.instance.list(
        status: statusStr,
        hospitalId: _hospitalId,
        type: _typeFilter,
        model: _modelFilter,
        zone: _zoneKey,
        replacementRecommended: _replacementRecommended ? true : null,
      );
      if (mounted) {
        setState(() {
          _machines = data;
          // Cache all equipment types + models from the first unfiltered fetch
          if (_statusFilter == null && _hospitalId == null &&
              _typeFilter == null && _modelFilter == null && _zoneFilter == null) {
            _allTypes = data.map((m) => m.type).toSet().toList()..sort();
            _allModels = data.map((m) => m.model).toSet().toList()..sort();
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  void _setStatusFilter(MachineStatus? s) {
    setState(() {
      _statusFilter = s;
      _hospitalFilter = null;
      _hospitalId = null;
      _typeFilter = null;
      _modelFilter = null;
      _zoneFilter = null;
      _showCount = _pageSize;
    });
    _load();
  }

  void _setTypeFilter(String? type) {
    setState(() {
      _typeFilter = type;
      _showCount = _pageSize;
    });
    _load();
  }

  void _setModelFilter(String? model) {
    setState(() {
      _modelFilter = model;
      _showCount = _pageSize;
    });
    _load();
  }

  void _setZoneFilter(String? label) {
    setState(() {
      _zoneFilter = label;
      _showCount = _pageSize;
    });
    _load();
  }

  void _toggleReplacementRecommended() {
    setState(() {
      _replacementRecommended = !_replacementRecommended;
      _showCount = _pageSize;
    });
    _load();
  }

  int _count(MachineStatus? s) => s == null
      ? _machines.length
      : _machines.where((m) => m.status == s).length;

  List<String> get _types => _allTypes.isNotEmpty
      ? _allTypes
      : _machines.map((m) => m.type).toSet().toList()..sort();

  List<String> get _models => _allModels.isNotEmpty
      ? _allModels
      : _machines.map((m) => m.model).toSet().toList()..sort();

  Future<void> _pickFilter(
    BuildContext context,
    String title,
    List<String> options,
    String? current,
    ValueChanged<String?> onPick,
  ) async {
    final picked = await showDialog<String?>(
      context: context,
      builder: (_) =>
          _PickerDialog(title: title, options: options, current: current),
    );
    if (picked != null) onPick(picked.isEmpty ? null : picked);
  }

  // Section 4 (hypermed_claude_code_prompt.md): the hospital directory is
  // modeled to grow into the thousands, so its filter can't reuse
  // _pickFilter/_PickerDialog's plain-list-of-all-options pattern — that's
  // exactly the "overflows the page by thousands of pixels" bug the spec
  // flags. This uses the server-side searchable combobox instead.
  Future<void> _pickHospitalFilterSearchable(BuildContext context) async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (_) => _HospitalFilterPickerDialog(currentName: _hospitalFilter),
    );
    if (result is _ClearHospitalFilter) {
      setState(() { _hospitalFilter = null; _hospitalId = null; _showCount = _pageSize; });
      _load();
    } else if (result is AppSelectItem<int>) {
      setState(() { _hospitalFilter = result.label; _hospitalId = result.value; _showCount = _pageSize; });
      _load();
    }
  }

  List<Machine> get _filtered {
    var list = _machines;
    if (_statusFilter != null) {
      list = list.where((m) => m.status == _statusFilter).toList();
    }
    if (_hospitalFilter != null) {
      list = list.where((m) => m.hospital == _hospitalFilter).toList();
    }
    if (_typeFilter != null) {
      list = list.where((m) => m.type == _typeFilter).toList();
    }
    if (_modelFilter != null) {
      list = list.where((m) => m.model == _modelFilter).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (m) =>
                m.serialNo.toLowerCase().contains(q) ||
                m.model.toLowerCase().contains(q) ||
                m.hospital.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // Map view — full-bleed, no table layout needed
    if (_mapView) {
      return Stack(
        children: [
          MachineMapScreen(
            onApplyZones: (zones) {
              setState(() {
                _mapView = false;
                _zoneFilter = zones.length == 1 ? zoneLabelFor(zones.first) : null;
                _showCount = _pageSize;
              });
              _load();
            },
          ),
          // Persistent "List view" toggle in top-left
          Positioned(
            top: 8,
            left: 12,
            child: GestureDetector(
              onTap: () => setState(() => _mapView = false),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: context.pal.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.pal.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 5),
                    Text(
                      'List view',
                      style: AppTheme.bodySm.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final allFiltered = _filtered;
    final machines = allFiltered.take(_showCount).toList();
    final remaining = allFiltered.length - machines.length;

    return Stack(
      children: [
        LayoutBuilder(
          builder: (ctx, cst) {
            final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
            return RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(pad, pad, pad, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page header
                    LayoutBuilder(
                      builder: (ctx2, cst2) {
                        final narrow = cst2.maxWidth < 560;
                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Crumb(),
                            const SizedBox(height: 4),
                            Text('Machine Registry', style: AppTheme.pageTitle),
                            const SizedBox(height: 4),
                            Text(
                              '${_machines.length} machines · Showing ${machines.length}',
                              style: AppTheme.bodySub,
                            ),
                          ],
                        );
                        final actions = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // List / Map view toggle
                            Container(
                              height: 32,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: context.pal.surface2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.pal.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ViewToggleBtn(
                                    icon: Symbols.list,
                                    label: 'List',
                                    active: !_mapView,
                                    onTap: () =>
                                        setState(() => _mapView = false),
                                  ),
                                  _ViewToggleBtn(
                                    icon: Symbols.map,
                                    label: 'Map',
                                    active: _mapView,
                                    onTap: () =>
                                        setState(() => _mapView = true),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (hasMachineReceiveAuthority(userRoleNotifier.value)) ...[
                              AppButton(
                                label: 'Receive Machine',
                                icon: Symbols.inventory_2,
                                variant: BtnVariant.ghost,
                                onPressed: () => setState(() => _showReceive = true),
                              ),
                              const SizedBox(width: 10),
                            ],
                            AppButton(
                              label: 'Import CSV',
                              icon: Symbols.upload_file,
                              variant: BtnVariant.ghost,
                            ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: 'Export',
                              icon: Symbols.download,
                              variant: BtnVariant.ghost,
                            ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: 'Scan QR',
                              icon: Symbols.qr_code_scanner,
                            ),
                          ],
                        );
                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleBlock,
                              const SizedBox(height: 12),
                              actions,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [titleBlock, const Spacer(), actions],
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Summary chips — 5 cols wide, 3 medium, 2 narrow (matches dashboard KPI grid)
                    AdaptiveColumns(
                      wideCols: 5,
                      mediumCols: 3,
                      narrowCols: 2,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          label: 'All Machines',
                          value: '${_count(null)}',
                          active: _statusFilter == null,
                          onTap: () => _setStatusFilter(null),
                        ),
                        _StatusChip(
                          label: 'Operational',
                          value: '${_count(MachineStatus.operational)}',
                          cls: 'op',
                          active: _statusFilter == MachineStatus.operational,
                          onTap: () => _setStatusFilter(
                            _statusFilter == MachineStatus.operational
                                ? null
                                : MachineStatus.operational,
                          ),
                        ),
                        _StatusChip(
                          label: 'Service',
                          value: '${_count(MachineStatus.needsService)}',
                          cls: 'svc',
                          active: _statusFilter == MachineStatus.needsService,
                          onTap: () => _setStatusFilter(
                            _statusFilter == MachineStatus.needsService
                                ? null
                                : MachineStatus.needsService,
                          ),
                        ),
                        _StatusChip(
                          label: 'Down',
                          value: '${_count(MachineStatus.down)}',
                          cls: 'down',
                          active: _statusFilter == MachineStatus.down,
                          onTap: () => _setStatusFilter(
                            _statusFilter == MachineStatus.down
                                ? null
                                : MachineStatus.down,
                          ),
                        ),
                        _StatusChip(
                          label: 'Warranty',
                          value: '${_count(MachineStatus.warranty)}',
                          cls: 'claim',
                          active: _statusFilter == MachineStatus.warranty,
                          onTap: () => _setStatusFilter(
                            _statusFilter == MachineStatus.warranty
                                ? null
                                : MachineStatus.warranty,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Filter bar
                    LayoutBuilder(
                      builder: (ctx3, cst3) {
                        final narrow = cst3.maxWidth < 600;
                        final searchBox = SearchField(
                          hint: 'Search by serial, model or hospital…',
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                        );
                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              searchBox,
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _FilterChip(
                                    icon: Symbols.local_hospital,
                                    label: 'Hospital',
                                    value: _hospitalFilter ?? 'All',
                                    active: _hospitalFilter != null,
                                    onTap: () => _pickHospitalFilterSearchable(context),
                                  ),
                                  _FilterChip(
                                    icon: Symbols.category,
                                    label: 'Type',
                                    value: _typeFilter ?? 'All',
                                    active: _typeFilter != null,
                                    onTap: () => _pickFilter(
                                      context,
                                      'Type',
                                      _types,
                                      _typeFilter,
                                      _setTypeFilter,
                                    ),
                                  ),
                                  _FilterChip(
                                    icon: Symbols.medical_services,
                                    label: 'Machine',
                                    value: _modelFilter ?? 'All',
                                    active: _modelFilter != null,
                                    onTap: () => _pickFilter(
                                      context,
                                      'Machine',
                                      _models,
                                      _modelFilter,
                                      _setModelFilter,
                                    ),
                                  ),
                                  _FilterChip(
                                    icon: Symbols.public,
                                    label: 'Zone',
                                    value: _zoneFilter ?? 'All',
                                    active: _zoneFilter != null,
                                    onTap: () => _pickFilter(
                                      context,
                                      'Zone',
                                      zoneLabels.values.toList(),
                                      _zoneFilter,
                                      _setZoneFilter,
                                    ),
                                  ),
                                  _ToggleChip(
                                    icon: Symbols.warning,
                                    label: 'Needs replacement review',
                                    active: _replacementRecommended,
                                    onTap: _toggleReplacementRecommended,
                                  ),
                                  AppButton(
                                    label: 'More filters',
                                    icon: Symbols.tune,
                                    variant: BtnVariant.ghost,
                                    small: true,
                                  ),
                                  AppButton(
                                    label: 'Columns',
                                    icon: Symbols.view_column,
                                    variant: BtnVariant.ghost,
                                    small: true,
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            SizedBox(width: 320, child: searchBox),
                            const SizedBox(width: 10),
                            _FilterChip(
                              icon: Symbols.local_hospital,
                              label: 'Hospital',
                              value: _hospitalFilter ?? 'All',
                              active: _hospitalFilter != null,
                              onTap: () => _pickHospitalFilterSearchable(context),
                            ),
                            const SizedBox(width: 10),
                            _FilterChip(
                              icon: Symbols.category,
                              label: 'Type',
                              value: _typeFilter ?? 'All',
                              active: _typeFilter != null,
                              onTap: () => _pickFilter(
                                context,
                                'Type',
                                _types,
                                _typeFilter,
                                (v) => setState(() {
                                  _typeFilter = v;
                                  _showCount = _pageSize;
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _ToggleChip(
                              icon: Symbols.warning,
                              label: 'Needs replacement review',
                              active: _replacementRecommended,
                              onTap: _toggleReplacementRecommended,
                            ),
                            const SizedBox(width: 10),
                            const Spacer(),
                            AppButton(
                              label: 'More filters',
                              icon: Symbols.tune,
                              variant: BtnVariant.ghost,
                              small: true,
                            ),
                            const SizedBox(width: 6),
                            AppButton(
                              label: 'Columns',
                              icon: Symbols.view_column,
                              variant: BtnVariant.ghost,
                              small: true,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Table — horizontally scrollable below 900px
                    HScrollTable(
                      minWidth: 900,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.pal.surface1,
                          borderRadius: BorderRadius.circular(AppColors.rLg),
                          border: Border.all(color: context.pal.border),
                        ),
                        child: Column(
                          children: [
                            // Table header
                            _TableHeader(),
                            // Rows — loading / error / data
                            if (_loading)
                              shimmerTable(count: 10, cols: 5)
                            // A background refresh failing while stale-but-
                            // valid cached data is already showing shouldn't
                            // blow away that data with an error screen —
                            // only surface the error when there's nothing
                            // else to show.
                            else if (_loadError != null && _machines.isEmpty)
                              ErrorView(
                                message: _loadError!,
                                onRetry: _load,
                                compact: true,
                              )
                            else if (machines.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 48,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Symbols.medical_services,
                                        size: 36,
                                        color: context.pal.textDim,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _machines.isEmpty
                                            ? 'No machines registered'
                                            : 'No machines match the current filter',
                                        style: AppTheme.bodySub,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...machines.map(
                                (m) => _MachineRow(
                                  machine: m,
                                  onTap: () =>
                                      widget.onMachineSelected?.call(m.id),
                                ),
                              ),
                            // Load more
                            if (remaining > 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _showCount += _pageSize),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: context.pal.border,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Load $remaining more',
                                        style: AppTheme.bodySm.copyWith(
                                          color: AppColors.teal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else if (!_loading && machines.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: Text(
                                    'Showing all ${machines.length} machines',
                                    style: AppTheme.bodySub.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ); // SingleChildScrollView + RefreshIndicator
          },
        ), // LayoutBuilder
        // FAB
        Positioned(
          right: 28,
          bottom: 28,
          child: GestureDetector(
            onTap: () => setState(() => _showAdd = true),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.60),
                    spreadRadius: -1,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Symbols.add, size: 20, color: Color(0xFF06120F)),
                  const SizedBox(width: 8),
                  Text(
                    'Add Machine',
                    style: AppTheme.bodyStrong.copyWith(
                      color: const Color(0xFF06120F),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Add Machine dialog
        if (_showAdd)
          _AddMachineDialog(
            existingModels: _allModels,
            onClose: () => setState(() => _showAdd = false),
            onSaved: () {
              setState(() => _showAdd = false);
              _load();
            },
          ),

        // Receive Machine dialog (Section 13)
        if (_showReceive)
          _ReceiveMachineDialog(
            existingModels: _allModels,
            onClose: () => setState(() => _showReceive = false),
            onSaved: () {
              setState(() => _showReceive = false);
              _load();
            },
          ),
      ],
    );
  }
}

// ── View toggle button (List / Map) ──────────────────────────────────────────

class _ViewToggleBtn extends StatelessWidget {
  const _ViewToggleBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: active
            ? Border.all(color: AppColors.teal.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: active ? AppColors.teal : context.pal.textMute,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: active ? AppColors.teal : context.pal.textMute,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Crumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: 6),
      Text('Workspace', style: AppTheme.monoXs),
      const SizedBox(width: 6),
      const SizedBox(width: 6),
      Text(
        'Machines',
        style: AppTheme.monoXs.copyWith(color: context.pal.text),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    this.cls,
    required this.active,
    required this.onTap,
  });
  final String label, value;
  final String? cls;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? context.pal.surface2 : context.pal.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? context.pal.borderStrong : context.pal.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppTheme.labelCaps),
                const SizedBox(height: 4),
                Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 22)),
              ],
            ),
            if (cls != null)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _dotColor(cls!),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _dotColor(String cls) => switch (cls) {
    'op' => AppColors.teal,
    'svc' => AppColors.amber,
    'down' => AppColors.coral,
    'claim' => AppColors.blue,
    _ => AppColors.textMute,
  };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.value,
    this.active = false,
    this.onTap,
  });
  final IconData icon;
  final String label, value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.tealSoft : context.pal.surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.teal : context.pal.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppColors.teal : context.pal.textMute,
            ),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: AppTheme.bodySm.copyWith(
                color: active ? context.pal.text : context.pal.textMute,
                fontSize: 12.5,
              ),
            ),
            Text(
              value,
              style: AppTheme.bodySm.copyWith(
                color: context.pal.text,
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active ? Symbols.close : Symbols.expand_more,
              size: 14,
              color: context.pal.textDim,
            ),
          ],
        ),
      ),
    );
  }
}

// Section 12: a plain on/off filter (not a pick-a-value one), so it skips
// _FilterChip's "Label: value" + expand/close affordance.
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.coralSoft : context.pal.surface1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppColors.coral : context.pal.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: active ? AppColors.coral : context.pal.textMute),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.bodySm.copyWith(
            color: active ? AppColors.coral : context.pal.textMute, fontSize: 12.5)),
        ],
      ),
    ),
  );
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.pal.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          SizedBox(
            width: 32,
            child: Checkbox(
              value: false,
              onChanged: (_) {},
              fillColor: WidgetStateProperty.all(Colors.transparent),
              side: BorderSide(color: context.pal.textDim),
            ),
          ),
          _Th('Serial No', flex: 1),
          _Th('Machine / Model', flex: 2),
          _Th('Hospital · Ward', flex: 2),
          _Th('Installed', flex: 1),
          _Th('Warranty', flex: 1),
          _Th('Status', flex: 1),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex});
  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.monoXs.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.10,
        ),
      ),
    ),
  );
}

class _MachineRow extends StatelessWidget {
  const _MachineRow({required this.machine, this.onTap});
  final Machine machine;
  final VoidCallback? onTap;

  IconData _icon(String type) {
    if (type.contains('Hematology')) return Symbols.biotech;
    if (type.contains('Ultrasound')) return Symbols.monitor_heart;
    if (type.contains('X-Ray')) return Symbols.radiology;
    if (type.contains('Ventilator')) return Symbols.air;
    if (type.contains('ECG')) return Symbols.monitoring;
    if (type.contains('Autoclave')) return Symbols.thermostat;
    if (type.contains('Monitor')) return Symbols.vital_signs;
    if (type.contains('Defibrillator')) return Symbols.bolt;
    return Symbols.precision_manufacturing;
  }

  int _warrantyDaysLeft(String dateStr) {
    try {
      final d = _parseDate(dateStr);
      final today = DateTime(2025, 6, 23);
      return d.difference(today).inDays;
    } catch (_) {
      return 0;
    }
  }

  DateTime _parseDate(String s) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final parts = s.split(' ');
    final day = int.parse(parts[0]);
    final mon = months.indexOf(parts[1]) + 1;
    final yr = int.parse(parts[2]);
    return DateTime(yr, mon, day);
  }

  @override
  Widget build(BuildContext context) {
    final days = _warrantyDaysLeft(machine.warrantyExpiry);
    final warrantyColor = days < 0
        ? AppColors.coral
        : days < 90
        ? AppColors.amber
        : context.pal.text;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(bottom: BorderSide(color: context.pal.divider)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            SizedBox(
              width: 32,
              child: Checkbox(
                value: false,
                onChanged: (_) {},
                fillColor: WidgetStateProperty.all(Colors.transparent),
                side: BorderSide(color: context.pal.textDim),
              ),
            ),
            // Serial
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Text(
                  machine.serialNo,
                  style: AppTheme.monoXs.copyWith(color: context.pal.textMute),
                ),
              ),
            ),
            // Model
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.pal.surface3,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        _icon(machine.type),
                        size: 18,
                        color: context.pal.textMute,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            machine.model,
                            style: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
                          ),
                          Text(
                            machine.type,
                            style: AppTheme.bodySub.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Hospital
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.hospital == '—' && machine.storeLocationName != null
                          ? machine.storeLocationName!
                          : machine.hospital,
                      style: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
                    ),
                    Text(
                      machine.isInStock ? 'Store location' : machine.ward,
                      style: AppTheme.bodySub.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
            // Install date
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Text(
                  machine.installDate,
                  style: AppTheme.monoXs.copyWith(color: context.pal.textMute),
                ),
              ),
            ),
            // Warranty
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.warrantyExpiry,
                      style: AppTheme.monoSm.copyWith(color: warrantyColor),
                    ),
                    Text(
                      days < 0 ? 'Expired ${-days}d ago' : '${days}d left',
                      style: AppTheme.bodySub.copyWith(
                        fontSize: 10.5,
                        color: context.pal.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Status
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge.machine(machine.status),
                    // Section 13: lifecycle_stage is a separate axis from
                    // status — only shown when it isn't the default Installed.
                    if (machine.lifecycleStage == 'in_stock' || machine.lifecycleStage == 'allocated') ...[
                      const SizedBox(height: 4),
                      Text(
                        machine.lifecycleStage == 'in_stock' ? 'In Stock' : 'Allocated',
                        style: AppTheme.bodySub.copyWith(
                          fontSize: 10.5,
                          color: machine.lifecycleStage == 'in_stock' ? context.pal.textDim : AppColors.amber,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: 80,
              child: Row(
                children: [
                  Icon(
                    Symbols.visibility,
                    size: 16,
                    color: context.pal.textDim,
                  ),
                  const SizedBox(width: 6),
                  Icon(Symbols.edit, size: 16, color: context.pal.textDim),
                  const SizedBox(width: 6),
                  Icon(
                    Symbols.more_horiz,
                    size: 16,
                    color: context.pal.textDim,
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // Container
    ); // GestureDetector
  }
}

// ── Add Machine Dialog ─────────────────────────────────────────────────────────

class _AddMachineDialog extends StatefulWidget {
  const _AddMachineDialog({required this.onClose, this.onSaved, this.existingModels = const []});
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  /// Known models, already loaded by the parent screen — backs the model
  /// combobox's client-side search + normalization + "Create new" offer.
  final List<String> existingModels;

  @override
  State<_AddMachineDialog> createState() => _AddMachineDialogState();
}

class _AddMachineDialogState extends State<_AddMachineDialog> {
  final _serialCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  String? _model;
  String _type = 'Hematology Analyzer';
  String _status = 'Operational';
  bool _saving = false;
  String? _error;

  int? _selectedHospitalId;
  String? _selectedHospitalName;

  static const _statusApiValue = {
    'Operational': 'operational',
    'Needs Service': 'needs_service',
    'Down': 'down',
    'Warranty Claim': 'warranty',
  };

  @override
  void dispose() {
    _serialCtrl.dispose();
    _wardCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if ((_model ?? '').trim().isEmpty || _serialCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Model name and serial number are required.');
      return;
    }
    if (_selectedHospitalId == null) {
      setState(() => _error = 'Please select a hospital.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MachineService.instance.create({
        'model': _model!.trim(),
        'serial_no': _serialCtrl.text.trim(),
        'type': _type,
        'hospital_id': _selectedHospitalId,
        'ward': _wardCtrl.text.trim(),
        'status': _statusApiValue[_status] ?? 'operational',
        'install_date': DateTime.now().toIso8601String().substring(0, 10),
        'warranty_expiry': DateTime.now()
            .add(const Duration(days: 365 * 2))
            .toIso8601String()
            .substring(0, 10),
        'revenue_per_month': 0,
      });
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _apiError(e);
        });
      }
    }
  }

  String _apiError(Object e) {
    final msg = e.toString();
    if (msg.contains('422')) return 'Validation failed — check all fields.';
    if (msg.contains('401') || msg.contains('403')) return 'Not authorised.';
    if (msg.contains('500')) return 'Server error — try again.';
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'No connection to server.';
    }
    return 'Failed to save. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: const Color(0xAA06070A),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 540, maxHeight: maxH),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: context.pal.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.pal.borderStrong),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x70000000),
                      blurRadius: 60,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.precision_manufacturing,
                            size: 18,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 10),
                          Text('Add New Machine', style: AppTheme.bodyStrong),
                          const Spacer(),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Icon(
                              Symbols.close,
                              size: 18,
                              color: context.pal.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form — scrollable
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppSearchableSelectField<String>(
                                    label: 'Model / Name',
                                    hint: 'e.g. Mindray BC-6800 Plus',
                                    selectedLabel: _model,
                                    items: widget.existingModels
                                        .map((m) => AppSelectItem(value: m, label: m))
                                        .toList(),
                                    onSelected: (item) => setState(() => _model = item?.value),
                                    onTextChanged: (text) => _model = text,
                                    createNewLabel: (q) => 'Use "$q" as a new model',
                                    onCreateNew: (text) => setState(() => _model = text),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _DField(
                                    'Serial Number',
                                    _serialCtrl,
                                    'e.g. BC68-0001',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _DDropdown(
                                    label: 'Equipment Type',
                                    value: _type,
                                    items: const [
                                      'Hematology Analyzer',
                                      'Ultrasound Unit',
                                      'X-Ray Machine',
                                      'Ventilator',
                                      'ECG Machine',
                                      'Autoclave',
                                      'Patient Monitor',
                                      'Defibrillator',
                                    ],
                                    onChanged: (v) => setState(() => _type = v),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _DDropdown(
                                    label: 'Status',
                                    value: _status,
                                    items: const [
                                      'Operational',
                                      'Needs Service',
                                      'Down',
                                      'Warranty Claim',
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _status = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            AppSearchableSelectField<int>(
                              label: 'Hospital',
                              hint: 'Search hospitals…',
                              selectedLabel: _selectedHospitalName,
                              asyncSearch: (q) async {
                                final results = await HospitalService.instance.search(q);
                                return results.map((h) => AppSelectItem(value: h.id, label: h.name)).toList();
                              },
                              onSelected: (item) => setState(() {
                                _selectedHospitalId = item?.value;
                                _selectedHospitalName = item?.label;
                              }),
                            ),
                            const SizedBox(height: 14),
                            _DField(
                              'Ward / Location',
                              _wardCtrl,
                              'e.g. ICU · Ward 2',
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 14,
                                    color: AppColors.coral,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: AppTheme.bodySub.copyWith(
                                        color: AppColors.coral,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onClose,
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  border: Border.all(color: context.pal.border),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('Cancel', style: AppTheme.bodySm),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _save,
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.teal,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Save Machine',
                                          style: AppTheme.bodyStrong.copyWith(
                                            color: const Color(0xFF06120F),
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ), // Column
              ), // Container (dialog box)
            ), // Material
          ), // ConstrainedBox
        ), // inner GestureDetector
      ), // outer Container (backdrop)
    ); // outer GestureDetector
  } // build
} // _AddMachineDialogState

// ── Receive Machine Dialog (Section 13) ─────────────────────────────────────
// New stock, no hospital yet — arrives In Stock at a store location. Separate
// from _AddMachineDialog, which registers a machine straight to Installed at
// a hospital (Section 13's "admin fallback registration" path).
class _ReceiveMachineDialog extends StatefulWidget {
  const _ReceiveMachineDialog({required this.onClose, this.onSaved, this.existingModels = const []});
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  final List<String> existingModels;

  @override
  State<_ReceiveMachineDialog> createState() => _ReceiveMachineDialogState();
}

class _ReceiveMachineDialogState extends State<_ReceiveMachineDialog> {
  final _serialCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _arrivalCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController();
  final _purchaseCostCtrl = TextEditingController();
  final _fxRateCtrl = TextEditingController();
  String? _model;
  String _type = 'Hematology Analyzer';
  String _currency = 'TZS';
  bool _saving = false;
  String? _error;

  List<Location> _locations = [];
  int? _selectedLocationId;
  bool _loadingLocations = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final list = await LocationService.instance.list();
      if (mounted) {
        setState(() {
          _locations = list;
          _selectedLocationId = list.isNotEmpty ? list.first.id : null;
          _loadingLocations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  @override
  void dispose() {
    _serialCtrl.dispose();
    _manufacturerCtrl.dispose();
    _conditionCtrl.dispose();
    _arrivalCtrl.dispose();
    _warrantyCtrl.dispose();
    _purchaseCostCtrl.dispose();
    _fxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if ((_model ?? '').trim().isEmpty || _serialCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Model name and serial number are required.');
      return;
    }
    if (_selectedLocationId == null) {
      setState(() => _error = 'Please select a store location.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final purchaseCostText = _purchaseCostCtrl.text.trim();
      await MachineService.instance.receive({
        'model': _model!.trim(),
        'serial_no': _serialCtrl.text.trim(),
        'type': _type,
        'manufacturer': _manufacturerCtrl.text.trim().isEmpty ? null : _manufacturerCtrl.text.trim(),
        'condition': _conditionCtrl.text.trim().isEmpty ? null : _conditionCtrl.text.trim(),
        'store_location_id': _selectedLocationId,
        'arrival_date': _arrivalCtrl.text.trim().isEmpty ? null : _arrivalCtrl.text.trim(),
        'warranty_expiry': _warrantyCtrl.text.trim().isEmpty ? null : _warrantyCtrl.text.trim(),
        'purchase_cost': purchaseCostText.isEmpty ? null : int.tryParse(purchaseCostText),
        if (purchaseCostText.isNotEmpty) 'purchase_cost_currency': _currency,
        if (purchaseCostText.isNotEmpty && _currency != 'TZS')
          'purchase_cost_fx_rate': double.tryParse(_fxRateCtrl.text.trim()),
      });
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; _error = _apiError(e); });
      }
    }
  }

  String _apiError(Object e) {
    final msg = e.toString();
    if (msg.contains('422')) return 'Validation failed — check all fields.';
    if (msg.contains('401') || msg.contains('403')) return 'Not authorised.';
    if (msg.contains('500')) return 'Server error — try again.';
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'No connection to server.';
    }
    return 'Failed to save. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: const Color(0xAA06070A),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 540, maxHeight: maxH),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: context.pal.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.pal.borderStrong),
                  boxShadow: const [
                    BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(Symbols.inventory_2, size: 18, color: AppColors.teal),
                        const SizedBox(width: 10),
                        Text('Receive Machine', style: AppTheme.bodyStrong),
                        const Spacer(),
                        GestureDetector(onTap: widget.onClose,
                            child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
                      ]),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(
                                child: AppSearchableSelectField<String>(
                                  label: 'Model / Name',
                                  hint: 'e.g. Mindray BC-6800 Plus',
                                  selectedLabel: _model,
                                  items: widget.existingModels.map((m) => AppSelectItem(value: m, label: m)).toList(),
                                  onSelected: (item) => setState(() => _model = item?.value),
                                  onTextChanged: (text) => _model = text,
                                  createNewLabel: (q) => 'Use "$q" as a new model',
                                  onCreateNew: (text) => setState(() => _model = text),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: _DField('Serial number', _serialCtrl, 'e.g. BC68-0001')),
                            ]),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(
                                child: _DDropdown(
                                  label: 'Equipment Type',
                                  value: _type,
                                  items: const [
                                    'Hematology Analyzer', 'Ultrasound Unit', 'X-Ray Machine',
                                    'Ventilator', 'ECG Machine', 'Autoclave', 'Patient Monitor', 'Defibrillator',
                                  ],
                                  onChanged: (v) => setState(() => _type = v),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: _DField('Manufacturer', _manufacturerCtrl, 'e.g. GE Healthcare')),
                            ]),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(
                                child: _loadingLocations
                                  ? _dLoadingField('Store Location')
                                  : _locations.isEmpty
                                    ? _dLoadingField('Store Location (none found)')
                                    : _DDropdown(
                                        label: 'Store Location',
                                        value: _locations.firstWhere(
                                          (l) => l.id == _selectedLocationId,
                                          orElse: () => _locations.first,
                                        ).name,
                                        items: _locations.map((l) => l.name).toList(),
                                        onChanged: (v) => setState(() =>
                                          _selectedLocationId = _locations.firstWhere((l) => l.name == v).id),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: _DField('Condition', _conditionCtrl, 'e.g. New, Refurbished')),
                            ]),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: _DField('Arrival date', _arrivalCtrl, 'YYYY-MM-DD')),
                              const SizedBox(width: 14),
                              Expanded(child: _DField('Warranty expiry', _warrantyCtrl, 'YYYY-MM-DD')),
                            ]),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: _DField('Purchase cost', _purchaseCostCtrl, 'e.g. 25000000')),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _DDropdown(
                                  label: 'Currency',
                                  value: _currency,
                                  items: const ['TZS', 'USD', 'EUR', 'GBP'],
                                  onChanged: (v) => setState(() => _currency = v),
                                ),
                              ),
                            ]),
                            if (_currency != 'TZS') ...[
                              const SizedBox(height: 14),
                              _DField('Exchange Rate (to TZS)', _fxRateCtrl, 'e.g. 2600'),
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
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(children: [
                        Expanded(child: GestureDetector(
                          onTap: widget.onClose,
                          child: Container(height: 38,
                            decoration: BoxDecoration(border: Border.all(color: context.pal.border),
                                borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text('Cancel', style: AppTheme.bodySm))),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: GestureDetector(
                          onTap: _save,
                          child: Container(height: 38,
                            decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: _saving
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text('Receive Machine', style: AppTheme.bodyStrong.copyWith(
                                    color: const Color(0xFF06120F), fontSize: 13)))),
                        )),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _dLoadingField(String label) => Builder(builder: (context) => Column(
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

class _DField extends StatelessWidget {
  const _DField(this.label, this.ctrl, this.hint);
  final String label, hint;
  final TextEditingController ctrl;

  // The Settings text input (shared LabeledTextField).
  @override
  Widget build(BuildContext context) => LabeledTextField(label: label, controller: ctrl, hint: hint);
}

class _DDropdown extends StatelessWidget {
  const _DDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTheme.labelCaps.copyWith(fontSize: 10),
      ),
      const SizedBox(height: 6),
      DropdownFieldBox<String>(
        value: value,
        items: items
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
        onChanged: (v) {
              if (v != null) onChanged(v);
            },
      ),
    ],
  );
}

// ── Filter picker dialog ───────────────────────────────────────────────────────

class _ClearHospitalFilter {
  const _ClearHospitalFilter();
}

class _HospitalFilterPickerDialog extends StatelessWidget {
  const _HospitalFilterPickerDialog({this.currentName});
  final String? currentName;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: Text('Filter by Hospital', style: AppTheme.bodyStrong),
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text('All', style: AppTheme.bodySm),
            trailing: currentName == null
                ? Icon(Symbols.check, size: 16, color: AppColors.teal)
                : null,
            onTap: () => Navigator.pop(context, const _ClearHospitalFilter()),
            dense: true,
          ),
          const SizedBox(height: 8),
          AppSearchableSelectField<int>(
            hint: 'Search hospitals…',
            selectedLabel: currentName,
            asyncSearch: (q) async {
              final results = await HospitalService.instance.search(q);
              return results.map((h) => AppSelectItem(value: h.id, label: h.name)).toList();
            },
            onSelected: (item) {
              if (item != null) Navigator.pop(context, item);
            },
          ),
        ],
      ),
    ),
  );
}

class _PickerDialog extends StatelessWidget {
  const _PickerDialog({
    required this.title,
    required this.options,
    this.current,
  });
  final String title;
  final List<String> options;
  final String? current;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: Text('Filter by $title', style: AppTheme.bodyStrong),
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    content: SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('All', style: AppTheme.bodySm),
            trailing: current == null
                ? Icon(Symbols.check, size: 16, color: AppColors.teal)
                : null,
            onTap: () => Navigator.pop(context, ''),
            dense: true,
          ),
          ...options.map(
            (opt) => ListTile(
              title: Text(
                opt,
                style: AppTheme.bodySm,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              trailing: current == opt
                  ? Icon(Symbols.check, size: 16, color: AppColors.teal)
                  : null,
              onTap: () => Navigator.pop(context, opt),
              dense: true,
            ),
          ),
        ],
      ),
    ),
  );
}
