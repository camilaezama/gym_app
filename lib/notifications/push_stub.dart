import '../data/gym_repository.dart';

/// Pide permiso y registra el dispositivo. Devuelve la suscripción en JSON.
Future<String> subscribeToPush() async {
  throw const GymException(
    'Las notificaciones solo funcionan en la app web por ahora.',
  );
}

/// La suscripción en JSON si el dispositivo ya está registrado, sin pedir
/// permiso.
Future<String?> existingPushSubscription() async => null;

/// Dirección a la que se le mandan las notificaciones a este dispositivo, o
/// null si no está registrado.
Future<String?> pushEndpoint() async => null;
