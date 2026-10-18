import 'dart:html' as html;

/// Notificações do sistema no navegador (Notification API de `dart:html`).
///
/// O painel Web do Admin (Vercel) fica atrás desta camada:
///   • Permissão pedida no arranque do shell (com fallback ao botão no menu).
///   • Quando a tab está escondida (`document.hidden`), cada evento novo é
///     espelhado como notificação nativa do browser — aparece mesmo com o
///     painel em segundo plano, igual a uma notificação de telemóvel.
class AdminSystemNotifications {
  static bool get isSupported => html.Notification.supported;

  /// Estado da permissão: 'granted' | 'denied' | 'default'.
  static String get permissionStatus {
    if (!isSupported) return 'unsupported';
    return html.Notification.permission ?? 'default';
  }

  /// Pede permissão ao utilizador (idempotente). Retorna true só se granted.
  static Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    try {
      if (html.Notification.permission == 'granted') return true;
      if (html.Notification.permission == 'denied') return false;
      final result = await html.Notification.requestPermission();
      return result == 'granted';
    } catch (_) {
      return false;
    }
  }

  /// Mostra uma notificação nativa. `tag` agrupa duplicados (eventos com o
  /// mesmo id substituem notificações antigas em vez de acumular).
  static void show({
    required String title,
    required String body,
    String? tag,
  }) {
    if (!isSupported || html.Notification.permission != 'granted') return;
    try {
      html.Notification(
        title,
        body: body.isEmpty ? null : body,
        tag: tag,
        icon: 'favicon.png',
      );
    } catch (_) {
      // Alguns browsers lançam se a página não estiver "desperta"; ignora.
    }
  }
}
