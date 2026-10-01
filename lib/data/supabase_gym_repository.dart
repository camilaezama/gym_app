import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';
import 'gym_repository.dart';

/// Base real. Las tablas están definidas en supabase/schema.sql.
class SupabaseGymRepository implements GymRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<Person> _profile(String userId) async {
    final row = await _db.from('profiles').select().eq('id', userId).single();
    return _personFromRow(row);
  }

  /// supabase_flutter guarda la sesión en el dispositivo y la renueva solo.
  @override
  Future<Person?> restoreSession() async {
    final user = _db.auth.currentUser;
    return user == null ? null : _profile(user.id);
  }

  @override
  Future<Person> signIn({
    required String username,
    required String password,
  }) async {
    final name = username.trim().toLowerCase();
    final email = name.contains('@') ? name : '$name@$loginEmailDomain';
    try {
      final response = await _db.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return await _profile(response.user!.id);
    } on AuthException {
      throw const GymException('Usuario o contraseña incorrectos.');
    }
  }

  @override
  Future<void> signOut() => _db.auth.signOut();

  @override
  Future<List<Person>> getUsers() async {
    final rows = await _db.from('profiles').select().order('name');
    return rows.map(_personFromRow).toList();
  }

  @override
  Future<Set<String>> getFriendIds(String userId) async {
    final rows = await _db
        .from('friends')
        .select('friend_id')
        .eq('user_id', userId);
    return {for (final row in rows) row['friend_id'] as String};
  }

  @override
  Future<void> setFriend({
    required String userId,
    required String friendId,
    required bool connected,
  }) async {
    if (connected) {
      await _db.from('friends').upsert({
        'user_id': userId,
        'friend_id': friendId,
      });
    } else {
      await _db
          .from('friends')
          .delete()
          .eq('user_id', userId)
          .eq('friend_id', friendId);
    }
  }

  @override
  Future<List<Exercise>> getExercises() async {
    final rows = await _db.from('exercises').select().order('created_at');
    return rows.map(_exerciseFromRow).toList();
  }

  @override
  Future<Exercise> addExercise(Exercise exercise) async {
    final row = await _db
        .from('exercises')
        .insert(_exerciseToRow(exercise))
        .select()
        .single();
    return _exerciseFromRow(row);
  }

  @override
  Future<void> updateExercise(Exercise exercise) async {
    await _db
        .from('exercises')
        .update(_exerciseToRow(exercise))
        .eq('id', exercise.id!);
  }

  @override
  Future<void> deleteExercise(String id) async {
    await _db.from('exercises').update({'archived': true}).eq('id', id);
  }

  @override
  Future<List<Routine>> getRoutines(Set<String> personIds) async {
    if (personIds.isEmpty) return [];
    final rows = await _db
        .from('routines')
        .select()
        .overlaps('person_ids', personIds.toList());
    return rows.map(_routineFromRow).toList();
  }

  @override
  Future<Routine> saveRoutine(Routine routine) async {
    final data = _routineToRow(routine);
    final row = routine.id == null
        ? await _db.from('routines').insert(data).select().single()
        : await _db
              .from('routines')
              .update(data)
              .eq('id', routine.id!)
              .select()
              .single();
    return _routineFromRow(row);
  }

  @override
  Future<void> deleteRoutine(String id) async {
    await _db.from('routines').delete().eq('id', id);
  }
}

Person _personFromRow(Map<String, dynamic> row) {
  return Person(id: row['id'] as String, name: row['name'] as String);
}

/// Convierte el JSON `{"idPersona": [25, 30, 35]}` de la base.
Map<String, List<double>> _weightsFromJson(Object? json) {
  return {
    for (final MapEntry(:key, :value) in (json as Map? ?? {}).entries)
      key as String: [for (final w in value as List) (w as num).toDouble()],
  };
}

Exercise _exerciseFromRow(Map<String, dynamic> row) {
  return Exercise(
    id: row['id'] as String,
    name: row['name'] as String,
    bodyPart: BodyPart.values.byName(row['body_part'] as String),
    weightType: WeightType.values.byName(row['weight_type'] as String),
    initialWeights: _weightsFromJson(row['initial_weights']),
    archived: row['archived'] as bool? ?? false,
  );
}

Map<String, dynamic> _exerciseToRow(Exercise exercise) {
  return {
    'name': exercise.name,
    'body_part': exercise.bodyPart.name,
    'weight_type': exercise.weightType.name,
    'initial_weights': exercise.initialWeights,
  };
}

Routine _routineFromRow(Map<String, dynamic> row) {
  return Routine(
    id: row['id'] as String,
    // Una fecha sin hora ("2026-10-01") se interpreta en hora local.
    date: DateTime.parse(row['date'] as String),
    personIds: [for (final id in row['person_ids'] as List) id as String],
    entries: [
      for (final entry in row['entries'] as List)
        RoutineEntry(
          exerciseId: entry['exercise_id'] as String,
          weights: _weightsFromJson(entry['weights']),
        ),
    ],
  );
}

Map<String, dynamic> _routineToRow(Routine routine) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = routine.date;
  return {
    'date': '${date.year}-${two(date.month)}-${two(date.day)}',
    'person_ids': routine.personIds,
    'entries': [
      for (final entry in routine.entries)
        {'exercise_id': entry.exerciseId, 'weights': entry.weights},
    ],
  };
}
