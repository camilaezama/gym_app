import 'dart:async';

import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/category_fields.dart';
import '../widgets/save_error.dart';

/// Permite cambiar el nombre, el tren y el músculo de un ejercicio y ver los
/// pesos usados en cada fecha. Los cambios se guardan solos.
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late final _name = TextEditingController(text: widget.exercise.name);
  final _nameFocus = FocusNode();
  bool _nameMissing = false;

  /// Espera a que se deje de escribir para guardar el nombre.
  Timer? _nameTimer;

  /// Si ya se está cerrando la pantalla porque se eliminó el ejercicio.
  bool _closing = false;

  /// Para avisar si un cambio no se pudo guardar, aunque ya se haya salido
  /// de la pantalla.
  late ScaffoldMessengerState _messenger;

  static const _columnWidth = 68.0;

  /// La versión del store, que incluye los cambios hechos desde otros
  /// dispositivos.
  Exercise get _exercise =>
      gymStore.exerciseById(widget.exercise.id!) ?? widget.exercise;

  @override
  void initState() {
    super.initState();
    gymStore.addListener(_onStoreChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    gymStore.removeListener(_onStoreChanged);
    // Si se sale mientras se escribía, el nombre se guarda igual.
    if (_nameTimer?.isActive ?? false) _saveName(leaving: true);
    _nameTimer?.cancel();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (_closing) return;
    // Otra persona eliminó el ejercicio mientras estaba abierto.
    if (_exercise.archived) {
      _closing = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El ejercicio fue eliminado.')),
      );
      Navigator.pop(context);
      return;
    }
    // Un nombre cambiado en otro dispositivo, si no se está escribiendo acá.
    if (!_nameFocus.hasFocus && _name.text.trim() != _exercise.name) {
      _name.text = _exercise.name;
    }
    setState(() {});
  }

  void _onNameChanged(String _) {
    if (_nameMissing) setState(() => _nameMissing = false);
    _nameTimer?.cancel();
    _nameTimer = Timer(const Duration(milliseconds: 700), _saveName);
  }

  void _saveName({bool leaving = false}) {
    final name = _name.text.trim();
    if (name.isEmpty) {
      if (!leaving) setState(() => _nameMissing = true);
      return;
    }
    if (name != _exercise.name) _save(name: name);
  }

  Future<void> _save({String? name, BodyPart? bodyPart, String? muscleId}) {
    final exercise = _exercise;
    final part = bodyPart ?? exercise.bodyPart;
    return gymStore
        .updateExercise(
          exercise,
          name: name ?? exercise.name,
          bodyPart: part,
          muscleId: bodyPart == null
              ? gymStore.muscleOf(exercise)?.id
              : muscleId,
        )
        .catchError((Object _) {
          _messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo guardar el cambio. Revisá la conexión.',
              ),
            ),
          );
        });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar ejercicio?'),
        content: Text(
          '"${_exercise.name}" va a dejar de aparecer en Ejercicios y '
          'no se va a poder agregar a rutinas nuevas. Las rutinas que ya lo '
          'tienen lo siguen mostrando.',
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
    _nameTimer?.cancel();
    final deleted = await trySaving(
      _messenger,
      () => gymStore.deleteExercise(_exercise),
    );
    if (!deleted) {
      _closing = false;
      return;
    }
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
    final exercise = _exercise;
    // Las rutinas ya vienen ordenadas de la más nueva a la más vieja.
    final history = [
      for (final routine in gymStore.routines)
        for (final entry in routine.entries)
          if (entry.exerciseId == exercise.id)
            (date: routine.date, weights: entry.weights),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar ejercicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar ejercicio',
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            focusNode: _nameFocus,
            textCapitalization: .sentences,
            decoration: InputDecoration(
              labelText: 'Nombre del ejercicio',
              border: const OutlineInputBorder(),
              errorText: _nameMissing ? 'Ingresá un nombre' : null,
            ),
            onChanged: _onNameChanged,
            onSubmitted: (_) {
              _nameTimer?.cancel();
              _saveName();
            },
          ),
          const SizedBox(height: 16),
          CategoryFields(
            bodyPart: exercise.bodyPart,
            muscleId: gymStore.muscleOf(exercise)?.id,
            onChanged: (bodyPart, muscleId) =>
                _save(bodyPart: bodyPart, muscleId: muscleId),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(exercise.weightType.icon, size: 18, color: scheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exercise.weightType.label,
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
          for (final item in history) _row(formatDate(item.date), item.weights),
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
    );
  }
}
