/// Stub (não-web): sem som — o banner/snackbar no shell cobre o resto.
class AdminAlertSounds {
  static bool get isSupported => false;

  /// [asset] é ignorado nas plataformas sem áudio.
  static void play(String asset) {}

  static void playSos() => play('assets/audio/ringtone.mp3');
  static void playNewRequest() =>
      play('assets/audio/solicitacao_motorista.mp3');
}
