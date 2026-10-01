import 'package:flutter/material.dart';

import '../data/gym_store.dart';

/// Pregunta quiénes entrenan. Devuelve los ids elegidos, o null si se cancela.
/// Si no se pasa [initial], arranca con el usuario actual seleccionado.
Future<List<String>?> showWhoTrainsDialog(
  BuildContext context, {
  List<String>? initial,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _WhoTrainsDialog(
      initial: initial ?? [?gymStore.currentUser?.id],
    ),
  );
}

class _WhoTrainsDialog extends StatefulWidget {
  const _WhoTrainsDialog({required this.initial});

  final List<String> initial;

  @override
  State<_WhoTrainsDialog> createState() => _WhoTrainsDialogState();
}

class _WhoTrainsDialogState extends State<_WhoTrainsDialog> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Quiénes entrenan?'),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: Column(
        mainAxisSize: .min,
        children: [
          for (final person in gymStore.people)
            CheckboxListTile(
              title: Text(person.name),
              controlAffinity: .leading,
              value: _selected.contains(person.id),
              onChanged: (value) => setState(() {
                value == true
                    ? _selected.add(person.id)
                    : _selected.remove(person.id);
              }),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              // Se devuelven en el mismo orden que la lista de personas.
              : () => Navigator.pop(context, [
                  for (final person in gymStore.people)
                    if (_selected.contains(person.id)) person.id,
                ]),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
