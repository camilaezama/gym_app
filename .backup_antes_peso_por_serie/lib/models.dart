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
  });

  /// null mientras todavía no fue guardado.
  final String? id;
  final String name;
  final BodyPart bodyPart;
  final WeightType weightType;

  /// Peso inicial por persona (id de persona -> peso).
  final Map<String, double> initialWeights;
}

class RoutineEntry {
  const RoutineEntry({required this.exerciseId, required this.weights});

  final String exerciseId;

  /// Peso usado por persona (id de persona -> peso).
  final Map<String, double> weights;
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
