import 'google_oidc_service.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/service_error.dart';
import '../models/sync_info.dart';
import '../models/user_settings.dart';

import 'core/store.dart' show isProfileCompleted;
import 'local_services.dart';
import 'service_gateway.dart';

/// Compatibility facade for the screens. Calls local Dart services directly;
/// it never creates an HTTP client, a socket or a localhost connection.
class Api extends ChangeNotifier {
  Api({ServiceGateway? gateway}) : _gateway = gateway ?? LocalServices() {
    ready = _initialize();
  }
  final ServiceGateway _gateway;
  late final Future<void> ready;
  bool initializing = true;
  String? initializationError;
  bool _disposed = false;
  Map<String, dynamic> _appearance = {};
  Future<void> _initialize() async {
    try {
      final appearance = await _gateway.execute('GET', '/appearance');
      if (_disposed) return;
      if (appearance is Map) {
        _appearance = appearancePreferences(appearance);
      }
      final session = await _gateway.execute('GET', '/auth/session');
      if (_disposed) return;
      token = session['token'] as String?;
      if (token != null) await refresh();
      initializationError = null;
    } catch (_) {
      initializationError =
          'Não foi possível ler os dados locais. Tente novamente.';
    } finally {
      initializing = false;
      _notify();
    }
  }

  Future<void> retryInitialization() async {
    initializing = true;
    initializationError = null;
    _notify();
    await _initialize();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String? token;
  Map<String, dynamic>? me;
  bool get isProfileComplete => me != null && isProfileCompleted(me!);
  Map<String, dynamic> get settings => {
    ...defaults,
    ..._appearance,
    ...Map<String, dynamic>.from(me?['settings'] ?? {}),
  };
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      return await _gateway.execute(
        method,
        path,
        data: data ?? {},
        token: token ?? '',
      );
    } on ServiceError catch (e) {
      if (e.status == 401 && token != null) {
        token = null;
        me = null;
        _notify();
      }
      throw ApiException(e.message, e.status);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Não foi possível acessar os dados neste dispositivo. Tente novamente.',
      );
    }
  }

  Future<void> login(
    String email,
    String password, {
    Map<String, dynamic>? registration,
  }) async {
    await ready;
    final result = await request(
      'POST',
      registration == null ? '/auth/login' : '/auth/register',
      {'email': email, 'password': password, ...?registration},
    );
    token = result['token'];
    try {
      await refresh();
    } catch (_) {
      token = null;
      me = null;
      _notify();
      rethrow;
    }
  }

  Future<void> loginGoogle(
    String idToken, {
    Map<String, dynamic>? registration,
  }) async {
    await ready;
    final result = await request('POST', '/auth/google', {
      'id_token': idToken,
      ...?registration,
    });
    token = result['token'];
    try {
      await refresh();
    } catch (_) {
      _clearSession();
      rethrow;
    }
  }

  Future<void> deleteGoogleAccount(String idToken) async {
    await request('DELETE', '/account/google', {'id_token': idToken});
    _clearSession();
  }

  Future<void> loginApple(
    String idToken, {
    Map<String, dynamic>? registration,
  }) async {
    await ready;
    final result = await request('POST', '/auth/apple', {
      'id_token': idToken,
      ...?registration,
    });
    token = result['token'];
    try {
      await refresh();
    } catch (_) {
      _clearSession();
      rethrow;
    }
  }

  Future<void> deleteAppleAccount(String idToken) async {
    await request('DELETE', '/account/apple', {'id_token': idToken});
    _clearSession();
  }

  Future<void> refresh() async {
    me = Map<String, dynamic>.from(await request('GET', '/me'));
    _appearance = appearancePreferences(settings);
    _notify();
  }

  Future<void> updateSettings(Map<String, dynamic> changes) async {
    await request('PATCH', '/settings', changes);
    await refresh();
  }

  Future<SyncInfo> storageStatus() => _gateway.syncInfo();
  Future<void> synchronize() async {
    await _gateway.synchronize();
    _notify();
  }

  Future<void> logout() async {
    if (token != null) await request('POST', '/auth/logout');
    _clearSession();
  }

  Future<void> deleteAccount(String password) async {
    await request('DELETE', '/account', {'password': password});
    _clearSession();
  }

  void _clearSession() {
    if (me?['auth_provider'] == 'google') {
      unawaited(GoogleOidcService().signOut().catchError((Object _) {}));
    }
    token = null;
    me = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_gateway.close());
    super.dispose();
  }
}
