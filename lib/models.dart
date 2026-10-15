import 'package:flutter/material.dart';

enum BodyPart {
  superior('Tren superior'),
  inferior('Tren inferior');

  const BodyPart(this.label);

  final String label;
}

/// Forma en la que se mide un ejercicio. El valor se guarda siempre como un
/// número: kg, cantidad de ladrillos o segundos según el tipo.
enum WeightType {
  mancuernas('Mancuernas', 'kg', Icons.fitness_center),
  ladrillos('Ladrillos', 'ladrillos', Icons.table_rows_rounded),
  barra('Barra (por lado)', 'kg por lado', Icons.horizontal_rule_rounded),
  total('Peso total', 'kg', Icons.scale_outlined),

  /// No lleva peso: se mide cuánto tiempo se sostiene el ejercicio.
  tiempo('Tiempo', 'segundos', Icons.timer_outlined);

  const WeightType(this.label, this.unit, this.icon);

  final String label;
  final String unit;
  final IconData icon;
}

/// Íconos que se le pueden asignar a un músculo. Cada uno es una imagen en
/// `assets/muscles/<nombre>.png` (ver el LEEME de esa carpeta); mientras no
/// esté cargada se muestra el ícono del tipo de peso.
enum MuscleIcon {
  hombros('Hombros', BodyPart.superior),
  espalda('Espalda', BodyPart.superior),
  pecho('Pecho', BodyPart.superior),
  biceps('Bíceps', BodyPart.superior),
  triceps('Tríceps', BodyPart.superior),
  abdominales('Abdominales', BodyPart.superior),
  gluteos('Glúteos', BodyPart.inferior),
  cuadriceps('Cuádriceps', BodyPart.inferior),
  isquiotibiales('Isquiotibiales', BodyPart.inferior),
  aductores('Aductores', BodyPart.inferior),
  abductores('Abductores', BodyPart.inferior),
  gemelos('Gemelos', BodyPart.inferior);

  const MuscleIcon(this.label, this.bodyPart);

  final String label;

  /// Tren en el que se ofrece al elegir el ícono.
  final BodyPart bodyPart;

  String get asset => 'assets/muscles/$name.png';

  /// El ícono cuyo nombre coincide con el texto, ignorando mayúsculas y
  /// tildes ("Glúteos" -> gluteos), o null.
  static MuscleIcon? matching(String text) {
    final key = text.trim().toLowerCase();
    const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
    final plain = key.split('').map((c) => accents[c] ?? c).join();
    for (final icon in values) {
      if (icon.name == plain) return icon;
    }
    return null;
  }
}

/// Nombre del grupo donde van los ejercicios sin músculo.
const generalMuscleName = 'General';

/// Músculo o categoría para agrupar ejercicios dentro de un tren. Los crea
/// cada usuario en Perfil y los ven él y quienes lo tienen conectado.
class Muscle {
  const Muscle({
    this.id,
    required this.name,
    required this.bodyPart,
    required this.ownerId,
    this.icon,
  });

  /// null mientras todavía no fue guardado.
  final String? id;
  final String name;
  final BodyPart bodyPart;

  /// null si no tiene: sus ejercicios muestran el ícono del tipo de peso.
  final MuscleIcon? icon;

  /// Usuario que lo creó: solo él lo puede eliminar.
  final String ownerId;
}

class Person {
  const Person({required this.id, required this.name});

  final String id;
  final String name;
}

/// Los ejercicios son compartidos entre el usuario y sus amigos.
class Exercise {
  const Exercise({
    this.id,
    required this.name,
    required this.bodyPart,
    required this.weightType,
    this.muscleId,
    this.initialWeights = const {},
    this.archived = false,
  });

  /// null mientras todavía no fue guardado.
  final String? id;
  final String name;
  final BodyPart bodyPart;
  final WeightType weightType;

  /// null si no tiene músculo: va al grupo General de su tren.
  final String? muscleId;

  /// Un ejercicio eliminado no se borra, se archiva: deja de aparecer en los
  /// listados pero las rutinas viejas que lo usan lo siguen mostrando.
  final bool archived;

  /// Para dejarlo sin músculo se pasa `clearMuscle: true`.
  Exercise copyWith({
    String? name,
    BodyPart? bodyPart,
    String? muscleId,
    bool clearMuscle = false,
    bool? archived,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      bodyPart: bodyPart ?? this.bodyPart,
      weightType: weightType,
      muscleId: clearMuscle ? null : muscleId ?? this.muscleId,
      initialWeights: initialWeights,
      archived: archived ?? this.archived,
    );
  }

  /// Pesos iniciales por persona (id de persona -> pesos). Ver
  /// [RoutineEntry.weights].
  final Map<String, List<double>> initialWeights;
}

class RoutineEntry {
  const RoutineEntry({required this.exerciseId, required this.weights});

  final String exerciseId;

  /// Pesos usados por persona (id de persona -> pesos). Si la lista tiene un
  /// solo peso, vale para todas las series; si no, tiene uno por cada serie
  /// en orden (por ejemplo 25-30-35).
  final Map<String, List<double>> weights;
}

/// La rutina de un día, hecha por una o más personas.
class Routine {
  const Routine({
    this.id,
    required this.date,
    required this.personIds,
    required this.entries,
  });

  /// null mientras todavía no fue guardada.
  final String? id;
  final DateTime date;
  final List<String> personIds;
  final List<RoutineEntry> entries;

  Routine copyWith({
    String? id,
    DateTime? date,
    List<String>? personIds,
    List<RoutineEntry>? entries,
  }) {
    return Routine(
      id: id ?? this.id,
      date: date ?? this.date,
      personIds: personIds ?? this.personIds,
      entries: entries ?? this.entries,
    );
  }
}

/// Un pago del gimnasio de una persona. Si varios pagaron juntos, cada uno
/// tiene el suyo.
class Payment {
  const Payment({
    this.id,
    required this.personId,
    required this.date,
    this.amount,
  });

  /// null mientras todavía no fue guardado.
  final String? id;
  final String personId;
  final DateTime date;

  /// Cuánto pagó esta persona, o null si no se cargó.
  final double? amount;

  /// Para dejarlo sin monto se pasa `clearAmount: true`.
  Payment copyWith({DateTime? date, double? amount, bool clearAmount = false}) {
    return Payment(
      id: id,
      personId: personId,
      date: date ?? this.date,
      amount: clearAmount ? null : amount ?? this.amount,
    );
  }

  /// Cuándo vence: el mismo día del mes siguiente, o el último día de ese
  /// mes si no lo tiene (31/01 -> 28/02).
  DateTime get dueDate {
    final lastDay = DateTime(date.year, date.month + 2, 0).day;
    return DateTime(date.year, date.month + 1, date.day.clamp(1, lastDay));
  }
}

/// Qué notificaciones quiere recibir un usuario. Por defecto ninguna.
class NotificationSettings {
  const NotificationSettings({
    this.paymentReminders = false,
    this.trainingReminders = false,
    this.trainingDays = const {},
  });

  /// Avisos de que faltan 3 días para pagar y de que ya hay que pagar.
  final bool paymentReminders;

  /// Un mensaje al azar los días de entrenamiento.
  final bool trainingReminders;

  /// Días de entrenamiento, como [DateTime.weekday]: 1 lunes ... 7 domingo.
  final Set<int> trainingDays;

  bool get anyEnabled => paymentReminders || trainingReminders;

  NotificationSettings copyWith({
    bool? paymentReminders,
    bool? trainingReminders,
    Set<int>? trainingDays,
  }) {
    return NotificationSettings(
      paymentReminders: paymentReminders ?? this.paymentReminders,
      trainingReminders: trainingReminders ?? this.trainingReminders,
      trainingDays: trainingDays ?? this.trainingDays,
    );
  }
}

/// Mensaje que puede llegar los días de entrenamiento ("Hoy gymmm"). Son
/// compartidos entre todos los usuarios.
class TrainingMessage {
  const TrainingMessage({this.id, required this.text});

  /// null mientras todavía no fue guardado.
  final String? id;
  final String text;
}
