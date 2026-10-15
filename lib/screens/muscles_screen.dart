import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../models.dart';
import '../widgets/muscle_icon.dart';
import '../widgets/save_error.dart';

/// Músculos de cada tren, para agregar, editar y eliminar los propios.
class MusclesScreen extends StatelessWidget {
  const MusclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Músculos')),
      body: ListenableBuilder(
        listenable: gymStore,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'Dividen los ejercicios de cada tren. Los que no tienen músculo '
              'van a $generalMuscleName. Los ven también tus amigos '
              'conectados.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            for (final part in BodyPart.values) _MuscleSection(part: part),
          ],
        ),
      ),
    );
  }
}

/// Los músculos de un tren, con un botón para agregar. Cada uno solo puede
/// editar y eliminar los que creó.
class _MuscleSection extends StatelessWidget {
  const _MuscleSection({required this.part});

  final BodyPart part;

  /// Crea un músculo, o edita [muscle] si se pasa.
  Future<void> _edit(BuildContext context, [Muscle? muscle]) async {
    final result = await showDialog<({String name, MuscleIcon? icon})>(
      context: context,
      builder: (context) => _MuscleDialog(part: part, muscle: muscle),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    var nameFree = true;
    await trySaving(messenger, () async {
      nameFree = muscle == null
          ? await gymStore.addMuscle(result.name, part, icon: result.icon)
          : await gymStore.updateMuscle(
              muscle,
              name: result.name,
              icon: result.icon,
            );
    });
    if (!nameFree) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ya existe "${result.name}" en ${part.label}.')),
      );
    }
  }

  Future<void> _delete(BuildContext context, Muscle muscle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar músculo?'),
        content: Text(
          'Los ejercicios de "${muscle.name}" pasan a $generalMuscleName.',
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
    if (confirmed != true || !context.mounted) return;
    await trySaving(
      ScaffoldMessenger.of(context),
      () => gymStore.deleteMuscle(muscle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = gymStore.currentUser?.id;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(part.label, style: const TextStyle(fontWeight: .w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final muscle in gymStore.musclesOf(part))
                if (muscle.ownerId == userId)
                  InputChip(
                    avatar: _chipIcon(muscle.icon),
                    label: Text(muscle.name),
                    tooltip: 'Editar músculo',
                    onPressed: () => _edit(context, muscle),
                    onDeleted: () => _delete(context, muscle),
                    deleteButtonTooltipMessage: 'Eliminar músculo',
                  )
                else
                  Chip(
                    avatar: _chipIcon(muscle.icon),
                    label: Text(muscle.name),
                  ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                tooltip: 'Agregar músculo a ${part.label}',
                onPressed: () => _edit(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _chipIcon(MuscleIcon? icon) => icon == null
      ? null
      : MuscleIconImage(icon: icon, fallback: Icons.image_outlined, size: 18);
}

/// Pide el nombre y el ícono de un músculo nuevo, o de [muscle] si se pasa.
class _MuscleDialog extends StatefulWidget {
  const _MuscleDialog({required this.part, this.muscle});

  final BodyPart part;
  final Muscle? muscle;

  @override
  State<_MuscleDialog> createState() => _MuscleDialogState();
}

class _MuscleDialogState extends State<_MuscleDialog> {
  late final _name = TextEditingController(text: widget.muscle?.name);
  late MuscleIcon? _icon = widget.muscle?.icon;
  bool _nameMissing = false;

  // Mientras no se elija a mano, el ícono sigue al nombre ("Bíceps" ->
  // biceps).
  late bool _iconChosen = widget.muscle != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    Navigator.pop(context, (name: name, icon: _icon));
  }

  @override
  Widget build(BuildContext context) {
    final part = widget.part;
    return AlertDialog(
      title: Text(
        widget.muscle == null
            ? 'Músculo de ${part.label.toLowerCase()}'
            : 'Editar músculo',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.muscle == null,
              textCapitalization: .sentences,
              decoration: InputDecoration(
                labelText: 'Nombre',
                hintText: part == BodyPart.superior ? 'Hombros' : 'Glúteos',
                border: const OutlineInputBorder(),
                errorText: _nameMissing ? 'Ingresá un nombre' : null,
              ),
              onChanged: (value) => setState(() {
                _nameMissing = false;
                if (!_iconChosen) _icon = MuscleIcon.matching(value);
              }),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            const Text('Ícono'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Ninguno'),
                  selected: _icon == null,
                  onSelected: (_) => setState(() {
                    _icon = null;
                    _iconChosen = true;
                  }),
                ),
                for (final icon in MuscleIcon.values)
                  if (icon.bodyPart == part || icon == _icon)
                    ChoiceChip(
                      avatar: MuscleIconImage(
                        icon: icon,
                        fallback: Icons.image_outlined,
                        size: 18,
                      ),
                      showCheckmark: false,
                      label: Text(icon.label),
                      selected: _icon == icon,
                      onSelected: (_) => setState(() {
                        _icon = icon;
                        _iconChosen = true;
                      }),
                    ),
              ],
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
          onPressed: _save,
          child: Text(widget.muscle == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}
