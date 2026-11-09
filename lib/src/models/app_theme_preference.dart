/// Stored strings stay independent of Flutter and are validated by the services.
enum AppThemePreference {
  system('system', 'Automático', 'Acompanha o sistema (OLED no escuro)'),
  light('light', 'Claro', 'Visual suave em lavanda e branco'),
  dark('dark', 'Escuro (OLED)', 'Preto puro (#000000) para telas OLED');

  const AppThemePreference(this.value, this.label, this.description);
  final String value, label, description;

  static AppThemePreference fromValue(Object? value) =>
      values.firstWhere((v) => v.value == value, orElse: () => system);
}
