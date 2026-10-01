import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';

class ExerciseRow {
  const ExerciseRow(this.exercise, this.weights);

  final Exercise exercise;

  /// id de persona -> peso.
  final Map<String, double> weights;
}

/// Lista de ejercicios agrupada por tren, con una columna de peso por persona.
class ExerciseTable extends StatelessWidget {
  const ExerciseTable({
    super.key,
    required this.people,
    required this.rows,
    this.onEdit,
    this.onDelete,
  });

  final List<Person> people;
  final List<ExerciseRow> rows;

  /// Si se pasa, cada fila muestra un botón de editar.
  final ValueChanged<ExerciseRow>? onEdit;

  /// Si se pasa, cada fila muestra un botón de eliminar.
  final ValueChanged<ExerciseRow>? onDelete;

  static const _columnWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        for (final part in BodyPart.values)
          if (rows.any((row) => row.exercise.bodyPart == part)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      part.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: .bold,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final person in people)
                    SizedBox(
                      width: _columnWidth,
                      child: Text(
                        person.name,
                        textAlign: .center,
                        overflow: .ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            for (final row in rows.where((r) => r.exercise.bodyPart == part))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      row.exercise.weightType.icon,
                      size: 20,
                      color: scheme.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text(row.exercise.name),
                          Text(
                            row.exercise.weightType.unit,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Editar pesos',
                        visualDensity: .compact,
                        onPressed: () => onEdit!(row),
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Eliminar ejercicio',
                        visualDensity: .compact,
                        onPressed: () => onDelete!(row),
                      ),
                    for (final person in people)
                      SizedBox(
                        width: _columnWidth,
                        child: Text(
                          formatWeight(row.weights[person.id]),
                          textAlign: .center,
                          style: const TextStyle(fontWeight: .w600),
                        ),
                      ),
                  ],
                ),
              ),
          ],
      ],
    );
  }
}
