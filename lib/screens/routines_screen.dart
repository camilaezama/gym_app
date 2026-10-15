import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/exercise_table.dart';
import '../widgets/person_filter.dart';
import 'payments_screen.dart';
import 'routine_editor_screen.dart';

/// Historial de rutinas por día. Si falta menos de una semana para pagar el
/// gimnasio, lo avisa al lado del título.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  // Se guardan las personas ocultas (y no las visibles) para que un amigo
  // recién conectado aparezca sin tener que tocar el filtro.
  Set<String> _hidden = {};

  // Vista resumen: una línea por ejercicio para que ocupe menos espacio.
  bool _compact = false;

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
        final paymentDays = gymStore.daysUntilPaymentDue;
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Historial',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        paymentDays != null &&
                            paymentDays <= paymentReminderDays
                        ? _PaymentAlert(days: paymentDays)
                        : const SizedBox.shrink(),
                  ),
                  IconButton(
                    icon: Icon(
                      _compact ? Icons.view_agenda_outlined : Icons.view_list,
                    ),
                    tooltip: _compact ? 'Vista detallada' : 'Vista resumen',
                    isSelected: _compact,
                    onPressed: () => setState(() => _compact = !_compact),
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
              child: routines.isEmpty
                  ? const Center(child: Text('No hay rutinas para mostrar.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: routines.length,
                      itemBuilder: (context, i) => _RoutineCard(
                        routine: routines[i],
                        compact: _compact,
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

/// Alerta chica de que falta poco para pagar el gimnasio (o que ya venció).
/// Al tocarla se abre el historial de pagos.
class _PaymentAlert extends StatelessWidget {
  const _PaymentAlert({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = days < 0;
    final background = overdue
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = overdue
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    return Align(
      alignment: .centerRight,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PaymentsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  overdue ? Icons.error_outline : Icons.notifications_outlined,
                  size: 16,
                  color: foreground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    paymentDueText(days),
                    overflow: .ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: .w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.people,
    required this.compact,
  });

  final Routine routine;
  final List<Person> people;
  final bool compact;

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
                formatDateWithWeekday(routine.date),
                style: const TextStyle(fontSize: 16, fontWeight: .bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  people.map((p) => p.name).join(', '),
                  maxLines: 1,
                  overflow: .ellipsis,
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
            compact: compact,
            rows: [
              for (final entry in routine.entries)
                if (gymStore.exerciseById(entry.exerciseId)
                    case final exercise?)
                  ExerciseRow(exercise, entry.weights),
            ],
          ),
        ],
      ),
    );
  }
}
