part of '../domain_services.dart';

extension AccountRoutes on TeviServices {
  dynamic _accountRoutes(String method, String path, Json data, Json u) {
    final String me = u['id'];
    if (path == '/me' && method == 'GET') {
      return {
        ...publicProfile(u, store.clock()),
        'email': u['email'],
        'birthdate': u['birthdate'],
        'settings': preferences(u),
        'role': u['role'],
        'relationship_status': u['relationship_status'] ?? '',
        'profile_completed': u['profile_completed'] == 1 || isProfileCompleted(u),
        'auth_provider': u['google_sub'] != null
            ? 'google'
            : (u['apple_sub'] != null ? 'apple' : 'password'),
      };
    }
    if (path == '/me') {
      final interests = data['interests'] ?? [];
      if (interests is! List ||
          interests.length > 10 ||
          interests.any((i) => i is! String || i.length > 30)) {
        throw const ServiceError(400, 'Escolha até 10 interesses.');
      }
      final photo = data['photo'] ?? u['photo'];
      final photos = data['photos'] ?? (photo == '' ? [] : [photo]);
      if (photos is! List ||
          photos.length > 6 ||
          photos.any((p) => p is! String)) {
        throw const ServiceError(400, 'Escolha até 6 fotos.');
      }
      if (photos.fold<int>(0, (n, p) => n + (p as String).length) > 4200000) {
        throw const ServiceError(400, 'O conjunto de fotos deve ter até 3 MB.');
      }
      for (final image in photos) {
        validateMedia(image);
      }
      final cover = photos.firstOrNull ?? '';
      store.update(
        'users',
        (r) => r['id'] == me,
        (r) => {
          'name': field(data, 'name', max: 60),
          'bio': field(data, 'bio', max: 500, required: false),
          'interests': List<String>.from(interests),
          'goal': field(data, 'goal', max: 50),
          if (data.containsKey('relationship_status'))
            'relationship_status': field(data, 'relationship_status', max: 60, required: false),
          if (data['socials'] is Map)
            'socials': Map<String, dynamic>.from(data['socials']),
          'verified': r['photo'] == cover ? r['verified'] : 0,
          'photo': cover,
          'photos': List<String>.from(photos),
          'profile_completed': 1,
        },
      );
      return {'ok': true};
    }
    if (path == '/settings') {
      final s = preferences(u);
      for (final entry in data.entries) {
        final expected = defaults[entry.key];
        final v = entry.value;
        if (!defaults.containsKey(entry.key) ||
            (expected is bool && v is! bool) ||
            (expected is int && v is! int) ||
            (expected is String && v is! String)) {
          throw const ServiceError(400, 'Preferência inválida.');
        }
        s[entry.key] = v;
      }
      if (!(s['timezone_offset'] >= -840 &&
          s['timezone_offset'] <= 840 &&
          s['min_age'] >= 18 &&
          s['max_age'] <= 110 &&
          s['min_age'] <= s['max_age'] &&
          s['period_days'] >= 1 &&
          s['period_days'] <= 7 &&
          s['start_hour'] >= 0 &&
          s['start_hour'] <= 23 &&
          s['end_hour'] >= 0 &&
          s['end_hour'] <= 24 &&
          s['start_minute'] >= 0 &&
          s['start_minute'] <= 59 &&
          s['end_minute'] >= 0 &&
          s['end_minute'] <= 59 &&
          (s['end_hour'] != 24 || s['end_minute'] == 0) &&
          s['quiet_start_minute'] >= 0 &&
          s['quiet_start_minute'] <= 59 &&
          s['quiet_end_minute'] >= 0 &&
          s['quiet_end_minute'] <= 59 &&
          s['quiet_start'] >= 0 &&
          s['quiet_start'] <= 23 &&
          s['quiet_end'] >= 0 &&
          s['quiet_end'] <= 23 &&
          [100, 115, 130].contains(s['text_scale']) &&
          ['system', 'light', 'dark'].contains(s['theme_mode']) &&
          (s['interest'] as String).length <= 30)) {
        throw const ServiceError(400, 'Preferências inválidas.');
      }
      store.update('users', (r) => r['id'] == me, (r) => {'settings': s});
      store.insert('app_preferences', {
        'key': 'appearance',
        'value': appearancePreferences(s),
      }, replace: true);
      if (s['discovery'] != true || s['invisible'] == true) {
        store.delete('presence', (r) => r['user_id'] == me);
      }
      return {'ok': true};
    }
    if (path == '/zones' && method == 'GET') {
      return store.select(
        'zones',
        where: (r) => r['user_id'] == me,
        fields: const ['id', 'label', 'radius'],
      );
    }
    if (path == '/zones') {
      final (lat, lon) = coordinates(data);
      if (store
              .select(
                'zones',
                where: (r) => r['user_id'] == me,
                fields: const ['id'],
              )
              .length >=
          10) {
        throw const ServiceError(400, 'Limite de 10 zonas privadas.');
      }
      store.insert('zones', {
        'id': randomToken(16),
        'user_id': me,
        'label': field(data, 'label', max: 40),
        'lat': lat,
        'lon': lon,
        'radius': 500,
      });
      store.delete('presence', (r) => r['user_id'] == me);
      return {'ok': true};
    }
    if (path.startsWith('/zones/')) {
      store.delete(
        'zones',
        (r) => r['id'] == path.split('/').last && r['user_id'] == me,
      );
      return {'ok': true};
    }
    if (path == '/history') {
      store.delete('encounters', (r) => r['a'] == me || r['b'] == me);
      store.delete('presence', (r) => r['user_id'] == me);
      return {'ok': true};
    }
    if (path == '/verification') {
      if (method == 'GET') {
        return {
          'status':
              store.find(
                'verification',
                where: (r) => r['user_id'] == me,
                orderBy: 'created',
                descending: true,
                limit: 1,
                fields: const ['status'],
              )?['status'] ??
              'not_requested',
        };
      }
      store.limit('verification:$me', 3, 86400);
      final selfie = validateMedia(data['selfie']);
      store.insert('verification', {
        'id': randomToken(16),
        'user_id': me,
        'selfie': selfie,
        'status': 'pending',
        'created': store.now,
      });
      return {'ok': true, 'status': 'pending'};
    }
    if (path == '/export') {
      final result = <String, dynamic>{
        'profile': {
          ...publicProfile(u, store.clock()),
          'email': u['email'],
          'birthdate': u['birthdate'],
        },
        'settings': preferences(u),
      };
      for (final (table, col) in [
        ('likes', 'a'),
        ('blocks', 'a'),
        ('reports', 'reporter'),
        ('zones', 'user_id'),
        ('tickets', 'user_id'),
        ('notifications', 'user_id'),
        ('messages', 'sender'),
        ('attendance', 'user_id'),
        ('verification', 'user_id'),
        ('hidden', 'a'),
        ('calls', 'sender'),
      ]) {
        result[table] = store.select(table, where: (r) => r[col] == me);
      }
      result['encounters'] = store.select(
        'encounters',
        where: (r) => r['a'] == me || r['b'] == me,
      );
      result['matches'] = store.select(
        'matches',
        where: (r) => r['a'] == me || r['b'] == me,
      );
      return result;
    }
    if (path == '/account' || path == '/account/google' || path == '/account/apple') {
      final googleDelete = path == '/account/google';
      final appleDelete = path == '/account/apple';
      if (googleDelete
          ? (googleIdentity == null ||
                googleIdentity!.subject != u['google_sub'])
          : appleDelete
              ? (appleIdentity == null ||
                    appleIdentity!.subject != u['apple_sub'])
              : !verifyPassword(passwordField(data, 'password'), u['password'])) {
        throw const ServiceError(403, 'Senha incorreta.');
      }
      store.delete('reports', (r) => r['reporter'] == me || r['target'] == me);
      store.update(
        'audit',
        (r) => r['actor'] == me,
        (r) => {'actor': 'deleted'},
      );
      store.update('audit', (r) => r['target'] == me, (r) => {'target': ''});
      store.delete('users', (r) => r['id'] == me);
      store.deviceSession = null;
      return {'ok': true};
    }
    throw const ServiceError(404, 'Recurso não encontrado.');
  }
}
