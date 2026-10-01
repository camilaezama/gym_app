import 'package:flutter/material.dart';

import '../format.dart';

/// Textos de los campos de peso de una persona, uno por serie.
class WeightsController {
  WeightsController([List<double> initial = const []]) {
    for (final weight in initial) {
      fields.add(TextEditingController(text: formatWeight(weight)));
    }
    _ensureFields(defaultSets);
  }

  /// Cantidad de campos de serie que se muestran como mínimo.
  static const defaultSets = 3;

  final List<TextEditingController> fields = [];

  void _ensureFields(int count) {
    while (fields.length < count) {
      fields.add(TextEditingController());
    }
  }

  void addField() => _ensureFields(fields.length + 1);

  /// Los pesos cargados, salteando los campos vacíos. Si hay uno solo, vale
  /// para todas las series.
  List<double> get values => [
    for (final field in fields) ?parseWeight(field.text),
  ];

  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
  }
}

/// Texto que explica cómo se cargan los pesos en un [WeightsField].
String weightsHelp(String unit) =>
    'Un valor por serie ($unit). Si cargás uno solo, vale para todas.';

/// Campos para cargar el peso de una persona: uno por serie, con un botón
/// para agregar más.
class WeightsField extends StatefulWidget {
  const WeightsField({super.key, required this.controller});

  final WeightsController controller;

  @override
  State<WeightsField> createState() => _WeightsFieldState();
}

class _WeightsFieldState extends State<WeightsField> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: .center,
      children: [
        for (final (i, field) in controller.fields.indexed)
          SizedBox(
            width: 56,
            child: TextField(
              controller: field,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: .center,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                hintText: 'S${i + 1}',
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          tooltip: 'Agregar serie',
          visualDensity: .compact,
          onPressed: () => setState(controller.addField),
        ),
      ],
    );
  }
}
