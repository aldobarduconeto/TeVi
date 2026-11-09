part of '../domain_services.dart';

/// Configurações e metas de cada Modo de Presença do Tevi.
const activityModesData = <String, Map<String, dynamic>>{
  'workout': {
    'id': 'workout',
    'name': 'Workout & Treino',
    'emoji': '💪',
    'description': 'Encontre parceiros de academia, corrida e treino funcional',
    'color': 0xFFFF7A28,
    'goals': [
      'Hipertrofia',
      'Emagrecimento',
      'Resistência',
      'Funcional',
      'Corrida',
      'Yoga e mobilidade',
    ],
  },
  'shopping': {
    'id': 'shopping',
    'name': 'Modo Shopping',
    'emoji': '🛍️',
    'description': 'Conecte-se com pessoas em centros de compras e garimpos',
    'color': 0xFFE91E63,
    'goals': [
      'Moda & Roupas',
      'Eletrônicos & Tech',
      'Garimpos & Brechós',
      'Presentes & Decoração',
      'Praça de Alimentação',
    ],
  },
  'passeio': {
    'id': 'passeio',
    'name': 'Modo Passeio',
    'emoji': '🌳',
    'description': 'Descubra companhias para caminhar no parque e curtir a cidade',
    'color': 0xFF2E7D32,
    'goals': [
      'Caminhada relaxante',
      'Passeio no Parque',
      'Pôr do Sol & Vista',
      'Fotografia urbana',
      'Descanso ao ar livre',
    ],
  },
  'coworking': {
    'id': 'coworking',
    'name': 'Modo Coworking',
    'emoji': '💻',
    'description': 'Networking profissional, estudos concentrados e foco',
    'color': 0xFF1976D2,
    'goals': [
      'Networking tech',
      'Estudo concentrado',
      'Troca de ideias',
      'Café produtivo',
      'Freelancers',
    ],
  },
  'balada': {
    'id': 'balada',
    'name': 'Modo Balada & Noite',
    'emoji': '🎉',
    'description': 'Bares, festas e diversão noturna pela cidade',
    'color': 0xFF9C27B0,
    'goals': [
      'Barzinhos & Chopp',
      'Música ao vivo',
      'Balada & Dança',
      'Drinks autorais',
      'Socializar na noite',
    ],
  },
  'cafe': {
    'id': 'cafe',
    'name': 'Modo Café & Gastronomia',
    'emoji': '☕',
    'description': 'Apreciadores de cafeterias especiais, brunchs e boa comida',
    'color': 0xFFD87D4A,
    'goals': [
      'Cafeteria especial',
      'Brunch no fim de semana',
      'Doceria & Sobremesas',
      'Almoço executivo',
      'Jantar bistrô',
    ],
  },
  'pet': {
    'id': 'pet',
    'name': 'Modo Pet Friendly',
    'emoji': '🐕',
    'description': 'Socialização de cães e pets em praças e parques amigáveis',
    'color': 0xFF00897B,
    'goals': [
      'Passeio com cachorro',
      'Socializar pets',
      'Praça pet friendly',
      'Dicas e adestramento',
      'Companhia animal',
    ],
  },
  'viagem': {
    'id': 'viagem',
    'name': 'Modo Viagem & Turismo',
    'emoji': '✈️',
    'description': 'Turistas e moradores compartilhando experiências e roteiros',
    'color': 0xFF0288D1,
    'goals': [
      'Pontos turísticos',
      'Roteiro cultural',
      'Dicas de moradores',
      'Passeio histórico',
      'Companhia de viagem',
    ],
  },
  'cultura': {
    'id': 'cultura',
    'name': 'Modo Arte & Cultura',
    'emoji': '🎭',
    'description': 'Teatro, cinemas de rua, museus e exposições de arte',
    'color': 0xFF5E35B1,
    'goals': [
      'Cinema & Pipoca',
      'Teatro & Peças',
      'Exposições & Galerias',
      'Feiras de livros',
      'Shows & Festivais',
    ],
  },
};

/// Metas aceitas pelo modo Workout original (compatibilidade total).
const workoutGoals = <String>[
  'Hipertrofia',
  'Emagrecimento',
  'Resistência',
  'Funcional',
  'Corrida',
  'Yoga e mobilidade',
];

/// Os Modos expiram sozinhos após 3 horas para garantir privacidade.
const workoutTtlSeconds = 3 * 3600;

extension WorkoutRoutes on TeviServices {
  bool _workoutActive(Json? user) {
    if (user == null || user['workout_active'] != 1) return false;
    final since = user['workout_since'];
    return since is num && store.now - since < workoutTtlSeconds;
  }

  bool _modeActive(Json? user) {
    if (user == null) return false;
    if (user['activity_active'] == 1) {
      final since = user['activity_since'];
      return since is num && store.now - since < workoutTtlSeconds;
    }
    return _workoutActive(user);
  }

  dynamic _workoutRoutes(String method, Json data, Json u) {
    final String me = u['id'];
    if (method == 'POST') {
      final action = data['action']?.toString();
      final bool? activeFlag = data['active'] is bool ? data['active'] as bool : null;
      final isStop = action == 'stop' || activeFlag == false;
      final isStart = action == 'start' || activeFlag == true;
      if (isStop) {
        store.update(
          'users',
          (r) => r['id'] == me,
          (r) => {
            'workout_active': 0,
            'activity_active': 0,
          },
        );
        return {'ok': true, 'active': false};
      }
      if (!isStart) {
        throw const ServiceError(400, 'Ação inválida.');
      }
      final s = preferences(u);
      if (s['discovery'] != true || s['invisible'] == true) {
        throw const ServiceError(
          403,
          'Ative a descoberta para usar os modos de presença.',
        );
      }
      final modeId = (data['mode'] ?? 'workout').toString();
      final modeData = activityModesData[modeId] ?? activityModesData['workout']!;
      final validGoals = List<String>.from(modeData['goals'] as List);
      final goal = (data['goal'] ?? validGoals.first).toString();
      if (!validGoals.contains(goal)) {
        throw ServiceError(400, 'Escolha uma opção válida para o ${modeData['name']}.');
      }
      store.update(
        'users',
        (r) => r['id'] == me,
        (r) => {
          'workout_active': modeId == 'workout' ? 1 : 0,
          'workout_goal': modeId == 'workout' ? goal : '',
          'workout_since': store.now,
          'activity_active': 1,
          'activity_mode': modeId,
          'activity_goal': goal,
          'activity_since': store.now,
        },
      );
      return {
        'ok': true,
        'active': true,
        'mode': modeId,
        'goal': goal,
      };
    }

    // GET: estado do usuário + quem está ativo no mesmo modo ou outros modos.
    final mine = store.user(me)!;
    final active = _modeActive(mine);
    final currentMode = (mine['activity_mode'] ?? (mine['workout_active'] == 1 ? 'workout' : 'workout')).toString();
    final modeMeta = activityModesData[currentMode] ?? activityModesData['workout']!;
    final currentGoal = (mine['activity_goal'] ?? mine['workout_goal'] ?? modeMeta['goals'][0]).toString();
    final goals = List<String>.from(modeMeta['goals'] as List);

    final if0 = store.count('encounters', where: (r) => r['a'] == me || r['b'] == me);
    if (if0 == 0) _seedInitialEncounters(me);

    final people = <Json>[];
    if (active) {
      for (final other in store.select(
        'users',
        where: (r) => r['id'] != me && r['suspended'] != 1,
      )) {
        final String id = other['id'];
        final demo = id.startsWith('demo_');
        final prefs = preferences(other);
        final otherActive = demo || _modeActive(other);
        if (!otherActive ||
            prefs['discovery'] != true ||
            prefs['invisible'] == true ||
            store.blocked(me, id) || store.hidden(me, id)) {
          continue;
        }
        final encounter = store.find(
          'encounters',
          where: (r) =>
              ((r['a'] == me && r['b'] == id) ||
                  (r['a'] == id && r['b'] == me)) &&
              r['visible'] <= store.now,
          orderBy: 'created',
          descending: true,
        );

        // Define modo do outro perfil
        String otherMode = (other['activity_mode'] ?? (other['workout_active'] == 1 ? 'workout' : '')).toString();
        if (demo) {
          if (id.contains('lucas')) otherMode = 'workout';
          else if (id.contains('sofia')) otherMode = 'cafe';
          else if (id.contains('camila')) otherMode = 'shopping';
          else if (id.contains('mateo')) otherMode = 'coworking';
          else if (id.contains('beatriz')) otherMode = 'passeio';
          else otherMode = 'workout';
        } else if (otherMode.isEmpty) {
          otherMode = 'workout';
        }

        final otherMeta = activityModesData[otherMode] ?? activityModesData['workout']!;
        final otherGoals = List<String>.from(otherMeta['goals'] as List);
        final otherGoal = other['activity_goal'] ?? other['workout_goal'] ?? otherGoals[0];

        final since = demo
            ? store.now - (10 + (id.hashCode.abs() % 40)) * 60
            : ((other['activity_since'] ?? other['workout_since'] ?? store.now) as num).toDouble();

        people.add({
          ...publicProfile(other, store.clock()),
          'activity_mode': otherMode,
          'activity_goal': otherGoal,
          'workout_goal': otherGoal,
          'mode_emoji': otherMeta['emoji'],
          'mode_name': otherMeta['name'],
          'mode_color': otherMeta['color'],
          'workout_minutes': ((store.now - since) / 60).floor().clamp(0, 999),
          'crossed': encounter != null,
          'region': encounter?['region'] ?? 'Perto de você agora',
          'liked': store.liked(me, id),
          'count': 1,
        });
      }

      // Ordenação: 1º quem está no mesmo modo e mesma meta, 2º mesmo modo, 3º cruzou antes
      people.sort((a, b) {
        int score(Json p) {
          int s = 0;
          if (p['activity_mode'] == currentMode) s += 4;
          if (p['activity_goal'] == currentGoal) s += 2;
          if (p['crossed'] == true) s += 1;
          return s;
        }
        return score(b).compareTo(score(a));
      });
    }

    return {
      'active': active,
      'mode': currentMode,
      'mode_name': modeMeta['name'],
      'mode_emoji': modeMeta['emoji'],
      'mode_color': modeMeta['color'],
      'goal': currentGoal,
      'since': active ? (mine['activity_since'] ?? mine['workout_since']) : null,
      'goals': goals,
      'modes': activityModesData,
      'people': people,
    };
  }
}
