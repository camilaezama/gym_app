import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';
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

  /// Duración del tiempo de preparación del temporizador, elegida en Perfil.
  int prepSeconds = 3;

  /// Rutinas del usuario actual y sus amigos conectados, de la más nueva a
  /// la más vieja.
  List<Routine> routines = [];

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
    await _repository.signOut();
    currentUser = null;
    users = [];
    friendIds = {};
    exercises = [];
    routines = [];
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
    await _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    routines = await _repository.getRoutines(connectedIds);
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

  Future<void> renameExercise(Exercise exercise, String name) async {
    final renamed = exercise.copyWith(name: name);
    await _repository.updateExercise(renamed);
    exercises[exercises.indexWhere((e) => e.id == exercise.id)] = renamed;
    notifyListeners();
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

  Future<void> saveRoutine(Routine routine) async {
    final saved = await _repository.saveRoutine(routine);
    routines.removeWhere((r) => r.id == saved.id);
    routines.add(saved);
    _sortRoutines();
    notifyListeners();
  }

  Future<void> deleteRoutine(String id) async {
    await _repository.deleteRoutine(id);
    routines.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void _sortRoutines() {
    routines.sort((a, b) => b.date.compareTo(a.date));
  }
}
