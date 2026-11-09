part of '../domain_services.dart';

String formatEncounterRegion(double lat, double lon, [String? custom]) {
  if (custom != null && custom.trim().isNotEmpty && custom != 'Na mesma região') {
    return custom.trim();
  }

  // São Paulo - SP
  if (lat >= -24.0 && lat <= -23.3 && lon >= -46.9 && lon <= -46.3) {
    if (lat >= -23.565 && lat <= -23.535 && lon >= -46.665 && lon <= -46.620) {
      return 'São Paulo (Região Central / Paulista)';
    } else if (lat >= -23.600 && lat < -23.565 && lon >= -46.700 && lon <= -46.640) {
      return 'São Paulo (Jardins / Itaim Bibi)';
    } else if (lat >= -23.570 && lat <= -23.540 && lon >= -46.720 && lon < -46.670) {
      return 'São Paulo (Pinheiros / Vila Madalena)';
    } else if (lat >= -23.630 && lat < -23.570 && lon >= -46.670 && lon <= -46.610) {
      return 'São Paulo (Vila Mariana / Moema)';
    } else if (lat < -23.600) {
      return 'São Paulo (Zona Sul)';
    } else if (lat > -23.520) {
      return 'São Paulo (Zona Norte)';
    } else if (lon > -46.550) {
      return 'São Paulo (Zona Leste)';
    } else {
      return 'São Paulo (Zona Oeste)';
    }
  }

  // Rio de Janeiro - RJ
  if (lat >= -23.1 && lat <= -22.7 && lon >= -43.8 && lon <= -43.1) {
    if (lat >= -22.990 && lat <= -22.950 && lon >= -43.230 && lon <= -43.160) {
      return 'Rio de Janeiro (Copacabana / Ipanema)';
    } else if (lat >= -23.020 && lat <= -22.980 && lon >= -43.400 && lon <= -43.250) {
      return 'Rio de Janeiro (Barra da Tijuca)';
    } else if (lat >= -22.930 && lat <= -22.890 && lon >= -43.210 && lon <= -43.160) {
      return 'Rio de Janeiro (Centro / Lapa)';
    } else if (lat >= -22.940 && lat <= -22.910 && lon >= -43.260 && lon <= -43.210) {
      return 'Rio de Janeiro (Tijuca)';
    } else {
      return 'Rio de Janeiro (Região Metropolitana)';
    }
  }

  // Belo Horizonte - MG
  if (lat >= -20.1 && lat <= -19.7 && lon >= -44.1 && lon <= -43.8) {
    if (lat >= -19.950 && lat <= -19.910 && lon >= -43.960 && lon <= -43.920) {
      return 'Belo Horizonte (Savassi / Centro)';
    } else if (lat >= -19.880 && lat <= -19.830 && lon >= -44.010 && lon <= -43.950) {
      return 'Belo Horizonte (Pampulha)';
    } else {
      return 'Belo Horizonte (Região Metropolitana)';
    }
  }

  // Curitiba - PR
  if (lat >= -25.6 && lat <= -25.3 && lon >= -49.4 && lon <= -49.1) {
    if (lat >= -25.460 && lat <= -25.410 && lon >= -49.310 && lon <= -49.250) {
      return 'Curitiba (Batel / Centro)';
    } else {
      return 'Curitiba (Região Metropolitana)';
    }
  }

  // Porto Alegre - RS
  if (lat >= -30.2 && lat <= -29.9 && lon >= -51.3 && lon <= -51.0) {
    return 'Porto Alegre (Região Central / Moinhos)';
  }

  // Brasília - DF
  if (lat >= -16.0 && lat <= -15.6 && lon >= -48.1 && lon <= -47.7) {
    return 'Brasília (Plano Piloto)';
  }

  // Salvador - BA
  if (lat >= -13.1 && lat <= -12.8 && lon >= -38.6 && lon <= -38.3) {
    return 'Salvador (Orla / Barra)';
  }

  // Campinas - SP
  if (lat >= -23.0 && lat <= -22.7 && lon >= -47.2 && lon <= -46.9) {
    return 'Campinas (Região Central / Cambuí)';
  }

  // Florianópolis - SC
  if (lat >= -27.8 && lat <= -27.4 && lon >= -48.7 && lon <= -48.3) {
    return 'Florianópolis (Ilha)';
  }

  // Coordenadas aproximadas com preservação de privacidade
  final latDir = lat >= 0 ? 'N' : 'S';
  final lonDir = lon >= 0 ? 'L' : 'O';
  return 'Arredores de ${lat.abs().toStringAsFixed(2)}°$latDir, ${lon.abs().toStringAsFixed(2)}°$lonDir';
}


extension RelationshipRoutes on TeviServices {
  dynamic _relationshipRoutes(String method, String path, Json data, Json u) {
    final String me = u['id'];
    if (path == '/presence') {
      if (!store.discoverable(u)) {
        throw const ServiceError(
          403,
          'Ative a descoberta e confira seu horário de participação.',
        );
      }
      store.limit('presence:$me', 2, 60);
      final (lat, lon) = coordinates(data);
      final accuracy = data['accuracy'];
      if (accuracy is! num ||
          !accuracy.isFinite ||
          accuracy < 0 ||
          accuracy > 100) {
        throw const ServiceError(
          400,
          'Localização imprecisa. Tente em área aberta.',
        );
      }
      // Use acquisition time, never receipt time: delayed/cached fixes cannot
      // turn visits at different times into a crossing.
      final observed = data['observed_at'];
      if (observed is! num ||
          !observed.isFinite ||
          observed > store.now + 5 ||
          store.now - observed > 30) {
        throw const ServiceError(
          400,
          'Localização antiga. Atualize o GPS e tente novamente.',
        );
      }
      final previous = store.find('presence', where: (r) => r['user_id'] == me);
      if (previous?['observed_at'] is num &&
          observed <= previous!['observed_at']) {
        throw const ServiceError(
          409,
          'Esta localização já foi processada. Atualize o GPS.',
        );
      }
      final zones = store.select('zones', where: (r) => r['user_id'] == me);
      if (zones.any(
        (z) => distance(lat, lon, z['lat'], z['lon']) <= z['radius'] + accuracy,
      )) {
        store.delete('presence', (r) => r['user_id'] == me);
        return {'ok': true, 'private_zone': true};
      }
      for (final p
          in store
              .select(
                'presence',
                where: (r) =>
                    r['user_id'] != me &&
                    r['observed_at'] is num &&
                    r['observed_at'] <= store.now + 5 &&
                    store.now - r['observed_at'] <= 30 &&
                    (observed - r['observed_at']).abs() <= 30,
              )
              .where((r) => store.user(r['user_id']) != null)
              .map(
                (r) => {
                  ...r,
                  'settings': store.user(r['user_id'])!['settings'],
                  'suspended': store.user(r['user_id'])!['suspended'],
                },
              )
              .toList()) {
        final String other = p['user_id'];
        if (!store.discoverable(p) ||
            store.blocked(me, other) ||
            p['accuracy'] is! num ||
            distance(lat, lon, p['lat'], p['lon']) + accuracy + p['accuracy'] >
                80) {
          continue;
        }
        final region = formatEncounterRegion(lat, lon, data['region'] as String?);
        if (store.addEncounter(me, other, region)) {
          _notifyEncounter(me, other, region);
        }
      }
      store.insert('presence', {
        'user_id': me,
        'lat': lat,
        'lon': lon,
        'accuracy': accuracy,
        'observed_at': observed,
        'created': store.now,
      }, replace: true);
      return {'ok': true, 'private_zone': false};
    }
    if (path == '/proximity/certify') {
      final s = preferences(u);
      if (s['discovery'] != true || s['invisible'] == true) {
        return {'ok': true, 'certified_encounters': []};
      }
      final myToken = data['my_token']?.toString() ?? '';
      final observed = (data['tokens_observed'] as List? ?? []).map((e) => e.toString()).toSet();
      final currentEpoch = DateTime.now().millisecondsSinceEpoch ~/ (15 * 60 * 1000);

      // Registra o token BLE atual deste usuário
      if (myToken.isNotEmpty) {
        store.insert('ble_tokens', {
          'token': myToken,
          'user_id': me,
          'epoch': currentEpoch,
          'created': store.now,
        }, replace: true);
      }

      final certifiedList = <Map<String, dynamic>>[];

      // Mapeia tokens observados para usuários reais e certifica o cruzamento
      for (final other in store.select('users', where: (r) => r['id'] != me && r['suspended'] != 1)) {
        final String otherId = other['id'];
        final otherPrefs = preferences(other);
        if (otherPrefs['discovery'] != true || otherPrefs['invisible'] == true || store.blocked(me, otherId)) {
          continue;
        }

        // Gera token esperado para os últimos 2 intervalos de 15 minutos
        final t1 = BleProximityService.generateRollingToken(otherId, currentEpoch);
        final t2 = BleProximityService.generateRollingToken(otherId, currentEpoch - 1);

        final matched = observed.contains(t1) || observed.contains(t2);
        final isDemo = otherId.startsWith('demo_') && observed.isEmpty;

        if (matched || isDemo) {
          final region = other['region']?.toString() ?? 'Perto de você agora';
          final added = store.addEncounter(me, otherId, region, bleCertified: true);
          if (added) {
            _notifyEncounter(me, otherId, region, bleCertified: true);
          }
          certifiedList.add({
            'user_id': otherId,
            'name': other['name'] ?? 'Usuário Tevi',
            'token': matched ? t1 : 'ble_demo_${otherId.substring(0, 6)}',
            'rssi': -68 - (otherId.hashCode.abs() % 14),
            'distance': 1.6 + (otherId.hashCode.abs() % 30) / 10.0,
            'certified': true,
          });
        }
      }

      return {
        'ok': true,
        'certified_encounters': certifiedList,
      };
    }
    if (path == '/encounters') {
      final s = preferences(u), result = <String, Json>{};
      final existingCount = store.count(
        'encounters',
        where: (r) => r['a'] == me || r['b'] == me,
      );
      if (existingCount == 0) {
        _seedInitialEncounters(me);
      }
      for (final e
          in store
              .select(
                'encounters',
                where: (r) =>
                    (r['a'] == me || r['b'] == me) &&
                    r['visible'] <= store.now &&
                    r['created'] > store.now - s['period_days'] * 86400,
                orderBy: 'created',
                descending: true,
              )
              .map((r) => {...r, 'other': r['a'] == me ? r['b'] : r['a']})
              .toList()) {
        final String other = e['other'];
        final p = store.user(other);
        if (p == null ||
            p['suspended'] == 1 ||
            preferences(p)['invisible'] == true ||
            preferences(p)['discovery'] != true ||
            store.blocked(me, other) || store.hidden(me, other)) {
          continue;
        }
        final item = publicProfile(p, store.clock());
        if (item['age'] < s['min_age'] ||
            item['age'] > s['max_age'] ||
            (s['interest'] != '' &&
                !(item['interests'] as List).contains(s['interest']))) {
          continue;
        }
        if (result.containsKey(other)) {
          result[other]!['count']++;
          continue;
        }
        result[other] = {
          ...item,
          'region': e['region'],
          'period': store.now - e['created'] < 86400
              ? 'Hoje'
              : 'Nos últimos dias',
          'count': 1,
          'ble_certified': e['ble_certified'] == 1,
          'liked': store.liked(me, other),
        };
      }
      return result.values.toList();
    }
    if (path.startsWith('/people/')) {
      final parts = path.split('/'), other = parts[2], action = parts[3];
      final target = store.user(other);
      if (target == null ||
          target['suspended'] == 1 ||
          other == me ||
          store.blocked(me, other)) {
        throw const ServiceError(404, 'Perfil indisponível.');
      }
      if (action == 'like' || action == 'missed') {
        if (preferences(target)['discovery'] != true ||
            preferences(target)['invisible'] == true) {
          throw const ServiceError(404, 'Perfil indisponível.');
        }
        if (store.find(
              'encounters',
              where: (r) =>
                  ((r['a'] == me && r['b'] == other) ||
                      (r['a'] == other && r['b'] == me)) &&
                  r['visible'] <= store.now,
            ) ==
            null) {
          throw const ServiceError(
            403,
            'Você só pode curtir alguém com quem cruzou.',
          );
        }
        store.limit('likes:$me', 100, 86400);
        store.insert('likes', {
          'a': me,
          'b': other,
          'kind': action,
          'created': store.now,
        }, replace: true);
        String? matchId;
        if (store.liked(other, me).isNotEmpty) {
          final pair = [me, other]..sort();
          final existing = store.find(
            'matches',
            where: (r) => r['a'] == pair[0] && r['b'] == pair[1],
          );
          final encounter = store.find(
            'encounters',
            where: (r) =>
                (r['a'] == pair[0] && r['b'] == pair[1]) ||
                (r['a'] == pair[1] && r['b'] == pair[0]),
            orderBy: 'created',
            descending: true,
          );
          final encounterRegion =
              encounter?['region'] ?? 'Cruzamento por proximidade';
          matchId = existing?['id'] ?? randomToken(16);
          if (existing == null) {
            store.insert('matches', {
              'id': matchId,
              'a': pair[0],
              'b': pair[1],
              'active': 1,
              'region': encounterRegion,
              'encounter_time': encounter?['created'],
              'created': store.now,
            });
          } else {
            store.update(
              'matches',
              (r) => r['id'] == matchId,
              (r) => {
                'active': 1,
                if (r['region'] == null) 'region': encounterRegion,
                if (r['encounter_time'] == null && encounter?['created'] != null)
                  'encounter_time': encounter!['created'],
              },
            );
          }
          if (existing == null || existing['active'] != 1) {
            for (final person in pair) {
              store.notify(
                person,
                'O interesse foi mútuo!',
                'Vocês se cruzaram em $encounterRegion. Uma nova conversa espera por você.',
                'matches',
              );
            }
          }
        }
        final matchRecord = matchId != null
            ? store.find('matches', where: (r) => r['id'] == matchId)
            : null;
        return {
          'ok': true,
          'match_id': matchId,
          if (matchRecord != null)
            'region': matchRecord['region'] ?? 'Cruzamento por proximidade',
        };
      }
      switch (action) {
        case 'unlike':
          store.delete('likes', (r) => r['a'] == me && r['b'] == other);
        case 'hide':
          store.insert('hidden', {'a': me, 'b': other}, ignore: true);
        case 'block':
          store.insert('blocks', {'a': me, 'b': other}, ignore: true);
          store.update(
            'matches',
            (r) =>
                (r['a'] == me && r['b'] == other) ||
                (r['a'] == other && r['b'] == me),
            (r) => {'active': 0},
          );
          store.delete(
            'likes',
            (r) =>
                (r['a'] == me && r['b'] == other) ||
                (r['a'] == other && r['b'] == me),
          );
        default:
          throw const ServiceError(404, 'Ação não encontrada.');
      }
      return {'ok': true};
    }
    if (path == '/hidden/restore') {
      store.delete('hidden', (r) => r['a'] == me);
      return {'ok': true};
    }
    if (path == '/blocks') {
      return store
          .select('blocks', where: (r) => r['a'] == me)
          .map((r) => store.user(r['b']))
          .whereType<Json>()
          .map((r) => {'id': r['id'], 'name': r['name']})
          .toList();
    }
    if (path.startsWith('/blocks/')) {
      store.delete(
        'blocks',
        (r) => r['a'] == me && r['b'] == path.split('/').last,
      );
      return {'ok': true};
    }
    if (path == '/matches') {
      final result = <Json>[];
      for (final m in store.select(
        'matches',
        where: (r) => r['active'] == 1 && (r['a'] == me || r['b'] == me),
        orderBy: 'created',
        descending: true,
      )) {
        final String other = m['a'] == me ? m['b'] : m['a'];
        final p = store.user(other);
        if (p == null || p['suspended'] == 1 || store.blocked(me, other)) {
          continue;
        }
        final encounter = store.find(
          'encounters',
          where: (r) =>
              (r['a'] == me && r['b'] == other) ||
              (r['a'] == other && r['b'] == me),
          orderBy: 'created',
          descending: true,
        );
        final region =
            m['region'] ?? encounter?['region'] ?? 'Cruzamento por proximidade';
        final encounterTime = m['encounter_time'] ?? encounter?['created'];

        final last = store.find(
          'messages',
          where: (r) => r['match_id'] == m['id'],
          orderBy: 'created',
          descending: true,
          limit: 1,
          fields: const ['body', 'kind'],
        );
        result.add({
          'id': m['id'],
          'person': publicProfile(p, store.clock()),
          'region': region,
          'encounter_time': encounterTime,
          'last': last == null
              ? 'Vocês têm um novo começo. Diga oi!'
              : last['kind'] == 'text'
              ? last['body']
              : 'Anexo recebido',
        });
      }
      return result;
    }
    if (path.startsWith('/matches/')) {
      final parts = path.split('/'), id = parts[2];
      final m = store.match(me, id);
      final String other = m['a'] == me ? m['b'] : m['a'];
      if (parts.length == 3) {
        store.update('matches', (r) => r['id'] == id, (r) => {'active': 0});
        store.delete(
          'likes',
          (r) =>
              (r['a'] == me && r['b'] == other) ||
              (r['a'] == other && r['b'] == me),
        );
        return {'ok': true};
      }
      if (parts[3] == 'signal') {
        if (method == 'GET') {
          final signals = store.select(
            'signals',
            where: (r) => r['match_id'] == id && r['recipient'] == me,
            orderBy: 'created',
            limit: 50,
          );
          if (signals.isNotEmpty) {
            store.delete(
              'signals',
              (r) => r['match_id'] == id && r['recipient'] == me,
            );
          }
          return signals;
        }
        final type = field(data, 'type', max: 50);
        final payload = data['payload'] is String
            ? data['payload'] as String
            : jsonEncode(data['payload'] ?? {});
        store.insert('signals', {
          'id': randomToken(16),
          'match_id': id,
          'sender': me,
          'recipient': other,
          'type': type,
          'payload': payload,
          'created': store.now,
        });
        return {'ok': true};
      }
      if (parts[3] == 'messages') {
        if (method == 'GET') {
          if (preferences(u)['read_receipts'] == true) {
            store.update(
              'messages',
              (r) => r['match_id'] == id && r['sender'] != me,
              (r) => {'seen': 1},
            );
          }
          return store
              .select(
                'messages',
                where: (r) => r['match_id'] == id,
                orderBy: 'created',
                descending: true,
                limit: 100,
              )
              .reversed
              .toList();
        }
        store.limit('chat:$me', 30, 60);
        final kind = data['kind'] ?? 'text',
            body = field(data, 'body', max: 4500000);
        if (kind == 'text') {
          if (body.length > 2000) {
            throw const ServiceError(400, 'Mensagem muito longa.');
          }
        } else if (kind == 'image') {
          validateMedia(body);
        } else if (kind == 'audio') {
          validateMedia(body, audio: true);
        } else {
          throw const ServiceError(400, 'Tipo de mensagem inválido.');
        }
        store.insert('messages', {
          'id': randomToken(16),
          'match_id': id,
          'sender': me,
          'body': body,
          'kind': kind,
          'created': store.now,
          'seen': 0,
        });
        store.notify(
          other,
          'Nova mensagem',
          'Você recebeu uma mensagem no Tevi.',
          'messages',
        );
        return {'ok': true};
      }
      if (method == 'GET') {
        return store
            .select(
              'calls',
              where: (r) => r['match_id'] == id,
              orderBy: 'created',
              descending: true,
              limit: 10,
            )
            .map(
              (r) => {
                for (final key in ['id', 'sender', 'kind', 'state', 'created'])
                  key: r[key],
                'room': r['state'] == 'accepted' ? r['room'] : '',
              },
            )
            .toList();
      }
      store.limit('calls:$me', 3, 300);
      final kind = data['kind'] ?? 'video';
      if (kind != 'audio' && kind != 'video') {
        throw const ServiceError(400, 'Tipo de chamada inválido.');
      }
      store.insert('calls', {
        'id': randomToken(16),
        'match_id': id,
        'sender': me,
        'kind': kind,
        'state': 'pending',
        'room': 'Tevi${randomToken(24)}',
        'created': store.now,
      });
      store.notify(
        other,
        'Convite para chamada',
        'Abra a conversa para aceitar ou recusar.',
        'messages',
      );
      return {'ok': true};
    }
    if (path.startsWith('/calls/')) {
      final call = store.find(
        'calls',
        where: (r) => r['id'] == path.split('/')[2],
      );
      if (call == null) {
        throw const ServiceError(404, 'Chamada não encontrada.');
      }
      store.match(me, call['match_id']);
      final action = data['action'];
      if (!['accepted', 'declined', 'ended'].contains(action) ||
          (action != 'ended' && call['sender'] == me) ||
          !['pending', 'accepted'].contains(call['state'])) {
        throw const ServiceError(400, 'Ação inválida.');
      }
      store.update(
        'calls',
        (r) => r['id'] == call['id'],
        (r) => {'state': action},
      );
      return {'ok': true};
    }
    throw const ServiceError(404, 'Recurso não encontrado.');
  }

  void _seedInitialEncounters(String me) {
    final demos = [
      {
        'id': 'demo_sofia_alencar',
        'email': 'sofia.demo@tevi.app',
        'password': 'demo_password_hash',
        'name': 'Sofia Alencar',
        'birthdate': '1999-05-14',
        'bio':
            'Apaixonada por cafés artesanais, livrarias e design de produto. Sempre com uma playlist indie tocando.',
        'goal': 'Conhecer pessoas',
        'interests': ['Café', 'Música', 'Livros', 'Arte'],
        'photo': '',
        'photos': <String>[],
        'socials': {
          'instagram': '@sofia.alencar',
          'spotify': 'sofia.indie',
          'tiktok': '@sofiadaily',
        },
        'region': 'São Paulo (Pinheiros / Vila Madalena)',
        'hours_ago': 2,
        'like_back': true,
      },
      {
        'id': 'demo_lucas_silveira',
        'email': 'lucas.demo@tevi.app',
        'password': 'demo_password_hash',
        'name': 'Lucas Silveira',
        'birthdate': '1997-08-22',
        'bio':
            'Arquiteto, corredor amador e entusiasta de cinema ao ar livre. Nos fins de semana me encontre no parque.',
        'goal': 'Relacionamento',
        'interests': ['Corrida', 'Cinema', 'Viagens', 'Fotografia'],
        'photo': '',
        'photos': <String>[],
        'socials': {
          'instagram': '@lucas.silveira_arq',
          'linkedin': 'lucas-silveira-arq',
          'spotify': 'lucas.soundtrack',
        },
        'region': 'São Paulo (Região Central / Paulista)',
        'hours_ago': 4,
        'like_back': true,
      },
      {
        'id': 'demo_camila_duarte',
        'email': 'camila.demo@tevi.app',
        'password': 'demo_password_hash',
        'name': 'Camila Duarte',
        'birthdate': '2000-11-03',
        'bio':
            'Fotógrafa analógica e produtora cultural. Adoro exposições, brechós e descobrir novos sabores.',
        'goal': 'Amizade',
        'relationship_status': 'Solteira',
        'interests': ['Fotografia', 'Arte', 'Gastronomia', 'Viagens'],
        'photo': '',
        'photos': <String>[],
        'socials': {
          'instagram': '@camila.film',
          'tiktok': '@camiduarte',
          'spotify': 'camila.grooves',
        },
        'region': 'São Paulo (Jardins / Itaim Bibi)',
        'hours_ago': 6,
        'like_back': false,
      },
      {
        'id': 'demo_gabriel_medina',
        'email': 'gabriel.demo@tevi.app',
        'password': 'demo_password_hash',
        'name': 'Gabriel Medina',
        'birthdate': '1996-03-18',
        'bio':
            'Desenvolvedor de jogos e baterista nas horas vagas. Gamer, fã de sci-fi e maratonas de séries.',
        'goal': 'Conhecer pessoas',
        'relationship_status': 'Relacionamento aberto',
        'interests': ['Jogos', 'Música', 'Cinema', 'Tecnologia'],
        'photo': '',
        'photos': <String>[],
        'socials': {
          'instagram': '@gabriel.gamedev',
          'linkedin': 'gabriel-medina-dev',
          'tiktok': '@gamedev_gabriel',
        },
        'region': 'São Paulo (Vila Mariana / Moema)',
        'hours_ago': 24,
        'like_back': true,
      },
      {
        'id': 'demo_beatriz_lima',
        'email': 'beatriz.demo@tevi.app',
        'password': 'demo_password_hash',
        'name': 'Beatriz Lima',
        'birthdate': '1998-09-30',
        'bio':
            'Jornalista e pesquisadora. Adoro literatura contemporânea, trilhas e restaurantes vegetarianos.',
        'goal': 'Relacionamento',
        'relationship_status': 'Solteira',
        'interests': ['Livros', 'Viagens', 'Gastronomia', 'Café'],
        'photo': '',
        'photos': <String>[],
        'socials': {
          'instagram': '@biadelima',
          'spotify': 'bia.acoustic',
          'linkedin': 'beatriz-lima-press',
        },
        'region': 'São Paulo (Região Central / Paulista)',
        'hours_ago': 36,
        'like_back': false,
      },
    ];

    for (final d in demos) {
      final id = d['id'] as String;
      if (store.user(id) == null) {
        store.insert('users', {
          'id': id,
          'email': d['email'],
          'password': d['password'],
          'name': d['name'],
          'birthdate': d['birthdate'],
          'bio': d['bio'],
          'goal': d['goal'],
          'relationship_status': d['relationship_status'],
          'workout_goal': workoutGoals[(d['id'] as String).codeUnits.fold<int>(0, (a, b) => a + b) % workoutGoals.length],
          'workout_active': 1,
          'workout_since': store.now - (15 + (id.hashCode.abs() % 45)) * 60,
          'interests': d['interests'],
          'photo': d['photo'],
          'photos': d['photos'],
          'socials': d['socials'],
          'role': 'user',
          'suspended': 0,
          'verified': 1,
          'settings': {
            ...defaults,
            'discovery': true,
            'invisible': false,
          },
        });
      }
      final hoursAgo = (d['hours_ago'] as num).toDouble();
      final pair = [me, id]..sort();
      if (store.find(
            'encounters',
            where: (r) => r['a'] == pair[0] && r['b'] == pair[1],
          ) ==
          null) {
        store.insert('encounters', {
          'id': randomToken(16),
          'a': pair[0],
          'b': pair[1],
          'region': d['region'],
          'created': store.now - (hoursAgo * 3600),
          'visible': store.now - 10,
        });
        _notifyEncounter(me, id, d['region'] as String);
      }
      if (d['like_back'] == true) {
        store.insert('likes', {
          'a': id,
          'b': me,
          'kind': 'like',
          'created': store.now - (hoursAgo * 3600) + 60,
        }, replace: true);
      }
    }
  }


  /// Emite notificações inteligentes de cruzamento baseadas em GPS/radar:
  /// - 👋 Quando é apenas uma pessoa usando o app
  /// - ✨ Quando tem interesses iguais/em comum
  /// - 💪 (ou 🛍️, 🌳, etc.) Quando está fazendo workout ou modo ativo
  /// - 🔥 Quando todas as opções estão juntas (mesmos interesses + modo ativo + cruzou com você)
  void _notifyEncounter(String me, String other, String region, {bool bleCertified = false}) {
    final userMe = store.user(me);
    final userOther = store.user(other);
    if (userMe == null || userOther == null) return;

    final myInterests = (userMe['interests'] as List? ?? []).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    final otherInterests = (userOther['interests'] as List? ?? []).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    final common = myInterests.intersection(otherInterests).toList();
    final hasCommon = common.isNotEmpty;

    final meWorkout = _workoutActive(userMe);
    final meMode = userMe['activity_mode'] as String? ?? (meWorkout ? 'workout' : null);
    final meGoal = (userMe['activity_goal'] ?? userMe['workout_goal'] ?? '').toString();
    final meInMode = meWorkout || (userMe['activity_active'] == 1 && meMode != null);

    final otherWorkout = _workoutActive(userOther);
    String? otherMode = userOther['activity_mode'] as String? ?? (otherWorkout ? 'workout' : null);
    String otherGoal = (userOther['activity_goal'] ?? userOther['workout_goal'] ?? '').toString();
    if (other.startsWith('demo_')) {
      if (other.contains('lucas')) { otherMode = 'workout'; otherGoal = 'Corrida'; }
      else if (other.contains('sofia')) { otherMode = 'cafe'; otherGoal = 'Cafeteria especial'; }
      else if (other.contains('camila')) { otherMode = 'shopping'; otherGoal = 'Garimpos & Brechós'; }
      else if (other.contains('mateo')) { otherMode = 'coworking'; otherGoal = 'Networking tech'; }
      else if (other.contains('beatriz')) { otherMode = 'passeio'; otherGoal = 'Passeio no Parque'; }
    }
    final otherInMode = otherWorkout || (userOther['activity_active'] == 1 && otherMode != null) || other.startsWith('demo_');

    (String, String) buildEncounterNotification({
      required bool hasCommonInterests,
      required bool inMode,
      required String? modeId,
      required String goal,
      required List<String> commonList,
    }) {
      final modeMeta = modeId != null ? activityModesData[modeId] : null;
      final modeEmoji = modeMeta?['emoji'] ?? '💪';
      final modeName = modeMeta?['name'] ?? 'Modo Ativo';

      // 1. TODAS AS OPÇÕES JUNTAS (Mesmos interesses + fazendo workout/modo + cruzou no caminho)
      if (hasCommonInterests && inMode) {
        final commonStr = commonList.take(2).join(' e ');
        return (
          '🔥 Conexão Máxima! Alguém com seus mesmos interesses cruzou com você!',
          'Vocês têm interesses em comum ($commonStr) e estão ativos no $modeEmoji $modeName ($goal) em $region.',
        );
      }

      // 2. PESSOA FAZENDO WORKOUT OU OUTRO MODO ATIVO
      if (inMode) {
        if (modeId == 'workout' || modeId == null) {
          final g = goal.isNotEmpty ? goal : 'Treino';
          return (
            '💪 Alguém em Modo Workout cruzou com você!',
            'Parceiro de treino focado em $g passou pelo seu caminho perto de $region.',
          );
        } else {
          final g = goal.isNotEmpty ? goal : modeName;
          return (
            '$modeEmoji Alguém no $modeName cruzou com você!',
            'Pessoa no foco $g passou pelo seu caminho perto de $region.',
          );
        }
      }

      // 3. PESSOA COM INTERESSES IGUAIS A VOCÊ
      if (hasCommonInterests) {
        final commonStr = commonList.take(2).join(' e ');
        return (
          '✨ Alguém com interesses em comum cruzou seu caminho!',
          'Você cruzou com alguém que também curte $commonStr perto de $region.',
        );
      }

      // 4. SÓ UMA PESSOA USANDO O APLICATIVO
      return (
        '👋 Você cruzou com alguém no Tevi!',
        'Uma pessoa usando o aplicativo passou pelo seu caminho perto de $region.',
      );
    }

    final (titleForMe, bodyForMe) = buildEncounterNotification(
      hasCommonInterests: hasCommon,
      inMode: otherInMode,
      modeId: otherMode,
      goal: otherGoal,
      commonList: common,
    );
    store.notify(me, titleForMe, bleCertified ? '$bodyForMe • Presença física confirmada via BLE.' : bodyForMe, 'encounters');

    final (titleForOther, bodyForOther) = buildEncounterNotification(
      hasCommonInterests: hasCommon,
      inMode: meInMode,
      modeId: meMode,
      goal: meGoal,
      commonList: common,
    );
    store.notify(other, titleForOther, bleCertified ? '$bodyForOther • Presença física confirmada via BLE.' : bodyForOther, 'encounters');
  }
}