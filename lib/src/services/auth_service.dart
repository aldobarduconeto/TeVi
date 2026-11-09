import '../models/apple_identity.dart';
import '../models/google_identity.dart';
import '../models/json.dart';
import '../models/service_error.dart';
import '../models/user_settings.dart';
import 'core/security.dart';
import 'core/store.dart';

/// Local account registration, authentication and session lifecycle in Dart.
/// No email/SMS delivery or remote identity provider is required.
class AuthService {
  AuthService(this.store);
  final ServiceStore store;
  Json authenticate(Json data, {required bool register}) {
    final email = field(data, 'email', max: 254).toLowerCase();
    final password = passwordField(data, 'password');
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        password.length < 10) {
      throw const ServiceError(
        400,
        'Informe e-mail válido e senha de pelo menos 10 caracteres.',
      );
    }
    late String id;
    if (register) {
      final birth = field(data, 'birthdate', max: 10);
      final years = age(birth, store.clock());
      if (years < 18 || years > 110 || data['consent'] != true) {
        throw const ServiceError(
          400,
          'É necessário ter 18 anos e aceitar os termos.',
        );
      }
      if (store.find('users', where: (r) => r['email'] == email) != null) {
        throw const ServiceError(
          409,
          'Não foi possível cadastrar este e-mail.',
        );
      }
      id = randomToken(16);
      store.insert('users', {
        'id': id,
        'email': email,
        'password': hashPassword(password),
        'name': field(data, 'name', max: 60),
        'birthdate': birth,
        'bio': '',
        'interests': <String>[],
        'goal': 'Conhecer pessoas',
        'settings': {...defaults},
      });
    } else {
      final u = store.find('users', where: (r) => r['email'] == email);
      if (u == null || !verifyPassword(password, u['password'])) {
        throw const ServiceError(401, 'E-mail ou senha incorretos.');
      }
      if (u['suspended'] == 1) {
        throw const ServiceError(403, 'Conta suspensa. Procure o suporte.');
      }
      id = u['id'];
    }
    return createSession(id);
  }

  Json createSession(String id) {
    final token = randomToken(48);
    store.insert('sessions', {
      'token': digestToken(token),
      'user_id': id,
      'expires': store.now + 7 * 86400,
    });
    store.deviceSession = token;
    return {'token': token};
  }

  Json authenticateGoogle(GoogleIdentity identity, Json data) {
    var user = store.find(
      'users',
      where: (r) => r['google_sub'] == identity.subject,
    );
    final created = user == null;
    if (user == null) {
      // Never merge identities by email: require explicit authenticated linking.
      if (store.find('users', where: (r) => r['email'] == identity.email) !=
          null) {
        throw const ServiceError(
          409,
          'Este e-mail já possui conta local. Entre com sua senha; a vinculação automática não é permitida.',
        );
      }
      if (data['birthdate'] == null || data['consent'] != true) {
        throw const ServiceError(
          428,
          'Complete o nascimento e aceite os termos para criar sua conta.',
        );
      }
      final birth = field(data, 'birthdate', max: 10);
      final years = age(birth, store.clock());
      if (years < 18 || years > 110)
        throw const ServiceError(400, 'É necessário ter pelo menos 18 anos.');
      final id = randomToken(16);
      store.insert('users', {
        'id': id,
        'email': identity.email,
        'google_sub': identity.subject,
        'password': '',
        'name': field(data, 'name', max: 60),
        'birthdate': birth,
        'bio': '',
        'interests': <String>[],
        'goal': 'Conhecer pessoas',
        'settings': {...defaults},
      });
      user = store.user(id)!;
    }
    if (user['suspended'] == 1)
      throw const ServiceError(403, 'Conta suspensa. Procure o suporte.');
    return {...createSession(user['id']), 'created': created};
  }

  Json authenticateApple(AppleIdentity identity, Json data) {
    var user = store.find(
      'users',
      where: (r) => r['apple_sub'] == identity.subject,
    );
    final created = user == null;
    if (user == null) {
      if (identity.email.isNotEmpty &&
          store.find('users', where: (r) => r['email'] == identity.email) !=
              null) {
        throw const ServiceError(
          409,
          'Este e-mail já possui conta local. Entre com sua senha; a vinculação automática não é permitida.',
        );
      }
      if (data['birthdate'] == null || data['consent'] != true) {
        throw const ServiceError(
          428,
          'Complete o nascimento e aceite os termos para criar sua conta.',
        );
      }
      final birth = field(data, 'birthdate', max: 10);
      final years = age(birth, store.clock());
      if (years < 18 || years > 110) {
        throw const ServiceError(400, 'É necessário ter pelo menos 18 anos.');
      }
      final id = randomToken(16);
      final inputName = (data['name'] as String?)?.trim();
      final name = (inputName != null && inputName.isNotEmpty)
          ? inputName
          : (identity.name.isNotEmpty ? identity.name : 'Pessoa');
      final email = identity.email.isNotEmpty
          ? identity.email
          : '$id@privaterelay.appleid.com';
      store.insert('users', {
        'id': id,
        'email': email,
        'apple_sub': identity.subject,
        'password': '',
        'name': field({'name': name}, 'name', max: 60),
        'birthdate': birth,
        'bio': '',
        'interests': <String>[],
        'goal': 'Conhecer pessoas',
        'settings': {...defaults},
      });
      user = store.user(id)!;
    }
    if (user['suspended'] == 1) {
      throw const ServiceError(403, 'Conta suspensa. Procure o suporte.');
    }
    return {...createSession(user['id']), 'created': created};
  }

  Json changePassword(Json data, Json user, String token) {
    final current = passwordField(data, 'current_password');
    final next = passwordField(data, 'new_password');
    if (!verifyPassword(current, user['password']))
      throw const ServiceError(403, 'Senha atual incorreta.');
    if (next.length < 10)
      throw const ServiceError(
        400,
        'A nova senha deve ter pelo menos 10 caracteres.',
      );
    if (current == next)
      throw const ServiceError(400, 'Escolha uma senha diferente da atual.');
    store.update(
      'users',
      (r) => r['id'] == user['id'],
      (r) => {'password': hashPassword(next)},
    );
    store.delete(
      'sessions',
      (r) => r['user_id'] == user['id'] && r['token'] != digestToken(token),
    );
    return {'ok': true};
  }

  Json? currentUser(String token) {
    if (token.isEmpty) return null;
    final hash = digestToken(token);
    final session = store.find(
      'sessions',
      where: (r) => r['token'] == hash && r['expires'] > store.now,
    );
    final user = session == null ? null : store.user(session['user_id']);
    return user?['suspended'] == 0 ? user : null;
  }

  String? restoreSession() {
    final token = store.deviceSession;
    if (token != null && currentUser(token) != null) return token;
    store.deviceSession = null;
    return null;
  }

  void logout(String token) {
    final hash = digestToken(token);
    store.delete('sessions', (r) => r['token'] == hash);
    if (store.deviceSession == token) store.deviceSession = null;
  }
}
