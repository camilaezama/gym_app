import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../config.dart';
import '../data/gym_repository.dart';

/// Service worker que recibe las notificaciones (web/push_sw.js).
const _serviceWorker = 'push_sw.js';

bool get _supported =>
    web.window.has('Notification') &&
    web.window.has('PushManager') &&
    web.window.navigator.has('serviceWorker');

/// Pide permiso y registra el dispositivo. Devuelve la suscripción en JSON.
///
/// En el iPhone el permiso solo se puede pedir apenas el usuario toca algo:
/// por eso es lo primero que se hace, antes de cualquier espera.
Future<String> subscribeToPush() async {
  if (!_supported) {
    throw const GymException(
      'Este navegador no puede recibir notificaciones. En el iPhone abrí la '
      'app desde el ícono de la pantalla de inicio (hace falta iOS 16.4 o '
      'más nuevo).',
    );
  }
  final permission = (await web.Notification.requestPermission().toDart).toDart;
  if (permission != 'granted') {
    throw const GymException(
      'No diste permiso para las notificaciones. Para activarlas andá a '
      'Ajustes > Notificaciones > Gym App en el celular.',
    );
  }
  final registration = await _registration();
  final existing = await registration.pushManager.getSubscription().toDart;
  final subscription =
      existing ??
      await registration.pushManager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: _decodeKey(vapidPublicKey).toJS,
            ),
          )
          .toDart;
  return _toJson(subscription);
}

/// La suscripción en JSON si el dispositivo ya está registrado, sin pedir
/// permiso.
Future<String?> existingPushSubscription() async {
  final subscription = await _existing();
  return subscription == null ? null : _toJson(subscription);
}

/// Dirección a la que se le mandan las notificaciones a este dispositivo, o
/// null si no está registrado.
Future<String?> pushEndpoint() async => (await _existing())?.endpoint;

Future<web.PushSubscription?> _existing() async {
  if (!_supported || web.Notification.permission != 'granted') return null;
  final registration = await web.window.navigator.serviceWorker
      .getRegistration()
      .toDart;
  return registration?.pushManager.getSubscription().toDart;
}

Future<web.ServiceWorkerRegistration> _registration() async {
  final container = web.window.navigator.serviceWorker;
  await container.register(_serviceWorker.toJS).toDart;
  return container.ready.toDart;
}

String _toJson(web.PushSubscription subscription) {
  final json = globalContext['JSON'] as JSObject;
  return json
      .callMethod<JSString>('stringify'.toJS, subscription.toJSON())
      .toDart;
}

/// La clave viene en base64 para URLs y sin "=" al final.
Uint8List _decodeKey(String key) {
  final padded = key.padRight((key.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(padded);
}
