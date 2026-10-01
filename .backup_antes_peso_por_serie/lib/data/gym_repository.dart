import '../models.dart';

/// Error con un mensaje para mostrarle al usuario.
class GymException implements Exception {
  const GymException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Acceso a los datos de la app. Para conectar una base real (Supabase),
/// crear otra implementación de esta clase y usarla en gym_store.dart.
abstract class GymRepository {
  /// Devuelve el usuario si los datos son correctos; si no, lanza
  /// [GymException].
  Future<Person> signIn({required String username, required String password});

  /// Todos los usuarios del sistema.
  Future<List<Person>> getUsers();

  /// Ids de los amigos que ese usuario tiene conectados.
  Future<Set<String>> getFriendIds(String userId);

  /// Conecta o desconecta a [friendId] como amigo de [userId].
  Future<void> setFriend({
    required String userId,
    required String friendId,
    required bool connected,
  });

  Future<List<Exercise>> getExercises();

  /// Devuelve el ejercicio guardado, con su id asignado.
  Future<Exercise> addExercise(Exercise exercise);

  /// Rutinas en las que participa alguna de esas personas.
  Future<List<Routine>> getRoutines(Set<String> personIds);

  /// Crea la rutina si su id es null, si no la actualiza.
  /// Devuelve la rutina guardada, con su id asignado.
  Future<Routine> saveRoutine(Routine routine);

  Future<void> deleteRoutine(String id);
}
