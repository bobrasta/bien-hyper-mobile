import '../models/staff_member.dart';
import 'api_client.dart';

export '../models/staff_member.dart';

class StaffService {
  StaffService._();
  static final instance = StaffService._();
  final _dio = ApiClient.instance.dio;

  // In-memory cache — staff rarely changes within a session.
  List<StaffMember>? _cache;
  Future<List<StaffMember>>? _inflight;

  /// Returns cached staff list; fetches only once per session.
  /// Pass [force] to bypass the cache (e.g. after creating/editing a member).
  Future<List<StaffMember>> list({String? group, bool force = false}) async {
    if (group == null && !force && _cache != null) return _cache!;
    // Deduplicate concurrent callers — if a fetch is already in flight, reuse it
    if (group == null && !force && _inflight != null) return _inflight!;

    final future = _fetch(group: group);
    if (group == null) _inflight = future;

    try {
      final result = await future;
      if (group == null) {
        _cache    = result;
        _inflight = null;
      }
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

  /// Call after adding/editing a member so the next list() re-fetches.
  void invalidateCache() { _cache = null; _inflight = null; }

  Future<StaffMember> get(int id) async {
    final res = await _dio.get('/staff/$id');
    return StaffMember.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<StaffMember> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/staff', data: data);
    return StaffMember.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<StaffMember> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/staff/$id', data: data);
    return StaffMember.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/staff/$id');
}
