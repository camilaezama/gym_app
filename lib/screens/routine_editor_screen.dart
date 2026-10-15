import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/exercise_table.dart';
import '../widgets/muscle_icon.dart';
import '../widgets/weights_field.dart';
import '../widgets/who_trains_dialog.dart';
import '../widgets/save_error.dart';

/// Crea o edita la rutina de un día. Cada cambio se guarda al instante, y
/// los que hacen otros dispositivos aparecen solos.
class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key, required this.routine});

  /// Si su id es null, se crea una rutina nueva.
  final Routine routine;

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late String? _id = widget.routine.id;

  /// La rutina nueva mientras todavía no se creó en la base: se crea recién
  /// al agregar el primer ejercicio.
  late Routine _draft = widget.routine;

  /// Mientras se crea la rutina, los cambios se juntan en [_draft].
  bool _creating = false;

  /// Si ya se está cerrando la pantalla porque se eliminó la rutina.
  bool _closing = false;

  /// La versión guardada en el store, que incluye los cambios hechos desde
  /// otros dispositivos.
  Routine get _routine =>
      (_id == null ? null : gymStore.routineById(_id!)) ?? _draft;

  List<Person> get _people => [
    for (final person in gymStore.people)
      if (_routine.personIds.contains(person.id)) person,
  ];

  @override
  void initState() {
    super.initState();
    gymStore.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    gymStore.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (_closing) return;
    // Otra persona eliminó la rutina mientras estaba abierta.
    if (_id != null &&
        gymStore.routineById(_id!) == null &&
        !gymStore.savingRoutines) {
      _closing = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('La rutina fue eliminada.')));
      Navigator.pop(context);
      return;
    }
    setState(() {});
  }

  /// Últimos pesos usados por cada persona de la rutina en ese ejercicio.
  Map<String, List<double>> _lastWeights(
    String exerciseId,
    Iterable<String> ids,
  ) {
    return {for (final id in ids) id: ?gymStore.lastWeights(exerciseId, id)};
  }

  /// Aplica el cambio sobre la última versión de la rutina y lo guarda.
  void _change(Routine Function(Routine routine) change) {
    final messenger = ScaffoldMessenger.of(context);
    final updated = change(_routine);
    if (_id != null) {
      _save(updated, messenger);
      return;
    }
    setState(() => _draft = updated);
    if (!_creating && updated.entries.isNotEmpty) _create(messenger);
  }

  Future<void> _save(Routine routine, ScaffoldMessengerState messenger) async {
    try {
      await gymStore.saveRoutine(routine);
    } catch (_) {
      _showSaveError(messenger);
    }
  }

  Future<void> _create(ScaffoldMessengerState messenger) async {
    _creating = true;
    final sent = _draft;
    try {
      final saved = await gymStore.saveRoutine(sent);
      _id = saved.id;
      // Los cambios hechos mientras se creaba.
      if (!identical(_draft, sent)) {
        _save(_draft.copyWith(id: saved.id), messenger);
      }
    } catch (_) {
      // Se vuelve a intentar con el próximo cambio.
      _showSaveError(messenger);
    } finally {
      _creating = false;
      if (mounted) setState(() {});
    }
  }

  void _showSaveError(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No se pudo guardar el cambio. Revisá la conexión.'),
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _routine.date,
      firstDate: DateTime(2020),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      _change((routine) => routine.copyWith(date: picked));
    }
  }

  Future<void> _editPeople() async {
    final chosen = await showWhoTrainsDialog(
      context,
      initial: _routine.personIds,
    );
    if (chosen == null || !mounted) return;
    _change((routine) {
      // El diálogo solo lista a los conectados: quien participa de la rutina
      // sin estar conectado en este dispositivo se mantiene.
      final connected = gymStore.connectedIds;
      final ids = [
        ...chosen,
        ...routine.personIds.where((id) => !connected.contains(id)),
      ];
      final added = ids.where((id) => !routine.personIds.contains(id));
      return routine.copyWith(
        personIds: ids,
        entries: [
          for (final entry in routine.entries)
            RoutineEntry(
              exerciseId: entry.exerciseId,
              // Se descartan los pesos de quienes se sacaron de la rutina.
              weights: {
                for (final id in ids) id: ?entry.weights[id],
                ..._lastWeights(entry.exerciseId, added),
              },
            ),
        ],
      );
    });
  }

  Future<void> _addExercises(BodyPart part) async {
    final used = {for (final entry in _routine.entries) entry.exerciseId};
    final ids = await showDialog<List<String>>(
      context: context,
      builder: (context) => _ExercisePickerDialog(
        part: part,
        exercises: [
          for (final exercise in gymStore.activeExercises)
            if (exercise.bodyPart == part && !used.contains(exercise.id))
              exercise,
        ],
      ),
    );
    if (ids == null || !mounted) return;
    _change((routine) {
      // Otra persona pudo haber agregado alguno mientras se elegía.
      final present = {for (final entry in routine.entries) entry.exerciseId};
      return routine.copyWith(
        entries: [
          ...routine.entries,
          for (final id in ids)
            if (!present.contains(id))
              RoutineEntry(
                exerciseId: id,
                weights: _lastWeights(id, routine.personIds),
              ),
        ],
      );
    });
  }

  Future<void> _editEntry(ExerciseRow row) async {
    final people = _people;
    final weights = await showDialog<Map<String, List<double>>>(
      context: context,
      builder: (context) => _WeightsDialog(row: row, people: people),
    );
    if (weights == null || !mounted) return;
    _change(
      (routine) => routine.copyWith(
        entries: [
          for (final entry in routine.entries)
            entry.exerciseId == row.exercise.id
                ? RoutineEntry(
                    exerciseId: entry.exerciseId,
                    // Se mantienen los pesos de quienes no aparecían en el
                    // diálogo.
                    weights: {
                      for (final MapEntry(:key, :value)
                          in entry.weights.entries)
                        if (!people.any((p) => p.id == key)) key: value,
                      ...weights,
                    },
                  )
                : entry,
        ],
      ),
    );
  }

  void _removeEntry(ExerciseRow row) {
    _change(
      (routine) => routine.copyWith(
        entries: [
          for (final entry in routine.entries)
            if (entry.exerciseId != row.exercise.id) entry,
        ],
      ),
    );
  }

  Future<void> _deleteRoutine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar rutina?'),
        content: Text(
          'Se va a eliminar la rutina del ${formatDate(_routine.date)} '
          'completa. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _closing) return;
    _closing = true;
    final deleted = await trySaving(
      ScaffoldMessenger.of(context),
      () => gymStore.deleteRoutine(_id!),
    );
    if (!deleted) {
      _closing = false;
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final routine = _routine;
    final people = _people;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routine.id == null ? 'Nueva rutina' : 'Editar rutina',
        ),
        actions: [
          // No hay botón de guardar: los cambios se guardan solos.
          if (_id != null || _creating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: gymStore.savingRoutines || _creating
                  ? const Tooltip(
                      message: 'Guardando…',
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Tooltip(
                      message: 'Guardado',
                      child: Icon(
                        Icons.cloud_done_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          if (_id != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar rutina',
              onPressed: _deleteRoutine,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 20),
              label: Text(
                formatDate(routine.date),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.people_outline, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(people.map((p) => p.name).join(', '))),
              TextButton(onPressed: _editPeople, child: const Text('Cambiar')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Agregar ejercicio',
            textAlign: .center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addExercises(.inferior),
                  icon: const Icon(Icons.add),
                  label: Text(BodyPart.inferior.label),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addExercises(.superior),
                  icon: const Icon(Icons.add),
                  label: Text(BodyPart.superior.label),
                ),
              ),
            ],
          ),
          if (routine.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'Todavía no agregaste ejercicios.',
                textAlign: .center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            ExerciseTable(
              people: people,
              onEdit: _editEntry,
              onDelete: _removeEntry,
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

/// Lista de ejercicios para elegir cuáles agregar a la rutina.
class _ExercisePickerDialog extends StatefulWidget {
  const _ExercisePickerDialog({required this.part, required this.exercises});

  final BodyPart part;

  /// Ejercicios de [part] que todavía no están en la rutina.
  final List<Exercise> exercises;

  @override
  State<_ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<_ExercisePickerDialog> {
  final List<String> _selected = [];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.part.label),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.exercises.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No quedan ejercicios de este tren para agregar.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final group in gymStore.groupByMuscle(
                    widget.part,
                    widget.exercises,
                    (exercise) => exercise,
                  )) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: .w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    for (final exercise in group.items)
                      CheckboxListTile(
                        dense: true,
                        secondary: ExerciseIcon(exercise, size: 24),
                        title: Text(exercise.name),
                        value: _selected.contains(exercise.id),
                        onChanged: (value) => setState(() {
                          value == true
                              ? _selected.add(exercise.id!)
                              : _selected.remove(exercise.id);
                        }),
                      ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

/// Edita los pesos de un ejercicio de la rutina.
class _WeightsDialog extends StatefulWidget {
  const _WeightsDialog({required this.row, required this.people});

  final ExerciseRow row;
  final List<Person> people;

  @override
  State<_WeightsDialog> createState() => _WeightsDialogState();
}

class _WeightsDialogState extends State<_WeightsDialog> {
  late final Map<String, WeightsController> _controllers = {
    for (final person in widget.people)
      person.id: WeightsController(widget.row.weights[person.id] ?? const []),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.row.exercise;
    return AlertDialog(
      title: Text(exercise.name),
      insetPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Text(
              weightsHelp(exercise.weightType.unit),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            for (final person in widget.people)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text('${person.name}:')),
                    Expanded(
                      child: WeightsField(controller: _controllers[person.id]!),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            for (final MapEntry(:key, :value) in _controllers.entries)
              if (value.values.isNotEmpty) key: value.values,
          }),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
