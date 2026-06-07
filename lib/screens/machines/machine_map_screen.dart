import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/machine.dart';
import '../../services/machine_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../theme/app_palette.dart';
// ── Zone / Region / District data ─────────────────────────────────────────────

class _Zone {
  const _Zone(this.key, this.label, this.regions);
  final String key;
  final String label;
  final List<_Region> regions;

  int get totalMachines => regions.fold(0, (s, r) => s + r.totalMachines);
}

class _Region {
  const _Region(this.key, this.label, this.districts);
  final String key;
  final String label;
  final List<_District> districts;

  int get totalMachines => districts.fold(0, (s, d) => s + d.machines);
}

class _District {
  const _District(this.label, this.machines);
  final String label;
  final int machines;
}

const _zones = [
  _Zone('coastal', 'Coastal Zone', [
    _Region('dsm', 'Dar es Salaam', [
      _District('Ilala', 142), _District('Kinondoni', 98),
      _District('Temeke', 56), _District('Ubungo', 44),
    ]),
    _Region('pwani', 'Pwani', [
      _District('Bagamoyo', 18), _District('Kibaha', 22), _District('Kisarawe', 8),
    ]),
    _Region('tanga', 'Tanga', [
      _District('Tanga City', 34), _District('Muheza', 12), _District('Korogwe', 9),
    ]),
  ]),
  _Zone('northern', 'Northern Zone', [
    _Region('arusha', 'Arusha', [
      _District('Arusha City', 56), _District('Arumeru', 18), _District('Karatu', 7),
    ]),
    _Region('kilimanjaro', 'Kilimanjaro', [
      _District('Moshi Urban', 48), _District('Moshi Rural', 22), _District('Same', 10),
    ]),
    _Region('manyara', 'Manyara', [
      _District('Babati', 16), _District('Hanang', 9),
    ]),
  ]),
  _Zone('lake', 'Lake Zone', [
    _Region('mwanza', 'Mwanza', [
      _District('Ilemela', 44), _District('Nyamagana', 38), _District('Magu', 12),
    ]),
    _Region('kagera', 'Kagera', [
      _District('Bukoba Urban', 24), _District('Bukoba Rural', 11),
    ]),
    _Region('geita', 'Geita', [_District('Geita Town', 16)]),
  ]),
  _Zone('central', 'Central Zone', [
    _Region('dodoma', 'Dodoma', [
      _District('Dodoma City', 42), _District('Chamwino', 14), _District('Mpwapwa', 8),
    ]),
    _Region('singida', 'Singida', [
      _District('Singida Urban', 16), _District('Singida Rural', 9),
    ]),
  ]),
  _Zone('shighland', 'Southern Highland', [
    _Region('mbeya', 'Mbeya', [
      _District('Mbeya City', 28), _District('Mbarali', 9),
    ]),
    _Region('iringa', 'Iringa', [
      _District('Iringa Urban', 18), _District('Kilolo', 9),
    ]),
  ]),
  _Zone('southern', 'Southern Zone', [
    _Region('lindi', 'Lindi', [
      _District('Lindi Urban', 10), _District('Liwale', 4),
    ]),
    _Region('mtwara', 'Mtwara', [
      _District('Mtwara Urban', 9),
    ]),
  ]),
];

// ── Map pin data with real Tanzania GPS coordinates ───────────────────────────

class _Pin {
  const _Pin(this.city, this.count, this.status, this.coords, this.zone);
  final String city;
  final int count;
  final String status; // 'ok' | 'warn' | 'down'
  final LatLng coords;
  final String zone;
}

const _pins = [
  _Pin('Dar es Salaam', 340, 'ok',   LatLng(-6.7924, 39.2083), 'coastal'),
  _Pin('Arusha',         82, 'ok',   LatLng(-3.3869, 36.6830), 'northern'),
  _Pin('Moshi',          80, 'warn', LatLng(-3.3545, 37.3411), 'northern'),
  _Pin('Tanga',          55, 'ok',   LatLng(-5.0685, 39.0988), 'coastal'),
  _Pin('Mwanza',         94, 'ok',   LatLng(-2.5164, 32.9175), 'lake'),
  _Pin('Dodoma',         64, 'warn', LatLng(-6.1722, 35.7395), 'central'),
  _Pin('Mbeya',          37, 'ok',   LatLng(-8.9000, 33.4667), 'shighland'),
  _Pin('Morogoro',       44, 'down', LatLng(-6.8235, 37.6603), 'coastal'),
  _Pin('Bukoba',         35, 'ok',   LatLng(-1.3317, 31.8167), 'lake'),
  _Pin('Iringa',         27, 'ok',   LatLng(-7.7667, 35.7000), 'shighland'),
  _Pin('Tabora',         28, 'warn', LatLng(-5.0167, 32.8000), 'central'),
  _Pin('Mtwara',         19, 'ok',   LatLng(-10.2667, 40.1833), 'southern'),
  _Pin('Lindi',          14, 'ok',   LatLng(-9.9942, 39.7175), 'southern'),
  _Pin('Singida',        25, 'ok',   LatLng(-4.8167, 34.7500), 'central'),
  _Pin('Geita',          16, 'warn', LatLng(-2.8667, 32.1667), 'lake'),
  _Pin('Shinyanga',      22, 'ok',   LatLng(-3.6607, 33.4256), 'lake'),
  _Pin('Kibaha',         30, 'ok',   LatLng(-6.7833, 38.9167), 'coastal'),
  _Pin('Babati',         25, 'ok',   LatLng(-4.2167, 35.7500), 'northern'),
  _Pin('Njombe',         18, 'ok',   LatLng(-9.3333, 34.7667), 'shighland'),
  _Pin('Songea',         14, 'ok',   LatLng(-10.6831, 35.6536), 'southern'),
];

// ── Hospital drill-down data ───────────────────────────────────────────────────

class _Hospital {
  const _Hospital(this.name, this.district, this.machines, this.active);
  final String name, district;
  final int machines, active;
}

const _dsmHospitals = [
  _Hospital('Muhimbili National Hospital',    'Ilala',      62, 58),
  _Hospital('Aga Khan Hospital',              'Kinondoni',  44, 44),
  _Hospital('Jakaya Kikwete Cardiac Inst.',   'Kinondoni',  38, 36),
  _Hospital('TMJ Hospital',                  'Kinondoni',  28, 26),
  _Hospital('CCBRT Disability Hospital',     'Kinondoni',  24, 22),
  _Hospital('Mwananyamala Regional',         'Kinondoni',  22, 20),
  _Hospital('Amana District Hospital',       'Ilala',      18, 16),
  _Hospital('Temeke District Hospital',      'Temeke',     16, 14),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class MachineMapScreen extends StatefulWidget {
  const MachineMapScreen({super.key});

  @override
  State<MachineMapScreen> createState() => _MachineMapScreenState();
}

class _MachineMapScreenState extends State<MachineMapScreen> {
  final _mapController = MapController();

  String _mapMode = 'normal'; // 'normal' | 'satellite' | 'terrain'
  final Set<String> _overlays = {'hospitals', 'alerts'};
  String _selectedZone = 'coastal';
  String _selectedRegion = 'dsm';
  String? _selectedHospital;
  bool _filterOpen = false;

  final Map<String, bool> _zoneExpanded = {
    'coastal': true, 'northern': false, 'lake': false,
    'central': false, 'shighland': false, 'southern': false,
  };
  final Set<String> _checkedZones = {'coastal'};

  // Live machine pins from API
  List<Machine> _liveMachines = [];

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    try {
      final machines = await MachineService.instance.mapPins();
      if (mounted) setState(() => _liveMachines = machines);
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Build live markers for machines that have GPS coordinates
  List<Marker> get _liveMarkers {
    return _liveMachines
        .where((m) => m.latitude != null && m.longitude != null)
        .map((m) {
      final color = switch (m.status) {
        MachineStatus.down         => AppColors.coral,
        MachineStatus.needsService => AppColors.amber,
        _                          => AppColors.teal,
      };
      return Marker(
        point: LatLng(m.latitude!, m.longitude!),
        width: 28, height: 28,
        child: Tooltip(
          message: '${m.model} · ${m.hospital}',
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
            ),
            child: const Icon(Symbols.medical_services, size: 12, color: Colors.white),
          ),
        ),
      );
    }).toList();
  }

  _Zone get _activeZone  => _zones.firstWhere((z) => z.key == _selectedZone);
  _Region get _activeRegion => _activeZone.regions
      .firstWhere((r) => r.key == _selectedRegion, orElse: () => _activeZone.regions.first);

  // ── Tile URL per map mode ─────────────────────────────────────────────────

  String get _tileUrl => switch (_mapMode) {
    'satellite' =>
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'terrain' =>
      'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    _ =>
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
  };

  List<String> get _tileSubdomains => switch (_mapMode) {
    'satellite' => const [],
    'terrain'   => const ['a', 'b', 'c'],
    _           => const ['a', 'b', 'c', 'd'],
  };

  String get _attribution => switch (_mapMode) {
    'satellite' => '© Esri',
    'terrain'   => '© OpenTopoMap (CC-BY-SA)',
    _           => '© CartoDB · © OpenStreetMap contributors',
  };

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
          // Filter overlay only needed for medium/narrow (wide shows it in bottom panel)
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

          // Map mode toggle
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
                for (final m in ['normal', 'satellite', 'terrain'])
                  _MapModeBtn(
                    label: m == 'normal' ? 'Street' : m[0].toUpperCase() + m.substring(1),
                    active: _mapMode == m,
                    onTap: () => setState(() => _mapMode = m),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Overlay chips
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
  //
  // Wide:   [Map ─ expanded] │ [Filter zones] │ [Zone details ◄ furthest right]
  // Medium: [Map ─ expanded] │ [Zone details]   (filter via top-bar overlay)
  // Narrow: [Map] stacked above [Zone details]

  Widget _buildWideLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: _buildRealMap()),
      _buildFilterTree(width: 240),
      _buildDrillDown(width: 280),
    ],
  );

  Widget _buildMediumLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: _buildRealMap()),
      _buildDrillDown(width: 260),
    ],
  );

  Widget _buildNarrowLayout() => Column(
    children: [
      Expanded(child: _buildRealMap()),
      SizedBox(height: 220, child: _buildDrillDown()),
    ],
  );

  // ── Real map ──────────────────────────────────────────────────────────────

  Widget _buildRealMap() {
    // Visible pins: either all or filtered to checked zones
    final visiblePins = _checkedZones.isEmpty
        ? _pins
        : _pins.where((p) => _checkedZones.contains(p.zone)).toList();

    final markers = _overlays.contains('hospitals')
        ? visiblePins.map((pin) => Marker(
            point: pin.coords,
            width: 110,
            height: 56,
            alignment: Alignment.bottomCenter,
            child: _MapMarker(
              pin: pin,
              selected: pin.zone == _selectedZone,
              onTap: () {
                final zone = _zones.firstWhere((z) => z.key == pin.zone);
                setState(() {
                  _selectedZone = pin.zone;
                  _selectedRegion = zone.regions.first.key;
                  _selectedHospital = null;
                  _zoneExpanded[pin.zone] = true;
                  _mapController.move(pin.coords, math.max(
                    _mapController.camera.zoom, 7.0));
                });
              },
            ),
          )).toList()
        : <Marker>[];

    return Stack(
      children: [
        // ── Base map (north-up, rotation locked) ──────────────────────────
        ClipRect(
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-6.37, 34.89),
              initialZoom: 5.8,
              initialRotation: 0,   // force north-up, no accidental rotation
              minZoom: 4.0,
              maxZoom: 16.0,
              interactionOptions: InteractionOptions(
                // allow pan + zoom only — rotation gesture disabled
                flags: InteractiveFlag.drag
                    | InteractiveFlag.flingAnimation
                    | InteractiveFlag.pinchMove
                    | InteractiveFlag.pinchZoom
                    | InteractiveFlag.scrollWheelZoom
                    | InteractiveFlag.doubleTapZoom,
              ),
            ),
              children: [
                TileLayer(
                  key: ValueKey(_mapMode),
                  urlTemplate: _tileUrl,
                  subdomains: _tileSubdomains,
                  userAgentPackageName: 'com.bienhypermed.app',
                ),
                MarkerLayer(markers: [...markers, ..._liveMarkers]),
                SimpleAttributionWidget(
                  source: Text(_attribution,
                    style: TextStyle(fontSize: 9, color: Colors.white54)),
                  backgroundColor: const Color(0xAA0F1117),
                ),
              ],
            ),
          ),

        // ── Floating controls (right edge) ─────────────────────────────────
        Positioned(
          right: 14,
          bottom: 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Satellite quick-toggle ──────────────────────────────────
              _FloatMapBtn(
                icon: _mapMode == 'satellite'
                    ? Symbols.map
                    : Symbols.satellite_alt,
                label: _mapMode == 'satellite' ? 'MAP' : 'SAT',
                active: _mapMode == 'satellite',
                tooltip: _mapMode == 'satellite'
                    ? 'Switch to street map'
                    : 'Switch to satellite',
                onTap: () => setState(() =>
                  _mapMode = _mapMode == 'satellite' ? 'normal' : 'satellite'),
              ),

              const SizedBox(height: 6),

              // ── Locate / reset ──────────────────────────────────────────
              _FloatMapBtn(
                icon: Symbols.my_location,
                tooltip: 'Reset to Tanzania overview',
                onTap: () => _mapController.move(
                  const LatLng(-6.37, 34.89), 6.0),
              ),

              const SizedBox(height: 6),

              // ── Zoom pad (+ and – joined) ───────────────────────────────
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
                    // Zoom in
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
                    // Zoom out
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
                children: _zones.map((zone) => _ZoneItem(
                  zone: zone,
                  expanded: _zoneExpanded[zone.key] == true,
                  checked: _checkedZones.contains(zone.key),
                  selectedRegion: _selectedZone == zone.key ? _selectedRegion : null,
                  onToggleExpand: () => setState(() =>
                    _zoneExpanded[zone.key] = !(_zoneExpanded[zone.key] ?? false)),
                  onToggleCheck: () => setState(() {
                    if (_checkedZones.contains(zone.key)) {
                      _checkedZones.remove(zone.key);
                    } else {
                      _checkedZones.add(zone.key);
                    }
                  }),
                  onSelectRegion: (regionKey) => setState(() {
                    _selectedZone = zone.key;
                    _selectedRegion = regionKey;
                    _selectedHospital = null;
                    // Fly to zone's first pin
                    final pin = _pins.firstWhere(
                      (p) => p.zone == zone.key,
                      orElse: () => _pins[0],
                    );
                    _mapController.move(pin.coords, 8.0);
                  }),
                )).toList(),
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
                    ? 'All 847 machines visible'
                    : '$_visibleCount / 847 selected',
                style: AppTheme.bodySm.copyWith(color: AppColors.teal, fontSize: 11.5)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _checkedZones
                    ..clear()
                    ..addAll(_zones.map((z) => z.key));
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

  int get _visibleCount {
    if (_checkedZones.isEmpty) return 847;
    return _zones
        .where((z) => _checkedZones.contains(z.key))
        .fold(0, (s, z) => s + z.totalMachines);
  }

  Widget _buildFilterOverlay() => Positioned(
    top: 48, left: 0, bottom: 0,
    child: Row(
      children: [
        SizedBox(width: 220, child: _buildFilterTree(width: 220)),
        GestureDetector(
          onTap: () => setState(() => _filterOpen = false),
          child: Container(width: 60, color: Colors.transparent),
        ),
      ],
    ),
  );

  // ── Drill-down panel ──────────────────────────────────────────────────────

  Widget _buildDrillDown({double? width}) {
    final zone   = _activeZone;
    final region = _activeRegion;

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
            // Zone header
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
                    Expanded(child: Text(zone.label,
                      style: AppTheme.bodyStrong.copyWith(fontSize: 13))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.tealSoft,
                        borderRadius: BorderRadius.circular(999)),
                      child: Text('${zone.totalMachines}',
                        style: AppTheme.monoXs.copyWith(color: AppColors.teal)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _DStat('${zone.regions.length}', 'REGIONS'),
                    const SizedBox(width: 14),
                    _DStat(
                      '${zone.regions.fold(0, (s, r) => s + r.districts.length)}',
                      'DISTRICTS'),
                    const SizedBox(width: 14),
                    _DStat('${zone.regions.length * 3 + 2}', 'HOSPITALS'),
                  ]),
                ],
              ),
            ),

            // Region list with progress bars
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text('REGIONS', style: AppTheme.monoXs)),
            ...zone.regions.map((r) {
              final isActive = r.key == _selectedRegion;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRegion = r.key;
                    _selectedHospital = null;
                  });
                  // Fly to a pin in this region
                  final pin = _pins.firstWhere(
                    (p) => p.zone == zone.key,
                    orElse: () => _pins[0],
                  );
                  _mapController.move(pin.coords, 8.0);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? context.pal.surface2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? context.pal.borderStrong : Colors.transparent)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(r.label, style: AppTheme.bodySm.copyWith(
                          color: isActive ? context.pal.text : context.pal.textMute,
                          fontWeight: FontWeight.w500, fontSize: 12.5)),
                        const Spacer(),
                        Text('${r.totalMachines}', style: AppTheme.monoXs.copyWith(
                          color: isActive ? AppColors.teal : context.pal.textDim)),
                      ]),
                      const SizedBox(height: 6),
                      ...r.districts.take(3).map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          SizedBox(
                            width: 70,
                            child: Text(d.label,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodySub.copyWith(fontSize: 10.5))),
                          const SizedBox(width: 6),
                          Expanded(child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.pal.surface3,
                              borderRadius: BorderRadius.circular(2)),
                            child: FractionallySizedBox(
                              widthFactor: math.min(1.0, d.machines / 150),
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(2)),
                              ),
                            ),
                          )),
                          const SizedBox(width: 6),
                          Text('${d.machines}', style: AppTheme.monoXs.copyWith(
                            fontSize: 9.5, color: context.pal.textDim)),
                        ]),
                      )),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 10),
            Container(height: 1, color: context.pal.border),

            // Hospital list
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(children: [
                Expanded(child: Text(
                  'HOSPITALS — ${region.label.toUpperCase()}',
                  style: AppTheme.monoXs,
                  overflow: TextOverflow.ellipsis)),
                Text('${_dsmHospitals.length}',
                  style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
              ])),
            ..._dsmHospitals.map((h) {
              final isSelected = _selectedHospital == h.name;
              return GestureDetector(
                onTap: () => setState(() =>
                  _selectedHospital = isSelected ? null : h.name),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.tealSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.teal.withValues(alpha: 0.4) : Colors.transparent)),
                  child: Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.tealSoft : context.pal.surface3,
                        borderRadius: BorderRadius.circular(6)),
                      child: Icon(Symbols.local_hospital, size: 14,
                        color: isSelected ? AppColors.teal : context.pal.textDim),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11.5,
                            color: isSelected ? context.pal.text : context.pal.textMute)),
                        Text(h.district, style: AppTheme.bodySub.copyWith(fontSize: 10)),
                      ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${h.machines}', style: AppTheme.bodyStrong.copyWith(
                        fontSize: 11.5,
                        color: isSelected ? AppColors.teal : context.pal.text)),
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

  // ── Bottom stats strip ────────────────────────────────────────────────────

  Widget _buildBottomStrip() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.pal.topbarBg,
        border: Border(top: BorderSide(color: context.pal.border))),
      child: Row(children: [
        const SizedBox(width: 16),
        for (final stat in [
          ('VISIBLE', '$_visibleCount'),
          ('HOSPITALS', '38'),
          ('DISTRICTS', '24'),
          ('OPERATIONAL', '${(_visibleCount * 0.92).round()}'),
          ('ISSUES', '${(_visibleCount * 0.08).round()}'),
        ]) ...[
          _BottomStat(label: stat.$1, value: stat.$2),
          Container(
            width: 1, height: 24, color: context.pal.border,
            margin: const EdgeInsets.symmetric(horizontal: 14)),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () {},
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

// ── Map marker widget ─────────────────────────────────────────────────────────

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.pin, required this.selected, required this.onTap});
  final _Pin pin;
  final bool selected;
  final VoidCallback onTap;

  Color get _color => switch (pin.status) {
    'warn' => AppColors.amber,
    'down' => AppColors.coral,
    _      => AppColors.teal,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final dotSize = selected ? 18.0 : 11.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label chip
          if (selected || pin.count > 60)
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
              child: Text('${pin.city} · ${pin.count}',
                style: AppTheme.monoXs.copyWith(
                  fontSize: 9.5,
                  color: selected ? context.pal.text : context.pal.textMute,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                )),
            )
          else
            const SizedBox(height: 16),
          const SizedBox(height: 3),
          // Dot with optional pulse ring
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
                child: selected
                    ? null
                    : null,
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
    required this.zone,      required this.expanded,
    required this.checked,   required this.selectedRegion,
    required this.onToggleExpand, required this.onToggleCheck,
    required this.onSelectRegion,
  });
  final _Zone zone;
  final bool expanded, checked;
  final String? selectedRegion;
  final VoidCallback onToggleExpand, onToggleCheck;
  final ValueChanged<String> onSelectRegion;

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
              Expanded(child: Text(zone.label, style: AppTheme.bodySm.copyWith(
                color: checked ? context.pal.text : context.pal.textMute,
                fontWeight: FontWeight.w500, fontSize: 12.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: context.pal.surface3,
                  borderRadius: BorderRadius.circular(999)),
                child: Text('${zone.totalMachines}', style: AppTheme.monoXs.copyWith(
                  fontSize: 10,
                  color: checked ? AppColors.teal : context.pal.textDim))),
            ]),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Column(
              children: zone.regions.map((r) {
                final isActive = r.key == selectedRegion;
                return GestureDetector(
                  onTap: () => onSelectRegion(r.key),
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
                      Expanded(child: Text(r.label, style: AppTheme.bodySm.copyWith(
                        color: isActive ? AppColors.teal : context.pal.textMute,
                        fontSize: 12))),
                      Text('${r.totalMachines}', style: AppTheme.monoXs.copyWith(
                        fontSize: 9.5,
                        color: isActive ? AppColors.teal : context.pal.textDim)),
                    ]),
                  ),
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
