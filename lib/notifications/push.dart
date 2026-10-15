/// Registro del dispositivo para recibir notificaciones (Web Push). Solo
/// funciona en el navegador; en las demás plataformas no hace nada.
library;

export 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';
