import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Alto de la franja de gestos en los iPhone sin botón de inicio.
const _iphoneHomeIndicator = 34.0;

/// Alto, en píxeles lógicos, de la franja inferior que el celular reserva
/// para su barra de gestos (la línea de inicio del iPhone).
double measureBottomInset() {
  _coverWholeScreen();
  final measured = _cssInset();
  if (measured > 0) return measured;
  // Si el navegador no informa la franja, se asume la de un iPhone cuando la
  // app está abierta desde la pantalla de inicio de uno sin botón.
  return _isHomeScreenAppOnNotchIphone() ? _iphoneHomeIndicator : 0;
}

/// Se le pregunta al navegador con un elemento de prueba, porque el valor
/// solo existe como variable de CSS.
double _cssInset() {
  final probe = web.document.createElement('div') as web.HTMLElement;
  probe.style.setProperty('position', 'fixed');
  probe.style.setProperty('visibility', 'hidden');
  probe.style.setProperty('padding-bottom', 'env(safe-area-inset-bottom)');
  web.document.body?.appendChild(probe);
  final padding = web.window.getComputedStyle(probe).paddingBottom;
  probe.remove();
  return double.tryParse(padding.replaceAll('px', '')) ?? 0;
}

/// El navegador solo informa la franja si la página declara que ocupa toda
/// la pantalla (viewport-fit=cover).
void _coverWholeScreen() {
  final meta = web.document.querySelector('meta[name="viewport"]');
  if (meta == null) return;
  final content = meta.getAttribute('content') ?? '';
  if (!content.contains('viewport-fit')) {
    meta.setAttribute('content', '$content, viewport-fit=cover');
  }
}

bool _isHomeScreenAppOnNotchIphone() {
  // navigator.standalone solo existe en iOS: es true al abrir la app desde
  // el ícono de la pantalla de inicio.
  final navigator = web.window.navigator as JSObject;
  final standalone = navigator.getProperty<JSAny?>('standalone'.toJS);
  if (standalone.dartify() != true) return false;
  // Los iPhone con botón de inicio miden como mucho 736 puntos de alto.
  final screen = web.window.screen;
  return screen.height >= 812 && screen.height > screen.width;
}
