import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/api_exception.dart';
import '../../services/api.dart';
import '../../services/google_oidc_service.dart';
import 'google_onboarding_dialog.dart';

class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({
    super.key,
    required this.api,
    this.onToken,
    this.enabled = true,
  });

  final Api api;
  final bool enabled;
  final Future<void> Function(String)? onToken;

  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  final service = GoogleOidcService();
  bool ready = false, busy = false, selecting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (GoogleOidcConfig.configured) unawaited(initialize());
  }

  Future<void> initialize() async {
    try {
      await service.initialize();
      if (widget.onToken != null) await service.signOut();
      if (!mounted) return;
      setState(() => ready = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Não foi possível iniciar o Google. Confira a configuração e tente novamente.',
        );
      }
    }
  }

  Future<void> complete(String token) async {
    if (!mounted || busy || !widget.enabled) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.onToken != null) {
        await widget.onToken!(token);
        return;
      }
      try {
        await widget.api.loginGoogle(token);
      } on ApiException catch (e) {
        if (e.status != 428 || !mounted) rethrow;
        final registration = await googleOnboarding(context);
        if (registration != null && mounted) {
          await widget.api.loginGoogle(token, registration: registration);
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signIn() async {
    if (busy || selecting || !widget.enabled) return;
    setState(() => selecting = true);
    try {
      final token = await service.authenticate();
      if (token != null && mounted) await complete(token);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: ready && !busy && !selecting && widget.enabled
                ? signIn
                : null,
            icon: const Icon(Icons.account_circle_outlined),
            label: Text(busy ? 'Entrando…' : 'Continuar com Google'),
          ),
          if (!GoogleOidcConfig.configured)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Google indisponível nesta instalação.',
                textAlign: TextAlign.center,
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
}
