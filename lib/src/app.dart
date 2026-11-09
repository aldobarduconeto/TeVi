import 'services/safe_meetup_service.dart';
import 'services/api.dart';
import 'models/app_theme_preference.dart';
import 'pages/auth.dart';
import 'pages/home.dart';
import 'pages/permissions_onboarding.dart';
import 'pages/profile_setup_screen.dart';
import 'pages/theme/app_theme.dart';

import 'package:flutter/material.dart';

class TeviApp extends StatefulWidget {
  const TeviApp({super.key, this.api});
  final Api? api;

  @override
  State<TeviApp> createState() => _TeviAppState();
}

class _TeviAppState extends State<TeviApp> {
  late final Api api = widget.api ?? Api();
  bool _checkingPermissions = true;
  bool _permissionsCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final completed = await PermissionsOnboardingScreen.hasCompleted();
    if (mounted) {
      setState(() {
        _permissionsCompleted = completed;
        _checkingPermissions = false;
      });
    }
  }

  @override
  void dispose() {
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: api,
    builder: (context, _) => MaterialApp(
      navigatorKey: SafeMeetupService.navigatorKey,
      key: ValueKey(api.me?['id'] ?? 'anonymous'),
      title: 'Tevi',
      debugShowCheckedModeBanner: false,
      theme: teviTheme(reduceMotion: api.settings['reduce_motion'] == true),
      darkTheme: teviTheme(
        brightness: Brightness.dark,
        reduceMotion: api.settings['reduce_motion'] == true,
      ),
      themeMode: switch (AppThemePreference.fromValue(
        api.settings['theme_mode'],
      )) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final factor = (api.settings['text_scale'] as num? ?? 100) / 100;
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(14) / 14 * factor,
            ),
            disableAnimations:
                media.disableAnimations ||
                api.settings['reduce_motion'] == true,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: api.initializing || _checkingPermissions || api.initializationError != null
          ? Scaffold(
              body: Center(
                child: api.initializing || _checkingPermissions
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              api.initializationError!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: api.retryInitialization,
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
              ),
            )
          : !_permissionsCompleted
              ? PermissionsOnboardingScreen(
                  onCompleted: () => setState(() => _permissionsCompleted = true),
                )
              : api.me == null
                  ? AuthScreen(api: api)
                  : !api.isProfileComplete
                      ? ProfileSetupScreen(api: api)
                      : HomeScreen(api: api),
    ),
  );
}
