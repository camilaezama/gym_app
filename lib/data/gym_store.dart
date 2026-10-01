import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'gym_repository.dart';
import 'mock_gym_repository.dart';

/// Estado compartido de la app. Para conectar una base real, cambiar acá
/// MockGymRepository por la implementación nueva.
final gymStore = GymStore(MockGymRepository());

// La sesión y la configuración del temporizador se guardan en el dispositivo.
const _sessionKey = 'sessionUserId';
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

  List<Exercise> exercises = [];

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

  /// Carga los datos y recupera la sesión guardada en el dispositivo, si hay.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    prepSeconds = prefs.getInt(_prepSecondsKey) ?? prepSeconds;
    users = await _repository.getUsers();
    exercises = await _repository.getExercises();
    final sessionId = prefs.getString(_sessionKey);
    for (final user in users) {
      if (user.id == sessionId) await _startSession(user);
    }
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, user.id);
    await _startSession(user);
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    currentUser = null;
    friendIds = {};
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

  Future<void> _startSession(Person user) async {
    currentUser = user;
    friendIds = await _repository.getFriendIds(user.id);
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
    final renamed = Exercise(
      id: exercise.id,
      name: name,
      bodyPart: exercise.bodyPart,
      weightType: exercise.weightType,
      initialWeights: exercise.initialWeights,
    );
    await _repository.updateExercise(renamed);
    exercises[exercises.indexWhere((e) => e.id == exercise.id)] = renamed;
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
