import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/exercise_table.dart';
import '../widgets/person_filter.dart';
import 'routine_editor_screen.dart';

/// Historial de rutinas por día.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
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
        final routines = gymStore.routines
            .where((r) => r.personIds.any(selected.contains))
            .toList();
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Historial',
                style: Theme.of(context).textTheme.headlineSmall,
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
              child: routines.isEmpty
                  ? const Center(child: Text('No hay rutinas para mostrar.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: routines.length,
                      itemBuilder: (context, i) => _RoutineCard(
                        routine: routines[i],
                        // Solo se muestran las personas elegidas en el filtro.
                        people: [
                          for (final person in gymStore.people)
                            if (routines[i].personIds.contains(person.id) &&
                                selected.contains(person.id))
                              person,
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.people});

  final Routine routine;
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Text(
                formatDate(routine.date),
                style: const TextStyle(fontSize: 16, fontWeight: .bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  people.map((p) => p.name).join(', '),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Editar rutina',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RoutineEditorScreen(routine: routine),
                  ),
                ),
              ),
            ],
          ),
          ExerciseTable(
            people: people,
            rows: [
              for (final entry in routine.entries)
                if (gymStore.exerciseById(entry.exerciseId) case final exercise?)
                  ExerciseRow(exercise, entry.weights),
            ],
          ),
        ],
      ),
    );
  }
}
