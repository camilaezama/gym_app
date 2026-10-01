import '../models.dart';

/// Error con un mensaje para mostrarle al usuario.
class GymException implements Exception {
  const GymException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Acceso a los datos de la app. Tiene dos implementaciones: la de mentira
/// (MockGymRepository) y la real (SupabaseGymRepository). Cuál se usa se
/// decide en gym_store.dart según config.dart.
abstract class GymRepository {
  /// Usuario de la sesión guardada en el dispositivo, o null si no hay.
  Future<Person?> restoreSession();

  /// Devuelve el usuario si los datos son correctos; si no, lanza
  /// [GymException]. La sesión queda guardada hasta llamar a [signOut].
  Future<Person> signIn({required String username, required String password});

  Future<void> signOut();

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

  /// Guarda los cambios de un ejercicio existente, identificado por su id.
  /// Las rutinas lo referencian por id, así que no hay que tocarlas.
  Future<void> updateExercise(Exercise exercise);

  /// No lo borra: lo marca como archivado, para no romper las rutinas que
  /// ya lo usaron.
  Future<void> deleteExercise(String id);

  /// Rutinas en las que participa alguna de esas personas.
  Future<List<Routine>> getRoutines(Set<String> personIds);

  /// Crea la rutina si su id es null, si no la actualiza.
  /// Devuelve la rutina guardada, con su id asignado.
  Future<Routine> saveRoutine(Routine routine);

  Future<void> deleteRoutine(String id);
}
