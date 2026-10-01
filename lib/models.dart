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
    this.initialWeights = const {},
    this.archived = false,
  });

  /// null mientras todavía no fue guardado.
  final String? id;
  final String name;
  final BodyPart bodyPart;
  final WeightType weightType;

  /// Un ejercicio eliminado no se borra, se archiva: deja de aparecer en los
  /// listados pero las rutinas viejas que lo usan lo siguen mostrando.
  final bool archived;

  Exercise copyWith({String? name, bool? archived}) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      bodyPart: bodyPart,
      weightType: weightType,
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
}
