import 'dart:convert';

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

  /// Lo que va antes del @ en el email: cami@gym.app -> cami.
  @override
  String? get currentUsername => _db.auth.currentUser?.email?.split('@').first;

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
  Future<List<Muscle>> getMuscles(Set<String> ownerIds) async {
    if (ownerIds.isEmpty) return [];
    final rows = await _db
        .from('muscles')
        .select()
        .inFilter('owner_id', ownerIds.toList())
        .order('created_at');
    return rows.map(_muscleFromRow).toList();
  }

  @override
  Future<Muscle> addMuscle(Muscle muscle) async {
    final row = await _db
        .from('muscles')
        .insert({
          'name': muscle.name,
          'body_part': muscle.bodyPart.name,
          'owner_id': muscle.ownerId,
          'icon': muscle.icon?.name,
        })
        .select()
        .single();
    return _muscleFromRow(row);
  }

  @override
  Future<void> updateMuscle(Muscle muscle) async {
    await _db
        .from('muscles')
        .update({'name': muscle.name, 'icon': muscle.icon?.name})
        .eq('id', muscle.id!);
  }

  /// La base deja en null el muscle_id de los ejercicios que lo usaban.
  @override
  Future<void> deleteMuscle(String id) async {
    await _db.from('muscles').delete().eq('id', id);
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

  @override
  Future<List<Payment>> getPayments(String personId) async {
    final rows = await _db.from('payments').select().eq('person_id', personId);
    return rows.map(_paymentFromRow).toList();
  }

  @override
  /// No pide de vuelta las filas guardadas: la base no deja leer los pagos
  /// de los amigos y rechazaría todo el insert.
  Future<void> addPayments(
    DateTime date,
    List<String> personIds, {
    double? amount,
  }) async {
    if (personIds.isEmpty) return;
    await _db.from('payments').insert([
      for (final id in personIds)
        {'person_id': id, 'date': _dateToText(date), 'amount': amount},
    ]);
  }

  @override
  Future<void> updatePayment(Payment payment) async {
    await _db
        .from('payments')
        .update({'date': _dateToText(payment.date), 'amount': payment.amount})
        .eq('id', payment.id!);
  }

  @override
  Future<void> deletePayment(String id) async {
    await _db.from('payments').delete().eq('id', id);
  }

  @override
  Future<NotificationSettings> getNotificationSettings(String userId) async {
    final row = await _db
        .from('notification_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const NotificationSettings();
    return NotificationSettings(
      paymentReminders: row['payment_reminders'] as bool,
      trainingReminders: row['training_reminders'] as bool,
      trainingDays: {for (final d in row['training_days'] as List) d as int},
    );
  }

  @override
  Future<void> saveNotificationSettings(
    String userId,
    NotificationSettings settings,
  ) async {
    await _db.from('notification_settings').upsert({
      'user_id': userId,
      'payment_reminders': settings.paymentReminders,
      'training_reminders': settings.trainingReminders,
      'training_days': settings.trainingDays.toList()..sort(),
    });
  }

  @override
  Future<List<TrainingMessage>> getTrainingMessages() async {
    final rows = await _db
        .from('training_messages')
        .select()
        .order('created_at');
    return rows.map(_trainingMessageFromRow).toList();
  }

  @override
  Future<TrainingMessage> addTrainingMessage(String text) async {
    final row = await _db
        .from('training_messages')
        .insert({'text': text})
        .select()
        .single();
    return _trainingMessageFromRow(row);
  }

  @override
  Future<void> updateTrainingMessage(TrainingMessage message) async {
    await _db
        .from('training_messages')
        .update({'text': message.text})
        .eq('id', message.id!);
  }

  @override
  Future<void> deleteTrainingMessage(String id) async {
    await _db.from('training_messages').delete().eq('id', id);
  }

  /// Es una función de la base: si el dispositivo estaba registrado a nombre
  /// de otro usuario (que usó el mismo celular), pasa a ser del actual.
  @override
  Future<void> savePushSubscription(String subscription) async {
    await _db.rpc(
      'save_push_subscription',
      params: {'subscription': jsonDecode(subscription)},
    );
  }

  @override
  Future<void> deletePushSubscription(String endpoint) async {
    await _db.from('push_subscriptions').delete().eq('endpoint', endpoint);
  }

  /// Las notificaciones las manda la función de
  /// supabase/functions/send-notifications. Llamada con la sesión del
  /// usuario, solo le manda una de prueba a él.
  @override
  Future<void> sendTestNotification() async {
    try {
      await _db.functions.invoke('send-notifications', body: {'test': true});
    } on FunctionException catch (e) {
      if (e.status == 404 && '${e.details}'.contains('dispositivos')) {
        throw const GymException(
          'Este celular no está registrado. Desactivá y volvé a activar las '
          'notificaciones.',
        );
      }
      throw const GymException(
        'No se pudo mandar la notificación de prueba. Revisá que la función '
        'send-notifications esté publicada en Supabase.',
      );
    }
  }

  /// Usa Supabase Realtime: solo avisa de las tablas agregadas a la
  /// publicación supabase_realtime (ver supabase/008_tiempo_real.sql) y de
  /// las filas que el usuario puede leer.
  @override
  void Function() watchChanges({
    required void Function(String table) onChange,
    required void Function() onConnected,
  }) {
    final channel = _db
        .channel('cambios')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (payload) => onChange(payload.table),
        )
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) onConnected();
        });
    return () => _db.removeChannel(channel);
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
    muscleId: row['muscle_id'] as String?,
    initialWeights: _weightsFromJson(row['initial_weights']),
    archived: row['archived'] as bool? ?? false,
  );
}

Map<String, dynamic> _exerciseToRow(Exercise exercise) {
  return {
    'name': exercise.name,
    'body_part': exercise.bodyPart.name,
    'weight_type': exercise.weightType.name,
    'muscle_id': exercise.muscleId,
    'initial_weights': exercise.initialWeights,
  };
}

Muscle _muscleFromRow(Map<String, dynamic> row) {
  return Muscle(
    id: row['id'] as String,
    name: row['name'] as String,
    bodyPart: BodyPart.values.byName(row['body_part'] as String),
    ownerId: row['owner_id'] as String,
    // Un nombre que esta versión de la app no conoce queda sin ícono.
    icon: MuscleIcon.values.asNameMap()[row['icon']],
  );
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

/// 2026-10-01 -> "2026-10-01", como guarda la base las fechas sin hora.
String _dateToText(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

Map<String, dynamic> _routineToRow(Routine routine) {
  return {
    'date': _dateToText(routine.date),
    'person_ids': routine.personIds,
    'entries': [
      for (final entry in routine.entries)
        {'exercise_id': entry.exerciseId, 'weights': entry.weights},
    ],
  };
}

Payment _paymentFromRow(Map<String, dynamic> row) {
  return Payment(
    id: row['id'] as String,
    personId: row['person_id'] as String,
    // Una fecha sin hora ("2026-10-01") se interpreta en hora local.
    date: DateTime.parse(row['date'] as String),
    amount: (row['amount'] as num?)?.toDouble(),
  );
}

TrainingMessage _trainingMessageFromRow(Map<String, dynamic> row) {
  return TrainingMessage(id: row['id'] as String, text: row['text'] as String);
}
