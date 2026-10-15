import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import 'muscle_icon.dart';

class ExerciseRow {
  const ExerciseRow(this.exercise, this.weights);

  final Exercise exercise;

  /// id de persona -> pesos (uno solo, o uno por serie).
  final Map<String, List<double>> weights;
}

/// Lista de ejercicios agrupada por tren (y si se pide, por músculo), con una
/// columna de peso por persona.
class ExerciseTable extends StatelessWidget {
  const ExerciseTable({
    super.key,
    required this.people,
    required this.rows,
    this.onEdit,
    this.editTooltip = 'Editar pesos',
    this.onDelete,
    this.byMuscle = false,
    this.compact = false,
  });

  final List<Person> people;
  final List<ExerciseRow> rows;

  /// Si se pasa, cada fila muestra un botón de editar.
  final ValueChanged<ExerciseRow>? onEdit;
  final String editTooltip;

  /// Si se pasa, cada fila muestra un botón de eliminar.
  final ValueChanged<ExerciseRow>? onDelete;

  /// Divide cada tren por músculo, con General al final. El historial no lo
  /// usa.
  final bool byMuscle;

  /// Vista resumen: una línea por ejercicio, sin ícono ni unidad.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Las columnas se ensanchan si hay pesos por serie (25-30-35).
    final hasSets = rows.any(
      (row) => row.weights.values.any((weights) => weights.length > 1),
    );
    final columnWidth = hasSets ? 68.0 : 52.0;
    final parts = [
      for (final part in BodyPart.values)
        if (rows.any((row) => row.exercise.bodyPart == part)) part,
    ];
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        for (final part in parts) ...[
          // En Ejercicios, franja de color a todo el ancho para que se note
          // el cambio de tren; en las rutinas, un título simple.
          Container(
            margin: byMuscle
                ? EdgeInsets.only(top: part == parts.first ? 4 : 16, bottom: 6)
                : null,
            padding: byMuscle
                ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
                : const EdgeInsets.fromLTRB(12, 12, 12, 4),
            decoration: byMuscle
                ? BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    part.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: byMuscle ? 13 : 12,
                      fontWeight: .bold,
                      letterSpacing: byMuscle ? 1 : null,
                      color: byMuscle
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final person in people)
                  SizedBox(
                    width: columnWidth,
                    child: Text(
                      person.name,
                      textAlign: .center,
                      overflow: .ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: byMuscle ? scheme.onPrimary : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (byMuscle)
            for (final group in gymStore.groupByMuscle(
              part,
              rows,
              (row) => row.exercise,
            )) ...[
              _MuscleHeader(group.name),
              for (final row in group.items) _row(context, row, columnWidth),
            ]
          else
            for (final row in rows.where((r) => r.exercise.bodyPart == part))
              _row(context, row, columnWidth),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, ExerciseRow row, double columnWidth) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 3 : 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 5 : 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Row(
        children: [
          if (compact)
            Expanded(
              child: Text(row.exercise.name, maxLines: 1, overflow: .ellipsis),
            )
          else ...[
            // El ícono del músculo, o el del tipo de peso si no tiene.
            ExerciseIcon(row.exercise, color: scheme.secondary),
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
          ],
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: editTooltip,
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
              width: columnWidth,
              // Si no entra (muchas series), se achica la letra.
              child: FittedBox(
                fit: .scaleDown,
                child: Text(
                  formatWeights(row.weights[person.id]),
                  style: const TextStyle(fontWeight: .w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MuscleHeader extends StatelessWidget {
  const _MuscleHeader(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: .w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
