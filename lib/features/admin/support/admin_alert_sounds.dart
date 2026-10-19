// Alertas sonoros do tin (SOS / nova corrida), com import condicional:
// a implementação web usa `dart:html`; noutras plataformas é stub no-op.
export 'admin_alert_sounds_stub.dart'
    if (dart.library.html) 'admin_alert_sounds_web.dart';
