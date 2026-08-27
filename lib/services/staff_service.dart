import 'package:flutter/foundation.dart';
import '../models/staff_member.dart';
import 'api_client.dart';

export '../models/staff_member.dart';

class StaffService {
  StaffService._();
  static final instance = StaffService._();
  final _dio = ApiClient.instance.dio;

  /// Live staff list — the real source of truth. `update()`/`create()`/
  /// `delete()` patch this immediately on success, so every screen that
  /// renders from it (via ValueListenableBuilder) reflects a change the
  /// instant it happens, without needing to navigate away and back.
  final ValueNotifier<List<StaffMember>> staffNotifier = ValueNotifier<List<StaffMember>>([]);

  bool _loaded = false;
  Future<List<StaffMember>>? _inflight;

  /// Returns the live list; fetches once per session unless [force].
  /// Pass [group] for a one-off filtered fetch that bypasses/doesn't
  /// affect the shared cache (used sparingly — most callers want the
  /// unfiltered live list and filter client-side).
  Future<List<StaffMember>> list({String? group, bool force = false}) async {
    if (group != null) return _fetch(group: group);
    if (!force && _loaded) return staffNotifier.value;
    if (!force && _inflight != null) return _inflight!;

    final future = _fetch();
    _inflight = future;
    try {
      final result = await future;
      staffNotifier.value = result;
      _loaded = true;
      _inflight = null;
      return result;
    } catch (_) {
      _inflight = null;
      rethrow;
    }
  }

  Future<List<StaffMember>> _fetch({String? group}) async {
    final res = await _dio.get('/staff', queryParameters: {
      'group': ?group,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => StaffMember.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Forces the next list() to re-fetch. Rarely needed now that
  /// create/update/delete patch staffNotifier directly — kept for callers
  /// that mutate staff through some other path (e.g. role/permission
  /// changes made via the Role Builder, not this service).
  void invalidateCache() { _loaded = false; }

  Future<StaffMember> get(int id) async {
    final res = await _dio.get('/staff/$id');
    return StaffMember.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<StaffMember> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/staff', data: data);
    final created = StaffMember.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
    staffNotifier.value = [...staffNotifier.value, created];
    return created;
  }

  Future<StaffMember> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/staff/$id', data: data);
    final updated = StaffMember.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
    staffNotifier.value = [
      for (final m in staffNotifier.value) if (m.id == id) updated else m,
    ];
    return updated;
  }

  Future<void> delete(int id) async {
    await _dio.delete('/staff/$id');
    staffNotifier.value = staffNotifier.value.where((m) => m.id != id).toList();
  }

  /// Resets the member's password back to the default they were invited with.
  Future<void> resetPassword(int id) => _dio.post('/staff/$id/reset-password');
}
