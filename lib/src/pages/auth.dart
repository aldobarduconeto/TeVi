import 'components/apple_login_button.dart';
import 'components/google_login_button.dart';

import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../services/api.dart';

class AuthScreen extends StatefulWidget {
  final Api api;
  const AuthScreen({super.key, required this.api});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  DateTime? birthdate;
  bool register = false, consent = false, busy = false, obscure = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (register && (birthdate == null || !consent)) {
      setState(() => error = 'Informe seu nascimento e aceite os termos.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.login(
        email.text.trim(),
        password.text,
        registration: register
            ? {
                'name': name.text.trim(),
                'birthdate': birthdate!.toIso8601String().split('T').first,
                'consent': consent,
              }
            : null,
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void terms() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Participação e privacidade'),
      content: SingleChildScrollView(
        child: Text(
          'O Tevi é exclusivo para maiores de 18 anos. A descoberta é opcional e começa desativada.\n\nCruzamentos são aproximados e aparecem após 15 minutos. Sua localização exata não é mostrada. Posições expiram em cinco minutos; cruzamentos, em sete dias.\n\nConversas dependem de interesse mútuo. Você pode pausar a descoberta, bloquear, denunciar, exportar dados e excluir a conta. Fotos e mensagens são armazenadas para prestar o serviço. Selfies são revisadas manualmente, sem reconhecimento biométrico.\n\nRespeite os limites das outras pessoas e não publique informações de desconhecidos.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Entendi')),
      ],
    ),
  );
  Widget fields() => Form(
    key: form,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            register ? 'Crie sua conta' : 'Que bom te ver.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              height: 1.2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            register
                ? 'Uma nova conexão começa com você.'
                : 'Entre para continuar suas conexões.',
            style: TextStyle(fontSize: 14, color: context.muted, height: 1.6),
          ),
          SizedBox(height: 32),
          if (register) ...[
            TextFormField(
              controller: name,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Seu nome',
                counterText: '',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe seu nome.' : null,
            ),
            SizedBox(height: 16),
          ],
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: [AutofillHints.email],
            decoration: InputDecoration(labelText: 'E-mail'),
            validator: (v) =>
                v != null &&
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                ? null
                : 'Informe um e-mail válido.',
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: password,
            obscureText: obscure,
            autofillHints: [
              register ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: 'Senha',
              helperText: 'Pelo menos 10 caracteres',
              suffixIcon: IconButton(
                tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                ),
              ),
            ),
            validator: (v) =>
                (v?.length ?? 0) < 10 ? 'Use pelo menos 10 caracteres.' : null,
            onFieldSubmitted: (_) {
              if (!busy) submit();
            },
          ),
          if (register) ...[
            SizedBox(height: 20),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final value = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year - 20),
                  firstDate: DateTime(now.year - 110),
                  lastDate: DateTime(now.year - 18, now.month, now.day),
                );
                if (value != null) setState(() => birthdate = value);
              },
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 17),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      birthdate == null
                          ? 'Data de nascimento • 18+'
                          : '${birthdate!.day}/${birthdate!.month}/${birthdate!.year}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: consent,
              onChanged: (v) => setState(() => consent = v ?? false),
              title: Text(
                'Tenho 18 anos e aceito os termos.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: terms,
                child: Text('Ler termos de participação'),
              ),
            ),
          ],
          if (error != null)
            Container(
              margin: EdgeInsets.only(top: 18),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          SizedBox(height: 28),
          FilledButton(
            onPressed: busy ? null : submit,
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(register ? 'Criar conta' : 'Entrar'),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          GoogleLoginButton(api: widget.api, enabled: !busy),
          const SizedBox(height: 12),
          AppleLoginButton(api: widget.api, enabled: !busy),
          SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                register ? 'Já tem uma conta?' : 'Novo por aqui?',
                style: TextStyle(fontSize: 12, color: context.muted),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        register = !register;
                        error = null;
                      }),
                child: Text(register ? 'Entrar na conta' : 'Criar conta'),
              ),
            ],
          ),
          SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: context.muted),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Sua privacidade vem primeiro.',
                  style: TextStyle(fontSize: 11, color: context.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, size) => Row(
          children: [
            if (size.maxWidth >= 980)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.lavender,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: size.maxHeight - 48,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TeviLogo(),
                              SizedBox(height: 32),
                              SizedBox(
                                height: 220,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: _ConnectionPainter(
                                    accent: context.coral,
                                    surface: context.surface,
                                    foreground: context.ink,
                                    onForeground: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                  ),
                                ),
                              ),
                              SizedBox(height: 28),
                              Text(
                                'Seu caminho.\nNovas conexões.',
                                style: TextStyle(
                                  fontSize: 48,
                                  height: 1.12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -2,
                                  color: context.ink,
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Reencontre quem cruzou com você.\nConverse quando o interesse for dos dois.',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.8,
                                  color: context.muted,
                                ),
                              ),
                              SizedBox(height: 40),
                              Row(
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                    color: context.coral,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No seu tempo. Com os seus limites.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(size.maxWidth < 600 ? 20 : 56),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 370),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (size.maxWidth < 980) ...[
                          TeviLogo(),
                          SizedBox(height: 48),
                        ],
                        fields(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter({
    required this.accent,
    required this.surface,
    required this.foreground,
    required this.onForeground,
  });
  final Color accent, surface, foreground, onForeground;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .12, size.height * .75)
      ..cubicTo(
        size.width * .65,
        size.height * 1.1,
        size.width * .2,
        -size.height * .2,
        size.width * .85,
        size.height * .3,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 32
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final point in [
      Offset(size.width * .12, size.height * .75),
      Offset(size.width * .85, size.height * .3),
    ]) {
      canvas.drawCircle(point, 22, Paint()..color = surface);
      canvas.drawCircle(point, 7, Paint()..color = accent);
    }
    final center = Offset(size.width * .52, size.height * .48);
    canvas.drawCircle(center, 38, Paint()..color = foreground);
    final painter = TextPainter(
      text: TextSpan(
        text: 'oi',
        style: TextStyle(
          color: onForeground,
          fontSize: 26,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is! _ConnectionPainter ||
      oldDelegate.accent != accent ||
      oldDelegate.surface != surface ||
      oldDelegate.foreground != foreground;
}
