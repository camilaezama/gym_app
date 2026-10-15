import 'package:flutter/material.dart';

import '../data/gym_repository.dart';

/// Corre [action] y, si falla, avisa con [messenger] que no se pudo
/// guardar. Devuelve true si salió bien.
///
/// El messenger se toma antes de llamar, por si la pantalla se cierra
/// mientras se guarda.
Future<bool> trySaving(
  ScaffoldMessengerState messenger,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error is GymException
              ? error.message
              : 'No se pudo guardar el cambio. Revisá la conexión.',
        ),
      ),
    );
    return false;
  }
}
