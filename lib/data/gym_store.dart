import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../notifications/push.dart';
import 'gym_repository.dart';
import 'mock_gym_repository.dart';
import 'supabase_gym_repository.dart';

/// Estado compartido de la app. Usa la base real si config.dart tiene los
/// datos de Supabase, y si no la base de mentira. Los tests lo reemplazan por
/// uno con la base de mentira.
GymStore gymStore = GymStore(
  supabaseConfigured ? SupabaseGymRepository() : MockGymRepository(),
);

// La configuración del temporizador se guarda en el dispositivo.
const _prepSecondsKey = 'prepSeconds';

const minPrepSeconds = 1;
const maxPrepSeconds = 60;

class GymStore extends ChangeNotifier {
  GymStore(this._repository);

  final GymRepository _repository;

  bool loaded = false;

  /// Todos los usuarios del sistema.
  List<Person> users = [];

  /// El usuario que inició sesión, o null si todavía no lo hizo.
  Person? currentUser;

  /// Amigos elegidos en Perfil por el usuario actual.
  Set<String> friendIds = {};

  /// Todos los ejercicios, incluidos los eliminados (archivados), que hacen
  /// falta para mostrar las rutinas viejas.
  List<Exercise> exercises = [];

  /// Los ejercicios que se pueden ver y elegir.
  List<Exercise> get activeExercises => [
    for (final exercise in exercises)
      if (!exercise.archived) exercise,
  ];

  /// Músculos del usuario actual y sus amigos conectados, en el orden en
  /// que se crearon.
  List<Muscle> muscles = [];

  /// Músculos de un tren.
  List<Muscle> musclesOf(BodyPart part) => [
    for (final muscle in muscles)
      if (muscle.bodyPart == part) muscle,
  ];

  /// El músculo del ejercicio, o null si va a General: no tiene, es de
  /// alguien que no está conectado o es de otro tren.
  Muscle? muscleOf(Exercise exercise) {
    for (final muscle in muscles) {
      if (muscle.id == exercise.muscleId &&
          muscle.bodyPart == exercise.bodyPart) {
        return muscle;
      }
    }
    return null;
  }

  /// Agrupa por músculo los elementos de un tren: primero los músculos en
  /// orden y al final General. Solo devuelve los grupos con elementos.
  List<({String name, List<T> items})> groupByMuscle<T>(
    BodyPart part,
    Iterable<T> items,
    Exercise Function(T item) exerciseOf,
  ) {
    final ofPart = [
      for (final item in items)
        if (exerciseOf(item).bodyPart == part) item,
    ];
    final groups = [
      for (final muscle in musclesOf(part))
        (
          name: muscle.name,
          items: [
            for (final item in ofPart)
              if (muscleOf(exerciseOf(item))?.id == muscle.id) item,
          ],
        ),
      (
        name: generalMuscleName,
        items: [
          for (final item in ofPart)
            if (muscleOf(exerciseOf(item)) == null) item,
        ],
      ),
    ];
    return [
      for (final group in groups)
        if (group.items.isNotEmpty) group,
    ];
  }

  /// Duración del tiempo de preparación del temporizador, elegida en Perfil.
  int prepSeconds = 3;

  /// Rutinas del usuario actual y sus amigos conectados, de la más nueva a
  /// la más vieja.
  List<Routine> routines = [];

  /// Pagos del gimnasio del usuario actual, del más nuevo al más viejo.
  List<Payment> payments = [];

  /// El último pago del usuario actual, o null si nunca cargó uno.
  Payment? get lastPayment => payments.isEmpty ? null : payments.first;

  /// Días que faltan para que venza el último pago (negativo si ya venció),
  /// o null si no hay pagos.
  int? get daysUntilPaymentDue {
    final due = lastPayment?.dueDate;
    if (due == null) return null;
    // Se redondea por si en el medio hay un cambio de horario.
    return (due.difference(dateOnly(DateTime.now())).inHours / 24).round();
  }

  /// Qué notificaciones quiere recibir el usuario actual.
  NotificationSettings notificationSettings = const NotificationSettings();

  /// Mensajes de los días de entrenamiento, compartidos entre todos. Solo
  /// se cargan si [canManageTrainingMessages].
  List<TrainingMessage> trainingMessages = [];

  /// Si el usuario actual puede ver y cambiar los mensajes de
  /// entrenamiento (por ahora solo [trainingMessagesAdmin]).
  bool canManageTrainingMessages = false;

  /// Deja de escuchar los cambios de la base, o null sin sesión.
  void Function()? _stopWatching;

  /// Tablas que cambiaron y todavía no se recargaron.
  final Set<String> _changedTables = {};
  Timer? _refreshTimer;

  /// Guardados de rutinas que todavía no terminaron. Se hacen de a uno, en
  /// orden: [_routineSaves] termina cuando termina el último pedido.
  int _pendingRoutineSaves = 0;
  Future<void>? _routineSaves;

  /// Cuántas veces se cambiaron las rutinas en este dispositivo. Sirve para
  /// descartar una recarga que empezó antes de un cambio local.
  int _routineChanges = 0;

  /// Si hay que recargar las rutinas cuando terminen de guardarse.
  bool _routinesOutdated = false;

  /// El usuario actual más sus amigos conectados.
  Set<String> get connectedIds => {?currentUser?.id, ...friendIds};

  /// El usuario actual (primero) y sus amigos conectados: la app solo
  /// muestra datos de ellos.
  List<Person> get people => [
    ?currentUser,
    for (final user in users)
      if (friendIds.contains(user.id)) user,
  ];

  /// Los demás usuarios del sistema, conectados o no.
  List<Person> get otherUsers => [
    for (final user in users)
      if (user.id != currentUser?.id) user,
  ];

  /// Recupera la sesión guardada en el dispositivo, si hay, y carga los
  /// datos.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    prepSeconds = prefs.getInt(_prepSecondsKey) ?? prepSeconds;
    final user = await _repository.restoreSession();
    if (user != null) await _startSession(user);
    loaded = true;
    notifyListeners();
  }

  /// La sesión queda guardada en el dispositivo hasta llamar a [signOut].
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final user = await _repository.signIn(
      username: username,
      password: password,
    );
    await _startSession(user);
    notifyListeners();
  }

  Future<void> signOut() async {
    // Este dispositivo deja de recibir las notificaciones del usuario que se
    // va. Se borra antes de cerrar la sesión: sin sesión la base no deja.
    final endpoint = await pushEndpoint();
    if (endpoint != null) {
      try {
        await _repository.deletePushSubscription(endpoint);
      } catch (_) {
        // Sin conexión igual se cierra la sesión.
      }
    }
    _stopWatching?.call();
    _stopWatching = null;
    _refreshTimer?.cancel();
    _changedTables.clear();
    await _repository.signOut();
    currentUser = null;
    users = [];
    friendIds = {};
    exercises = [];
    muscles = [];
    routines = [];
    payments = [];
    notificationSettings = const NotificationSettings();
    trainingMessages = [];
    canManageTrainingMessages = false;
    notifyListeners();
  }

  Future<void> setPrepSeconds(int seconds) async {
    prepSeconds = seconds.clamp(minPrepSeconds, maxPrepSeconds);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prepSecondsKey, prepSeconds);
  }

  Future<void> setFriend(String userId, bool connected) async {
    await _repository.setFriend(
      userId: currentUser!.id,
      friendId: userId,
      connected: connected,
    );
    connected ? friendIds.add(userId) : friendIds.remove(userId);
    await _loadMuscles();
    await _loadRoutines();
    notifyListeners();
  }

  // Los datos se cargan recién con la sesión iniciada: la base real no deja
  // leer nada sin sesión.
  Future<void> _startSession(Person user) async {
    final loadedUsers = await _repository.getUsers();
    final loadedExercises = await _repository.getExercises();
    final loadedFriends = await _repository.getFriendIds(user.id);
    currentUser = user;
    users = loadedUsers;
    exercises = loadedExercises;
    friendIds = loadedFriends;
    await _loadMuscles();
    await _loadRoutines();
    await _loadPayments();
    notificationSettings = await _repository.getNotificationSettings(user.id);
    canManageTrainingMessages =
        _repository.currentUsername == trainingMessagesAdmin;
    trainingMessages = canManageTrainingMessages
        ? await _repository.getTrainingMessages()
        : [];
    // Si el usuario tiene notificaciones, se vuelve a registrar este
    // dispositivo por si el navegador renovó la suscripción. Sin pedir
    // permiso: si no lo dio, no hace nada.
    if (notificationSettings.anyEnabled) _refreshPushSubscription();
    _stopWatching?.call();
    _stopWatching = _repository.watchChanges(
      onChange: _onTableChanged,
      // Mientras estuvo desconectado se pudieron perder cambios.
      onConnected: refresh,
    );
  }

  static const _allTables = {
    'profiles',
    'friends',
    'muscles',
    'exercises',
    'routines',
    'payments',
    'notification_settings',
    'training_messages',
  };

  /// Vuelve a cargar todos los datos, por ejemplo al volver a la app.
  Future<void> refresh() => _refresh(_allTables);

  // Se espera un momento antes de recargar: un mismo guardado puede avisar
  // varios cambios seguidos.
  void _onTableChanged(String table) {
    _changedTables.add(table);
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 300), () {
      final tables = {..._changedTables};
      _changedTables.clear();
      _refresh(tables);
    });
  }

  Future<void> _refresh(Set<String> tables) async {
    final user = currentUser;
    if (user == null) return;
    try {
      if (tables.contains('profiles')) users = await _repository.getUsers();
      if (tables.contains('friends')) {
        friendIds = await _repository.getFriendIds(user.id);
      }
      if (tables.contains('exercises')) {
        exercises = await _repository.getExercises();
      }
      if (tables.contains('muscles') || tables.contains('friends')) {
        await _loadMuscles();
      }
      if (tables.contains('routines') || tables.contains('friends')) {
        await _loadRoutines();
      }
      if (tables.contains('payments')) await _loadPayments();
      if (tables.contains('notification_settings')) {
        notificationSettings = await _repository.getNotificationSettings(
          user.id,
        );
      }
      if (tables.contains('training_messages') && canManageTrainingMessages) {
        trainingMessages = await _repository.getTrainingMessages();
      }
    } catch (_) {
      // Sin conexión: se vuelve a cargar todo al reconectar.
      return;
    }
    // Mientras cargaba pudo cerrar la sesión.
    if (currentUser?.id == user.id) notifyListeners();
  }

  Future<void> _refreshPushSubscription() async {
    try {
      final subscription = await existingPushSubscription();
      if (subscription != null) {
        await _repository.savePushSubscription(subscription);
      }
    } catch (_) {
      // No es grave: se reintenta la próxima vez que se abra la app.
    }
  }

  Future<void> _loadMuscles() async {
    muscles = await _repository.getMuscles(connectedIds);
  }

  /// Si el nombre se puede usar en el tren: no es General ni está repetido.
  bool _muscleNameFree(String name, BodyPart part, {String? exceptId}) {
    final lower = name.toLowerCase();
    return lower != generalMuscleName.toLowerCase() &&
        !musclesOf(
          part,
        ).any((m) => m.id != exceptId && m.name.toLowerCase() == lower);
  }

  /// Devuelve false si ya hay un músculo con ese nombre en el tren.
  Future<bool> addMuscle(String name, BodyPart part, {MuscleIcon? icon}) async {
    if (!_muscleNameFree(name, part)) return false;
    muscles.add(
      await _repository.addMuscle(
        Muscle(
          name: name,
          bodyPart: part,
          ownerId: currentUser!.id,
          icon: icon,
        ),
      ),
    );
    notifyListeners();
    return true;
  }

  /// Devuelve false si ya hay otro músculo con ese nombre en el tren.
  Future<bool> updateMuscle(
    Muscle muscle, {
    required String name,
    required MuscleIcon? icon,
  }) async {
    if (!_muscleNameFree(name, muscle.bodyPart, exceptId: muscle.id)) {
      return false;
    }
    final updated = Muscle(
      id: muscle.id,
      name: name,
      bodyPart: muscle.bodyPart,
      ownerId: muscle.ownerId,
      icon: icon,
    );
    await _repository.updateMuscle(updated);
    muscles[muscles.indexWhere((m) => m.id == muscle.id)] = updated;
    notifyListeners();
    return true;
  }

  /// Los ejercicios que lo usaban pasan a General.
  Future<void> deleteMuscle(Muscle muscle) async {
    await _repository.deleteMuscle(muscle.id!);
    muscles.removeWhere((m) => m.id == muscle.id);
    for (var i = 0; i < exercises.length; i++) {
      if (exercises[i].muscleId == muscle.id) {
        exercises[i] = exercises[i].copyWith(clearMuscle: true);
      }
    }
    notifyListeners();
  }

  /// Si mientras cargaba se cambió una rutina en este dispositivo, o hay
  /// guardados sin terminar, no pisa la lista: se vuelve a cargar cuando
  /// terminen de guardarse.
  Future<void> _loadRoutines() async {
    final changes = _routineChanges;
    final loaded = await _repository.getRoutines(connectedIds);
    if (changes != _routineChanges || _pendingRoutineSaves > 0) {
      _routinesOutdated = true;
      _reloadRoutinesIfSaved();
      return;
    }
    routines = loaded;
    _sortRoutines();
  }

  void _reloadRoutinesIfSaved() {
    if (_pendingRoutineSaves > 0 || !_routinesOutdated) return;
    _routinesOutdated = false;
    _refresh({'routines'});
  }

  Routine? routineById(String id) {
    for (final routine in routines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  void _putRoutine(Routine routine) {
    routines.removeWhere((r) => r.id == routine.id);
    routines.add(routine);
    _sortRoutines();
  }

  Exercise? exerciseById(String id) {
    for (final exercise in exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  /// Pesos de la rutina más reciente en la que la persona hizo el ejercicio
  /// o, si nunca lo hizo, los pesos iniciales cargados en el ejercicio.
  List<double>? lastWeights(String exerciseId, String personId) {
    for (final routine in routines) {
      for (final entry in routine.entries) {
        final weights = entry.weights[personId];
        if (entry.exerciseId == exerciseId &&
            weights != null &&
            weights.isNotEmpty) {
          return weights;
        }
      }
    }
    return exerciseById(exerciseId)?.initialWeights[personId];
  }

  /// Cambia el nombre, el tren y el músculo (null para General).
  Future<void> updateExercise(
    Exercise exercise, {
    required String name,
    required BodyPart bodyPart,
    required String? muscleId,
  }) async {
    final updated = exercise.copyWith(
      name: name,
      bodyPart: bodyPart,
      muscleId: muscleId,
      clearMuscle: muscleId == null,
    );
    // Se muestra al instante, sin esperar a la base.
    final index = exercises.indexWhere((e) => e.id == exercise.id);
    exercises[index] = updated;
    notifyListeners();
    try {
      await _repository.updateExercise(updated);
    } catch (_) {
      // Vuelve a lo que hay en la base.
      _refresh({'exercises'});
      rethrow;
    }
  }

  /// Archiva el ejercicio: sale de los listados pero se conserva en las
  /// rutinas que ya lo usaron.
  Future<void> deleteExercise(Exercise exercise) async {
    await _repository.deleteExercise(exercise.id!);
    exercises[exercises.indexWhere((e) => e.id == exercise.id)] = exercise
        .copyWith(archived: true);
    notifyListeners();
  }

  Future<void> addExercise(Exercise exercise) async {
    exercises.add(await _repository.addExercise(exercise));
    notifyListeners();
  }

  /// Guarda la rutina (la crea si su id es null) y devuelve la guardada. Si
  /// ya existía, la lista se actualiza al instante, sin esperar a la base.
  /// Los guardados se hacen de a uno, en el orden en que se pidieron. Si uno
  /// falla, la lista vuelve a lo que hay en la base.
  Future<Routine> saveRoutine(Routine routine) async {
    _routineChanges++;
    if (routine.id != null) {
      _putRoutine(routine);
      notifyListeners();
    }
    _pendingRoutineSaves++;
    final previous = _routineSaves;
    final done = Completer<void>();
    _routineSaves = done.future;
    try {
      if (previous != null) await previous;
      final saved = await _repository.saveRoutine(routine);
      if (routine.id == null) _putRoutine(saved);
      return saved;
    } catch (_) {
      _routinesOutdated = true;
      rethrow;
    } finally {
      done.complete();
      _pendingRoutineSaves--;
      _reloadRoutinesIfSaved();
      notifyListeners();
    }
  }

  /// Si se están guardando cambios de rutinas.
  bool get savingRoutines => _pendingRoutineSaves > 0;

  Future<void> deleteRoutine(String id) async {
    _routineChanges++;
    await _repository.deleteRoutine(id);
    routines.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void _sortRoutines() {
    routines.sort((a, b) => b.date.compareTo(a.date));
  }

  /// Guarda el pago para cada una de las personas (el usuario actual y los
  /// amigos conectados que pagaron con él).
  Future<void> addPayment(
    DateTime date,
    List<String> personIds, {
    double? amount,
  }) async {
    await _repository.addPayments(dateOnly(date), personIds, amount: amount);
    await _loadPayments();
    notifyListeners();
  }

  /// Cambia la fecha y el monto de un pago del usuario actual.
  Future<void> updatePayment(Payment payment) async {
    final updated = payment.copyWith(date: dateOnly(payment.date));
    await _repository.updatePayment(updated);
    payments[payments.indexWhere((p) => p.id == payment.id)] = updated;
    payments.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> deletePayment(Payment payment) async {
    await _repository.deletePayment(payment.id!);
    payments.removeWhere((p) => p.id == payment.id);
    notifyListeners();
  }

  Future<void> _loadPayments() async {
    payments = await _repository.getPayments(currentUser!.id);
    payments.sort((a, b) => b.date.compareTo(a.date));
  }

  /// Activa o desactiva tipos de notificaciones. Al activar alguno, pide
  /// permiso y registra este dispositivo: si no se puede lanza
  /// [GymException] y no cambia nada.
  ///
  /// En el iPhone el permiso solo se puede pedir apenas el usuario toca algo,
  /// así que hay que llamarlo directo desde el botón, sin esperar antes.
  Future<void> setNotifications({
    bool? paymentReminders,
    bool? trainingReminders,
  }) async {
    final updated = notificationSettings.copyWith(
      paymentReminders: paymentReminders,
      trainingReminders: trainingReminders,
    );
    if (paymentReminders == true || trainingReminders == true) {
      final subscription = await subscribeToPush();
      await _repository.savePushSubscription(subscription);
    }
    await _saveNotificationSettings(updated);
  }

  Future<void> setTrainingDay(int weekday, bool selected) async {
    final days = {...notificationSettings.trainingDays};
    selected ? days.add(weekday) : days.remove(weekday);
    await _saveNotificationSettings(
      notificationSettings.copyWith(trainingDays: days),
    );
  }

  Future<void> _saveNotificationSettings(NotificationSettings settings) async {
    await _repository.saveNotificationSettings(currentUser!.id, settings);
    notificationSettings = settings;
    notifyListeners();
  }

  Future<void> sendTestNotification() => _repository.sendTestNotification();

  Future<void> addTrainingMessage(String text) async {
    trainingMessages.add(await _repository.addTrainingMessage(text));
    notifyListeners();
  }

  Future<void> updateTrainingMessage(
    TrainingMessage message,
    String text,
  ) async {
    final updated = TrainingMessage(id: message.id, text: text);
    await _repository.updateTrainingMessage(updated);
    final index = trainingMessages.indexWhere((m) => m.id == message.id);
    if (index >= 0) trainingMessages[index] = updated;
    notifyListeners();
  }

  Future<void> deleteTrainingMessage(TrainingMessage message) async {
    await _repository.deleteTrainingMessage(message.id!);
    trainingMessages.removeWhere((m) => m.id == message.id);
    notifyListeners();
  }
}
