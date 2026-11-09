import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> googleOnboarding(
  BuildContext context, {
  String? initialName,
}) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _GoogleOnboarding(initialName: initialName),
    );

class _GoogleOnboarding extends StatefulWidget {
  const _GoogleOnboarding({this.initialName});
  final String? initialName;
  @override
  State<_GoogleOnboarding> createState() => _GoogleOnboardingState();
}

class _GoogleOnboardingState extends State<_GoogleOnboarding> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  DateTime? birth;
  bool consent = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Complete sua conta'),
    content: SizedBox(
      width: 370,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'O Tevi é exclusivo para maiores de 18 anos. Sua descoberta começa desativada.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Seu nome'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe seu nome.' : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final value = await showDatePicker(
                    context: context,
                    initialDate: DateTime(now.year - 18, now.month, now.day),
                    firstDate: DateTime(now.year - 110),
                    lastDate: now,
                  );
                  if (mounted && value != null) setState(() => birth = value);
                },
                child: Text(
                  birth == null
                      ? 'Data de nascimento'
                      : '${birth!.day}/${birth!.month}/${birth!.year}',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: (v) => setState(() => consent = v ?? false),
                title: const Text(
                  'Tenho 18 anos e aceito os termos de participação e privacidade.',
                ),
              ),
              const Text(
                'Descoberta opcional; cruzamentos aproximados e atrasados; conversas só com interesse mútuo. Você pode bloquear, denunciar, exportar e excluir seus dados. Solicitações de moderação ficam locais até integração externa.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: birth == null || !consent
            ? null
            : () {
                if (form.currentState!.validate())
                  Navigator.pop(context, <String, dynamic>{
                    'name': name.text.trim(),
                    'birthdate': birth!.toIso8601String().split('T').first,
                    'consent': consent,
                  });
              },
        child: const Text('Continuar'),
      ),
    ],
  );
}
