part of '../domain_services.dart';

extension CommunityRoutes on TeviServices {
  dynamic _communityRoutes(String method, String path, Json data, Json u) {
    final String me = u['id'];
    if (path == '/events') {
      return store
          .select('events', orderBy: 'starts')
          .map(
            (e) => {
              ...e,
              'joined':
                  store.find(
                    'attendance',
                    where: (r) =>
                        r['event_id'] == e['id'] &&
                        r['user_id'] == me &&
                        r['expires'] > store.now,
                  ) !=
                  null,
            },
          )
          .toList();
    }
    if (path.startsWith('/events/')) {
      final id = path.split('/').last,
          event = store.find(
            'events',
            where: (r) => r['id'] == path.split('/').last,
          );
      if (event == null) {
        throw const ServiceError(404, 'Evento não encontrado.');
      }
      if (data['join'] == true) {
        if (!store.discoverable(u)) {
          throw const ServiceError(403, 'Ative a descoberta para participar.');
        }
        for (final person
            in store
                .select(
                  'attendance',
                  where: (r) =>
                      r['event_id'] == id &&
                      r['expires'] > store.now &&
                      r['user_id'] != me,
                )
                .map((r) => store.user(r['user_id']))
                .whereType<Json>()
                .toList()) {
          if (store.discoverable(person) && !store.blocked(me, person['id'])) {
            store.addEncounter(me, person['id'], 'Evento: ${event['title']}');
          }
        }
        store.insert('attendance', {
          'user_id': me,
          'event_id': id,
          'expires': store.now + 3600,
        }, replace: true);
      } else {
        store.delete(
          'attendance',
          (r) => r['user_id'] == me && r['event_id'] == id,
        );
      }
      return {'ok': true};
    }
    if (path == '/invites') {
      final code = randomToken(9);
      store.insert('invites', {
        'code': code,
        'user_id': me,
        'expires': store.now + 600,
      });
      return {'code': code, 'expires_minutes': 10};
    }
    if (path == '/invites/redeem') {
      store.limit('invite:$me', 10, 600);
      final invite = store.find(
        'invites',
        where: (r) =>
            r['code'] == field(data, 'code', max: 30) &&
            r['expires'] > store.now,
      );
      if (invite == null ||
          invite['user_id'] == me ||
          store.blocked(me, invite['user_id'])) {
        throw const ServiceError(404, 'Convite inválido ou expirado.');
      }
      final other = store.user(invite['user_id']);
      if (other == null ||
          !store.discoverable(u) ||
          !store.discoverable(other)) {
        throw const ServiceError(403, 'Os dois precisam ativar a descoberta.');
      }
      // Explicit, single-use invitation may reveal this encounter immediately.
      store.insert('encounters', {
        'id': randomToken(16),
        'a': ([me, other['id']]..sort())[0],
        'b': ([me, other['id']]..sort())[1],
        'region': 'Convite presencial',
        'created': store.now,
        'visible': store.now,
      });
      store.delete('invites', (r) => r['code'] == invite['code']);
      return {'ok': true};
    }
    if (path == '/notifications') {
      if (method == 'GET') {
        return store.select(
          'notifications',
          where: (r) => r['user_id'] == me,
          orderBy: 'created',
          descending: true,
          limit: 100,
        );
      }
      store.update(
        'notifications',
        (r) => r['user_id'] == me,
        (r) => {'seen': 1},
      );
      return {'ok': true};
    }
    if (path == '/reports') {
      if (method == 'GET') {
        return store.select(
          'reports',
          where: (r) => r['reporter'] == me,
          orderBy: 'created',
          descending: true,
          fields: const ['id', 'reason', 'detail', 'status'],
        );
      }
      store.limit('reports:$me', 10, 3600);
      final target = field(data, 'target', max: 40);
      if (target == me || store.user(target) == null) {
        throw const ServiceError(400, 'Perfil inválido.');
      }
      store.insert('reports', {
        'id': randomToken(16),
        'reporter': me,
        'target': target,
        'reason': field(data, 'reason', max: 80),
        'detail': field(data, 'detail', max: 2000, required: false),
        'status': 'open',
        'created': store.now,
      });
      return {'ok': true};
    }
    if (path == '/tickets') {
      if (method == 'GET') {
        return store.select(
          'tickets',
          where: (r) => r['user_id'] == me,
          fields: const ['id', 'subject', 'detail', 'status'],
        );
      }
      store.insert('tickets', {
        'id': randomToken(16),
        'user_id': me,
        'subject': field(data, 'subject', max: 100),
        'detail': field(data, 'detail', max: 2000),
        'status': 'open',
        'created': store.now,
      });
      return {'ok': true};
    }
    if (path.startsWith('/admin')) {
      if (u['role'] != 'admin') {
        throw const ServiceError(403, 'Acesso restrito à moderação.');
      }
      store.insert('audit', {
        'id': randomToken(16),
        'actor': me,
        'action': '$method $path',
        'target': data['id']?.toString() ?? '',
        'created': store.now,
      });
      if (path == '/admin') {
        return {
          'users': store.select(
            'users',
            fields: const ['id', 'name', 'suspended', 'verified'],
          ),
          'reports': store.select(
            'reports',
            orderBy: 'created',
            descending: true,
          ),
          'verification': store.select(
            'verification',
            where: (r) => r['status'] == 'pending',
          ),
          'tickets': store.select('tickets'),
          'stats': {
            for (final t in ['users', 'encounters', 'matches', 'messages'])
              t: store.count(t),
          },
          'audit': store.select(
            'audit',
            orderBy: 'created',
            descending: true,
            limit: 50,
          ),
        };
      }
      if (path.startsWith('/admin/profile/')) {
        final person = store.user(path.split('/').last);
        if (person == null) {
          throw const ServiceError(404, 'Perfil não encontrado.');
        }
        return publicProfile(person, store.clock());
      }
      if (path == '/admin/users') {
        final id = field(data, 'id', max: 40);
        if (id == me) {
          throw const ServiceError(
            400,
            'Você não pode suspender sua própria conta.',
          );
        }
        if (store.user(id) == null) {
          throw const ServiceError(404, 'Perfil não encontrado.');
        }
        final suspend = data['suspended'] == true;
        store.update(
          'users',
          (r) => r['id'] == id,
          (r) => {'suspended': suspend ? 1 : 0},
        );
        if (suspend) {
          store.delete('sessions', (r) => r['user_id'] == id);
          store.delete('presence', (r) => r['user_id'] == id);
        }
        return {'ok': true};
      }
      if (path == '/admin/reports' || path == '/admin/tickets') {
        final table = path.split('/').last;
        store.update(
          table,
          (r) => r['id'] == field(data, 'id', max: 40),
          (r) => {'status': 'resolved'},
        );
        return {'ok': true};
      }
      if (path == '/admin/verification') {
        final req = store.find(
          'verification',
          where: (r) =>
              r['id'] == field(data, 'id', max: 40) && r['status'] == 'pending',
        );
        if (req == null) {
          throw const ServiceError(404, 'Solicitação não encontrada.');
        }
        final approved = data['approved'] == true;
        store.update(
          'verification',
          (r) => r['id'] == req['id'],
          (r) => {'status': approved ? 'approved' : 'rejected', 'selfie': ''},
        );
        store.update(
          'users',
          (r) => r['id'] == req['user_id'],
          (r) => {'verified': approved ? 1 : 0},
        );
        return {'ok': true};
      }
      if (path == '/admin/events') {
        store.insert('events', {
          'id': randomToken(16),
          'title': field(data, 'title', max: 100),
          'place': field(data, 'place', max: 100),
          'category': field(data, 'category', max: 50),
          'description': field(data, 'description', max: 500),
          'starts': field(data, 'starts', max: 60),
        });
        return {'ok': true};
      }
    }
    throw const ServiceError(404, 'Recurso não encontrado.');
  }
}
