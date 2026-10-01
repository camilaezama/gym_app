import 'package:shared_preferences/shared_preferences.dart';

import '../format.dart';
import '../models.dart';
import 'gym_repository.dart';

const _cami = 'cami';
const _agos = 'agos';
const _mica = 'mica';
const _password = '123';
const _sessionKey = 'sessionUserId';

/// Base de datos de mentira: guarda todo en memoria y se reinicia al
/// recargar la app. Los usuarios, ejercicios y rutinas de acá son solo de
/// ejemplo: el resto de la app no los conoce, usa lo que devuelva el
/// repositorio.
class MockGymRepository implements GymRepository {
  int _nextId = 1;

  final List<Person> _users = const [
    Person(id: _cami, name: 'Cami'),
    Person(id: _agos, name: 'Agos'),
    Person(id: _mica, name: 'Mica'),
  ];

  late final List<Exercise> _exercises = [
    _seed('Triceps con soga', .superior, .ladrillos, 2, 3),
    _seed('Triceps catana', .superior, .mancuernas, 5, 5),
    _seed('Press plano con barra', .superior, .barra, 3.75, 2.5),
    _seed('Press plano con mancuernas', .superior, .mancuernas, 8, 8),
    _seed('Press inclinado con mancuernas', .superior, .mancuernas, 6, 6),
    _seed('Bicep martillo con mancuernas', .superior, .mancuernas, 5, 7.5),
    _seed('Pecho Hammer', .superior, .barra, 10, 10),
    // Con un peso distinto por serie.
    Exercise(
      id: _newId(),
      name: 'Hip Trust Con Barra',
      bodyPart: .inferior,
      weightType: .barra,
      initialWeights: const {
        _cami: [20, 25, 25],
        _agos: [30, 35, 40],
      },
    ),
    _seed('Peso muerto con mancuernas', .inferior, .mancuernas, 8, 12.5),
    _seed('Prensa', .inferior, .total, 60, 100),
    _seed('Bulgaras', .inferior, .mancuernas, 5, 5),
    _seed('Sillon cuadriceps', .inferior, .ladrillos, 7, 8),
    _seed('Sillon isquio', .inferior, .ladrillos, 3, 4),
    _seed('Sentadilla Smith', .inferior, .barra, 15, 15),
    _seed('Sentadilla Isometrica', .inferior, .tiempo, 30, 30),
  ];

  // Rutinas de ejemplo para que el historial no arranque vacío.
  late final List<Routine> _routines = [
    Routine(
      id: _newId(),
      date: dateOnly(DateTime.now()).subtract(const Duration(days: 2)),
      personIds: const [_cami, _agos],
      entries: [
        _entry('Hip Trust Con Barra', [20, 25, 25], [30, 35, 40]),
        _entry('Prensa', [60], [100]),
        _entry('Bulgaras', [5], [5]),
      ],
    ),
    Routine(
      id: _newId(),
      date: dateOnly(DateTime.now()).subtract(const Duration(days: 5)),
      personIds: const [_cami],
      entries: [
        _entry('Triceps con soga', [2]),
        _entry('Press plano con mancuernas', [8]),
        _entry('Bicep martillo con mancuernas', [5]),
      ],
    ),
  ];

  String _newId() => '${_nextId++}';

  Exercise _seed(
    String name,
    BodyPart bodyPart,
    WeightType weightType,
    double cami,
    double agos,
  ) {
    return Exercise(
      id: _newId(),
      name: name,
      bodyPart: bodyPart,
      weightType: weightType,
      initialWeights: {
        _cami: [cami],
        _agos: [agos],
      },
    );
  }

  RoutineEntry _entry(
    String exerciseName,
    List<double> cami, [
    List<double>? agos,
  ]) {
    return RoutineEntry(
      exerciseId: _exercises.firstWhere((e) => e.name == exerciseName).id!,
      weights: {_cami: cami, _agos: ?agos},
    );
  }

  /// El nombre de usuario es el id (cami, agos, mica) y la contraseña es la
  /// misma para todos.
  @override
  Future<Person> signIn({
    required String username,
    required String password,
  }) async {
    final id = username.trim().toLowerCase();
    for (final user in _users) {
      if (user.id == id && password == _password) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionKey, user.id);
        return user;
      }
    }
    throw const GymException('Usuario o contraseña incorrectos.');
  }

  @override
  Future<Person?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_sessionKey);
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  @override
  Future<List<Person>> getUsers() async => List.of(_users);

  // Los amigos se guardan en el dispositivo para que no se pierdan al
  // recargar; con la base real van en una tabla.
  String _friendsKey(String userId) => 'friends.$userId';

  @override
  Future<Set<String>> getFriendIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(_friendsKey(userId))};
  }

  @override
  Future<void> setFriend({
    required String userId,
    required String friendId,
    required bool connected,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final friends = await getFriendIds(userId);
    connected ? friends.add(friendId) : friends.remove(friendId);
    await prefs.setStringList(_friendsKey(userId), friends.toList());
  }

  @override
  Future<List<Exercise>> getExercises() async => List.of(_exercises);

  @override
  Future<Exercise> addExercise(Exercise exercise) async {
    final saved = Exercise(
      id: _newId(),
      name: exercise.name,
      bodyPart: exercise.bodyPart,
      weightType: exercise.weightType,
      initialWeights: exercise.initialWeights,
    );
    _exercises.add(saved);
    return saved;
  }

  @override
  Future<void> updateExercise(Exercise exercise) async {
    final index = _exercises.indexWhere((e) => e.id == exercise.id);
    _exercises[index] = exercise;
  }

  @override
  Future<List<Routine>> getRoutines(Set<String> personIds) async => [
    for (final routine in _routines)
      if (routine.personIds.any(personIds.contains)) routine,
  ];

  @override
  Future<Routine> saveRoutine(Routine routine) async {
    final saved = Routine(
      id: routine.id ?? _newId(),
      date: routine.date,
      personIds: routine.personIds,
      entries: routine.entries,
    );
    final index = _routines.indexWhere((r) => r.id == saved.id);
    if (index == -1) {
      _routines.add(saved);
    } else {
      _routines[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> deleteRoutine(String id) async {
    _routines.removeWhere((r) => r.id == id);
  }
}
