import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/hospital.dart';
import '../../models/machine.dart';
import '../../services/hospital_service.dart';
import '../../services/machine_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/zones.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/charts/map_tiles.dart';

import '../../theme/app_palette.dart';

/// Real, hospital-aggregated fleet map. One marker per hospital (not per
/// machine) — with hundreds of real installed machines, plotting every one
/// individually would be unusable clutter. Each pin shows the hospital's
/// short code + machine count (e.g. "KCMC (43)"); tapping it loads that
/// hospital's real machine list into the detail panel. The zone tree on the
/// left narrows both the map and the detail panel to a zone/region at a
/// time. All data (zones, regions, hospitals, machine counts) is derived
/// live from the real imported facility dataset — nothing here is
/// hardcoded/sample data.
class MachineMapScreen extends StatefulWidget {
  const MachineMapScreen({super.key, this.onApplyZones});

  /// Called when the user taps "Apply to list" with the currently checked
  /// zone keys — lets the parent (MachineListScreen) switch back to list
  /// view pre-filtered to match.
  final ValueChanged<Set<String>>? onApplyZones;

  @override
  State<MachineMapScreen> createState() => _MachineMapScreenState();
}

class _MachineMapScreenState extends State<MachineMapScreen> {
  final _mapController = MapController();

  MapStyle _mapMode = MapStyle.dark;
  final Set<String> _overlays = {'hospitals', 'alerts'};
  String? _selectedZone;
  String? _selectedRegion;
  Hospital? _selectedHospital;
  bool _filterOpen = false;

  final Map<String, bool> _zoneExpanded = {};
  final Set<String> _checkedZones = {}; // empty = all zones visible

  List<Hospital> _hospitals = [];
  bool _loadingHospitals = true;

  List<Machine> _hospitalMachines = [];
  bool _loadingMachines = false;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    try {
      final list = await HospitalService.instance.list(hasMachines: true);
      if (mounted) {
        setState(() {
          _hospitals = list;
          _loadingHospitals = false;
          _selectedZone ??= _byZone.keys.isNotEmpty ? _byZone.keys.first : null;
          if (_selectedZone != null) {
            _zoneExpanded[_selectedZone!] = true;
            final regions = _regionsInZone(_selectedZone!);
            _selectedRegion ??= regions.keys.isNotEmpty ? regions.keys.first : null;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHospitals = false);
    }
  }

  // ── Real data aggregation ────────────────────────────────────────────────

  Map<String, List<Hospital>> get _byZone {
    final map = <String, List<Hospital>>{};
    for (final h in _hospitals) {
      final z = h.zone;
      if (z == null) continue;
      map.putIfAbsent(z, () => []).add(h);
    }
    return map;
  }

  Map<String, List<Hospital>> _regionsInZone(String zone) {
    final map = <String, List<Hospital>>{};
    for (final h in _byZone[zone] ?? const <Hospital>[]) {
      map.putIfAbsent(h.region, () => []).add(h);
    }
    return map;
  }

  int _sumMachines(List<Hospital> list) => list.fold(0, (s, h) => s + h.machineCount);

  List<Hospital> get _visibleHospitals => _checkedZones.isEmpty
      ? _hospitals
      : _hospitals.where((h) => _checkedZones.contains(h.zone)).toList();

  void _selectHospital(Hospital h) {
    setState(() {
      _selectedZone = h.zone ?? _selectedZone;
      _selectedRegion = h.region;
      _selectedHospital = h;
      if (h.zone != null) _zoneExpanded[h.zone!] = true;
    });
    if (h.latitude != 0 && h.longitude != 0) {
      _mapController.move(LatLng(h.latitude, h.longitude),
          math.max(_mapController.camera.zoom, 7.5));
    }
    _loadMachinesFor(h);
  }

  void _clearSelectedHospital() => setState(() {
    _selectedHospital = null;
    _hospitalMachines = [];
  });

  Future<void> _loadMachinesFor(Hospital h) async {
    setState(() {
      _loadingMachines = true;
      _hospitalMachines = [];
    });
    try {
      final list = await MachineService.instance.list(hospitalId: h.id);
      if (mounted) setState(() { _hospitalMachines = list; _loadingMachines = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMachines = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final wide   = cst.maxWidth >= 860;
      final medium = !wide && cst.maxWidth >= 600;

      return Stack(
        children: [
          Column(
            children: [
              _buildTopBar(wide: wide),
              Expanded(
                child: wide
                    ? _buildWideLayout()
                    : medium
                        ? _buildMediumLayout()
                        : _buildNarrowLayout(),
              ),
              _buildBottomStrip(),
            ],
          ),
          if (!wide && _filterOpen) _buildFilterOverlay(),
        ],
      );
    });
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar({required bool wide}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.pal.topbarBg,
        border: Border(bottom: BorderSide(color: context.pal.border)),
      ),
      child: Row(
        children: [
          if (!wide) ...[
            GestureDetector(
              onTap: () => setState(() => _filterOpen = !_filterOpen),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _filterOpen ? AppColors.tealSoft : context.pal.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _filterOpen ? AppColors.teal : context.pal.border),
                ),
                child: Icon(Symbols.filter_list, size: 16,
                  color: _filterOpen ? AppColors.teal : context.pal.textMute),
              ),
            ),
            const SizedBox(width: 12),
          ],

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
                for (final m in MapStyle.values)
                  _MapModeBtn(
                    label: m.label,
                    active: _mapMode == m,
                    onTap: () => setState(() => _mapMode = m),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final layer in ['hospitals', 'technicians', 'routes', 'alerts'])
                    _OverlayChip(
                      label: layer[0].toUpperCase() + layer.substring(1),
                      icon: _layerIcon(layer),
                      active: _overlays.contains(layer),
                      onTap: () => setState(() {
                        if (_overlays.contains(layer)) {
                          _overlays.remove(layer);
                        } else {
                          _overlays.add(layer);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _layerIcon(String layer) => switch (layer) {
    'hospitals'   => Symbols.local_hospital,
    'technicians' => Symbols.engineering,
    'routes'      => Symbols.route,
    'alerts'      => Symbols.warning,
    _             => Symbols.layers,
  };

  // ── Layouts ───────────────────────────────────────────────────────────────

  Widget _buildWideLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: _buildRealMap()),
      _buildFilterTree(width: 240),
      _buildDrillDown(width: 300),
    ],
  );

  Widget _buildMediumLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: _buildRealMap()),
      _buildDrillDown(width: 280),
    ],
  );

  Widget _buildNarrowLayout() => Column(
    children: [
      Expanded(child: _buildRealMap()),
      SizedBox(height: 240, child: _buildDrillDown()),
    ],
  );

  // ── Real map ──────────────────────────────────────────────────────────────

  Widget _buildRealMap() {
    final visible = _overlays.contains('hospitals')
        ? _visibleHospitals.where((h) => h.latitude != 0 && h.longitude != 0).toList()
        : <Hospital>[];

    final markers = visible.map((h) => Marker(
          point: LatLng(h.latitude, h.longitude),
          width: 130,
          height: 80,
          alignment: Alignment.bottomCenter,
          child: _HospitalMarker(
            hospital: h,
            selected: h.zone != null && h.zone == _selectedZone,
            onTap: () => _selectHospital(h),
          ),
        )).toList();

    return Stack(
      children: [
        ClipRect(
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-6.37, 34.89),
              initialZoom: 5.8,
              initialRotation: 0,
              minZoom: 4.0,
              maxZoom: 16.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.drag
                    | InteractiveFlag.flingAnimation
                    | InteractiveFlag.pinchMove
                    | InteractiveFlag.pinchZoom
                    | InteractiveFlag.scrollWheelZoom
                    | InteractiveFlag.doubleTapZoom,
              ),
            ),
              children: [
                // Same keyless base layers as the dashboard map (map_tiles.dart).
                mapTileLayer(_mapMode),
                MarkerLayer(markers: markers),
                SimpleAttributionWidget(
                  source: Text(_mapMode.attribution,
                    style: TextStyle(fontSize: 9, color: Colors.white54)),
                  backgroundColor: const Color(0xAA0F1117),
                ),
              ],
            ),
          ),

        if (_loadingHospitals)
          const Positioned(
            top: 12, left: 12,
            child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          ),

        Positioned(
          right: 14,
          bottom: 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _FloatMapBtn(
                icon: _mapMode == MapStyle.satellite
                    ? Symbols.map
                    : Symbols.satellite_alt,
                label: _mapMode == MapStyle.satellite ? 'MAP' : 'SAT',
                active: _mapMode == MapStyle.satellite,
                tooltip: _mapMode == MapStyle.satellite
                    ? 'Switch to street map'
                    : 'Switch to satellite',
                onTap: () => setState(() =>
                  _mapMode = _mapMode == MapStyle.satellite ? MapStyle.dark : MapStyle.satellite),
              ),

              const SizedBox(height: 6),

              _FloatMapBtn(
                icon: Symbols.my_location,
                tooltip: 'Reset to Tanzania overview',
                onTap: () => _mapController.move(
                  const LatLng(-6.37, 34.89), 6.0),
              ),

              const SizedBox(height: 6),

              Container(
                width: 38,
                decoration: BoxDecoration(
                  color: context.pal.surface1.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.pal.borderStrong),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final z = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          (z + 1).clamp(4.0, 16.0));
                      },
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: context.pal.border))),
                        child: Icon(Symbols.add,
                          size: 18, color: context.pal.textMute),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final z = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          (z - 1).clamp(4.0, 16.0));
                      },
                      child: SizedBox(
                        width: 38, height: 38,
                        child: Icon(Symbols.remove,
                          size: 18, color: context.pal.textMute),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Filter tree ───────────────────────────────────────────────────────────

  Widget _buildFilterTree({double? width}) {
    final zoneKeys = zoneLabels.keys.where((k) => (_byZone[k]?.isNotEmpty ?? false)).toList();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: context.pal.sidebarBg,
        border: Border(right: BorderSide(color: context.pal.border)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.pal.border))),
            child: Row(
              children: [
                Text('FILTER BY ZONE', style: AppTheme.monoXs),
                const Spacer(),
                Text('${_checkedZones.length} zone${_checkedZones.length != 1 ? 's' : ''}',
                  style: AppTheme.monoXs.copyWith(color: AppColors.teal)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: zoneKeys.map((zoneKey) {
                  final regions = _regionsInZone(zoneKey);
                  return _ZoneItem(
                    zoneKey: zoneKey,
                    label: zoneLabelFor(zoneKey),
                    totalMachines: _sumMachines(_byZone[zoneKey] ?? const []),
                    regions: regions,
                    expanded: _zoneExpanded[zoneKey] == true,
                    checked: _checkedZones.contains(zoneKey),
                    selectedRegion: _selectedZone == zoneKey ? _selectedRegion : null,
                    onToggleExpand: () => setState(() =>
                      _zoneExpanded[zoneKey] = !(_zoneExpanded[zoneKey] ?? false)),
                    onToggleCheck: () => setState(() {
                      if (_checkedZones.contains(zoneKey)) {
                        _checkedZones.remove(zoneKey);
                      } else {
                        _checkedZones.add(zoneKey);
                      }
                    }),
                    onSelectRegion: (region) {
                      setState(() {
                        _selectedZone = zoneKey;
                        _selectedRegion = region;
                        _selectedHospital = null;
                      });
                      final hs = regions[region] ?? const <Hospital>[];
                      final pin = hs.where((h) => h.latitude != 0 && h.longitude != 0).firstOrNull;
                      if (pin != null) _mapController.move(LatLng(pin.latitude, pin.longitude), 7.5);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.pal.border))),
            child: Row(children: [
              Icon(Symbols.check_circle, size: 14, color: AppColors.teal),
              const SizedBox(width: 6),
              Text(
                _checkedZones.isEmpty
                    ? 'All ${_sumMachines(_hospitals)} machines visible'
                    : '${_sumMachines(_visibleHospitals)} / ${_sumMachines(_hospitals)} selected',
                style: AppTheme.bodySm.copyWith(color: AppColors.teal, fontSize: 11.5)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _checkedZones
                    ..clear()
                    ..addAll(zoneKeys);
                }),
                child: Text('All', style: AppTheme.bodySm.copyWith(
                  color: context.pal.textDim, fontSize: 11.5,
                  decoration: TextDecoration.underline)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _checkedZones.clear()),
                child: Text('None', style: AppTheme.bodySm.copyWith(
                  color: context.pal.textDim, fontSize: 11.5,
                  decoration: TextDecoration.underline)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOverlay() => Positioned(
    top: 48, left: 0, bottom: 0,
    child: Row(
      children: [
        SizedBox(width: 240, child: _buildFilterTree(width: 240)),
        GestureDetector(
          onTap: () => setState(() => _filterOpen = false),
          child: Container(width: 60, color: Colors.transparent),
        ),
      ],
    ),
  );

  // ── Drill-down panel ──────────────────────────────────────────────────────

  Widget _buildDrillDown({double? width}) {
    if (_selectedHospital != null) {
      return _buildHospitalDetail(_selectedHospital!, width: width);
    }

    final zoneKeys = zoneLabels.keys.where((k) => (_byZone[k]?.isNotEmpty ?? false)).toList();
    if (zoneKeys.isEmpty) {
      return Container(
        width: width,
        decoration: BoxDecoration(
          color: context.pal.surface1,
          border: Border(left: BorderSide(color: context.pal.border)),
        ),
        child: Center(
          child: _loadingHospitals
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('No facility data yet', style: AppTheme.bodySub),
        ),
      );
    }

    final zoneKey = _selectedZone ?? zoneKeys.first;
    final zoneHospitals = _byZone[zoneKey] ?? const <Hospital>[];
    final regions = _regionsInZone(zoneKey);
    final regionKey = _selectedRegion != null && regions.containsKey(_selectedRegion)
        ? _selectedRegion!
        : (regions.keys.isNotEmpty ? regions.keys.first : null);
    final hospitalsInRegion = regionKey != null ? (regions[regionKey] ?? const <Hospital>[]) : const <Hospital>[];
    final zoneTotal = _sumMachines(zoneHospitals);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: context.pal.surface1,
        border: Border(left: BorderSide(color: context.pal.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.pal.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.teal, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.tealGlow, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(zoneLabelFor(zoneKey),
                      style: AppTheme.bodyStrong.copyWith(fontSize: 13))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.tealSoft,
                        borderRadius: BorderRadius.circular(999)),
                      child: Text('$zoneTotal',
                        style: AppTheme.monoXs.copyWith(color: AppColors.teal)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _DStat('${regions.length}', 'REGIONS'),
                    const SizedBox(width: 14),
                    _DStat('${zoneHospitals.length}', 'HOSPITALS'),
                  ]),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text('REGIONS', style: AppTheme.monoXs)),
            ...regions.entries.map((e) {
              final isActive = e.key == regionKey;
              final regionTotal = _sumMachines(e.value);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedZone = zoneKey;
                    _selectedRegion = e.key;
                    _selectedHospital = null;
                  });
                  final pin = e.value.where((h) => h.latitude != 0 && h.longitude != 0).firstOrNull;
                  if (pin != null) _mapController.move(LatLng(pin.latitude, pin.longitude), 7.5);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? context.pal.surface2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? context.pal.borderStrong : Colors.transparent)),
                  child: Row(children: [
                    Expanded(child: Text(e.key, style: AppTheme.bodySm.copyWith(
                      color: isActive ? context.pal.text : context.pal.textMute,
                      fontWeight: FontWeight.w500, fontSize: 12.5))),
                    Text('${e.value.length} hosp · $regionTotal', style: AppTheme.monoXs.copyWith(
                      color: isActive ? AppColors.teal : context.pal.textDim, fontSize: 10)),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 10),
            Container(width: double.infinity, height: 1, color: context.pal.border),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(children: [
                Expanded(child: Text(
                  regionKey != null ? 'HOSPITALS — ${regionKey.toUpperCase()}' : 'HOSPITALS',
                  style: AppTheme.monoXs,
                  overflow: TextOverflow.ellipsis)),
                Text('${hospitalsInRegion.length}',
                  style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
              ])),
            ...hospitalsInRegion.map((h) {
              return GestureDetector(
                onTap: () => _selectHospital(h),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: context.pal.surface3,
                        borderRadius: BorderRadius.circular(6)),
                      child: Icon(Symbols.local_hospital, size: 14, color: context.pal.textDim),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(fontSize: 11.5, color: context.pal.textMute)),
                        Text(h.district, style: AppTheme.bodySub.copyWith(fontSize: 10)),
                      ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${h.machineCount}', style: AppTheme.bodyStrong.copyWith(fontSize: 11.5)),
                      Text('machines', style: AppTheme.bodySub.copyWith(fontSize: 9.5)),
                    ]),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalDetail(Hospital h, {double? width}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: context.pal.surface1,
        border: Border(left: BorderSide(color: context.pal.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.pal.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _clearSelectedHospital,
                    child: Row(children: [
                      Icon(Symbols.arrow_back, size: 14, color: context.pal.textMute),
                      const SizedBox(width: 4),
                      Text('Back to ${zoneLabelFor(h.zone)}',
                        style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(h.name, style: AppTheme.bodyStrong.copyWith(fontSize: 14)),
                  const SizedBox(height: 3),
                  Text('${h.district} · ${h.region}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _DStat('${h.machineCount}', 'MACHINES'),
                    const SizedBox(width: 14),
                    _DStat('${h.machinesOperational}', 'OPERATIONAL'),
                    const SizedBox(width: 14),
                    _DStat('${(h.uptimePct * 100).toStringAsFixed(0)}%', 'UPTIME'),
                  ]),
                ],
              ),
            ),

            if (h.contactName != '—' || h.contactPhone != '—')
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.pal.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.pal.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (h.contactName != '—')
                      Text(h.contactName, style: AppTheme.bodySm.copyWith(fontSize: 11.5)),
                    if (h.contactPhone != '—')
                      Text(h.contactPhone, style: AppTheme.monoXs.copyWith(
                        color: context.pal.textMute, fontSize: 10.5)),
                  ]),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(children: [
                Expanded(child: Text('MACHINES', style: AppTheme.monoXs)),
                Text('${_hospitalMachines.length}',
                  style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
              ]),
            ),
            if (_loadingMachines)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_hospitalMachines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No machines on record', style: AppTheme.bodySub)),
              )
            else
              ..._hospitalMachines.map((m) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.model, style: AppTheme.bodySm.copyWith(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(m.serialNo, style: AppTheme.monoXs.copyWith(
                        color: context.pal.textMute, fontSize: 10)),
                    ],
                  )),
                  StatusBadge.machine(m.status),
                ]),
              )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Bottom stats strip ────────────────────────────────────────────────────

  Widget _buildBottomStrip() {
    final visible = _visibleHospitals;
    final visibleMachines = _sumMachines(visible);
    final visibleOperational = visible.fold(0, (s, h) => s + h.machinesOperational);
    final districts = visible.map((h) => h.district).toSet().length;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.pal.topbarBg,
        border: Border(top: BorderSide(color: context.pal.border))),
      child: Row(children: [
        const SizedBox(width: 16),
        for (final stat in [
          ('VISIBLE', '$visibleMachines'),
          ('HOSPITALS', '${visible.length}'),
          ('DISTRICTS', '$districts'),
          ('OPERATIONAL', '$visibleOperational'),
          ('ISSUES', '${visibleMachines - visibleOperational}'),
        ]) ...[
          _BottomStat(label: stat.$1, value: stat.$2),
          Container(
            width: 1, height: 24, color: context.pal.border,
            margin: const EdgeInsets.symmetric(horizontal: 14)),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () => widget.onApplyZones?.call(_checkedZones),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Symbols.list, size: 14, color: Color(0xFF06120F)),
              const SizedBox(width: 6),
              Text('Apply to list', style: AppTheme.bodyStrong.copyWith(
                color: const Color(0xFF06120F), fontSize: 12,
                fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 16),
      ]),
    );
  }
}

// ── Hospital marker widget ────────────────────────────────────────────────────

class _HospitalMarker extends StatelessWidget {
  const _HospitalMarker({required this.hospital, required this.selected, required this.onTap});
  final Hospital hospital;
  final bool selected;
  final VoidCallback onTap;

  Color get _color {
    if (hospital.machineCount == 0) return AppColors.amber;
    if (hospital.machinesOperational == hospital.machineCount) return AppColors.teal;
    if (hospital.machinesOperational == 0) return AppColors.coral;
    return AppColors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final dotSize = selected ? 18.0 : 12.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.pal.surface1.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: selected ? color : context.pal.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Tooltip(
              message: hospital.name,
              child: Text('${hospital.shortCode} (${hospital.machineCount})',
                style: AppTheme.monoXs.copyWith(
                  fontSize: 9.5,
                  color: selected ? context.pal.text : context.pal.textMute,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                )),
            ),
          ),
          const SizedBox(height: 3),
          Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                Container(
                  width: dotSize + 14,
                  height: dotSize + 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.20),
                    border: Border.all(
                      color: color.withValues(alpha: 0.40), width: 1),
                  ),
                ),
              Container(
                width: dotSize, height: dotSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.pal.bg,
                    width: selected ? 2.5 : 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: selected ? 16 : 6),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Zone filter tree item ─────────────────────────────────────────────────────

class _ZoneItem extends StatelessWidget {
  const _ZoneItem({
    required this.zoneKey,     required this.label,
    required this.totalMachines, required this.regions,
    required this.expanded,    required this.checked,
    required this.selectedRegion,
    required this.onToggleExpand, required this.onToggleCheck,
    required this.onSelectRegion,
  });
  final String zoneKey;
  final String label;
  final int totalMachines;
  final Map<String, List<Hospital>> regions;
  final bool expanded, checked;
  final String? selectedRegion;
  final VoidCallback onToggleExpand, onToggleCheck;
  final ValueChanged<String> onSelectRegion;

  /// district -> total machine count, for one region's hospitals.
  Map<String, int> _districtCounts(List<Hospital> hospitals) {
    final map = <String, int>{};
    for (final h in hospitals) {
      map.update(h.district, (v) => v + h.machineCount, ifAbsent: () => h.machineCount);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggleExpand,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(children: [
              GestureDetector(
                onTap: onToggleCheck,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: checked ? AppColors.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: checked ? AppColors.teal : context.pal.borderStrong)),
                  child: checked
                      ? const Icon(Icons.check, size: 11, color: Color(0xFF06120F))
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                expanded ? Symbols.expand_more : Symbols.chevron_right,
                size: 14, color: context.pal.textDim),
              const SizedBox(width: 4),
              Expanded(child: Text(label, style: AppTheme.bodySm.copyWith(
                color: checked ? context.pal.text : context.pal.textMute,
                fontWeight: FontWeight.w500, fontSize: 12.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: context.pal.surface3,
                  borderRadius: BorderRadius.circular(999)),
                child: Text('$totalMachines', style: AppTheme.monoXs.copyWith(
                  fontSize: 10,
                  color: checked ? AppColors.teal : context.pal.textDim))),
            ]),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: regions.entries.map((e) {
                final isActive = e.key == selectedRegion;
                final regionTotal = e.value.fold(0, (s, h) => s + h.machineCount);
                final districts = _districtCounts(e.value);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => onSelectRegion(e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.tealSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.teal : context.pal.textDim,
                              shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: AppTheme.bodySm.copyWith(
                            color: isActive ? AppColors.teal : context.pal.textMute,
                            fontWeight: FontWeight.w500,
                            fontSize: 12), overflow: TextOverflow.ellipsis)),
                          Text('$regionTotal', style: AppTheme.monoXs.copyWith(
                            fontSize: 9.5,
                            color: isActive ? AppColors.teal : context.pal.textDim)),
                        ]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: districts.entries.map((d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(children: [
                            Expanded(child: Text(d.key, style: AppTheme.bodySub.copyWith(
                              fontSize: 10.5), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            Text('${d.value}', style: AppTheme.monoXs.copyWith(
                              fontSize: 9, color: context.pal.textDim)),
                          ]),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _DStat extends StatelessWidget {
  const _DStat(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: AppTheme.bodyStrong.copyWith(
        fontSize: 14, fontFeatures: [const FontFeature.tabularFigures()])),
      Text(label, style: AppTheme.monoXs.copyWith(fontSize: 9, color: context.pal.textDim)),
    ],
  );
}

class _BottomStat extends StatelessWidget {
  const _BottomStat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: AppTheme.bodyStrong.copyWith(
        fontSize: 13, fontFeatures: [const FontFeature.tabularFigures()])),
      const SizedBox(width: 5),
      Text(label, style: AppTheme.monoXs.copyWith(
        fontSize: 9.5, color: context.pal.textDim)),
    ],
  );
}

class _MapModeBtn extends StatelessWidget {
  const _MapModeBtn({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: active
            ? Border.all(color: AppColors.teal.withValues(alpha: 0.3))
            : null,
      ),
      child: Text(label, style: AppTheme.bodySm.copyWith(
        fontSize: 12,
        color: active ? AppColors.teal : context.pal.textMute,
        fontWeight: FontWeight.w500)),
    ),
  );
}

// Floating button used on the map canvas (zoom, locate, satellite toggle)
class _FloatMapBtn extends StatelessWidget {
  const _FloatMapBtn({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    this.active = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: label != null ? 44 : 38,
        decoration: BoxDecoration(
          color: active
              ? AppColors.teal.withValues(alpha: 0.18)
              : context.pal.surface1.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.teal.withValues(alpha: 0.55)
                : context.pal.borderStrong),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17,
              color: active ? AppColors.teal : context.pal.textMute),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(label!,
                style: AppTheme.monoXs.copyWith(
                  fontSize: 8,
                  color: active ? AppColors.teal : context.pal.textDim,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
            ],
          ],
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({
    required this.label, required this.icon,
    required this.active, required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.tealSoft : context.pal.surface1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? AppColors.teal.withValues(alpha: 0.5) : context.pal.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: active ? AppColors.teal : context.pal.textMute),
        const SizedBox(width: 5),
        Text(label, style: AppTheme.bodySm.copyWith(
          fontSize: 11.5,
          color: active ? AppColors.teal : context.pal.textMute)),
      ]),
    ),
  );
}
