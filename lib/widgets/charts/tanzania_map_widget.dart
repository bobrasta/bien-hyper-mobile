import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/hospital.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';

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

  @override
  Widget build(BuildContext context) {
    final pinned = widget.hospitals.where((h) => h.latitude != 0 && h.longitude != 0).toList();
    final regions = widget.hospitals.map((h) => h.region).where((r) => r != '—').toSet().length;
    final machineTotal = widget.totalMachines ?? pinned.fold<int>(0, (s, h) => s + h.machineCount);

    return SizedBox(
      height: 320,
      child: Stack(
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
                TileLayer(
                  // CartoDB's dark_all basemap now requires a registered API
                  // key — without one every tile renders as a plastered
                  // "API KEY REQUIRED" watermark instead of a map. Standard
                  // OSM tiles need no key/registration for this traffic level.
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bienhypermed.app',
                ),
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
                  source: const Text('© CartoDB · © OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Colors.white54)),
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

          // Bottom stats strip
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xD90F1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.pal.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(label: 'REGIONS', value: '$regions'),
                  _Stat(label: 'HOSPITALS', value: '${widget.hospitals.length}'),
                  _Stat(label: 'MACHINES', value: '$machineTotal'),
                  _Stat(
                    label: 'UPTIME',
                    value: widget.uptimePct != null
                        ? '${(widget.uptimePct! * 100).toStringAsFixed(0)}%'
                        : '—',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.monoXs.copyWith(fontSize: 10)),
        Text(value,
          style: AppTheme.bodyStrong.copyWith(
            fontSize: 14,
            fontFeatures: [const FontFeature.tabularFigures()],
          )),
      ],
    );
  }
}
