import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../services/api.dart';
import 'common.dart';
import '../services/map_launcher_service.dart';

class EventsScreen extends StatefulWidget {
  final Api api;
  const EventsScreen({super.key, required this.api});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<dynamic> future;
  String category = 'Todos';
  final pending = <String>{};
  @override
  void initState() {
    super.initState();
    future = widget.api.request('GET', '/events');
  }

  void reload() {
    if (!mounted) return;
    final next = widget.api.request('GET', '/events');
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('events-scroll'),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: context.pageInsets,
    children: [
      PageTitle(
        'Saia da rotina',
        'Bons lugares. Novas histórias.',
        'Encontros começam com algo em comum.',
        action: IconButton(
          onPressed: reload,
          tooltip: 'Atualizar',
          icon: Icon(Icons.refresh),
        ),
      ),
      Container(
        padding: context.cardInsets,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(Icons.local_florist_outlined, size: 42, color: context.coral),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aberto a uma boa conversa?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Participe por uma hora. O Tevi não mostra quem continua no local. Cruzamentos de participantes aparecem com atraso.',
                    style: TextStyle(
                      height: 1.6,
                      color: context.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: 24),
      Wrap(
        spacing: 8,
        children: ['Todos', 'Café', 'Ao ar livre', 'Arte']
            .map(
              (v) => ChoiceChip(
                label: Text(v),
                selected: category == v,
                onSelected: (_) => setState(() => category = v),
              ),
            )
            .toList(),
      ),
      SizedBox(height: 20),
      FutureBuilder<dynamic>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState('Não conseguimos carregar', '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final items = (snapshot.data as List)
              .where((e) => category == 'Todos' || category == e['category'])
              .toList();
          if (items.isEmpty) {
            return Card(
              child: EmptyState(
                'Novos lugares em breve',
                'Os eventos publicados pela equipe aparecem aqui.',
                icon: Icons.local_cafe_outlined,
              ),
            );
          }
          return Column(
            children: items
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Card(
                      child: Padding(
                        padding: context.cardInsets,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: context.lavender,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    e['category'] == 'Café'
                                        ? Icons.coffee_outlined
                                        : e['category'] == 'Arte'
                                        ? Icons.palette_outlined
                                        : Icons.park_outlined,
                                    color: context.coral,
                                    size: 30,
                                  ),
                                ),
                                SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e['category'].toString().toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 1.5,
                                          color: context.coral,
                                        ),
                                      ),
                                      SizedBox(height: 7),
                                      Text(
                                        e['title'],
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 18),
                            Text(
                              e['description'],
                              style: TextStyle(
                                height: 1.6,
                                color: context.muted,
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              '${e['place']} • ${e['starts']}',
                              style: TextStyle(fontSize: 12),
                            ),
                            SizedBox(height: 18),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => MapLauncherService.openMapLocation(
                                    regionName: e['place'] ?? e['title'],
                                  ),
                                  icon: const Icon(Icons.map_outlined, size: 16),
                                  label: const Text('Ver no Maps'),
                                ),
                                FilledButton.icon(
                                  onPressed: pending.contains(e['id'])
                                      ? null
                                      : () async {
                                          final join = e['joined'] != true;
                                          if (join &&
                                              !await confirm(
                                                context,
                                                'Participar por uma hora?',
                                                'Você aceita cruzamentos com outros participantes. A descoberta deve estar ativa.',
                                              )) {
                                            return;
                                          }
                                          if (!context.mounted) return;
                                          setState(() => pending.add(e['id']));
                                          await attempt(context, () async {
                                            await widget.api.request(
                                              'POST',
                                              '/events/${e['id']}',
                                              {'join': join},
                                            );
                                            reload();
                                          });
                                          if (mounted) {
                                            setState(
                                              () => pending.remove(e['id']),
                                            );
                                          }
                                        },
                                  icon: Icon(
                                    e['joined'] == true
                                        ? Icons.check
                                        : Icons.add,
                                  ),
                                  label: Text(
                                    e['joined'] == true
                                        ? 'Participando • sair'
                                        : 'Estou aberto a conversar',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => copyText(
                                    context,
                                    'Meu plano de encontro: ${e['title']} em ${e['place']}. Combine o horário comigo. Este compartilhamento é voluntário.',
                                  ),
                                  icon: Icon(Icons.share_outlined, size: 16),
                                  label: Text('Compartilhar plano'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      SizedBox(height: 24),
      Text(
        'Dica de encontro: escolha um espaço público, combine seu transporte e avise alguém de confiança.',
        style: TextStyle(fontSize: 12, color: context.muted, height: 1.7),
      ),
    ],
  );
}
