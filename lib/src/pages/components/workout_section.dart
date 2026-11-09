import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../common.dart';
import 'crossing_popup.dart';
import '../theme/app_theme.dart';
import '../theme/liquid_glass.dart';

/// Ícones para metas comuns do aplicativo.
const _goalIcons = <String, IconData>{
  'Hipertrofia': Icons.fitness_center_rounded,
  'Emagrecimento': Icons.local_fire_department_rounded,
  'Resistência': Icons.timer_rounded,
  'Funcional': Icons.sports_gymnastics_rounded,
  'Corrida': Icons.directions_run_rounded,
  'Yoga e mobilidade': Icons.self_improvement_rounded,
  'Moda & Roupas': Icons.checkroom_rounded,
  'Eletrônicos & Tech': Icons.devices_rounded,
  'Garimpos & Brechós': Icons.shopping_bag_rounded,
  'Presentes & Decoração': Icons.card_giftcard_rounded,
  'Praça de Alimentação': Icons.restaurant_rounded,
  'Caminhada relaxante': Icons.hiking_rounded,
  'Passeio no Parque': Icons.park_rounded,
  'Pôr do Sol & Vista': Icons.wb_twilight_rounded,
  'Fotografia urbana': Icons.camera_alt_rounded,
  'Descanso ao ar livre': Icons.nature_people_rounded,
  'Networking tech': Icons.work_rounded,
  'Estudo concentrado': Icons.menu_book_rounded,
  'Troca de ideias': Icons.lightbulb_rounded,
  'Café produtivo': Icons.coffee_rounded,
  'Freelancers': Icons.laptop_mac_rounded,
  'Barzinhos & Chopp': Icons.sports_bar_rounded,
  'Música ao vivo': Icons.music_note_rounded,
  'Balada & Dança': Icons.nightlife_rounded,
  'Drinks autorais': Icons.local_bar_rounded,
  'Socializar na noite': Icons.celebration_rounded,
  'Cafeteria especial': Icons.local_cafe_rounded,
  'Brunch no fim de semana': Icons.bakery_dining_rounded,
  'Doceria & Sobremesas': Icons.cake_rounded,
  'Almoço executivo': Icons.lunch_dining_rounded,
  'Jantar bistrô': Icons.wine_bar_rounded,
  'Passeio com cachorro': Icons.pets_rounded,
  'Socializar pets': Icons.cruelty_free_rounded,
  'Praça pet friendly': Icons.nature_rounded,
  'Dicas e adestramento': Icons.psychology_rounded,
  'Companhia animal': Icons.favorite_rounded,
  'Pontos turísticos': Icons.location_city_rounded,
  'Roteiro cultural': Icons.map_rounded,
  'Dicas de moradores': Icons.explore_rounded,
  'Passeio histórico': Icons.museum_rounded,
  'Companhia de viagem': Icons.flight_takeoff_rounded,
  'Cinema & Pipoca': Icons.movie_rounded,
  'Teatro & Peças': Icons.theater_comedy_rounded,
  'Exposições & Galerias': Icons.palette_rounded,
  'Feiras de livros': Icons.auto_stories_rounded,
  'Shows & Festivais': Icons.festival_rounded,
};

/// Modos de presença disponíveis no Tevi
const _fallbackModes = <String, Map<String, dynamic>>{
  'workout': {
    'id': 'workout',
    'name': 'Workout & Treino',
    'emoji': '💪',
    'description': 'Parceiros de treino e corrida',
    'color': 0xFFFF7A28,
    'goals': ['Hipertrofia', 'Emagrecimento', 'Resistência', 'Funcional', 'Corrida', 'Yoga e mobilidade'],
  },
  'shopping': {
    'id': 'shopping',
    'name': 'Modo Shopping',
    'emoji': '🛍️',
    'description': 'Compras, moda e achados',
    'color': 0xFFE91E63,
    'goals': ['Moda & Roupas', 'Eletrônicos & Tech', 'Garimpos & Brechós', 'Presentes & Decoração', 'Praça de Alimentação'],
  },
  'passeio': {
    'id': 'passeio',
    'name': 'Modo Passeio',
    'emoji': '🌳',
    'description': 'Ar livre, caminhadas e parques',
    'color': 0xFF2E7D32,
    'goals': ['Caminhada relaxante', 'Passeio no Parque', 'Pôr do Sol & Vista', 'Fotografia urbana', 'Descanso ao ar livre'],
  },
  'coworking': {
    'id': 'coworking',
    'name': 'Modo Coworking',
    'emoji': '💻',
    'description': 'Networking tech e foco',
    'color': 0xFF1976D2,
    'goals': ['Networking tech', 'Estudo concentrado', 'Troca de ideias', 'Café produtivo', 'Freelancers'],
  },
  'balada': {
    'id': 'balada',
    'name': 'Modo Balada & Noite',
    'emoji': '🎉',
    'description': 'Festas, bares e diversão',
    'color': 0xFF9C27B0,
    'goals': ['Barzinhos & Chopp', 'Música ao vivo', 'Balada & Dança', 'Drinks autorais', 'Socializar na noite'],
  },
  'cafe': {
    'id': 'cafe',
    'name': 'Modo Café & Food',
    'emoji': '☕',
    'description': 'Cafeterias especiais e brunch',
    'color': 0xFFD87D4A,
    'goals': ['Cafeteria especial', 'Brunch no fim de semana', 'Doceria & Sobremesas', 'Almoço executivo', 'Jantar bistrô'],
  },
  'pet': {
    'id': 'pet',
    'name': 'Modo Pet Friendly',
    'emoji': '🐕',
    'description': 'Passeios com cães e pets',
    'color': 0xFF00897B,
    'goals': ['Passeio com cachorro', 'Socializar pets', 'Praça pet friendly', 'Dicas e adestramento', 'Companhia animal'],
  },
  'viagem': {
    'id': 'viagem',
    'name': 'Modo Viagem & Turismo',
    'emoji': '✈️',
    'description': 'Turismo e pontos culturais',
    'color': 0xFF0288D1,
    'goals': ['Pontos turísticos', 'Roteiro cultural', 'Dicas de moradores', 'Passeio histórico', 'Companhia de viagem'],
  },
  'cultura': {
    'id': 'cultura',
    'name': 'Modo Arte & Cultura',
    'emoji': '🎭',
    'description': 'Cinema, teatro e museus',
    'color': 0xFF5E35B1,
    'goals': ['Cinema & Pipoca', 'Teatro & Peças', 'Exposições & Galerias', 'Feiras de livros', 'Shows & Festivais'],
  },
};

/// Seção "Modos de Presença & Atividade":
/// Suporta Modo Workout, Shopping, Passeio, Coworking, Balada, Café, Pet, Viagem e Cultura.
class WorkoutSection extends StatefulWidget {
  const WorkoutSection({super.key, required this.api});
  final Api api;

  @override
  State<WorkoutSection> createState() => _WorkoutSectionState();
}

class _WorkoutSectionState extends State<WorkoutSection> {
  bool loading = true, busy = false;
  bool active = false;
  String currentMode = 'workout';
  String modeName = 'Workout & Treino';
  String modeEmoji = '💪';
  Color modeColor = const Color(0xFFFF7A28);
  String goal = '';
  List<String> goals = const [];
  Map<String, dynamic> modesData = _fallbackModes;
  List<Map<String, dynamic>> people = [];
  String? error;
  Timer? _refresh;
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    load();
    _refresh = Timer.periodic(const Duration(seconds: 45), (_) {
      if (active && !busy) load(silent: true);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    try {
      final r = Map<String, dynamic>.from(
        await widget.api.request('GET', '/workout') as Map,
      );
      if (!mounted) return;
      setState(() {
        active = r['active'] == true;
        currentMode = (r['mode'] ?? 'workout').toString();
        modeName = (r['mode_name'] ?? 'Workout & Treino').toString();
        modeEmoji = (r['mode_emoji'] ?? '💪').toString();
        modeColor = Color(r['mode_color'] as int? ?? 0xFFFF7A28);
        goal = (r['goal'] ?? '').toString();
        goals = List<String>.from(r['goals'] ?? const []);
        if (r['modes'] is Map) {
          modesData = Map<String, dynamic>.from(r['modes'] as Map);
        }
        people = (r['people'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        error = null;
      });
    } catch (e) {
      if (mounted && !silent) setState(() => error = '$e');
    } finally {
      if (mounted && loading) setState(() => loading = false);
    }
  }

  Future<void> start(String modeId, String selectedGoal) async {
    setState(() => busy = true);
    await attempt(context, () async {
      await widget.api.request('POST', '/workout', {
        'action': 'start',
        'mode': modeId,
        'goal': selectedGoal,
      });
      await load();
      if (mounted) {
        final mMeta = modesData[modeId] ?? _fallbackModes[modeId] ?? _fallbackModes['workout']!;
        toast(
          context,
          '${mMeta['emoji']} ${mMeta['name']} ativado! Foco: $selectedGoal',
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> stop() async {
    setState(() => busy = true);
    await attempt(context, () async {
      await widget.api.request('POST', '/workout', {'action': 'stop'});
      await load();
      if (mounted) {
        toast(context, 'Modo desativado.');
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> pickGoalAndStart({String? targetMode}) async {
    final modeToUse = targetMode ?? currentMode;
    final mMeta = modesData[modeToUse] ?? _fallbackModes[modeToUse] ?? _fallbackModes['workout']!;
    final modeGoals = List<String>.from(mMeta['goals'] as List? ?? ['Geral']);
    final mColor = Color(mMeta['color'] as int? ?? 0xFFFF7A28);

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        final isDark = Theme.of(c).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141724) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          mMeta['emoji'] ?? '✨',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Qual é o seu foco em ${mMeta['name']}?',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mMeta['description'] ?? 'Selecione para encontrar pessoas na mesma vibe',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final g in modeGoals)
                        ActionChip(
                          avatar: Icon(
                            _goalIcons[g] ?? Icons.star_rounded,
                            size: 18,
                            color: mColor,
                          ),
                          label: Text(
                            g,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: mColor.withValues(alpha: 0.35),
                          ),
                          onPressed: () => Navigator.pop(c, g),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '🔒 O modo desliga automaticamente após 3 horas para garantir total privacidade.',
                    style: TextStyle(fontSize: 11.5, color: c.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected != null) await start(modeToUse, selected);
  }

  Future<void> act(Map<String, dynamic> p, String action) async {
    if (_pending.contains(p['id'])) return;
    setState(() => _pending.add(p['id']));
    await attempt(context, () async {
      await widget.api.request('POST', '/people/${p['id']}/$action');
      await load(silent: true);
    });
    if (mounted) setState(() => _pending.remove(p['id']));
  }

  @override
  Widget build(BuildContext context) {
    final discoveryOn =
        widget.api.settings['discovery'] == true &&
        widget.api.settings['invisible'] != true;

    return LiquidGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho com Ícone e Descrição do Modo Ativo
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: modeColor.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  modeEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          modeName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: active
                                ? modeColor.withValues(alpha: 0.18)
                                : Colors.grey.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            active ? 'ATIVO' : 'DESLIGADO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: active ? modeColor : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active
                          ? 'Foco: $goal • Radar de proximidade ligado'
                          : 'Escolha um modo para encontrar pessoas no mesmo ritmo',
                      style: TextStyle(fontSize: 12, color: context.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Seletor Horizontal de Modos (Workout, Shopping, Passeio, etc.)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: modesData.entries.map((entry) {
                final mId = entry.key;
                final mData = entry.value as Map;
                final isSelected = active && currentMode == mId;
                final mColor = Color(mData['color'] as int? ?? 0xFFFF7A28);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Text(
                      mData['emoji'] ?? '✨',
                      style: const TextStyle(fontSize: 15),
                    ),
                    label: Text(
                      mData['name'] ?? mId,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? mColor : null,
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    selectedColor: mColor.withValues(alpha: 0.18),
                    side: BorderSide(
                      color: isSelected ? mColor : Colors.grey.withValues(alpha: 0.25),
                      width: isSelected ? 1.5 : 1,
                    ),
                    onSelected: (_) {
                      if (!discoveryOn) {
                        toast(context, 'Ative a descoberta geral para ligar os modos.');
                        return;
                      }
                      pickGoalAndStart(targetMode: mId);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Botão de Ação / Desativação
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (!active) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: discoveryOn ? () => pickGoalAndStart(targetMode: currentMode) : null,
                icon: Text(modeEmoji, style: const TextStyle(fontSize: 18)),
                label: Text(
                  'Ativar $modeName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: modeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            if (!discoveryOn) ...[
              const SizedBox(height: 8),
              Text(
                'Ative a descoberta geral acima para poder ativar os modos.',
                style: TextStyle(fontSize: 11.5, color: context.muted),
              ),
            ],
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: stop,
                    icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: const Text(
                      'Desativar Modo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: () => pickGoalAndStart(targetMode: currentMode),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Trocar Foco',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(error!, style: TextStyle(color: context.muted)),
            )
          // 4. Lista de pessoas ativas por perto
          else if (active) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(modeEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pessoas ativas por perto',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${people.length} no radar',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: modeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhum outro usuário com modo ativo por perto agora. Ao cruzarem caminhos, o Tevi notificará você automaticamente.',
                  style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.4),
                ),
              )
            else
              SizedBox(
                height: 184,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: people.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _ModePersonCard(
                    person: people[i],
                    currentMode: currentMode,
                    currentGoal: goal,
                    onTap: () => showCrossingPopup(
                      context: context,
                      person: people[i],
                      busy: _pending.contains(people[i]['id']),
                      onLike: () => act(
                        people[i],
                        people[i]['liked'] == '' ? 'like' : 'unlike',
                      ),
                      onReject: () => act(people[i], 'hide'),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ModePersonCard extends StatelessWidget {
  const _ModePersonCard({
    required this.person,
    required this.currentMode,
    required this.currentGoal,
    required this.onTap,
  });
  final Map<String, dynamic> person;
  final String currentMode;
  final String currentGoal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = (person['activity_goal'] ?? person['workout_goal'] ?? '').toString();
    final minutes = person['workout_minutes'] as int? ?? 0;
    final crossed = person['crossed'] == true;
    final pMode = (person['activity_mode'] ?? 'workout').toString();
    final pEmoji = (person['mode_emoji'] ?? '💪').toString();
    final pColor = Color(person['mode_color'] as int? ?? 0xFFFF7A28);
    final sameGoal = g == currentGoal;
    final sameMode = pMode == currentMode;

    return SizedBox(
      width: 148,
      child: LiquidGlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PersonAvatar(person, radius: 28),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: pColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      pEmoji,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${person['name']}'.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                g,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: pColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              minutes < 1 ? 'começou agora' : 'há $minutes min',
              style: TextStyle(fontSize: 9.5, color: context.muted),
            ),
            if (sameGoal && sameMode) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 10, color: pColor),
                  const SizedBox(width: 2),
                  Text(
                    'Mesmo foco',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: pColor,
                    ),
                  ),
                ],
              ),
            ] else if (crossed) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alt_route_rounded, size: 10, color: context.coral),
                  const SizedBox(width: 2),
                  Text(
                    'Cruzou caminho',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: context.coral,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
