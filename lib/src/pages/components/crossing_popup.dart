import 'dart:convert';
import 'package:flutter/material.dart';

import '../../services/map_launcher_service.dart';
import '../common.dart';
import '../theme/app_theme.dart';
import '../theme/liquid_glass.dart';
import 'social_links_bar.dart';

/// Shows the full liquid glass encounter popup when a crossing item or card is tapped.
Future<void> showCrossingPopup({
  required BuildContext context,
  required Map<String, dynamic> person,
  required bool busy,
  required VoidCallback onLike,
  required VoidCallback onReject,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    constraints: const BoxConstraints(maxWidth: 580),
    builder: (c) => _CrossingPopupContent(
      person: person,
      busy: busy,
      onLike: onLike,
      onReject: onReject,
    ),
  );
}

class _CrossingPopupContent extends StatelessWidget {
  const _CrossingPopupContent({
    required this.person,
    required this.busy,
    required this.onLike,
    required this.onReject,
  });

  final Map<String, dynamic> person;
  final bool busy;
  final VoidCallback onLike, onReject;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liked = p['liked'] != '';
    final photos = List<String>.from(
      p['photos'] ?? ((p['photo'] ?? '') == '' ? <String>[] : [p['photo']]),
    );
    final socials = p['socials'] is Map
        ? Map<String, dynamic>.from(p['socials'] as Map)
        : <String, dynamic>{};
    final region = p['region']?.toString() ?? 'Cruzamento por proximidade';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141724) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.coral.withValues(alpha: 0.16),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Large Hero Photo with Liquid Glass Overlay
            _buildHeroPhoto(context, photos, p, region),
            const SizedBox(height: 18),

            // 2. Name, Age & Verified
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${p['name']}, ${p['age']}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                if (p['verified'] == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.coral.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.coral.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 16, color: context.coral),
                        const SizedBox(width: 4),
                        Text(
                          'Verificado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.coral,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // 3. Status de Relacionamento & Goal / Buscando
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if ((p['relationship_status'] ?? '').toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.coral.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_rounded, size: 13, color: context.coral),
                        const SizedBox(width: 5),
                        Text(
                          '${p['relationship_status']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.coral,
                          ),
                        ),
                      ],
                    ),
                  ),
                if ((p['goal'] ?? '').toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BD8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF6F4BD8).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.explore_outlined, size: 13, color: Color(0xFF6F4BD8)),
                        const SizedBox(width: 5),
                        Text(
                          'Buscando: ${p['goal']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6F4BD8),
                          ),
                        ),
                      ],
                    ),
                  ),
                if ((p['workout_goal'] ?? '').toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A28).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF7A28).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fitness_center_rounded, size: 13, color: Color(0xFFFF7A28)),
                        const SizedBox(width: 5),
                        Text(
                          'Treino: ${p['workout_goal']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7A28),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. Bio
            Text(
              p['bio'].toString().isEmpty
                  ? 'Cruzaram caminhos no mundo real através do Tevi.'
                  : p['bio'],
              style: TextStyle(
                fontSize: 14,
                color: context.ink,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),

            // 5. Interests Chips
            if ((p['interests'] as List? ?? []).isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (p['interests'] as List)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.lavender,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: context.coral.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.ink,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
            ],

            // 6. Prominent Social Networks (Redes Sociais)
            _buildSocialsSection(context, socials),
            const SizedBox(height: 16),

            // 7. Encounter Location with Native Maps Button
            LiquidGlassContainer(
              padding: const EdgeInsets.all(14),
              borderRadius: 18,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.coral.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.place_rounded, color: context.coral, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Onde seus caminhos se cruzaram:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              region,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (p['ble_certified'] == true) ...[
                              const SizedBox(height: 4),
                              const Row(
                                children: [
                                  Icon(Icons.verified_rounded, size: 14, color: Color(0xFF00C853)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Presença física comprovada via sinal BLE de rádio',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF00C853),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: context.coral.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => MapLauncherService.openMapLocation(
                        regionName: region,
                      ),
                      icon: Icon(Icons.map_outlined, color: context.coral, size: 18),
                      label: Text(
                        'Abrir no Google Maps / Apple Maps',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.coral,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 8. Action Buttons (Recusar e Aceitar)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: context.line),
                      foregroundColor: context.muted,
                    ),
                    onPressed: busy
                        ? null
                        : () {
                            Navigator.pop(context);
                            onReject();
                          },
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text(
                      'Recusar',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: liked ? context.lavender : context.coral,
                      foregroundColor: liked
                          ? context.coral
                          : Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      shadowColor: context.coral.withValues(alpha: 0.4),
                    ),
                    onPressed: busy
                        ? null
                        : () {
                            Navigator.pop(context);
                            onLike();
                          },
                    icon: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      size: 20,
                    ),
                    label: Text(
                      liked ? 'Match Confirmado' : 'Aceitar / Match',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPhoto(
    BuildContext context,
    List<String> photos,
    Map<String, dynamic> p,
    String region,
  ) {
    if (photos.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 270,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.lavender,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                base64Decode(photos.first.split(',').last),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackAvatar(context, p),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                    const Icon(Icons.near_me_rounded, color: Colors.white, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cruzaram em $region',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p['ble_certified'] == true) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bluetooth_connected_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'BLE Certificado',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p['period'] ?? 'Recentemente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildFallbackAvatar(context, p);
  }

  Widget _buildFallbackAvatar(BuildContext context, Map<String, dynamic> p) {
    final name = (p['name'] ?? '?').toString();
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.coral.withValues(alpha: 0.2),
            context.lavender,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonAvatar(p, radius: 44),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialsSection(BuildContext context, Map<String, dynamic> socials) {
    if (socials.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.lavender.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.share_outlined, size: 16, color: context.muted),
            const SizedBox(width: 8),
            Text(
              'Redes sociais não vinculadas pelo usuário',
              style: TextStyle(fontSize: 12, color: context.muted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link_rounded, size: 16, color: context.coral),
            const SizedBox(width: 6),
            const Text(
              'Redes Sociais Conectadas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SocialLinksBar(socials: socials, compact: false),
      ],
    );
  }
}
