import '../models/email.dart';
import 'api_client.dart';

class EmailService {
  EmailService._();
  static final instance = EmailService._();
  final _dio = ApiClient.instance.dio;

  // Stale-while-revalidate screen cache — see MachineService for the full
  // reasoning. EmailScreen fetches a different folder's list via a
  // different method (inbox()/sent()/drafts()/folder()) rather than one
  // method with a folder param, so cache by the same folder key the
  // screen itself uses ('inbox', 'sent', 'drafts', or a server folder
  // name) instead of a single unfiltered-list field. Only inbox()'s fully
  // unfiltered call (no unread/search/accountId) is cached — a filtered
  // inbox view showing stale data from a different filter would be
  // misleading, same reasoning as MachineService's own default-list cache.
  static final Map<String, List<Email>> cachedByFolder = {};

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<List<Email>> inbox({bool? unread, String? search, int? accountId}) async {
    final res = await _dio.get('/emails/inbox', queryParameters: {
      if (unread == true) 'unread':     '1',
      'search':     ?search,
      'account_id': ?accountId,
    });
    final (data, _) = ApiClient.unwrapList(res);
    final emails = data.map((j) => Email.fromJson(j as Map<String, dynamic>)).toList();
    if (unread != true && search == null && accountId == null) {
      cachedByFolder['inbox'] = emails;
    }
    return emails;
  }

  Future<List<Email>> sent()   => _folder('sent');
  Future<List<Email>> drafts() => _folder('drafts');

  Future<List<Email>> folder(String name) async {
    final res = await _dio.get('/emails/folder/$name');
    final (data, _) = ApiClient.unwrapList(res);
    final emails = data.map((j) => Email.fromJson(j as Map<String, dynamic>)).toList();
    cachedByFolder[name] = emails;
    return emails;
  }

  Future<List<Email>> _folder(String name) async {
    final res = await _dio.get('/emails/$name');
    final (data, _) = ApiClient.unwrapList(res);
    final emails = data.map((j) => Email.fromJson(j as Map<String, dynamic>)).toList();
    cachedByFolder[name] = emails;
    return emails;
  }

  Future<Email> get(int id) async {
    final res = await _dio.get('/emails/$id');
    return Email.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<int> unreadCount({bool noCache = false}) async {
    try {
      final res = await _dio.get('/emails/unread-count',
          options: noCache ? ApiClient.noCache : null);
      final raw = ApiClient.unwrap(res);
      if (raw is Map) return (raw['unread'] as num? ?? 0).toInt();
    } catch (_) {}
    return 0;
  }

  Future<List<String>> folders() async {
    try {
      final res = await _dio.get('/emails/folders');
      final (data, _) = ApiClient.unwrapList(res);
      return data.map((f) => f.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  Future<void> sync({String folder = 'INBOX', int limit = 50}) =>
      _dio.post('/emails/sync', data: {'folder': folder, 'limit': limit});

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> compose({
    required String to,
    String? cc,
    String? bcc,
    required String subject,
    required String body,
  }) =>
      _dio.post('/emails/compose', data: {
        'to':      _splitAddrs(to),
        if (cc  != null && cc.trim().isNotEmpty)  'cc':  _splitAddrs(cc),
        if (bcc != null && bcc.trim().isNotEmpty) 'bcc': _splitAddrs(bcc),
        'subject': subject,
        'body':    body,
      });

  Future<void> reply(int id, {required String body, bool replyAll = false}) =>
      _dio.post('/emails/$id/reply', data: {'body': body, 'reply_all': replyAll});

  Future<void> forward(int id, {required String to, required String body}) =>
      _dio.post('/emails/$id/forward', data: {'to': _splitAddrs(to), 'body': body});

  static List<Map<String, String>> _splitAddrs(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)
          .map((e) => {'email': e}).toList();

  Future<void> toggleRead(int id)  => _dio.patch('/emails/$id/read');
  Future<void> toggleFlag(int id)  => _dio.patch('/emails/$id/flag');
  Future<void> delete(int id)      => _dio.delete('/emails/$id');
}
