import 'apple_oidc_service.dart';
import 'google_oidc_service.dart';

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_info.dart';
import 'domain_services.dart';
import 'remote_provider.dart';
import 'service_gateway.dart';

/// The only persistence entry point. All app data is one versioned JSON value
/// written with SharedPreferencesAsync, including accounts and pending changes.
class LocalServices implements ServiceGateway {
  LocalServices({
    SharedPreferencesAsync? preferences,
    this.provider,
    GoogleTokenVerifier? googleVerifier,
    AppleTokenVerifier? appleVerifier,
    DateTime Function()? clock,
  }) : _googleVerifier = googleVerifier ?? GoogleTokenVerifier(),
       _appleVerifier = appleVerifier ?? AppleTokenVerifier(),
       _preferences = preferences,
       _clock = clock;

  final GoogleTokenVerifier _googleVerifier;
  final AppleTokenVerifier _appleVerifier;
  static const storageKey = 'tevi.data.v1';
  // Serialize all instances in this isolate, reading fresh preferences each time.
  static Future<void>? _tail;
  SharedPreferencesAsync? _preferences;
  final DateTime Function()? _clock;
  RemoteProvider? provider;
  bool _closed = false;
    ServiceStore? _cachedStore;
  bool _initialized = false;

  Future<T> _serial<T>(Future<T> Function(ServiceStore store) action) {
    if (_closed) return Future.error(StateError('Serviços encerrados.'));
    final result = Completer<T>();
    late final Future<void> pending;
    pending = (_tail ?? Future<void>.value()).then((_) async {
      try {
        final preferences = _preferences ??= SharedPreferencesAsync();
        if (!_initialized) {
          final document = await preferences.getString(storageKey);
          _cachedStore = ServiceStore(clock: _clock);
          if (document != null) _cachedStore!.restore(document);
          _initialized = true;
        }
        final store = _cachedStore!;
        store.clearDirty();
        T? value;
        Object? failure;
        StackTrace? trace;
        try {
          value = await action(store);
        } catch (error, stack) {
          // Domain rollback retains authentication attempt counters. Persist
          // these too, so restarting the app does not reset the rate limit.
          failure = error;
          trace = stack;
        }
        if (store.isDirty) {
          final next = store.snapshot();
          await preferences.setString(storageKey, next);
          store.clearDirty();
        }
        if (failure != null) Error.throwWithStackTrace(failure, trace!);
        result.complete(value as T);
      } catch (error, stack) {
        // Request state is discarded on write failure. The UI sees no success.
        result.completeError(error, stack);
      } finally {
        // Release completed chains instead of retaining the caller's zone.
        if (identical(_tail, pending)) _tail = null;
      }
    });
    _tail = pending;
    return result.future;
  }

  @override
  Future<dynamic> execute(
    String method,
    String resource, {
    Map<String, dynamic> data = const {},
    String token = '',
  }) async {
    // Network verification happens before entering the serialized local store.
    // No route accepts unverified claims or a caller-supplied subject.
    final google = resource == '/auth/google' || resource == '/account/google';
    final apple = resource == '/auth/apple' || resource == '/account/apple';
    final raw = data['id_token'];
    if (google && (raw is! String || raw.isEmpty)) {
      throw const ServiceError(401, 'ID Token Google ausente.');
    }
    if (apple && (raw is! String || raw.isEmpty)) {
      throw const ServiceError(401, 'ID Token Apple ausente.');
    }
    final gIdentity = google
        ? await _googleVerifier.verify(
            raw as String,
            maxAge: resource == '/account/google'
                ? const Duration(minutes: 5)
                : null,
          )
        : null;
    final aIdentity = apple
        ? await _appleVerifier.verify(
            raw as String,
            fallbackName: data['name'] as String?,
            maxAge: resource == '/account/apple'
                ? const Duration(minutes: 5)
                : null,
          )
        : null;
    final safeData = {...data}..remove('id_token');
    return _serial(
      (store) async => TeviServices(
        store,
        googleIdentity: gIdentity,
        appleIdentity: aIdentity,
      ).handle(method, resource, data: safeData, token: token),
    );
  }

  @override
  Future<SyncInfo> syncInfo() => _serial((store) async {
    // Operação estritamente local: nenhum dado é enviado para servidores externos
    return const SyncInfo(
      pending: 0,
      conflicts: 0,
      provider: 'Armazenamento Local Estrito (Zero Nuvem)',
      lastSuccess: null,
    );
  });

  @override
  Future<void> synchronize() => Future<void>.value();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cachedStore = null;
    _initialized = false;
    await _tail;
  }
}
