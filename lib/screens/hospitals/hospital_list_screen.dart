import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show can;
import '../../models/hospital.dart';
import '../../models/machine.dart';
import '../../services/hospital_service.dart';
import '../../services/machine_service.dart';
import '../../utils/api_error.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart';
import '../../widgets/common/shimmer_box.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/tin.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/charts/map_tiles.dart';

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

  // Real server-side pagination — the directory is 13,000+ rows since the
  // national facility registry import, so "fetch up to 500 and treat that
  // as the whole list" (the old behaviour here) silently truncated it down
  // to whatever 500 rows happened to load first, and showed that count as
  // if it were the true total. See lib/services/hospital_service.dart's
  // listPaged() — filtering (search/type) happens server-side too, so what's
  // displayed and what's actually in the table always agree.
  static const _pageSize = 25;
  List<Hospital> _pageHospitals = [];
  int     _page      = 1;
  int     _lastPage  = 1;
  int     _pageTotal = 0;
  bool    _loading   = true;
  String? _loadError;
  Timer?  _debounce;

  // KPI chip numbers — deliberately NOT derived from _pageHospitals (that's
  // only the current page). Total/Public/Private/Mission are true counts
  // across the whole directory (cheap: paginate() computes a COUNT(*) for
  // `total` regardless of per_page, so per_page:1 is a lightweight count-
  // only request). Machines/Revenue are summed from the real client set
  // only (has_machines:1, ~250 rows, safe to load in full) — every
  // prospect row from the registry import has machine_count/revenue_monthly
  // of exactly 0, so that sum is exact, not an approximation.
  int?    _totalAll, _totalPublic, _totalPrivate, _totalMission;
  int     _totalMachines = 0;
  double  _totalRev      = 0;

  @override
  void initState() {
    super.initState();
    // Stale-while-revalidate: show the last-known page-1, no-filter table
    // instantly if cached, then quietly refresh — same reasoning as
    // MachineListScreen. The KPI stat chips above the table have no
    // matching cache (each is its own count-only or has_machines-filtered
    // query) — they already show "…" until they resolve, an existing,
    // unrelated loading affordance.
    final cached = HospitalService.cachedFirstPage;
    if (cached != null) {
      _pageHospitals = cached.items;
      _lastPage = cached.lastPage;
      _pageTotal = cached.total;
      _loading = false;
    }
    _loadStats();
    _loadPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        HospitalService.instance.listPaged(perPage: 1),
        HospitalService.instance.listPaged(perPage: 1, type: 'public'),
        HospitalService.instance.listPaged(perPage: 1, type: 'private'),
        HospitalService.instance.listPaged(perPage: 1, type: 'mission'),
        HospitalService.instance.list(hasMachines: true),
      ]);
      if (!mounted) return;
      final clients = results[4] as List<Hospital>;
      setState(() {
        _totalAll      = (results[0] as HospitalPage).total;
        _totalPublic   = (results[1] as HospitalPage).total;
        _totalPrivate  = (results[2] as HospitalPage).total;
        _totalMission  = (results[3] as HospitalPage).total;
        _totalMachines = clients.fold(0, (s, h) => s + h.machineCount);
        _totalRev      = clients.fold(0.0, (s, h) => s + h.revenueMonthly);
      });
    } catch (_) {
      // Non-critical — the table itself doesn't depend on these.
    }
  }

  Future<void> _loadPage() async {
    setState(() {
      if (_pageHospitals.isEmpty) _loading = true;
      _loadError = null;
    });
    try {
      final q = _search.text.trim();
      final result = await HospitalService.instance.listPaged(
        page: _page,
        perPage: _pageSize,
        q: q.isEmpty ? null : q,
        type: _typeFilter,
      );
      if (mounted) {
        setState(() {
          _pageHospitals = result.items;
          _lastPage      = result.lastPage;
          _pageTotal     = result.total;
          _loading       = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadError = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _load() async {
    _page = 1;
    await Future.wait([_loadStats(), _loadPage()]);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _loadPage();
    });
  }

  void _setTypeFilter(String? t) {
    setState(() { _typeFilter = t; _page = 1; });
    _loadPage();
  }

  void _goToPage(int p) {
    if (p < 1 || p > _lastPage || p == _page) return;
    setState(() => _page = p);
    _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    final hospitals = _pageHospitals;

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
                final narrow = cst2.maxWidth < 700;
                final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Crumb(),
                  const SizedBox(height: 4),
                  Text('Hospitals', style: AppTheme.pageTitle),
                  const SizedBox(height: 4),
                  Text('${_totalAll ?? '…'} hospitals · $_totalMachines machines',
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
                  _TypeChip(label: 'All Hospitals',  value: '${_totalAll ?? '…'}',
                    active: _typeFilter == null,
                    onTap: () => _setTypeFilter(null)),
                  _TypeChip(label: 'Public',         value: '${_totalPublic ?? '…'}',
                    color: AppColors.teal,   active: _typeFilter == 'public',
                    onTap: () => _setTypeFilter(_typeFilter == 'public'  ? null : 'public')),
                  _TypeChip(label: 'Private',        value: '${_totalPrivate ?? '…'}',
                    color: AppColors.blue,   active: _typeFilter == 'private',
                    onTap: () => _setTypeFilter(_typeFilter == 'private' ? null : 'private')),
                  _TypeChip(label: 'Mission / NGO',  value: '${_totalMission ?? '…'}',
                    color: AppColors.violet, active: _typeFilter == 'mission',
                    onTap: () => _setTypeFilter(_typeFilter == 'mission' ? null : 'mission')),
                  _TypeChip(label: 'Monthly Revenue',
                    value: 'TSh ${(_totalRev / 1e6).toStringAsFixed(1)}M',
                    color: AppColors.amber, active: false, onTap: () {}),
                ],
              ),
              const SizedBox(height: 16),

              // Search bar
              LayoutBuilder(builder: (ctx3, cst3) {
                final narrow = cst3.maxWidth < 600;
                final searchBox = SearchField(
                  hint: 'Search by name, region or code…',
                  controller: _search,
                  onChanged: (_) => _onSearchChanged(),
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

              // Table · fits the width; Contact, then Machines, drop out
              // on narrow windows instead of scrolling sideways.
              LayoutBuilder(builder: (ctx4, cst4) {
                final cols = _Cols(machines: cst4.maxWidth >= 560, contact: cst4.maxWidth >= 760);
                return Container(
                  decoration: BoxDecoration(
                    color: context.pal.surface1,
                    borderRadius: BorderRadius.circular(AppColors.rLg),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: Column(children: [
                    _TableHeader(cols),
                    if (_loading)
                      shimmerList(count: 8)
                    // A background refresh failing while stale-but-valid
                    // cached hospitals are already showing shouldn't blow
                    // that away.
                    else if (_loadError != null && _pageHospitals.isEmpty)
                      ErrorView(message: _loadError!, onRetry: _load, compact: true)
                    else if (hospitals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Symbols.local_hospital, size: 36, color: context.pal.textDim),
                          const SizedBox(height: 10),
                          Text(_pageTotal == 0 ? 'No hospitals match your search' : 'No hospitals yet',
                              style: AppTheme.bodySub),
                        ])),
                      )
                    else
                      ...hospitals.map((h) => _HospitalRow(
                        hospital: h,
                        cols: cols,
                        onView: () => setState(() => _viewHospital = h),
                        onEdit: () => setState(() => _editHospital = h),
                      )),
                    // Footer — real server-side pagination over _pageTotal
                    // (the filtered directory's true count), not a client-
                    // side "load more" over an already-fetched batch.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: context.pal.border)),
                      ),
                      child: Row(children: [
                        Text('Showing ${hospitals.isEmpty ? 0 : (_page - 1) * _pageSize + 1}'
                          '–${(_page - 1) * _pageSize + hospitals.length} of $_pageTotal hospitals',
                          style: AppTheme.bodySub.copyWith(fontSize: 12)),
                        const Spacer(),
                        if (_lastPage > 1) ...[
                          GestureDetector(
                            onTap: _page > 1 ? () => _goToPage(_page - 1) : null,
                            child: Icon(Symbols.chevron_left, size: 18,
                              color: _page > 1 ? context.pal.text : context.pal.textDim),
                          ),
                          const SizedBox(width: 10),
                          Text('Page $_page of $_lastPage', style: AppTheme.bodySm.copyWith(fontSize: 12)),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _page < _lastPage ? () => _goToPage(_page + 1) : null,
                            child: Icon(Symbols.chevron_right, size: 18,
                              color: _page < _lastPage ? context.pal.text : context.pal.textDim),
                          ),
                        ],
                      ]),
                    ),
                  ]),
                );
              }),
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
          EditHospitalDialog(
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

// Column weights shared by the header and every row so they always line up.
// Flex (not fixed widths) spreads the columns across whatever width the table
// gets; long text ellipsizes instead of pushing neighbours around.
// Each column is a main line plus a sub line, so four columns carry
// name/type, district/region/zone, machines and contact.
const _kColHospital = 5;
const _kColLocation = 4;
const _kColMachines = 2;
const _kColContact  = 3;
const _kActionsW    = 84.0;

/// Which optional columns fit the table's width.
class _Cols {
  const _Cols({required this.machines, required this.contact});
  final bool machines, contact;
}

const _zoneLabels = {
  'coastal': 'Coastal', 'northern': 'Northern', 'lake': 'Lake',
  'central': 'Central', 'shighland': 'Southern Highlands', 'southern': 'Southern',
};

String? zoneLabel(String? zone) => zone == null || zone.isEmpty ? null : _zoneLabels[zone] ?? zone;

bool _hasLocation(Hospital h) => h.latitude != 0 && h.longitude != 0;

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.cols);
  final _Cols cols;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
    child: Row(children: [
      const SizedBox(width: 20),
      _Th('Hospital', flex: _kColHospital),
      _Th('Location', flex: _kColLocation),
      if (cols.machines) _Th('Machines', flex: _kColMachines),
      if (cols.contact) _Th('Contact',  flex: _kColContact),
      const SizedBox(width: _kActionsW),
    ]),
  );
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex});
  final String label; final int flex;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(label.toUpperCase(),
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.10)),
    ),
  );
}

/// Whole row is clickable (opens the detail modal) with a hover highlight;
/// the edit icon keeps its own tap so it doesn't also open the detail.
class _HospitalRow extends StatefulWidget {
  const _HospitalRow({required this.hospital, required this.cols, this.onView, this.onEdit});
  final Hospital hospital;
  final _Cols cols;
  final VoidCallback? onView;
  final VoidCallback? onEdit;

  @override
  State<_HospitalRow> createState() => _HospitalRowState();
}

class _HospitalRowState extends State<_HospitalRow> {
  bool _hover = false;

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

  Widget _cell(int flex, Widget child) => Expanded(flex: flex, child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    child: child,
  ));

  Widget _line(String text, TextStyle style) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

  @override
  Widget build(BuildContext context) {
    final hospital = widget.hospital;
    final cols = widget.cols;
    final typeColor = _typeColor(hospital.type);
    final zone = zoneLabel(hospital.zone);
    final district = hospital.district == '—' ? '' : hospital.district;
    final region = hospital.region == '—' ? '' : hospital.region;
    final where = [if (region.isNotEmpty) region, if (zone != null) '$zone zone'].join(' · ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover ? context.pal.surface2 : Colors.transparent,
            border: Border(bottom: BorderSide(color: context.pal.divider)),
          ),
          child: Row(children: [
            const SizedBox(width: 20),
            // Hospital name
            _cell(_kColHospital, Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(hospital.shortCode.length > 3 ? hospital.shortCode.substring(0, 3) : hospital.shortCode,
                  style: AppTheme.monoXs.copyWith(
                    color: typeColor, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _line(hospital.name, AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                Text.rich(TextSpan(children: [
                  TextSpan(text: _typeLabel(hospital.type), style: TextStyle(color: typeColor, fontWeight: FontWeight.w500)),
                  if (hospital.shortCode.isNotEmpty && hospital.shortCode != '??') TextSpan(text: '  ·  ${hospital.shortCode}'),
                ]), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.bodySub.copyWith(fontSize: 11)),
              ])),
            ])),
            // Location: district, then region · zone
            _cell(_kColLocation, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _line(district.isEmpty ? (region.isEmpty ? '—' : region) : district,
                  AppTheme.bodySm.copyWith(fontSize: 12.5)),
              if (where.isNotEmpty)
                _line(where, AppTheme.bodySub.copyWith(fontSize: 11)),
            ])),
            // Machines
            if (cols.machines)
            _cell(_kColMachines, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${hospital.machineCount}', style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
              _line('${hospital.machinesOperational} active', AppTheme.bodySub.copyWith(fontSize: 11)),
            ])),
            // Contact
            if (cols.contact)
            _cell(_kColContact, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _line(hospital.contactName.isEmpty ? '—' : hospital.contactName,
                  AppTheme.bodySm.copyWith(fontSize: 12)),
              if (hospital.contactPhone.isNotEmpty)
                _line(hospital.contactPhone,
                    AppTheme.monoXs.copyWith(color: context.pal.textMute, fontSize: 10.5)),
            ])),
            // Actions — map pin and edit; viewing is a click anywhere on the row.
            SizedBox(width: _kActionsW, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                onPressed: _hasLocation(hospital) ? () => showHospitalLocation(context, hospital) : null,
                tooltip: _hasLocation(hospital) ? 'See on map' : 'No location saved',
                visualDensity: VisualDensity.compact,
                iconSize: 17,
                icon: Icon(Symbols.location_on,
                    color: _hasLocation(hospital) ? AppColors.teal : context.pal.textDim.withValues(alpha: 0.4)),
              ),
              if (can('hospitals.manage'))
                IconButton(
                  onPressed: widget.onEdit,
                  tooltip: 'Edit hospital',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  icon: Icon(Symbols.edit, color: context.pal.textDim),
                ),
              const SizedBox(width: 8),
            ])),
          ]),
        ),
      ),
    );
  }
}

// ── Location map ─────────────────────────────────────────────────────────────

/// The hospital's saved coordinates on a map, with a link out to Google Maps.
Future<void> showHospitalLocation(BuildContext context, Hospital hospital) =>
    showDialog(context: context, builder: (_) => _LocationDialog(hospital: hospital));

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({required this.hospital});
  final Hospital hospital;

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  MapStyle _style = MapStyle.light;

  @override
  Widget build(BuildContext context) {
    final h = widget.hospital;
    final point = LatLng(h.latitude, h.longitude);
    final zone = zoneLabel(h.zone);
    final where = [
      if (h.district.isNotEmpty && h.district != '—') h.district,
      if (h.region.isNotEmpty && h.region != '—') h.region,
      if (zone != null) '$zone zone',
    ].join(' · ');
    final coords = '${h.latitude.toStringAsFixed(5)}, ${h.longitude.toStringAsFixed(5)}';

    return Dialog(
      backgroundColor: context.pal.surface1,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.rLg)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(children: [
              Icon(Symbols.location_on, size: 20, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.bodyStrong.copyWith(fontSize: 14)),
                if (where.isNotEmpty)
                  Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.bodySub.copyWith(fontSize: 12)),
              ])),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Symbols.close, size: 18, color: context.pal.textDim),
              ),
            ]),
          ),
          Flexible(child: SizedBox(
            height: 400,
            child: Stack(children: [
              FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 14),
                children: [
                  mapTileLayer(_style),
                  MarkerLayer(markers: [
                    Marker(
                      point: point,
                      width: 36,
                      height: 36,
                      alignment: Alignment.topCenter,
                      child: Icon(Symbols.location_on, fill: 1, size: 36, color: AppColors.coral,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 6)]),
                    ),
                  ]),
                  SimpleAttributionWidget(
                    source: Text(_style.attribution, style: const TextStyle(fontSize: 9, color: Colors.white54)),
                    backgroundColor: const Color(0xAA0F1117),
                  ),
                ],
              ),
              Positioned(
                top: 10, right: 10,
                child: SegmentedButton<MapStyle>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: context.pal.surface1,
                    visualDensity: VisualDensity.compact,
                    textStyle: AppTheme.bodySm.copyWith(fontSize: 12),
                  ),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: MapStyle.light, label: Text('Map')),
                    ButtonSegment(value: MapStyle.satellite, label: Text('Satellite')),
                  ],
                  selected: {_style},
                  onSelectionChanged: (v) => setState(() => _style = v.first),
                ),
              ),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
            child: Row(children: [
              Expanded(child: SelectableText(coords, style: AppTheme.monoXs.copyWith(color: context.pal.textMute, fontSize: 11.5))),
              AppButton(
                label: 'Open in Google Maps',
                icon: Symbols.open_in_new,
                variant: BtnVariant.normal,
                small: true,
                onPressed: () => launchUrl(
                  Uri.parse('https://www.google.com/maps/search/?api=1&query=${h.latitude},${h.longitude}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ]),
          ),
        ]),
      ),
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
  final _tinCtrl      = TextEditingController();
  final _addressCtrl  = TextEditingController();
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
    _tinCtrl.dispose(); _addressCtrl.dispose();
    _latCtrl.dispose(); _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _nameCtrl.text.trim().isEmpty) return;
    if (_tinCtrl.text.trim().isNotEmpty && normalizeTin(_tinCtrl.text) == null) {
      setState(() => _error = 'TIN must be 9 digits (e.g. 123-456-789).');
      return;
    }
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
        'tin':           normalizeTin(_tinCtrl.text),
        'address':       _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
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
                  Expanded(flex: 3, child: _HField('Hospital name', _nameCtrl, 'e.g. Mwananyamala Regional Hospital')),
                  const SizedBox(width: 14),
                  Expanded(flex: 1, child: _HField('Short code', _codeCtrl, 'e.g. MRH')),
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
                  Expanded(child: _HField('Contact person', _contactCtrl, 'e.g. Dr. Amina Hassan')),
                  const SizedBox(width: 14),
                  Expanded(child: _HField('Phone', _phoneCtrl, '+255 ...')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HField('TIN', _tinCtrl, '123-456-789')),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: _HField('Address', _addressCtrl, 'e.g. P.O. Box 36463, Dar es Salaam')),
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

  // The Settings text input (shared LabeledTextField).
  @override
  Widget build(BuildContext context) => LabeledTextField(label: label, controller: ctrl, hint: hint, keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text);
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
    Text(label, style: AppTheme.fieldLabel),
    const SizedBox(height: 6),
    DropdownFieldBox<String>(
      value: value,
      items: items.asMap().entries.map((e) => DropdownMenuItem(
            value: e.value,
            child: Text(display != null ? display![e.key] : e.value))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
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
                        const SizedBox(height: 6),
                        _InfoPair('TIN', hospital.tin ?? '—'),
                        const SizedBox(height: 6),
                        _InfoPair('Address', hospital.address ?? '—'),
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
class EditHospitalDialog extends StatefulWidget {
  const EditHospitalDialog({super.key, required this.hospital, required this.onClose});
  final Hospital hospital;
  final VoidCallback onClose;

  @override
  State<EditHospitalDialog> createState() => EditHospitalDialogState();
}

class EditHospitalDialogState extends State<EditHospitalDialog> {
  late final _nameCtrl     = TextEditingController(text: widget.hospital.name);
  late final _codeCtrl     = TextEditingController(text: widget.hospital.shortCode);
  late final _districtCtrl = TextEditingController(text: widget.hospital.district);
  late final _contactCtrl  = TextEditingController(text: widget.hospital.contactName);
  late final _phoneCtrl    = TextEditingController(text: widget.hospital.contactPhone);
  late final _tinCtrl      = TextEditingController(text: widget.hospital.tin ?? '');
  late final _addressCtrl  = TextEditingController(text: widget.hospital.address ?? '');
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
    _tinCtrl.dispose(); _addressCtrl.dispose();
    _latCtrl.dispose(); _lngCtrl.dispose(); _creditLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_tinCtrl.text.trim().isNotEmpty && normalizeTin(_tinCtrl.text) == null) {
      setState(() => _error = 'TIN must be 9 digits (e.g. 123-456-789).');
      return;
    }
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
        'tin':           normalizeTin(_tinCtrl.text),
        'address':       _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
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
                  Expanded(flex: 3, child: _HField('Hospital name', _nameCtrl, '')),
                  const SizedBox(width: 14),
                  Expanded(flex: 1, child: _HField('Short code', _codeCtrl, '')),
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
                  Expanded(child: _HField('Contact person', _contactCtrl, '')),
                  const SizedBox(width: 14),
                  Expanded(child: _HField('Phone', _phoneCtrl, '')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HField('TIN', _tinCtrl, '123-456-789')),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: _HField('Address', _addressCtrl, 'P.O. Box, street, town')),
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
