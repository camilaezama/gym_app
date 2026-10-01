import 'package:flutter/material.dart';

import '../models.dart';

/// Chips para elegir de qué personas se quieren ver los datos.
class PersonFilter extends StatelessWidget {
  const PersonFilter({
    super.key,
    required this.people,
    required this.selected,
    required this.onChanged,
  });

  final List<Person> people;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final person in people)
          FilterChip(
            label: Text(person.name),
            selected: selected.contains(person.id),
            onSelected: (value) {
              final next = {...selected};
              value ? next.add(person.id) : next.remove(person.id);
              // Siempre tiene que quedar al menos una persona.
              if (next.isNotEmpty) onChanged(next);
            },
          ),
      ],
    );
  }
}
