import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models/api_exception.dart';
import '../../services/api.dart';
import '../../services/apple_oidc_service.dart';
import 'google_onboarding_dialog.dart';

class AppleLoginButton extends StatefulWidget {
  const AppleLoginButton({
    super.key,
    required this.api,
    this.onToken,
    this.enabled = true,
  });

  final Api api;
  final bool enabled;
  final Future<void> Function(String)? onToken;

  @override
  State<AppleLoginButton> createState() => _AppleLoginButtonState();
}

class _AppleLoginButtonState extends State<AppleLoginButton> {
  final service = AppleOidcService();
  bool busy = false;
  String? error;

  Future<void> signIn() async {
    if (busy || !widget.enabled) return;
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final result = await service.authenticate();
      if (result == null || !mounted) return;

      if (widget.onToken != null) {
        await widget.onToken!(result.identityToken);
        return;
      }

      try {
        await widget.api.loginApple(
          result.identityToken,
          registration: result.fullName.isNotEmpty
              ? {'name': result.fullName}
              : null,
        );
      } on ApiException catch (e) {
        if (e.status != 428 || !mounted) rethrow;

        final registration = await googleOnboarding(
          context,
          initialName: result.fullName,
        );
        if (registration != null && mounted) {
          await widget.api.loginApple(
            result.identityToken,
            registration: registration,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = AppleOidcConfig.configured;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: SignInWithAppleButton(
            onPressed: configured && widget.enabled && !busy ? signIn : null,
            text: busy ? 'Entrando com a Apple…' : 'Continuar com a Apple',
            style: isDark
                ? SignInWithAppleButtonStyle.white
                : SignInWithAppleButtonStyle.black,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        if (!configured)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Apple indisponível nesta plataforma.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
