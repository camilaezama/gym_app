import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/exercise_table.dart';
import '../widgets/weights_field.dart';
import '../widgets/who_trains_dialog.dart';

/// Crea o edita la rutina de un día.
class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key, required this.routine});

  /// Si su id es null, se crea una rutina nueva.
  final Routine routine;

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late DateTime _date = widget.routine.date;
  late List<String> _personIds = [...widget.routine.personIds];
  late final List<RoutineEntry> _entries = [...widget.routine.entries];

  List<Person> get _people => [
    for (final person in gymStore.people)
      if (_personIds.contains(person.id)) person,
  ];

  /// Últimos pesos usados por cada persona de la rutina en ese ejercicio.
  Map<String, List<double>> _lastWeights(
    String exerciseId,
    Iterable<String> ids,
  ) {
    return {for (final id in ids) id: ?gymStore.lastWeights(exerciseId, id)};
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _editPeople() async {
    final chosen = await showWhoTrainsDialog(context, initial: _personIds);
    if (chosen == null) return;
    // El diálogo solo lista a los conectados: quien participa de la rutina
    // sin estar conectado en este dispositivo se mantiene.
    final connected = gymStore.connectedIds;
    final ids = [
      ...chosen,
      ..._personIds.where((id) => !connected.contains(id)),
    ];
    setState(() {
      final added = ids.where((id) => !_personIds.contains(id)).toList();
      for (var i = 0; i < _entries.length; i++) {
        final entry = _entries[i];
        _entries[i] = RoutineEntry(
          exerciseId: entry.exerciseId,
          weights: {
            ...entry.weights,
            ..._lastWeights(entry.exerciseId, added),
          },
        );
      }
      _personIds = ids;
    });
  }

  Future<void> _addExercises() async {
    final used = {for (final entry in _entries) entry.exerciseId};
    final ids = await showDialog<List<String>>(
      context: context,
      builder: (context) => _ExercisePickerDialog(
        exercises: [
          for (final exercise in gymStore.activeExercises)
            if (!used.contains(exercise.id)) exercise,
        ],
      ),
    );
    if (ids == null) return;
    setState(() {
      for (final id in ids) {
        _entries.add(
          RoutineEntry(exerciseId: id, weights: _lastWeights(id, _personIds)),
        );
      }
    });
  }

  Future<void> _editEntry(ExerciseRow row) async {
    final weights = await showDialog<Map<String, List<double>>>(
      context: context,
      builder: (context) => _WeightsDialog(row: row, people: _people),
    );
    if (weights == null) return;
    setState(() {
      final index = _entries.indexWhere(
        (e) => e.exerciseId == row.exercise.id,
      );
      _entries[index] = RoutineEntry(
        exerciseId: row.exercise.id!,
        weights: weights,
      );
    });
  }

  void _removeEntry(ExerciseRow row) {
    setState(() {
      _entries.removeWhere((e) => e.exerciseId == row.exercise.id);
    });
  }

  Future<void> _deleteRoutine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar rutina?'),
        content: Text(
          'Se va a eliminar la rutina del ${formatDate(widget.routine.date)} '
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
    if (confirmed != true) return;
    await gymStore.deleteRoutine(widget.routine.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    await gymStore.saveRoutine(
      Routine(
        id: widget.routine.id,
        date: _date,
        personIds: _personIds,
        entries: [
          for (final entry in _entries)
            RoutineEntry(
              exerciseId: entry.exerciseId,
              // Se descartan los pesos de personas que se sacaron de la rutina.
              weights: {
                for (final id in _personIds) id: ?entry.weights[id],
              },
            ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final people = _people;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routine.id == null ? 'Nueva rutina' : 'Editar rutina',
        ),
        actions: [
          if (widget.routine.id != null)
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
                formatDate(_date),
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
          Align(
            alignment: .centerRight,
            child: OutlinedButton.icon(
              onPressed: _addExercises,
              icon: const Icon(Icons.add),
              label: const Text('Agregar ejercicio'),
            ),
          ),
          if (_entries.isEmpty)
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
                for (final entry in _entries)
                  if (gymStore.exerciseById(entry.exerciseId)
                      case final exercise?)
                    ExerciseRow(exercise, entry.weights),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _entries.isEmpty ? null : _save,
            child: const Text('Guardar'),
          ),
        ),
      ),
    );
  }
}

/// Lista de ejercicios para elegir cuáles agregar a la rutina.
class _ExercisePickerDialog extends StatefulWidget {
  const _ExercisePickerDialog({required this.exercises});

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
      title: const Text('Agregar ejercicios'),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.exercises.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Ya agregaste todos los ejercicios.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final part in BodyPart.values) ...[
                    if (widget.exercises.any((e) => e.bodyPart == part))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: Text(
                          part.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: .bold,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (final exercise in widget.exercises.where(
                      (e) => e.bodyPart == part,
                    ))
                      CheckboxListTile(
                        dense: true,
                        secondary: Icon(exercise.weightType.icon),
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
                      child: WeightsField(
                        controller: _controllers[person.id]!,
                      ),
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
