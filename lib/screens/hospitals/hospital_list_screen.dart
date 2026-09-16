import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show can;
import '../../models/hospital.dart';
import '../../models/machine.dart';
import '../../services/hospital_service.dart';
import '../../services/machine_service.dart';
import '../../utils/api_error.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/shimmer_box.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_button.dart';

import '../../theme/app_palette.dart';
class HospitalListScreen extends StatefulWidget {
  const HospitalListScreen({super.key});

  @override
  State<HospitalListScreen> createState() => _HospitalListScreenState();
}

class _HospitalListScreenState extends State<HospitalListScreen> {
  String?   _typeFilter;
  final _search = TextEditingController();
  bool _showAdd = false;
  Hospital? _viewHospital;
  Hospital? _editHospital;

  List<Hospital> _hospitals  = [];
  bool           _loading    = true;
  String?        _loadError;
  int            _showCount  = 25;
  static const   _pageSize   = 25;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final data = await HospitalService.instance.list();
      if (mounted) setState(() { _hospitals = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loadError = friendlyError(e); _loading = false; });
    }
  }

  int _typeCount(String? t) => t == null
      ? _hospitals.length
      : _hospitals.where((h) => h.type == t).length;

  List<Hospital> get _filtered {
    var list = _hospitals;
    if (_typeFilter != null) list = list.where((h) => h.type == _typeFilter).toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((h) =>
        h.name.toLowerCase().contains(q) ||
        h.region.toLowerCase().contains(q) ||
        h.shortCode.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final allFiltered   = _filtered;
    final hospitals     = allFiltered.take(_showCount).toList();
    final remaining     = allFiltered.length - hospitals.length;
    final totalMachines = _hospitals.fold(0, (s, h) => s + h.machineCount);
    final totalRev      = _hospitals.fold(0.0, (s, h) => s + h.revenueMonthly);

    return Stack(
      children: [
        LayoutBuilder(builder: (ctx, cst) {
          final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
          return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              LayoutBuilder(builder: (ctx2, cst2) {
                final narrow = cst2.maxWidth < 560;
                final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Crumb(),
                  const SizedBox(height: 4),
                  Text('Hospitals', style: AppTheme.pageTitle),
                  const SizedBox(height: 4),
                  Text('${_hospitals.length} hospitals · $totalMachines machines · 11 regions',
                    style: AppTheme.bodySub),
                ]);
                final actions = Row(mainAxisSize: MainAxisSize.min, children: [
                  AppButton(label: 'Export', icon: Symbols.download, variant: BtnVariant.ghost),
                  const SizedBox(width: 8),
                  AppButton(label: 'Map View', icon: Symbols.map, variant: BtnVariant.ghost),
                  if (can('hospitals.manage')) ...[
                    const SizedBox(width: 8),
                    AppButton(label: 'Add Hospital', icon: Symbols.add, variant: BtnVariant.primary,
                        onPressed: () => setState(() => _showAdd = true)),
                  ],
                ]);
                if (narrow) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    titleBlock, const SizedBox(height: 12), actions,
                  ]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  titleBlock, const Spacer(), actions,
                ]);
              }),
              const SizedBox(height: 20),

              // KPI chips · 5 cols wide, 3 medium, 2 narrow
              AdaptiveColumns(
                wideCols: 5, mediumCols: 3, narrowCols: 2,
                spacing: 10, runSpacing: 10,
                children: [
                  _TypeChip(label: 'All Hospitals',  value: '${_typeCount(null)}',
                    active: _typeFilter == null,
                    onTap: () => setState(() { _typeFilter = null; _showCount = _pageSize; })),
                  _TypeChip(label: 'Public',         value: '${_typeCount('public')}',
                    color: AppColors.teal,   active: _typeFilter == 'public',
                    onTap: () => setState(() { _typeFilter = _typeFilter == 'public'  ? null : 'public';  _showCount = _pageSize; })),
                  _TypeChip(label: 'Private',        value: '${_typeCount('private')}',
                    color: AppColors.blue,   active: _typeFilter == 'private',
                    onTap: () => setState(() { _typeFilter = _typeFilter == 'private' ? null : 'private'; _showCount = _pageSize; })),
                  _TypeChip(label: 'Mission / NGO',  value: '${_typeCount('mission')}',
                    color: AppColors.violet, active: _typeFilter == 'mission',
                    onTap: () => setState(() { _typeFilter = _typeFilter == 'mission' ? null : 'mission'; _showCount = _pageSize; })),
                  _TypeChip(label: 'Monthly Revenue',
                    value: 'TSh ${(totalRev / 1e6).toStringAsFixed(1)}M',
                    color: AppColors.amber, active: false, onTap: () {}),
                ],
              ),
              const SizedBox(height: 16),

              // Search bar
              LayoutBuilder(builder: (ctx3, cst3) {
                final narrow = cst3.maxWidth < 600;
                final searchBox = Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: context.pal.surface1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.pal.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() => _showCount = _pageSize),
                      style: AppTheme.bodySm,
                      decoration: InputDecoration(
                        hintText: 'Search by name, region or code—',
                        hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                        border: InputBorder.none, isDense: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )),
                  ]),
                );
                if (narrow) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    searchBox,
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      _FilterPill(icon: Symbols.location_on, label: 'Region', value: 'All'),
                      _FilterPill(icon: Symbols.precision_manufacturing, label: 'Machines', value: 'Any'),
                      AppButton(label: 'Columns', icon: Symbols.view_column, variant: BtnVariant.ghost, small: true),
                    ]),
                  ]);
                }
                return Row(children: [
                  SizedBox(width: 340, child: searchBox),
                  const SizedBox(width: 10),
                  _FilterPill(icon: Symbols.location_on, label: 'Region', value: 'All'),
                  const SizedBox(width: 10),
                  _FilterPill(icon: Symbols.precision_manufacturing, label: 'Machines', value: 'Any'),
                  const Spacer(),
                  AppButton(label: 'Columns', icon: Symbols.view_column, variant: BtnVariant.ghost, small: true),
                ]);
              }),
              const SizedBox(height: 16),

              // Table · horizontally scrollable below 900px
              HScrollTable(
                minWidth: 900,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.pal.surface1,
                    borderRadius: BorderRadius.circular(AppColors.rLg),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: Column(children: [
                    _TableHeader(),
                    if (_loading)
                      shimmerList(count: 8)
                    else if (_loadError != null)
                      ErrorView(message: _loadError!, onRetry: _load, compact: true)
                    else if (hospitals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Symbols.local_hospital, size: 36, color: context.pal.textDim),
                          const SizedBox(height: 10),
                          Text(_hospitals.isEmpty ? 'No hospitals yet' : 'No hospitals match your search',
                              style: AppTheme.bodySub),
                        ])),
                      )
                    else
                      ...hospitals.map((h) => _HospitalRow(
                        hospital: h,
                        onView: () => setState(() => _viewHospital = h),
                        onEdit: () => setState(() => _editHospital = h),
                      )),
                    // Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: context.pal.border)),
                      ),
                      child: Row(children: [
                        Text('Showing ${hospitals.length} of ${allFiltered.length} hospitals',
                          style: AppTheme.bodySub.copyWith(fontSize: 12)),
                        if (remaining > 0) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _showCount += _pageSize),
                            child: Text('Load $remaining more',
                              style: AppTheme.bodySm.copyWith(color: AppColors.teal, fontSize: 12)),
                          ),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ),
            ],
          ),
          ));  // SingleChildScrollView + RefreshIndicator
        }),   // LayoutBuilder

        // FAB
        if (can('hospitals.manage'))
        Positioned(
          right: 28, bottom: 28,
          child: GestureDetector(
            onTap: () => setState(() => _showAdd = true),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(color: AppColors.teal.withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 12)),
                ],
              ),
              child: Row(children: [
                const Icon(Symbols.add, size: 20, color: Color(0xFF06120F)),
                const SizedBox(width: 8),
                Text('Add Hospital', style: AppTheme.bodyStrong.copyWith(
                  color: const Color(0xFF06120F), fontSize: 13.5, fontWeight: FontWeight.w600,
                )),
              ]),
            ),
          ),
        ),

        // Add Hospital dialog
        if (_showAdd)
          _AddHospitalDialog(
            onClose: () => setState(() => _showAdd = false),
            onSaved: () { setState(() => _showAdd = false); _load(); },
          ),

        // View Hospital detail
        if (_viewHospital != null)
          _HospitalDetailSheet(
            hospital: _viewHospital!,
            onClose: () => setState(() => _viewHospital = null),
            onEdit: () => setState(() {
              _editHospital = _viewHospital;
              _viewHospital = null;
            }),
          ),

        // Edit Hospital dialog
        if (_editHospital != null)
          _EditHospitalDialog(
            hospital: _editHospital!,
            onClose: () => setState(() => _editHospital = null),
          ),
      ],
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────
class _Crumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    const SizedBox(width: 6),
    Text('Workspace', style: AppTheme.monoXs),
    const SizedBox(width: 6),
    const SizedBox(width: 6),
    Text('Hospitals', style: AppTheme.monoXs.copyWith(color: context.pal.text)),
  ]);
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label, required this.value, this.color,
    required this.active, required this.onTap,
  });
  final String label, value;
  final Color? color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? context.pal.surface2 : context.pal.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? context.pal.borderStrong : context.pal.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: AppTheme.labelCaps),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 20, color: color ?? context.pal.text)),
        ]),
        if (color != null) ...[
          const SizedBox(width: 12),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ],
      ]),
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label, required this.value});
  final IconData icon; final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: context.pal.surface1, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.pal.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: context.pal.textMute),
      const SizedBox(width: 6),
      Text('$label: ', style: AppTheme.bodySm.copyWith(color: context.pal.textMute, fontSize: 12.5)),
      Text(value, style: AppTheme.bodySm.copyWith(color: context.pal.text, fontWeight: FontWeight.w500, fontSize: 12.5)),
      const SizedBox(width: 4),
    ]),
  );
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
    child: Row(children: [
      const SizedBox(width: 20),
      _Th('Hospital',         flex: 3),
      _Th('Region',           flex: 2),
      _Th('Type',             flex: 1),
      _Th('Machines',         flex: 1),
      _Th('Uptime',           flex: 1),
      _Th('Monthly Rev.',     flex: 2, right: true),
      _Th('Contact',          flex: 2),
      const SizedBox(width: 80),
    ]),
  );
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex, this.right = false});
  final String label; final int flex; final bool right;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(label.toUpperCase(),
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.10)),
    ),
  );
}

class _HospitalRow extends StatelessWidget {
  const _HospitalRow({required this.hospital, this.onView, this.onEdit});
  final Hospital hospital;
  final VoidCallback? onView;
  final VoidCallback? onEdit;

  Color _typeColor(String t) => switch (t) {
    'public'   => AppColors.teal,
    'private'  => AppColors.blue,
    'mission'  => AppColors.violet,
    _          => AppColors.textMute,
  };

  String _typeLabel(String t) => switch (t) {
    'public'   => 'Public',
    'private'  => 'Private',
    'mission'  => 'Mission',
    _          => t,
  };

  @override
  Widget build(BuildContext context) {
    final uptimePct = hospital.uptimePct;
    final uptimeColor = uptimePct >= 0.95
        ? AppColors.teal
        : uptimePct >= 0.85
            ? AppColors.amber
            : AppColors.coral;

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider))),
      child: Row(children: [
        const SizedBox(width: 20),
        // Hospital name
        Expanded(flex: 3, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _typeColor(hospital.type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(hospital.shortCode.length > 3 ? hospital.shortCode.substring(0, 3) : hospital.shortCode,
                style: AppTheme.monoXs.copyWith(
                  color: _typeColor(hospital.type), fontSize: 9, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hospital.name, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
              Text(hospital.district, style: AppTheme.bodySub.copyWith(fontSize: 11)),
            ])),
          ]),
        )),
        // Region
        Expanded(flex: 2, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            const SizedBox(width: 4),
            Text(hospital.region, style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
          ]),
        )),
        // Type
        Expanded(flex: 1, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _typeColor(hospital.type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(_typeLabel(hospital.type), style: AppTheme.bodySub.copyWith(
              color: _typeColor(hospital.type), fontSize: 11.5, fontWeight: FontWeight.w500,
            )),
          ),
        )),
        // Machines
        Expanded(flex: 1, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${hospital.machineCount}', style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
            Text('${hospital.machinesOperational} active', style: AppTheme.bodySub.copyWith(fontSize: 11)),
          ]),
        )),
        // Uptime
        Expanded(flex: 1, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${(uptimePct * 100).toStringAsFixed(0)}%',
              style: AppTheme.bodyStrong.copyWith(fontSize: 13, color: uptimeColor)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: uptimePct,
                backgroundColor: context.pal.surface3,
                valueColor: AlwaysStoppedAnimation(uptimeColor),
                minHeight: 3,
              ),
            ),
          ]),
        )),
        // Revenue
        Expanded(flex: 2, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('TSh ${hospital.revenueMonthly.toStringAsFixed(1)}M',
              style: AppTheme.bodyStrong.copyWith(
                fontSize: 12.5, color: AppColors.amber,
                fontFeatures: [const FontFeature.tabularFigures()],
              )),
            Text('/ month', style: AppTheme.bodySub.copyWith(fontSize: 10)),
          ]),
        )),
        // Contact
        Expanded(flex: 2, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hospital.contactName, style: AppTheme.bodySm.copyWith(fontSize: 12)),
            Text(hospital.contactPhone, style: AppTheme.monoXs.copyWith(color: context.pal.textMute, fontSize: 10.5)),
          ]),
        )),
        // Actions
        SizedBox(width: 80, child: Row(children: [
          GestureDetector(onTap: onView,
              child: Icon(Symbols.visibility, size: 16, color: context.pal.textDim)),
          const SizedBox(width: 8),
          if (can('hospitals.manage')) ...[
            GestureDetector(onTap: onEdit,
                child: Icon(Symbols.edit, size: 16, color: context.pal.textDim)),
            const SizedBox(width: 8),
          ],
        ])),
      ]),
    );
  }
}

// ── Add Hospital Dialog ──────────────────────────────────────────────────────

class _AddHospitalDialog extends StatefulWidget {
  const _AddHospitalDialog({required this.onClose, this.onSaved});
  final VoidCallback  onClose;
  final VoidCallback? onSaved;

  @override
  State<_AddHospitalDialog> createState() => _AddHospitalDialogState();
}

class _AddHospitalDialogState extends State<_AddHospitalDialog> {
  final _nameCtrl     = TextEditingController();
  final _codeCtrl     = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _contactCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _latCtrl      = TextEditingController();
  final _lngCtrl      = TextEditingController();
  String _type    = 'public';
  String _region  = 'Dar es Salaam';
  bool   _saving  = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose(); _districtCtrl.dispose();
    _contactCtrl.dispose(); _phoneCtrl.dispose();
    _latCtrl.dispose(); _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _nameCtrl.text.trim().isEmpty) return;
    final lat = double.tryParse(_latCtrl.text.trim()) ?? 0.0;
    final lng = double.tryParse(_lngCtrl.text.trim()) ?? 0.0;
    setState(() { _saving = true; _error = null; });
    try {
      await HospitalService.instance.create({
        'name':          _nameCtrl.text.trim(),
        'short_code':    _codeCtrl.text.trim(),
        'type':          _type,
        'region':        _region,
        'district':      _districtCtrl.text.trim(),
        'contact_name':  _contactCtrl.text.trim(),
        'contact_phone': _phoneCtrl.text.trim(),
        'contact_email': '',
        'latitude':      lat,
        'longitude':     lng,
      });
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error  = e.toString().contains('422') ? 'Validation failed — check all fields.' : 'Failed to save.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 520,
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
                Icon(Symbols.local_hospital, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('Add Hospital', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  Expanded(flex: 3, child: _HField('Hospital Name', _nameCtrl, 'e.g. Mwananyamala Regional Hospital')),
                  const SizedBox(width: 14),
                  Expanded(flex: 1, child: _HField('Short Code', _codeCtrl, 'e.g. MRH')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HDropdown(
                    label: 'Type',
                    value: _type,
                    items: const ['public', 'private', 'mission'],
                    display: const ['Public', 'Private', 'Mission/Faith'],
                    onChanged: (v) => setState(() => _type = v),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _HDropdown(
                    label: 'Region',
                    value: _region,
                    items: const ['Dar es Salaam', 'Kilimanjaro', 'Mwanza', 'Mbeya',
                        'Arusha', 'Dodoma', 'Tanga', 'Morogoro'],
                    onChanged: (v) => setState(() => _region = v),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _HField('District', _districtCtrl, 'e.g. Ilala')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HField('Contact Person', _contactCtrl, 'e.g. Dr. Amina Hassan')),
                  const SizedBox(width: 14),
                  Expanded(child: _HField('Phone', _phoneCtrl, '+255 ...')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HField('Latitude', _latCtrl, 'e.g. -6.7924',
                      numeric: true)),
                  const SizedBox(width: 14),
                  Expanded(child: _HField('Longitude', _lngCtrl, 'e.g. 39.2083',
                      numeric: true)),
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
                      : Text('Save Hospital', style: AppTheme.bodyStrong.copyWith(
                          color: const Color(0xFF06120F), fontSize: 13)))),
                )),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _HField extends StatelessWidget {
  const _HField(this.label, this.ctrl, this.hint, {this.numeric = false});
  final String label, hint;
  final TextEditingController ctrl;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(controller: ctrl, style: AppTheme.bodySm,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
        decoration: InputDecoration(hintText: hint,
            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),
    ),
  ]);
}

class _HDropdown extends StatelessWidget {
  const _HDropdown({required this.label, required this.value, required this.items,
      this.display, required this.onChanged});
  final String label, value;
  final List<String> items;
  final List<String>? display;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      height: 38,
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

// ── Hospital Detail Sheet ────────────────────────────────────────────────────

class _HospitalDetailSheet extends StatefulWidget {
  const _HospitalDetailSheet({required this.hospital, required this.onClose, required this.onEdit});
  final Hospital hospital;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  @override
  State<_HospitalDetailSheet> createState() => _HospitalDetailSheetState();
}

class _HospitalDetailSheetState extends State<_HospitalDetailSheet> {
  List<Machine> _machines        = [];
  bool          _loadingMachines = true;
  // Outstanding balance / available credit aren't on the list payload
  // (would mean one query per hospital row) — fetched only when this
  // sheet opens for one specific hospital.
  Hospital?     _creditInfo;

  @override
  void initState() {
    super.initState();
    _loadMachines();
    if (widget.hospital.creditLimit != null) _loadCreditInfo();
  }

  Future<void> _loadMachines() async {
    try {
      final data = await MachineService.instance.list(hospitalId: widget.hospital.id);
      if (mounted) setState(() { _machines = data; _loadingMachines = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMachines = false);
    }
  }

  Future<void> _loadCreditInfo() async {
    try {
      final full = await HospitalService.instance.get(widget.hospital.id);
      if (mounted) setState(() => _creditInfo = full);
    } catch (_) {
      // Non-critical — the sheet still works without the credit KPI card.
    }
  }

  Color _typeColor(String t) => switch (t) {
    'public'  => AppColors.teal,
    'private' => AppColors.blue,
    'mission' => AppColors.violet,
    _         => AppColors.textMute,
  };
  String _typeLabel(String t) => switch (t) {
    'public'  => 'Public',
    'private' => 'Private',
    'mission' => 'Mission / NGO',
    _         => t,
  };

  @override
  Widget build(BuildContext context) {
    final hospital   = widget.hospital;
    final uptimePct  = hospital.uptimePct;
    final uptimeColor = uptimePct >= 0.95
        ? AppColors.teal
        : uptimePct >= 0.85 ? AppColors.amber : AppColors.coral;

    final machines = _machines;

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: const Color(0xAA06070A),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 720),
            decoration: BoxDecoration(
              color: context.pal.surface1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.pal.borderStrong),
              boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ────────────────────────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _typeColor(hospital.type).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hospital.shortCode.length > 3 ? hospital.shortCode.substring(0, 3) : hospital.shortCode,
                      style: AppTheme.monoXs.copyWith(
                          color: _typeColor(hospital.type), fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hospital.name, style: AppTheme.pageTitle.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _typeColor(hospital.type).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(_typeLabel(hospital.type), style: AppTheme.bodySub.copyWith(
                            color: _typeColor(hospital.type), fontSize: 11, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(width: 3),
                      Text('${hospital.district}, ${hospital.region}',
                          style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                    ]),
                  ])),
                  if (can('hospitals.manage')) ...[
                    AppButton(label: 'Edit', icon: Symbols.edit, variant: BtnVariant.normal, small: true,
                        onPressed: widget.onEdit),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(onTap: widget.onClose,
                      child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
                ]),
              ),

              // ── Scrollable body ────────────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // KPI row
                    Row(children: [
                      _KpiCard(label: 'Total Machines',  value: '${hospital.machineCount}',
                          sub: '${hospital.machinesOperational} operational'),
                      const SizedBox(width: 12),
                      _KpiCard(label: 'Uptime',
                          value: '${(uptimePct * 100).toStringAsFixed(0)}%',
                          valueColor: uptimeColor),
                      const SizedBox(width: 12),
                      _KpiCard(label: 'Monthly Revenue',
                          value: 'TSh ${hospital.revenueMonthly.toStringAsFixed(1)}M',
                          valueColor: AppColors.amber),
                      if (hospital.creditLimit != null) ...[
                        const SizedBox(width: 12),
                        _KpiCard(
                          label: 'Credit Available',
                          value: _creditInfo == null
                              ? '…'
                              : 'TSh ${(_creditInfo!.creditAvailable! / 1e6).toStringAsFixed(1)}M',
                          sub: _creditInfo == null
                              ? null
                              : 'of TSh ${(hospital.creditLimit! / 1e6).toStringAsFixed(1)}M limit',
                          valueColor: _creditInfo == null
                              ? null
                              : (_creditInfo!.creditAvailable! <= 0 ? AppColors.coral : AppColors.teal),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 16),

                    // Contact info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.pal.surface2,
                        borderRadius: BorderRadius.circular(AppColors.rLg),
                        border: Border.all(color: context.pal.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const SizedBox(width: 8),
                          Text('Primary Contact', style: AppTheme.cardTitle),
                        ]),
                        const SizedBox(height: 12),
                        _InfoPair('Name',  hospital.contactName),
                        const SizedBox(height: 6),
                        _InfoPair('Phone', hospital.contactPhone),
                        const SizedBox(height: 6),
                        _InfoPair('Email', hospital.contactEmail),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Machines at this hospital
                    Row(children: [
                      const SizedBox(width: 8),
                      Text(_loadingMachines ? 'Machines' : 'Machines (${machines.length})',
                          style: AppTheme.cardTitle),
                    ]),
                    const SizedBox(height: 10),
                    if (_loadingMachines)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (machines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('No machines registered at this hospital',
                            style: AppTheme.bodySub)),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: context.pal.surface2,
                          borderRadius: BorderRadius.circular(AppColors.rLg),
                          border: Border.all(color: context.pal.border),
                        ),
                        child: Column(
                          children: machines.asMap().entries.map((e) {
                            final m = e.value;
                            final isLast = e.key == machines.length - 1;
                            final sc = m.status == MachineStatus.operational ? AppColors.teal
                                : m.status == MachineStatus.down ? AppColors.coral
                                : AppColors.amber;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: isLast ? null : Border(bottom: BorderSide(color: context.pal.divider)),
                              ),
                              child: Row(children: [
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(m.model, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                                  Text('${m.serialNo} · ${m.ward}',
                                      style: AppTheme.bodySub.copyWith(fontSize: 11)),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: sc.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(m.status.label, style: AppTheme.bodySub.copyWith(
                                      color: sc, fontSize: 11, fontWeight: FontWeight.w500)),
                                ),
                              ]),
                            );
                          }).toList(),
                        ),
                      ),

                    if (hospital.notes != null) ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        const SizedBox(width: 8),
                        Text('Notes', style: AppTheme.cardTitle),
                      ]),
                      const SizedBox(height: 8),
                      Text(hospital.notes!, style: AppTheme.bodySub.copyWith(height: 1.6)),
                    ],
                  ]),
                ),
              ),

              // ── Footer ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(height: 38,
                      decoration: BoxDecoration(border: Border.all(color: context.pal.border),
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('Close', style: AppTheme.bodySm))),
                  )),
                  if (can('hospitals.manage')) ...[
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: widget.onEdit,
                      child: Container(height: 38,
                        decoration: BoxDecoration(color: AppColors.teal,
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Symbols.edit, size: 15, color: Color(0xFF06120F)),
                          const SizedBox(width: 6),
                          Text('Edit Hospital', style: AppTheme.bodyStrong.copyWith(
                              color: const Color(0xFF06120F), fontSize: 13)),
                        ]))),
                    )),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, this.sub, this.valueColor});
  final String label, value;
  final String? sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.pal.surface2,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.labelCaps),
      const SizedBox(height: 6),
      Text(value, style: AppTheme.kpiValue.copyWith(fontSize: 18, color: valueColor ?? context.pal.text)),
      if (sub != null) ...[
        const SizedBox(height: 2),
        Text(sub!, style: AppTheme.bodySub.copyWith(fontSize: 11)),
      ],
    ]),
  ));
}

class _InfoPair extends StatelessWidget {
  const _InfoPair(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 60, child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12))),
    Expanded(child: Text(value, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5))),
  ]);
}

// ── Edit Hospital Dialog ─────────────────────────────────────────────────────
class _EditHospitalDialog extends StatefulWidget {
  const _EditHospitalDialog({required this.hospital, required this.onClose});
  final Hospital hospital;
  final VoidCallback onClose;

  @override
  State<_EditHospitalDialog> createState() => _EditHospitalDialogState();
}

class _EditHospitalDialogState extends State<_EditHospitalDialog> {
  late final _nameCtrl     = TextEditingController(text: widget.hospital.name);
  late final _codeCtrl     = TextEditingController(text: widget.hospital.shortCode);
  late final _districtCtrl = TextEditingController(text: widget.hospital.district);
  late final _contactCtrl  = TextEditingController(text: widget.hospital.contactName);
  late final _phoneCtrl    = TextEditingController(text: widget.hospital.contactPhone);
  late final _latCtrl      = TextEditingController(
      text: widget.hospital.latitude  != 0.0 ? widget.hospital.latitude.toString()  : '');
  late final _lngCtrl      = TextEditingController(
      text: widget.hospital.longitude != 0.0 ? widget.hospital.longitude.toString() : '');
  late final _creditLimitCtrl = TextEditingController(
      text: widget.hospital.creditLimit?.toString() ?? '');
  late String _type        = widget.hospital.type;
  late String _region      = widget.hospital.region;
  bool        _saving      = false;
  String?     _error;

  static const _regions = ['Dar es Salaam', 'Kilimanjaro', 'Mwanza', 'Mbeya',
      'Arusha', 'Dodoma', 'Tanga', 'Morogoro'];

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose(); _districtCtrl.dispose();
    _contactCtrl.dispose(); _phoneCtrl.dispose();
    _latCtrl.dispose(); _lngCtrl.dispose(); _creditLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    setState(() { _saving = true; _error = null; });
    try {
      await HospitalService.instance.update(widget.hospital.id, {
        'name':          _nameCtrl.text.trim(),
        'short_code':    _codeCtrl.text.trim(),
        'type':          _type,
        'region':        _region,
        'district':      _districtCtrl.text.trim(),
        'contact_name':  _contactCtrl.text.trim(),
        'contact_phone': _phoneCtrl.text.trim(),
        'latitude':      lat ?? widget.hospital.latitude,
        'longitude':     lng ?? widget.hospital.longitude,
        'credit_limit':  _creditLimitCtrl.text.trim().isEmpty
            ? null : int.tryParse(_creditLimitCtrl.text.trim()),
      });
      widget.onClose();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error  = e.toString().contains('422') ? 'Validation failed — check all fields.' : 'Failed to save.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 520,
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
                Icon(Symbols.edit, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text('Edit: ${widget.hospital.name}',
                    style: AppTheme.bodyStrong, overflow: TextOverflow.ellipsis)),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  Expanded(flex: 3, child: _HField('Hospital Name', _nameCtrl, '')),
                  const SizedBox(width: 14),
                  Expanded(flex: 1, child: _HField('Short Code', _codeCtrl, '')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HDropdown(
                    label: 'Type', value: _type,
                    items: const ['public', 'private', 'mission'],
                    display: const ['Public', 'Private', 'Mission/Faith'],
                    onChanged: (v) => setState(() => _type = v),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _HDropdown(
                    label: 'Region', value: _regions.contains(_region) ? _region : _regions.first,
                    items: _regions,
                    onChanged: (v) => setState(() => _region = v),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _HField('District', _districtCtrl, '')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HField('Contact Person', _contactCtrl, '')),
                  const SizedBox(width: 14),
                  Expanded(child: _HField('Phone', _phoneCtrl, '')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HField('Latitude', _latCtrl, 'e.g. -6.7924',
                      numeric: true)),
                  const SizedBox(width: 14),
                  Expanded(child: _HField('Longitude', _lngCtrl, 'e.g. 39.2083',
                      numeric: true)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HField('Credit Limit (TZS, blank = unlimited)',
                      _creditLimitCtrl, 'e.g. 5000000', numeric: true)),
                  const SizedBox(width: 14),
                  const Expanded(child: SizedBox()),
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
                    decoration: BoxDecoration(color: AppColors.teal,
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save Changes', style: AppTheme.bodyStrong.copyWith(
                          color: const Color(0xFF06120F), fontSize: 13)))),
                )),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}
