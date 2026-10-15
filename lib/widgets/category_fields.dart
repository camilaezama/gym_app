import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../models.dart';

/// Elige el tren y el músculo de un ejercicio. El músculo null es General.
class CategoryFields extends StatelessWidget {
  const CategoryFields({
    super.key,
    required this.bodyPart,
    required this.muscleId,
    required this.onChanged,
  });

  final BodyPart bodyPart;
  final String? muscleId;
  final void Function(BodyPart bodyPart, String? muscleId) onChanged;

  @override
  Widget build(BuildContext context) {
    final muscles = gymStore.musclesOf(bodyPart);
    // Si el músculo ya no está (lo eliminaron o es de otro tren), General.
    final selected = muscles.any((m) => m.id == muscleId) ? muscleId : null;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SegmentedButton<BodyPart>(
          showSelectedIcon: false,
          segments: [
            for (final part in BodyPart.values)
              ButtonSegment(value: part, label: Text(part.label)),
          ],
          selected: {bodyPart},
          // Los músculos son de cada tren: al cambiarlo vuelve a General.
          onSelectionChanged: (value) => onChanged(value.first, null),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          // Se recrea al cambiar de tren para tomar el valor nuevo.
          key: ValueKey(bodyPart),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Músculo',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text(generalMuscleName)),
            for (final muscle in muscles)
              DropdownMenuItem(value: muscle.id, child: Text(muscle.name)),
          ],
          onChanged: (value) => onChanged(bodyPart, value),
        ),
      ],
    );
  }
}
