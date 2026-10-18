// Acesso às notificações do sistema (Notification API do browser) com
// import condicional: a implementação web usa `dart:html`; noutras
// plataformas é stub no-op (o banner/snackbar existente cobre).
export 'admin_system_notifications_stub.dart'
    if (dart.library.html) 'admin_system_notifications_web.dart';
