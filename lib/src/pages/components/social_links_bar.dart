import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class SocialLinksBar extends StatelessWidget {
  const SocialLinksBar({super.key, required this.socials, this.compact = false});

  final Map<String, dynamic> socials;
  final bool compact;

  static Future<void> openSocialLink(
    BuildContext context,
    String network,
    String rawValue,
  ) async {
    final cleanValue = rawValue.trim();
    if (cleanValue.isEmpty) return;

    Uri? targetUrl;
    if (cleanValue.startsWith('http://') || cleanValue.startsWith('https://')) {
      targetUrl = Uri.tryParse(cleanValue);
    } else {
      final handle = cleanValue.replaceAll('@', '');
      switch (network) {
        case 'instagram':
          targetUrl = Uri.parse('https://instagram.com/$handle');
          break;
        case 'tiktok':
          targetUrl = Uri.parse('https://tiktok.com/@$handle');
          break;
        case 'spotify':
          targetUrl = Uri.parse(
            'https://open.spotify.com/search/${Uri.encodeComponent(cleanValue)}',
          );
          break;
        case 'linkedin':
          targetUrl = Uri.parse('https://linkedin.com/in/$handle');
          break;
      }
    }

    if (targetUrl != null) {
      try {
        if (await canLaunchUrl(targetUrl)) {
          await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(targetUrl);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (socials.isEmpty) return const SizedBox.shrink();

    final items = <Widget>[];

    void addBadge({
      required String key,
      required String label,
      required IconData icon,
      required Color color,
      required Color textColor,
    }) {
      final val = socials[key]?.toString().trim() ?? '';
      if (val.isEmpty) return;

      items.add(
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => openSocialLink(context, key, val),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 13 : 15, color: color),
                const SizedBox(width: 5),
                Text(
                  compact
                      ? (val.startsWith('@') ? val : '@$val')
                      : '$label ${val.startsWith('@') ? val : '@$val'}',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    addBadge(
      key: 'instagram',
      label: 'Instagram',
      icon: Icons.camera_alt_outlined,
      color: const Color(0xFFE1306C),
      textColor: const Color(0xFFC13584),
    );

    addBadge(
      key: 'spotify',
      label: 'Spotify',
      icon: Icons.headphones_outlined,
      color: const Color(0xFF1DB954),
      textColor: const Color(0xFF1AA34A),
    );

    addBadge(
      key: 'tiktok',
      label: 'TikTok',
      icon: Icons.music_note_outlined,
      color: context.ink,
      textColor: context.ink,
    );

    addBadge(
      key: 'linkedin',
      label: 'LinkedIn',
      icon: Icons.work_outline_rounded,
      color: const Color(0xFF0077B5),
      textColor: const Color(0xFF00669C),
    );

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items,
    );
  }
}
