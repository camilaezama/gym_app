import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../models.dart';
import 'weights_field.dart';

Future<void> showAddExerciseDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _AddExerciseDialog(),
  );
}

class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog();

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _name = TextEditingController();
  late final Map<String, WeightsController> _weights = {
    for (final person in gymStore.people) person.id: WeightsController(),
  };

  BodyPart _bodyPart = .superior;
  WeightType _weightType = .mancuernas;
  bool _nameMissing = false;

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _weights.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    await gymStore.addExercise(
      Exercise(
        name: name,
        bodyPart: _bodyPart,
        weightType: _weightType,
        initialWeights: {
          for (final MapEntry(:key, :value) in _weights.entries)
            if (value.values.isNotEmpty) key: value.values,
        },
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo ejercicio'),
      insetPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
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
            const SizedBox(height: 16),
            SegmentedButton<BodyPart>(
              showSelectedIcon: false,
              segments: [
                for (final part in BodyPart.values)
                  ButtonSegment(value: part, label: Text(part.label)),
              ],
              selected: {_bodyPart},
              onSelectionChanged: (value) =>
                  setState(() => _bodyPart = value.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WeightType>(
              initialValue: _weightType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo de peso',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in WeightType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(type.icon, size: 20),
                        const SizedBox(width: 10),
                        Text(type.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _weightType = value!),
            ),
            const SizedBox(height: 20),
            Text(
              _weightType == WeightType.tiempo
                  ? 'Tiempos iniciales'
                  : 'Pesos iniciales',
            ),
            Text(
              weightsHelp(_weightType.unit),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            for (final person in gymStore.people)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text('${person.name}:')),
                    Expanded(
                      child: WeightsField(controller: _weights[person.id]!),
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
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
