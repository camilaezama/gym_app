import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';

/// Permite cambiar el nombre de un ejercicio y ver los pesos usados en cada
/// fecha.
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late final _name = TextEditingController(text: widget.exercise.name);
  bool _nameMissing = false;

  static const _columnWidth = 68.0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    await gymStore.renameExercise(widget.exercise, name);
    if (mounted) Navigator.pop(context);
  }

  Widget _row(String label, Map<String, List<double>> weights) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          for (final person in gymStore.people)
            SizedBox(
              width: _columnWidth,
              child: FittedBox(
                fit: .scaleDown,
                child: Text(
                  formatWeights(weights[person.id]),
                  style: const TextStyle(fontWeight: .w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exercise = widget.exercise;
    // Las rutinas ya vienen ordenadas de la más nueva a la más vieja.
    final history = [
      for (final routine in gymStore.routines)
        for (final entry in routine.entries)
          if (entry.exerciseId == exercise.id)
            (date: routine.date, weights: entry.weights),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Editar ejercicio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: .sentences,
            decoration: InputDecoration(
              labelText: 'Nombre del ejercicio',
              border: const OutlineInputBorder(),
              errorText: _nameMissing ? 'Ingresá un nombre' : null,
            ),
            onChanged: (_) {
              if (_nameMissing) setState(() => _nameMissing = false);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(exercise.weightType.icon, size: 18, color: scheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${exercise.bodyPart.label} · ${exercise.weightType.label}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'HISTORIAL (${exercise.weightType.unit})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: .bold,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final person in gymStore.people)
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
          for (final item in history)
            _row(formatDate(item.date), item.weights),
          _row('Inicial', exercise.initialWeights),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Todavía no se usó en ninguna rutina.',
                textAlign: .center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _save, child: const Text('Guardar')),
        ),
      ),
    );
  }
}
