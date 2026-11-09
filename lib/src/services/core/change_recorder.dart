part of '../domain_services.dart';

extension ChangeRecorder on TeviServices {
  void _recordChange(
    String method,
    String path,
    Json data,
    dynamic result,
    String? actor,
  ) {
    if (((path == '/auth/google' || path == '/auth/apple') && result['created'] != true) ||
        method == 'GET' ||
        [
          '/auth/login',
          '/auth/logout',
          '/password',
          '/presence',
          '/workout',
          '/invites',
          '/invites/redeem',
          '/notifications',
        ].contains(path) ||
        path.startsWith('/zones') ||
        path.endsWith('/signal') ||
        path.startsWith('/admin')) {
      return;
    }
    // Queue only fields consumed by each service. Unknown input must not become
    // an accidental side channel for credentials or private metadata.
    final fields = switch (path) {
      '/reports' => ['target', 'reason', 'detail'],
      '/tickets' => ['subject', 'detail'],
      '/verification' => ['selfie'],
      _ when path.endsWith('/messages') => ['body', 'kind'],
      _ when path.endsWith('/calls') => ['kind'],
      _ when path.startsWith('/calls/') => ['action'],
      _ when path.startsWith('/events/') => ['join'],
      _ => <String>[],
    };
    Json payload = {
      for (final key in fields)
        if (data.containsKey(key)) key: data[key],
    };
    if ((path == '/auth/register' || path == '/auth/google' || path == '/auth/apple')) {
      final session = store.find(
        'sessions',
        where: (r) => r['token'] == digestToken(result['token']),
        fields: const ['user_id'],
      );
      actor = session?['user_id'];
    }
    if (actor == null) return;
    if (path == '/settings') payload = preferences(store.user(actor)!);
    if ((path == '/auth/register' || path == '/auth/google' || path == '/auth/apple') || path == '/me') {
      final user = store.user(actor);
      if (user == null) return;
      payload = {
        ...publicProfile(user, store.clock()),
        'email': user['email'],
        'birthdate': user['birthdate'],
      };
    }
    // Credentials, sessions and exact positions never enter the sync queue.
    payload.remove('password');
    payload.remove('token');
    payload.remove('lat');
    payload.remove('lon');
    if (path == '/account' || path == '/account/google' || path == '/account/apple') {
      store.delete('sync_queue', (r) => r['actor'] == actor);
      payload = {};
    }
    store.insert('sync_queue', {
      'id': randomToken(24),
      'actor': actor,
      'method': method,
      'resource': (path == '/auth/google' || path == '/auth/apple')
          ? '/auth/register'
          : (path == '/account/google' || path == '/account/apple')
          ? '/account'
          : path,
      'payload': payload,
      'created': store.now,
      'attempts': 0,
      'state': 'pending',
      'last_error': '',
    });
  }
}
