import 'package:bienhypermed/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('orders numerically, not lexically', () {
      expect(compareVersions('1.10.0', '1.9.3'), greaterThan(0));
      expect(compareVersions('1.2.0', '1.2.1'), lessThan(0));
      expect(compareVersions('2.0.0', '2.0.0'), 0);
    });
    test('ignores build/suffix and pads missing parts', () {
      expect(compareVersions('1.4.0+12', '1.4.0'), 0);
      expect(compareVersions('1.4', '1.4.0'), 0);
      expect(compareVersions('1.4.1-beta', '1.4.0'), greaterThan(0));
    });
  });

  group('UpdateManifest', () {
    final json = {
      'version': '1.4.0',
      'min_version': '1.2.0',
      'notes': 'Faster lists',
      'platforms': {
        'windows': {'url': 'https://x/Hypermed-Setup-1.4.0.exe', 'sha256': 'ABC', 'size': 10},
      },
    };
    test('picks the current platform asset and lowercases the hash', () {
      final m = UpdateManifest.fromJson(json, 'windows');
      expect(m.version, '1.4.0');
      expect(m.minVersion, '1.2.0');
      expect(m.asset!.sha256, 'abc');
      expect(m.asset!.size, 10);
    });
    test('no asset for a platform the release does not ship', () {
      expect(UpdateManifest.fromJson(json, 'linux').asset, isNull);
    });
  });

  test('UpdateMode.parse round-trips and rejects junk', () {
    for (final m in UpdateMode.values) {
      expect(UpdateMode.parse(m.name), m);
    }
    expect(UpdateMode.parse('user'), isNull);
    expect(UpdateMode.parse(null), isNull);
  });
}
