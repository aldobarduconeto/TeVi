import 'package:flutter/material.dart';

import '../../services/api.dart';

Future<bool?> showPasswordDialog(BuildContext context, Api api) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordDialog(api: api),
    );

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.api});
  final Api api;
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      next = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, obscure = true;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request('PATCH', '/password', {
        'current_password': current.text,
        'new_password': next.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text('Alterar senha'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A senha é local. Outras sessões desta conta neste dispositivo serão encerradas.',
                ),
                SizedBox(height: 18),
                TextFormField(
                  controller: current,
                  obscureText: obscure,
                  autofillHints: [AutofillHints.password],
                  enabled: !busy,
                  decoration: InputDecoration(labelText: 'Senha atual'),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Informe sua senha atual.'
                      : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: next,
                  obscureText: obscure,
                  autofillHints: [AutofillHints.newPassword],
                  enabled: !busy,
                  maxLength: 128,
                  decoration: InputDecoration(
                    labelText: 'Nova senha',
                    helperText: 'Pelo menos 10 caracteres',
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 10
                      ? 'Use pelo menos 10 caracteres.'
                      : v == current.text
                      ? 'Escolha uma senha diferente da atual.'
                      : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: confirmation,
                  obscureText: obscure,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: 'Confirmar nova senha',
                  ),
                  validator: (v) =>
                      v != next.text ? 'As senhas não coincidem.' : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: !obscure,
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          obscure = !(v ?? false);
                        }),
                  title: Text('Mostrar senhas', style: TextStyle(fontSize: 13)),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Salvando…' : 'Salvar nova senha'),
        ),
      ],
    ),
  );
}
