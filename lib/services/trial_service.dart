import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

enum TrialState { valid, expired, pending, noLicense, networkError }

class TrialStatus {
  const TrialStatus({
    required this.state,
    this.expiresAt,
    this.daysLeft,
    this.customerName,
    this.message,
    this.installId,
  });

  final TrialState state;
  final DateTime?  expiresAt;
  final int?       daysLeft;
  final String?    customerName;
  final String?    message;
  final String?    installId;

  bool get isValid    => state == TrialState.valid;
  bool get isPending  => state == TrialState.pending;
  bool get showBanner => isValid && (daysLeft ?? 999) <= 7;
}

class TrialService {
  TrialService._();
  static final instance = TrialService._();

  static const _installIdKey = 'hypermed_install_id';

  // Central license server URL.
  // For production, rebuild with:
  //   flutter build windows --dart-define=LICENSE_SERVER_URL=https://your-app.railway.app/api/v1
  static const _licenseServerBase = String.fromEnvironment(
    'LICENSE_SERVER_URL',
    defaultValue: 'http://hypermed.local:8080/api/v1',
  );

  // Hardcoded fallback — used only when the license server is unreachable.
  // Update this date before each demo build.
  static final _fallbackExpiry = DateTime(2026, 12, 31);

  final _storage = const FlutterSecureStorage();

  // Own Dio instance pointing to the license server (separate from main API).
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _licenseServerBase,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'Accept': 'application/json'},
  ));

  // ── Install ID ─────────────────────────────────────────────────────────────

  Future<String> _getOrCreateInstallId() async {
    var id = await _storage.read(key: _installIdKey);
    if (id != null) return id;
    id = _generateUuid();
    await _storage.write(key: _installIdKey, value: id);
    return id;
  }

  String _generateUuid() {
    final rng   = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<TrialStatus> check() async {
    final installId = await _getOrCreateInstallId();
    try {
      final res = await _dio.get(
        '/license/check',
        queryParameters: {'install_id': installId},
      ).timeout(const Duration(seconds: 8));

      final data = ApiClient.unwrap(res);
      if (data is! Map) return _fallback(installId);

      final status     = data['status'] as String? ?? '';
      final expiresRaw = data['expires_at'] as String?;
      final expires    = expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;
      final customer   = data['customer'] as String?;
      final message    = data['message'] as String?;

      switch (status) {
        case 'active':
          final now = DateTime.now();
          return TrialStatus(
            state:        TrialState.valid,
            expiresAt:    expires,
            daysLeft:     expires?.difference(now).inDays,
            customerName: customer,
            installId:    installId,
          );
        case 'pending':
          return TrialStatus(
            state:        TrialState.pending,
            customerName: customer,
            message:      message,
            installId:    installId,
          );
        case 'expired':
          return TrialStatus(
            state:        TrialState.expired,
            expiresAt:    expires,
            customerName: customer,
            message:      message,
            installId:    installId,
          );
        case 'revoked':
          return TrialStatus(
            state:        TrialState.expired,
            expiresAt:    expires,
            customerName: customer,
            message:      message ?? 'This license has been revoked. Contact sales@hypermed.app.',
            installId:    installId,
          );
        case 'unknown':
          // First time this installation is seen — auto-submit a trial request.
          return await _requestTrial(installId);
        default:
          return _fallback(installId);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return _fallback(installId);
      }
      if ((e.response?.statusCode ?? 0) >= 400) {
        return _fallback(installId);
      }
      return _fallback(installId);
    } catch (_) {
      return _fallback(installId);
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<TrialStatus> _requestTrial(String installId) async {
    try {
      await _dio.post('/license/request', data: {
        'install_id':  installId,
        'machine_name': Platform.localHostname,
      }).timeout(const Duration(seconds: 8));

      return TrialStatus(
        state:     TrialState.pending,
        message:   'Your trial request has been submitted. Please wait for approval.',
        installId: installId,
      );
    } catch (_) {
      // If the request itself fails, fall back to hardcoded date.
      return _fallback(installId);
    }
  }

  TrialStatus _fallback(String installId) {
    final now  = DateTime.now();
    final diff = _fallbackExpiry.difference(now).inDays;
    if (now.isAfter(_fallbackExpiry)) {
      return TrialStatus(
        state:     TrialState.expired,
        expiresAt: _fallbackExpiry,
        message:   'Your trial period has ended. Please contact us to continue.',
        installId: installId,
      );
    }
    return TrialStatus(
      state:     TrialState.valid,
      expiresAt: _fallbackExpiry,
      daysLeft:  diff,
      installId: installId,
    );
  }
}
