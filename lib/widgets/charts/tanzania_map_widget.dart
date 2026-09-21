import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/hospital.dart';
import '../../theme/app_colors.dart';

// Section 2: "Satellite, Terrain, Light/Dark" — the map's own visual-style
// switcher, distinct from the dashboard card's Machines/Alerts/Technicians
// *data*-layer toggles (which stay in the card header). Dark is a
// ColorFiltered inversion of the same OSM tiles rather than a separate dark
// tile provider — CartoDB's dark_all basemap now requires a registered API
// key (see the TileLayer comment below), and Esri/OpenTopoMap have no dark
// variant that doesn't require one either.
enum MapStyle { light, dark, satellite, terrain }

/// Real interactive fleet map for the dashboard — same OSM/CartoDB tile
/// engine as MachineMapScreen, plotting every hospital that has real GPS
/// coordinates as a status-colored pin. Replaces the old hand-drawn
/// Tanzania-outline painter, which only ever showed the top-5-by-revenue
/// hospitals and a handful of hardcoded stats (REGIONS/ACTIVE TECHS never
/// reflected real data).
class FleetMapWidget extends StatefulWidget {
  const FleetMapWidget({
    super.key,
    required this.hospitals,
    this.totalMachines,
    this.uptimePct,
    this.borderRadius,
  });
  final List<Hospital> hospitals;
  final int? totalMachines;
  final double? uptimePct;
  // Defaults to all-corners rounded (existing behavior); pass a
  // corner-specific radius when the map sits directly under a card header
  // with its own square top edge, so the two don't double-round.
  final BorderRadius? borderRadius;

  @override
  State<FleetMapWidget> createState() => _FleetMapWidgetState();
}

class _FleetMapWidgetState extends State<FleetMapWidget> {
  final _mapController = MapController();
  MapStyle _style = MapStyle.light;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Color _statusColor(Hospital h) {
    if (h.machineCount == 0) return AppColors.amber;
    if (h.machinesOperational == h.machineCount) return AppColors.teal;
    if (h.machinesOperational == 0) return AppColors.coral;
    return AppColors.amber;
  }

  void _zoomBy(double delta) {
    final z = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (z + delta).clamp(4.0, 12.0));
  }

  // Esri World Imagery and OpenTopoMap are both free, no-API-key XYZ tile
  // sources at this traffic level — same reasoning as the standard OSM
  // tiles' own comment below. No dark-tile provider fits that bar (see the
  // MapStyle doc comment), so Dark reuses the light tiles under a
  // ColorFiltered inversion instead.
  String get _tileUrl => switch (_style) {
    MapStyle.satellite => 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapStyle.terrain => 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    MapStyle.light || MapStyle.dark => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  };

  String get _attribution => switch (_style) {
    MapStyle.satellite => '© Esri, Maxar, Earthstar Geographics',
    MapStyle.terrain => '© OpenTopoMap (CC-BY-SA) · © OpenStreetMap contributors',
    MapStyle.light || MapStyle.dark => '© OpenStreetMap contributors',
  };

  @override
  Widget build(BuildContext context) {
    final pinned = widget.hospitals.where((h) => h.latitude != 0 && h.longitude != 0).toList();

    Widget tiles = TileLayer(urlTemplate: _tileUrl, userAgentPackageName: 'com.bienhypermed.app');
    if (_style == MapStyle.dark) {
      // Simulated dark mode: invert + hue-rotate the same light tiles
      // rather than depending on a dark tile provider (see class doc).
      tiles = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: tiles,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(AppColors.rLg),
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-6.37, 34.89),
              initialZoom: 5.4,
              initialRotation: 0,
              minZoom: 4.0,
              maxZoom: 12.0,
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
              tiles,
              MarkerLayer(markers: [
                for (final h in pinned)
                  Marker(
                    point: LatLng(h.latitude, h.longitude),
                    width: 20,
                    height: 20,
                    child: Tooltip(
                      message: '${h.name} · ${h.machinesOperational}/${h.machineCount}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: _statusColor(h),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: _statusColor(h).withValues(alpha: 0.5), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
              ]),
              SimpleAttributionWidget(
                source: Text(_attribution, style: const TextStyle(fontSize: 9, color: Colors.white54)),
                backgroundColor: const Color(0xAA0F1117),
              ),
            ],
          ),
        ),

        // Zoom controls
        Positioned(
          right: 10,
          top: 10,
          child: Column(children: [
            _ZoomBtn(icon: Symbols.add, onTap: () => _zoomBy(1)),
            const SizedBox(height: 4),
            _ZoomBtn(icon: Symbols.remove, onTap: () => _zoomBy(-1)),
          ]),
        ),

        // Section 2: "the layer switcher stays inside the map" — the map's
        // own visual style, separate from the dashboard card's data-layer
        // toggles (Machines/Alerts/Technicians) in the card header.
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xD90F1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _StyleBtn(icon: Symbols.light_mode, tooltip: 'Light', active: _style == MapStyle.light, onTap: () => setState(() => _style = MapStyle.light)),
              _StyleBtn(icon: Symbols.dark_mode, tooltip: 'Dark', active: _style == MapStyle.dark, onTap: () => setState(() => _style = MapStyle.dark)),
              _StyleBtn(icon: Symbols.satellite_alt, tooltip: 'Satellite', active: _style == MapStyle.satellite, onTap: () => setState(() => _style = MapStyle.satellite)),
              _StyleBtn(icon: Symbols.terrain, tooltip: 'Terrain', active: _style == MapStyle.terrain, onTap: () => setState(() => _style = MapStyle.terrain)),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xD90F1117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, size: 15, color: Colors.white70),
    ),
  );
}

class _StyleBtn extends StatelessWidget {
  const _StyleBtn({required this.icon, required this.tooltip, required this.active, required this.onTap});
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: active ? AppColors.teal.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 14, color: active ? AppColors.teal : Colors.white70),
      ),
    ),
  );
}
