import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/media_service.dart';
import '../common.dart';

Future<void> editProfile(BuildContext context, Api api) async {
  final p = api.me!;
  final name = TextEditingController(text: p['name']);
  final bio = TextEditingController(text: p['bio']);
  var goal = p['goal']?.toString() ?? 'Amizade e boas conversas';
  var relationshipStatus = p['relationship_status']?.toString() ?? 'Solteiro(a)';
  var photo = p['photo'] as String;
  final photos = List<String>.from(
    p['photos'] ?? (photo.isEmpty ? <String>[] : [photo]),
  );
  final interests = List<String>.from(p['interests']);
  final currentSocials = p['socials'] is Map
      ? Map<String, dynamic>.from(p['socials'] as Map)
      : <String, dynamic>{};
  final instagram = TextEditingController(
    text: currentSocials['instagram']?.toString() ?? '',
  );
  final tiktok = TextEditingController(
    text: currentSocials['tiktok']?.toString() ?? '',
  );
  final spotify = TextEditingController(
    text: currentSocials['spotify']?.toString() ?? '',
  );
  final linkedin = TextEditingController(
    text: currentSocials['linkedin']?.toString() ?? '',
  );
  final saved = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, change) => AlertDialog(
        title: Text('Do seu jeito'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PersonAvatar({'name': name.text, 'photo': photo}, radius: 42),
                TextButton.icon(
                  onPressed: photos.length >= 6
                      ? null
                      : () => attempt(c, () async {
                          final picked = await pickPhoto();
                          if (picked != null && c.mounted) {
                            change(() {
                              photos.add(picked);
                              photo = photos.first;
                            });
                          }
                        }),
                  icon: Icon(Icons.photo_camera_outlined),
                  label: Text('Adicionar foto (${photos.length}/6)'),
                ),
                if (photos.isNotEmpty) ...[
                  Text(
                    'Toque numa foto para usar como principal.',
                    style: TextStyle(fontSize: 11),
                  ),
                  Wrap(
                    spacing: 8,
                    children: photos
                        .map(
                          (src) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => change(() {
                                  photos.remove(src);
                                  photos.insert(0, src);
                                  photo = src;
                                }),
                                child: PersonAvatar({
                                  'name': name.text,
                                  'photo': src,
                                }, radius: 28),
                              ),
                              IconButton(
                                tooltip: 'Remover foto',
                                icon: Icon(Icons.close, size: 15),
                                onPressed: () => change(() {
                                  photos.remove(src);
                                  photo = photos.isEmpty ? '' : photos.first;
                                }),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ],
                TextField(
                  controller: name,
                  maxLength: 60,
                  decoration: InputDecoration(labelText: 'Nome'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: bio,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'Um pouco sobre você'),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: [
                    'Solteiro(a)',
                    'Em um relacionamento sério',
                    'Relacionamento aberto',
                    'Enrolado(a)',
                    'Prefiro não rotular',
                  ].contains(relationshipStatus) ? relationshipStatus : 'Solteiro(a)',
                  decoration: InputDecoration(
                    labelText: 'Status de Relacionamento',
                    prefixIcon: Icon(Icons.favorite_border_rounded, size: 20),
                  ),
                  items: [
                    'Solteiro(a)',
                    'Em um relacionamento sério',
                    'Relacionamento aberto',
                    'Enrolado(a)',
                    'Prefiro não rotular',
                  ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => change(() => relationshipStatus = v!),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: [
                    'Amizade e boas conversas',
                    'Namoro sério',
                    'Conhecer pessoas novas',
                    'Bate-papo casual',
                    'Companhia para eventos e rolês',
                    'Networking profissional',
                    'Conhecer pessoas',
                    'Amizade',
                    'Relacionamento',
                  ].contains(goal) ? goal : 'Amizade e boas conversas',
                  decoration: InputDecoration(
                    labelText: 'O que você busca?',
                    prefixIcon: Icon(Icons.explore_outlined, size: 20),
                  ),
                  items: [
                    'Amizade e boas conversas',
                    'Namoro sério',
                    'Conhecer pessoas novas',
                    'Bate-papo casual',
                    'Companhia para eventos e rolês',
                    'Networking profissional',
                  ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => change(() => goal = v!),
                ),
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Seus interesses • até 10'),
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children:
                      [
                            'Café',
                            'Música',
                            'Cinema',
                            'Arte',
                            'Viagens',
                            'Corrida',
                            'Livros',
                            'Fotografia',
                            'Gastronomia',
                            'Jogos',
                          ]
                          .map(
                            (i) => FilterChip(
                              label: Text(i),
                              selected: interests.contains(i),
                              onSelected: (v) => change(() {
                                if (v && interests.length < 10) {
                                  interests.add(i);
                                } else {
                                  interests.remove(i);
                                }
                              }),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Suas redes sociais (opcional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: instagram,
                  decoration: const InputDecoration(
                    labelText: 'Instagram',
                    hintText: '@seu.usuario',
                    prefixIcon: Icon(Icons.camera_alt_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tiktok,
                  decoration: const InputDecoration(
                    labelText: 'TikTok',
                    hintText: '@seu.usuario',
                    prefixIcon: Icon(Icons.music_note_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: spotify,
                  decoration: const InputDecoration(
                    labelText: 'Spotify',
                    hintText: 'Nome de usuário ou artista',
                    prefixIcon: Icon(Icons.headphones_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: linkedin,
                  decoration: const InputDecoration(
                    labelText: 'LinkedIn',
                    hintText: 'seu-usuario',
                    prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) {
                toast(c, 'Informe seu nome.');
                return;
              }
              Navigator.pop(c, true);
            },
            child: Text('Salvar perfil'),
          ),
        ],
      ),
    ),
  );
  if (saved == true && context.mounted) {
    await attempt(context, () async {
      await api.request('PATCH', '/me', {
        'name': name.text.trim(),
        'bio': bio.text.trim(),
        'goal': goal,
        'relationship_status': relationshipStatus,
        'photo': photo,
        'photos': photos,
        'interests': interests,
        'socials': {
          if (instagram.text.trim().isNotEmpty)
            'instagram': instagram.text.trim(),
          if (tiktok.text.trim().isNotEmpty)
            'tiktok': tiktok.text.trim(),
          if (spotify.text.trim().isNotEmpty)
            'spotify': spotify.text.trim(),
          if (linkedin.text.trim().isNotEmpty)
            'linkedin': linkedin.text.trim(),
        },
      });
      await api.refresh();
      if (context.mounted) toast(context, 'Perfil atualizado.');
    });
  }
}
