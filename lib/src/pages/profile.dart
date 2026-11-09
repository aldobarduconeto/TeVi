import 'package:flutter/material.dart';

import '../services/api.dart';
import 'common.dart';
import 'components/profile_editor.dart';
import 'components/social_links_bar.dart';
import 'settings.dart';
import 'theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) {
    final p = api.me;
    if (p == null) return SizedBox.shrink();
    return ListView(
      key: const PageStorageKey('profile-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: context.pageInsets,
      children: [
        PageTitle(
          'Seu perfil',
          'Toda história tem seu jeito.',
          'Mostre um pouco de quem você é.',
        ),
        Card(
          child: Padding(
            padding: context.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PersonAvatar(p, radius: 40),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['name']}, ${p['age']}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if ((p['relationship_status'] ?? '').toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: context.coral.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.favorite_rounded, size: 12, color: context.coral),
                                      const SizedBox(width: 4),
                                      Text(
                                        p['relationship_status'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: context.coral,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6F4BD8).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.explore_outlined, size: 12, color: Color(0xFF6F4BD8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      p['goal'],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6F4BD8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (p['verified'] == true)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                '✓ Perfil revisado',
                                style: TextStyle(color: context.coral),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar perfil',
                      onPressed: () => editProfile(context, api),
                      icon: Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  p['bio'].toString().isEmpty
                      ? 'Adicione uma descrição para que as pessoas conheçam você.'
                      : p['bio'],
                  style: TextStyle(color: context.muted, height: 1.7),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (p['interests'] as List)
                      .map((i) => Chip(label: Text(i)))
                      .toList(),
                ),
                if (p['socials'] is Map && (p['socials'] as Map).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SocialLinksBar(socials: Map<String, dynamic>.from(p['socials'] as Map)),
                ],
                if ((p['photos'] as List? ?? []).isNotEmpty) ...[
                  SizedBox(height: 20),
                  ProfileGallery(p),
                ],
                SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => editProfile(context, api),
                  icon: Icon(Icons.edit_outlined, size: 17),
                  label: Text('Editar meu perfil'),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        Card(
          child: ListTile(
            contentPadding: EdgeInsets.all(22),
            leading: Icon(Icons.settings_outlined, color: context.coral),
            title: Text(
              'Configurações',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Privacidade, descoberta, notificações e conta.'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => SettingsScreen(api: api)),
            ),
          ),
        ),
      ],
    );
  }
}
