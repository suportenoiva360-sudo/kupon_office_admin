/// Stub para plataformas não-web (Windows/Linux/macOS do painel).
/// A atividade fica na campainha do app (snackbar + badge) sem notificações
/// do sistema operativo.
class AdminSystemNotifications {
  static bool get isSupported => false;

  /// Estado da permissão: 'granted' | 'denied' | 'default' | 'unsupported'.
  static String get permissionStatus => 'unsupported';

  /// Pede permissão ao utilizador. Em plataformas não-web devolve sempre false.
  static Future<bool> ensurePermission() async => false;

  /// Mostra uma notificação do sistema. No-op.
  static void show({
    required String title,
    required String body,
    String? tag,
  }) {}
}
