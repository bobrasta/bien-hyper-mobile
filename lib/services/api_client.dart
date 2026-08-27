import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import '../main.dart';
import 'auth_service.dart';

/// Authenticated Dio instance — automatically attaches Bearer token
/// and signs the user out on 401.
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  // Default points at the Railway-hosted backend so every device (phone,
  // tablet, laptop) reaches the same real data without extra build flags —
  // set for the multi-device demo. Override back to local dev with:
  //   flutter run --dart-define=API_BASE_URL=http://hypermed.local:8080/api/v1
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hypermed-api-production.up.railway.app/api/v1',
  );

  // In-memory cache store shared across all requests — 10 MB cap.
  static final _cacheStore = MemCacheStore(maxSize: 10 * 1024 * 1024);

  static final _globalCacheOptions = CacheOptions(
    store: _cacheStore,
    policy: CachePolicy.request,
    hitCacheOnErrorExcept: [401, 403],
    maxStale: const Duration(minutes: 5),
    priority: CachePriority.normal,
  );

  /// Returns `Options` that cache the response for [ttl].
  /// Pass to a specific `_dio.get(...)` call to override the global 5-min default.
  static Options cachingOptions(Duration ttl) => CacheOptions(
        store: _cacheStore,
        policy: CachePolicy.request,
        hitCacheOnErrorExcept: [401, 403],
        maxStale: ttl,
        priority: CachePriority.normal,
      ).toOptions();

  /// Bypass cache entirely — use for polling / realtime endpoints.
  static Options get noCache => CacheOptions(
        store: _cacheStore,
        policy: CachePolicy.noCache,
      ).toOptions();

  late final Dio dio = _build();

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout:    const Duration(seconds: 15),
      headers: {
        'Accept':          'application/json',
        'Accept-Encoding': 'gzip',
        'Connection':      'keep-alive',
      },
    ));

    d.interceptors.add(DioCacheInterceptor(options: _globalCacheOptions));

    // Log only in debug mode — responseBody/requestBody serialise the entire
    // payload to a String on the UI thread; disable them to avoid blocking renders.
    assert(() {
      d.interceptors.add(LogInterceptor(
        requestHeader:  false,
        requestBody:    false,  // too slow for large payloads
        responseHeader: false,
        responseBody:   false,  // too slow for large payloads
        error:          true,
        logPrint: (o) => dev.log(o.toString(), name: 'API'),
      ));
      return true;
    }());

    // Inject auth token on every request
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = authTokenNotifier.value;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final status  = error.response?.statusCode;
        final path    = error.requestOptions.path;
        final body    = error.response?.data;
        dev.log('API $status $path — ${error.type}: ${error.message}', name: 'API');
        if (body != null) dev.log('  body: $body', name: 'API');
        // Only force-logout when the token used for THIS request is still the
        // active token. A stale in-flight request arriving after a fresh login
        // will have a different (old) Authorization header — don't wipe the
        // new token in that case.
        if (status == 401) {
          final usedBearer    = error.requestOptions.headers['Authorization'] as String?;
          final currentToken  = authTokenNotifier.value;
          if (currentToken != null && usedBearer == 'Bearer $currentToken') {
            AuthService.instance.clearToken();
            authTokenNotifier.value = null;
          }
        }
        handler.next(error);
      },
    ));

    return d;
  }

  /// Unwraps the standard Laravel `{ "data": ... }` envelope.
  /// Falls back to the raw body if it isn't a map with a "data" key.
  static dynamic unwrap(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  /// Unwraps a paginated response and returns the list + meta.
  /// Handles three server shapes:
  ///   {"data": [...], "meta": {...}}  — standard Laravel resource collection
  ///   {"data": [...]}                 — resource collection, no meta
  ///   [...]                           — raw JSON array (no envelope)
  static (List<dynamic>, Map<String, dynamic>?) unwrapList(Response res) {
    final body = res.data;

    // Raw JSON array — server skipped the envelope
    if (body is List) return (body, null);

    if (body is! Map) {
      dev.log('unwrapList: unexpected body type ${body.runtimeType}', name: 'API');
      return (<dynamic>[], null);
    }

    final raw  = body['data'];
    if (raw is List) {
      final meta = body['meta'] as Map<String, dynamic>?;
      return (raw, meta);
    }

    // data field is a Map or null — single resource or empty
    if (raw != null) {
      dev.log('unwrapList: data is ${raw.runtimeType}, wrapping as single-item list', name: 'API');
      return ([raw], null);
    }

    return (<dynamic>[], null);
  }
}
