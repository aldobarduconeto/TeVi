import 'dart:convert';

import 'theme/app_theme.dart';
import '../services/api.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void toast(BuildContext context, String message) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

Future<void> attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;
Future<String?> input(
  BuildContext context,
  String title, {
  String hint = '',
  bool secret = false,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        obscureText: secret,
        maxLength: secret ? 128 : 2000,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text.trim()),
          child: Text('Continuar'),
        ),
      ],
    ),
  );
  // The dialog's exit animation may still reference the controller.
  return result;
}

class PersonAvatar extends StatelessWidget {
  final Map<String, dynamic> person;
  final double radius;
  const PersonAvatar(this.person, {super.key, this.radius = 26});

  static final Map<String, Uint8List> _avatarCache = {};

  static Uint8List? _getOrDecode(String photo) {
    if (!photo.startsWith('data:image/')) return null;
    final cached = _avatarCache[photo];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(photo.split(',').last);
      if (_avatarCache.length > 120) {
        _avatarCache.remove(_avatarCache.keys.first);
      }
      _avatarCache[photo] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (person['name'] ?? '?').toString();
    final photo = (person['photo'] ?? '').toString();
    final imageBytes = _getOrDecode(photo);
    final pixelSize = (radius * 2 * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0)).toInt().clamp(32, 180);
    final imageProvider = imageBytes != null
        ? ResizeImage(MemoryImage(imageBytes), width: pixelSize, height: pixelSize)
        : null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: context.lavender,
      backgroundImage: imageProvider,
      child: imageBytes == null
          ? Text(
              name.isEmpty ? '?' : name[0],
              style: TextStyle(
                fontSize: radius * .65,
                color: context.coral,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const EmptyState(
    this.title,
    this.subtitle, {
    super.key,
    this.icon = Icons.explore_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: context.lavender,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 28, color: context.coral),
        ),
        SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.muted, height: 1.7, fontSize: 13),
        ),
      ],
    ),
  );
}

class PageTitle extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final Widget? action;
  const PageTitle(
    this.eyebrow,
    this.title,
    this.subtitle, {
    super.key,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 28),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: context.coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(color: context.muted, height: 1.5),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class RemoteList extends StatefulWidget {
  final Api api;
  final String path;
  final String title;
  final Widget Function(BuildContext, dynamic, VoidCallback) itemBuilder;
  const RemoteList({
    super.key,
    required this.api,
    required this.path,
    required this.title,
    required this.itemBuilder,
  });
  @override
  State<RemoteList> createState() => _RemoteListState();
}

class _RemoteListState extends State<RemoteList> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = widget.api.request('GET', widget.path);
  }

  void reload() {
    if (!mounted) return;
    final next = widget.api.request('GET', widget.path);
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [IconButton(onPressed: reload, icon: Icon(Icons.refresh))],
    ),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${snapshot.error}'),
                TextButton(onPressed: reload, child: Text('Tentar novamente')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data as List;
        if (items.isEmpty) {
          return Center(
            child: EmptyState(
              'Tudo tranquilo por aqui',
              'Os novos registros vão aparecer nesta tela.',
            ),
          );
        }
        return ListView.separated(
          padding: context.cardInsets,
          itemCount: items.length,
          separatorBuilder: (_, _) => SizedBox(height: 12),
          itemBuilder: (context, i) =>
              widget.itemBuilder(context, items[i], reload),
        );
      },
    ),
  );
}

Future<void> copyText(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) toast(context, 'Copiado para a área de transferência.');
}

class ProfileGallery extends StatelessWidget {
  final Map<String, dynamic> person;
  const ProfileGallery(this.person, {super.key});
  @override
  Widget build(BuildContext context) {
    final photos = List<String>.from(
      person['photos'] ??
          ((person['photo'] ?? '') == '' ? <String>[] : [person['photo']]),
    );
    if (photos.isEmpty) return PersonAvatar(person, radius: 50);
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => SizedBox(width: 12),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(
            base64Decode(photos[i].split(',').last),
            width: 200,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
