import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

// Map base layers shared by every map in the app (dashboard fleet map,
// Machines map view). All free, no-API-key XYZ sources at this traffic
// level: OSM standard tiles, Esri World Imagery, OpenTopoMap. There is no
// keyless dark provider (CartoDB's dark_all now requires a registered key —
// it was showing "API key required" on the Machines map), so Dark is the
// light OSM tiles under a ColorFiltered inversion.
enum MapStyle { light, dark, satellite, terrain }

extension MapStyleX on MapStyle {
  String get label => switch (this) {
    MapStyle.light => 'Light',
    MapStyle.dark => 'Dark',
    MapStyle.satellite => 'Satellite',
    MapStyle.terrain => 'Terrain',
  };

  String get tileUrl => switch (this) {
    MapStyle.satellite => 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapStyle.terrain => 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    MapStyle.light || MapStyle.dark => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  };

  String get attribution => switch (this) {
    MapStyle.satellite => '© Esri, Maxar, Earthstar Geographics',
    MapStyle.terrain => '© OpenTopoMap (CC-BY-SA) · © OpenStreetMap contributors',
    MapStyle.light || MapStyle.dark => '© OpenStreetMap contributors',
  };
}

/// The base tile layer for [style] (dark = inverted light tiles).
Widget mapTileLayer(MapStyle style) {
  Widget tiles = TileLayer(
    key: ValueKey(style),
    urlTemplate: style.tileUrl,
    userAgentPackageName: 'com.bienhypermed.app',
  );
  if (style == MapStyle.dark) {
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
  return tiles;
}
