import 'package:flutter/material.dart';

// Light defaults remain available for callers constructing static artwork.
const ink = Color(0xFF1D2431);
const coral = Color(0xFF6F4BD8);
const paper = Color(0xFFF6F7FB);
const muted = Color(0xFF606B7C);
const line = Color(0xFFE0E4EE);
const lavender = Color(0xFFEDE7FB);

extension TeviColors on BuildContext {
  bool get compactLayout => MediaQuery.sizeOf(this).width < 600;
  EdgeInsets get pageInsets => EdgeInsets.all(compactLayout ? 16 : 28);
  EdgeInsets get cardInsets => EdgeInsets.all(compactLayout ? 16 : 24);
  Color get ink => Theme.of(this).colorScheme.onSurface;
  Color get coral => Theme.of(this).colorScheme.primary;
  Color get paper => Theme.of(this).scaffoldBackgroundColor;
  Color get muted => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get line => Theme.of(this).colorScheme.outlineVariant;
  Color get lavender => Theme.of(this).colorScheme.primaryContainer;
  Color get surface => Theme.of(this).colorScheme.surface;
}

ThemeData teviTheme({
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) {
  final dark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Roboto',
  );
  // True OLED Black (#000000) turns pixels off on OLED displays for maximum battery life and infinite contrast.
  final background = dark ? const Color(0xFF000000) : paper;
  final surface = dark ? const Color(0xFF0A0C14) : Colors.white;
  final foreground = dark ? const Color(0xFFFFFFFF) : ink;
  final secondaryText = dark ? const Color(0xFFA1ABBf) : muted;
  final accent = dark ? const Color(0xFF8E6EFD) : coral;
  final border = dark ? const Color(0xFF1E2335) : line;
  final tint = dark ? const Color(0xFF261947) : lavender;
  final scheme = ColorScheme.fromSeed(seedColor: coral, brightness: brightness)
      .copyWith(
        primary: accent,
        onPrimary: dark ? Colors.black : Colors.white,
        primaryContainer: tint,
        onPrimaryContainer: foreground,
        surface: surface,
        onSurface: foreground,
        onSurfaceVariant: secondaryText,
        surfaceContainerLowest: dark ? const Color(0xFF000000) : background,
        surfaceContainerLow: dark ? const Color(0xFF05060A) : background,
        surfaceContainer: dark ? const Color(0xFF0E111C) : surface,
        surfaceContainerHigh: dark ? const Color(0xFF151928) : surface,
        surfaceContainerHighest: dark ? const Color(0xFF1E2437) : tint,
        outline: secondaryText,
        outlineVariant: border,
      );
  return base.copyWith(
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: background,
    colorScheme: scheme,
    textTheme: base.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    ),
    iconTheme: IconThemeData(color: secondaryText),
    pageTransitionsTheme: reduceMotion
        ? PageTransitionsTheme(
            builders: {
              for (final platform in TargetPlatform.values)
                platform: const _ReducedMotionTransitions(),
            },
          )
        : base.pageTransitionsTheme,
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: foreground,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      floatingLabelStyle: TextStyle(fontFamily: 'Roboto', color: accent),
      labelStyle: TextStyle(
        fontFamily: 'Roboto',
        color: secondaryText,
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        fontFamily: 'Roboto',
        color: secondaryText,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF090B13) : Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE6E2F3),
          width: 1.2,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: dark ? Colors.white.withValues(alpha: 0.15) : Colors.white,
          width: 1.2,
        ),
      ),
      backgroundColor: dark ? const Color(0xFF080911) : Colors.white,
      elevation: 12,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF080911) : Colors.white,
      modalBackgroundColor: dark ? const Color(0xFF080911) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      dragHandleColor: dark ? Colors.white24 : Colors.black26,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surface,
      selectedColor: tint,
      side: BorderSide(color: border),
      labelStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 12,
        color: foreground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      height: 74,
      indicatorColor: tint,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? accent : secondaryText,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? scheme.onPrimary : secondaryText,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : border,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(
      textColor: foreground,
      iconColor: secondaryText,
      subtitleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: secondaryText,
        fontSize: 12,
        height: 1.5,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: scheme.onInverseSurface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    popupMenuTheme: PopupMenuThemeData(color: surface),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(
        fontFamily: 'Roboto',
        color: scheme.onInverseSurface,
      ),
    ),
  );
}

class TeviLogo extends StatelessWidget {
  const TeviLogo({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        label: 'Tevi',
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset('assets/branding/app_icon.png', width: 36, height: 36,
            fit: BoxFit.cover, filterQuality: FilterQuality.medium, excludeFromSemantics: true),
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 10),
        Text(
          'tevi',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: context.ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
      ],
    ],
  );
}

class _ReducedMotionTransitions extends PageTransitionsBuilder {
  const _ReducedMotionTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
