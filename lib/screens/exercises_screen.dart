import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../widgets/add_exercise_dialog.dart';
import '../widgets/exercise_table.dart';
import 'exercise_detail_screen.dart';
import '../widgets/person_filter.dart';

/// Listado de ejercicios con el último peso usado por cada persona.
class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  // Se guardan las personas ocultas (y no las visibles) para que un amigo
  // recién conectado aparezca sin tener que tocar el filtro.
  Set<String> _hidden = {};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gymStore,
      builder: (context, _) {
        final allIds = {for (final p in gymStore.people) p.id};
        final selected = allIds.difference(_hidden);
        final people = [
          for (final person in gymStore.people)
            if (selected.contains(person.id)) person,
        ];
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ejercicios',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar ejercicio'),
                    onPressed: () => showAddExerciseDialog(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PersonFilter(
                people: gymStore.people,
                selected: selected,
                onChanged: (value) =>
                    setState(() => _hidden = allIds.difference(value)),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                children: [
                  ExerciseTable(
                    people: people,
                    editTooltip: 'Editar ejercicio',
                    onEdit: (row) => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ExerciseDetailScreen(exercise: row.exercise),
                      ),
                    ),
                    rows: [
                      for (final exercise in gymStore.activeExercises)
                        ExerciseRow(exercise, {
                          for (final person in people)
                            person.id: ?gymStore.lastWeights(
                              exercise.id!,
                              person.id,
                            ),
                        }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
