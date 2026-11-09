library;

import 'dart:convert';

import '../models/apple_identity.dart';
import '../models/google_identity.dart';

import 'core/security.dart';
import '../models/json.dart';
import '../models/service_error.dart';
import '../models/user_settings.dart';
import 'core/store.dart';
import 'auth_service.dart';
import 'ble_proximity_service.dart';

export 'core/store.dart' show ServiceStore, isProfileCompleted;
export '../models/json.dart';
export '../models/service_error.dart';
export '../models/user_settings.dart' show defaults;
part 'core/account_routes.dart';
part 'core/relationship_routes.dart';
part 'core/community_routes.dart';
part 'core/change_recorder.dart';
part 'core/workout_routes.dart';

/// Local domain services. No sockets or separate process are created.
class TeviServices {
  TeviServices(this.store, {this.googleIdentity, this.appleIdentity})
      : auth = AuthService(store);
  final GoogleIdentity? googleIdentity;
  final AppleIdentity? appleIdentity;
  final AuthService auth;
  final ServiceStore store;
  static final routes = <String, List<String>>{
    r'/health': ['GET'],
    r'/appearance': ['GET'],
    r'/auth/session': ['GET'],
    r'/auth/(register|login|logout|google|apple)': ['POST'],
    r'/me': ['GET', 'PATCH'],
    r'/settings': ['PATCH'],
    r'/password': ['PATCH'],
    r'/presence': ['POST'],
    r'/proximity/certify': ['POST'],
    r'/(workout|modes)(/status)?': ['GET', 'POST'],
    r'/encounters': ['GET'],
    r'/people/[^/]+/[^/]+': ['POST'],
    r'/hidden/restore': ['POST'],
    r'/blocks': ['GET'],
    r'/blocks/[^/]+': ['DELETE'],
    r'/matches': ['GET'],
    r'/matches/[^/]+': ['DELETE'],
    r'/matches/[^/]+/(messages|calls|signal)': ['GET', 'POST'],
    r'/calls/[^/]+': ['POST'],
    r'/events': ['GET'],
    r'/events/[^/]+': ['POST'],
    r'/invites(/redeem)?': ['POST'],
    r'/zones': ['GET', 'POST'],
    r'/zones/[^/]+': ['DELETE'],
    r'/history': ['DELETE'],
    r'/notifications': ['GET', 'POST'],
    r'/reports': ['POST'],
    r'/tickets': ['POST'],
    r'/verification': ['POST'],
    r'/account(/google|/apple)?': ['DELETE'],
    r'/export': ['GET'],
    r'/admin/(overview|reports|tickets|verification)': ['GET'],
    r'/admin/(resolve|moderate|verify)': ['POST'],
  };

  dynamic handle(
    String method,
    String path, {
    Json data = const {},
    String token = '',
    String ip = 'local',
  }) {
    if (!routes.entries.any(
      (e) => RegExp('^${e.key}\$').hasMatch(path) && e.value.contains(method),
    )) {
      throw const ServiceError(404, 'Operação não encontrada.');
    }
    if (path == '/health') return {'status': 'ok'};
    if (path == '/appearance') {
      final session = token.isEmpty
          ? null
          : store.find(
              'sessions',
              where: (r) =>
                  r['token'] == digestToken(token) && r['expires'] > store.now,
              fields: const ['user_id'],
            );
      final me = session == null ? null : store.user(session['user_id']);
      if (me != null) {
        return Json.from(preferences(me)['appearance'] as Map? ?? const {});
      }
      final row = store.find('settings', where: (r) => r['key'] == 'appearance');
      return row == null ? <String, dynamic>{} : Json.from(row['value']);
    }
    if (path == '/auth/session') {
      return {'token': auth.restoreSession()};
    }
    // Authentication limits are committed even when credentials are invalid.
    if (path == '/auth/login' ||
        path == '/auth/register' ||
        path == '/auth/google' ||
        path == '/auth/apple') {
      store.limit('auth:$ip', 20, 900);
    }
    store.begin();
    try {
      final actor =
          store.find(
                'sessions',
                where: (r) => r['token'] == digestToken(token),
                fields: const ['user_id'],
              )?['user_id']
              as String?;
      final result = _dispatch(method, path, data, token);
      _recordChange(method, path, data, result, actor);
      store.commit();
      return result;
    } catch (_) {
      store.rollback();
      rethrow;
    }
  }

  dynamic _dispatch(String method, String path, Json data, String token) {
    if (path == '/auth/google') {
      if (googleIdentity == null)
        throw const ServiceError(401, 'Identidade Google não validada.');
      return auth.authenticateGoogle(googleIdentity!, data);
    }
    if (path == '/auth/apple') {
      if (appleIdentity == null)
        throw const ServiceError(401, 'Identidade Apple não validada.');
      return auth.authenticateApple(appleIdentity!, data);
    }
    if (path == '/auth/register' || path == '/auth/login') {
      return auth.authenticate(data, register: path == '/auth/register');
    }
    final u = auth.currentUser(token);
    if (u == null) {
      throw const ServiceError(401, 'Entre na sua conta para continuar.');
    }
    if (method != 'GET') store.limit('write:${u['id']}', 180, 60);
    if (path == '/password') return auth.changePassword(data, u, token);
    if (path == '/auth/logout') {
      auth.logout(token);
      return {'ok': true};
    }
    if (path == '/me' ||
        path == '/settings' ||
        path == '/account' ||
        path == '/account/google' ||
        path == '/account/apple' ||
        path == '/export' ||
        path.startsWith('/zones') ||
        path == '/history' ||
        path == '/verification') {
      return _accountRoutes(method, path, data, u);
    }
    if (path == '/workout' || path == '/workout/status' || path == '/modes' || path == '/modes/status') return _workoutRoutes(method, data, u);
    if (path == '/presence' ||
        path == '/proximity/certify' ||
        path == '/encounters' ||
        path.startsWith('/people/') ||
        path.startsWith('/hidden/') ||
        path.startsWith('/blocks') ||
        path.startsWith('/matches') ||
        path.startsWith('/calls/')) {
      return _relationshipRoutes(method, path, data, u);
    }
    return _communityRoutes(method, path, data, u);
  }
}
