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

  /// Nombre con el que entró el usuario actual ("cami"), o null sin sesión.
  String? get currentUsername;

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

  /// Músculos creados por alguna de esas personas, en el orden en que se
  /// crearon.
  Future<List<Muscle>> getMuscles(Set<String> ownerIds);

  /// Devuelve el músculo guardado, con su id asignado.
  Future<Muscle> addMuscle(Muscle muscle);

  /// Guarda el nombre y el ícono de un músculo existente.
  Future<void> updateMuscle(Muscle muscle);

  /// Los ejercicios que lo usaban quedan sin músculo (van a General).
  Future<void> deleteMuscle(String id);

  /// Rutinas en las que participa alguna de esas personas.
  Future<List<Routine>> getRoutines(Set<String> personIds);

  /// Crea la rutina si su id es null, si no la actualiza.
  /// Devuelve la rutina guardada, con su id asignado.
  Future<Routine> saveRoutine(Routine routine);

  Future<void> deleteRoutine(String id);

  /// Pagos de esa persona, en cualquier orden.
  Future<List<Payment>> getPayments(String personId);

  /// Guarda un pago con esa fecha (y monto, si se pasa) para cada una de las
  /// personas.
  Future<void> addPayments(
    DateTime date,
    List<String> personIds, {
    double? amount,
  });

  /// Guarda la fecha y el monto de un pago existente.
  Future<void> updatePayment(Payment payment);

  Future<void> deletePayment(String id);

  /// Configuración de notificaciones del usuario; todas desactivadas si
  /// nunca la guardó.
  Future<NotificationSettings> getNotificationSettings(String userId);

  Future<void> saveNotificationSettings(
    String userId,
    NotificationSettings settings,
  );

  /// Mensajes de los días de entrenamiento, en el orden en que se crearon.
  Future<List<TrainingMessage>> getTrainingMessages();

  /// Devuelve el mensaje guardado, con su id asignado.
  Future<TrainingMessage> addTrainingMessage(String text);

  Future<void> updateTrainingMessage(TrainingMessage message);

  Future<void> deleteTrainingMessage(String id);

  /// Registra este dispositivo para que le lleguen las notificaciones del
  /// usuario actual. [subscription] es el JSON que da el navegador.
  Future<void> savePushSubscription(String subscription);

  /// Deja de mandarle notificaciones a ese dispositivo.
  Future<void> deletePushSubscription(String endpoint);

  /// Le manda ahora una notificación de prueba a los dispositivos del
  /// usuario actual.
  Future<void> sendTestNotification();

  /// Avisa a [onChange] con el nombre de la tabla cada vez que alguien (este
  /// u otro dispositivo) cambia algo en la base, y a [onConnected] cada vez
  /// que se conecta o reconecta, porque mientras estuvo desconectado se
  /// pudieron perder avisos. Devuelve una función para dejar de escuchar.
  void Function() watchChanges({
    required void Function(String table) onChange,
    required void Function() onConnected,
  });
}
