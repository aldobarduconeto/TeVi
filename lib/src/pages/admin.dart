import 'dart:convert';

import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../services/api.dart';
import 'common.dart';

class AdminScreen extends StatefulWidget {
  final Api api;
  const AdminScreen({super.key, required this.api});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<dynamic> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    future = widget.api.request('GET', '/admin');
  }

  void reload() {
    if (!mounted) return;
    final next = widget.api.request('GET', '/admin');
    setState(() {
      future = next;
    });
  }

  Future<void> action(String path, Map<String, dynamic> data) async {
    if (busy) return;
    setState(() => busy = true);
    await attempt(context, () async {
      await widget.api.request('POST', path, data);
      reload();
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> event() async {
    final form = GlobalKey<FormState>();
    final fields = <String, TextEditingController>{
      for (final k in ['title', 'place', 'category', 'description', 'starts'])
        k: TextEditingController(),
    };
    final labels = {
      'title': 'Nome do evento',
      'place': 'Local público',
      'category': 'Categoria (Café, Arte, Ao ar livre)',
      'description': 'Descrição',
      'starts': 'Data e horário com fuso',
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Publicar evento'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fields.entries
                    .map(
                      (e) => Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: e.value,
                          maxLength: e.key == 'description'
                              ? 500
                              : e.key == 'starts'
                              ? 60
                              : e.key == 'category'
                              ? 50
                              : 100,
                          decoration: InputDecoration(labelText: labels[e.key]),
                          validator: (s) => s == null || s.trim().isEmpty
                              ? 'Campo obrigatório.'
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
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
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: Text('Publicar'),
          ),
        ],
      ),
    );
    if (save == true) {
      await action(
        '/admin/events',
        fields.map((k, v) => MapEntry(k, v.text.trim())),
      );
    }
  }

  Widget section(
    String title,
    List<dynamic> rows,
    Widget Function(dynamic) builder,
  ) => Padding(
    padding: EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 12),
        if (rows.isEmpty)
          Text('Nenhum registro.', style: TextStyle(color: context.muted)),
        ...rows.map(
          (r) => Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Card(child: builder(r)),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Moderação e operação'),
      actions: [
        IconButton(
          onPressed: reload,
          tooltip: 'Atualizar',
          icon: Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: EmptyState('Acesso indisponível', '${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final d = snapshot.data as Map<String, dynamic>;
        return ListView(
          padding: context.pageInsets,
          children: [
            PageTitle(
              'Painel administrativo',
              'Cuidar das conexões.',
              'Todas as consultas deste painel são registradas para auditoria.',
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: (d['stats'] as Map<String, dynamic>).entries
                  .map(
                    (s) => SizedBox(
                      width: 150,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s.value}',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: context.coral,
                                ),
                              ),
                              Text(
                                {
                                  'users': 'Pessoas',
                                  'encounters': 'Cruzamentos',
                                  'matches': 'Matches',
                                  'messages': 'Mensagens',
                                }[s.key]!,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: busy ? null : event,
                icon: Icon(Icons.add),
                label: Text('Publicar evento'),
              ),
            ),
            section(
              'Denúncias',
              d['reports'],
              (r) => ListTile(
                title: Text(r['reason']),
                subtitle: Text('Perfil: ${r['target']}\n${r['detail']}'),
                isThreeLine: true,
                trailing: r['status'] == 'open'
                    ? TextButton(
                        onPressed: busy
                            ? null
                            : () => action('/admin/reports', {'id': r['id']}),
                        child: Text('Marcar revisada'),
                      )
                    : Text('Revisada'),
              ),
            ),
            section(
              'Verificações pendentes',
              d['verification'],
              (r) => Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Solicitação de ${r['user_id']}'),
                    SizedBox(height: 12),
                    if ((r['selfie'] as String).startsWith('data:'))
                      Image.memory(
                        base64Decode((r['selfie'] as String).split(',').last),
                        height: 180,
                      ),
                    SizedBox(height: 12),
                    Text(
                      'A revisão é manual. Compare a selfie com o perfil antes de decidir.',
                      style: TextStyle(fontSize: 12),
                    ),
                    TextButton(
                      onPressed: () async {
                        final users = d['users'] as List;
                        final user = users.where(
                          (u) => u['id'] == r['user_id'],
                        );
                        if (user.isNotEmpty) {
                          final p = await widget.api.request(
                            'GET',
                            '/admin/profile/${r['user_id']}',
                          );
                          if (context.mounted) {
                            await showDialog<void>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(p['name']),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PersonAvatar(
                                      Map<String, dynamic>.from(p),
                                      radius: 80,
                                    ),
                                    Text(p['bio']),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: Text('Fechar'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                      child: Text('Consultar perfil'),
                    ),
                    Wrap(
                      spacing: 10,
                      children: [
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => action('/admin/verification', {
                                  'id': r['id'],
                                  'approved': true,
                                }),
                          child: Text('Aprovar revisão'),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => action('/admin/verification', {
                                  'id': r['id'],
                                  'approved': false,
                                }),
                          child: Text('Recusar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            section(
              'Atendimentos',
              d['tickets'],
              (r) => ListTile(
                title: Text(r['subject']),
                subtitle: Text(r['detail']),
                trailing: r['status'] == 'open'
                    ? TextButton(
                        onPressed: busy
                            ? null
                            : () => action('/admin/tickets', {'id': r['id']}),
                        child: Text('Resolver'),
                      )
                    : Text('Resolvido'),
              ),
            ),
            section(
              'Pessoas',
              d['users'],
              (u) => ListTile(
                leading: Icon(Icons.person_outline),
                title: Text(u['name']),
                subtitle: Text(u['id']),
                trailing: u['id'] == widget.api.me!['id']
                    ? Text('Você')
                    : TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (await confirm(
                                  context,
                                  u['suspended'] == 1
                                      ? 'Reativar conta?'
                                      : 'Suspender conta?',
                                  'A ação será registrada para auditoria.',
                                )) {
                                  await action('/admin/users', {
                                    'id': u['id'],
                                    'suspended': u['suspended'] != 1,
                                  });
                                }
                              },
                        child: Text(
                          u['suspended'] == 1 ? 'Reativar' : 'Suspender',
                        ),
                      ),
              ),
            ),
            section(
              'Auditoria recente',
              d['audit'],
              (r) => ListTile(
                leading: Icon(Icons.history),
                title: Text(r['action']),
                subtitle: Text('Operador: ${r['actor']} • ${r['target']}'),
              ),
            ),
          ],
        );
      },
    ),
  );
}
