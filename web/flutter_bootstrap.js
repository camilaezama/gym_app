{{flutter_js}}
{{flutter_build_config}}

// Arranca la app sin el service worker de Flutter: está deprecado y, como
// se desinstala solo, borraría el de las notificaciones (push_sw.js).
_flutter.loader.load();
