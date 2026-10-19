import 'dart:html' as html;

/// Alertas sonoros do painel Web (elemento <audio> de `dart:html`).
///
/// Toca em tempo real assim que a atividade crítica entra no centro
/// de atividade — inclusive com a tab em segundo plano. O browser
/// só permite som após o primeiro gesto do admin (login/clique),
/// o que acontece sempre neste fluxo.
///
/// Sons:
///   • SOS (motorista aciona o botão de emergência) → `ringtone.mp3`.
///   • Nova corrida (pedido de viagem criado)       → `solicitacao_motorista.mp3`.
class AdminAlertSounds {
  static bool get isSupported => true;

  /// Toca o ficheiro uma vez, sem bloquear nada (investir em fila aqui
  /// não compensa; sobrepõe chamadas seguidas do mesmo som).
  static void play(String asset) {
    try {
      final element = html.AudioElement(asset)
        ..volume = 0.9
        ..play();
      element.onEnded.first.then((_) => element.remove()).catchError((_) {});
    } catch (_) {
      // Política de autoplay/bloqueio do browser: falha silenciosa.
    }
  }

  static void playSos() => play('assets/audio/ringtone.mp3');

  static void playNewRequest() =>
      play('assets/audio/solicitacao_motorista.mp3');
}
