import 'package:flutter/material.dart';

import '../data/gym_repository.dart';
import '../data/gym_store.dart';
import '../models.dart';

/// Iniciales de los días de entrenamiento, de lunes (1) a domingo (7).
const _weekdayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _weekdayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Elige qué notificaciones le llegan al usuario actual: recordatorios de
/// pago y mensajes los días de entrenamiento. Quien puede (ver
/// [GymStore.canManageTrainingMessages]) también agrega, edita y borra esos
/// mensajes, que son compartidos entre todos.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _sendingTest = false;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is GymException
              ? error.message
              : 'No se pudo guardar. Revisá la conexión.',
        ),
      ),
    );
  }

  /// En el iPhone el permiso se pide apenas se toca: no hay que esperar
  /// nada antes de llamar al store.
  Future<void> _set({bool? payment, bool? training}) async {
    try {
      await gymStore.setNotifications(
        paymentReminders: payment,
        trainingReminders: training,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _sendTest() async {
    setState(() => _sendingTest = true);
    try {
      await gymStore.sendTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listo, te tiene que llegar ahora.')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  Future<void> _addMessage() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _MessageDialog(),
    );
    if (text == null) return;
    try {
      await gymStore.addTrainingMessage(text);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editMessage(TrainingMessage message) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _MessageDialog(initialText: message.text),
    );
    if (text == null || text == message.text) return;
    try {
      await gymStore.updateTrainingMessage(message, text);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteMessage(TrainingMessage message) async {
    try {
      await gymStore.deleteTrainingMessage(message);
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: gymStore,
          builder: (context, _) {
            final settings = gymStore.notificationSettings;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Text(
                  'Llegan a las 10 de la mañana. En el iPhone tenés que abrir '
                  'la app desde el ícono de la pantalla de inicio.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Recordatorio de pago'),
                  subtitle: const Text(
                    'Cuando faltan 3 días y el día que se cumple el mes del '
                    'último pago.',
                  ),
                  value: settings.paymentReminders,
                  onChanged: (value) => _set(payment: value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.fitness_center_outlined),
                  title: const Text('Días de entrenamiento'),
                  subtitle: Text(
                    gymStore.canManageTrainingMessages
                        ? 'Un mensaje al azar de los de abajo los días que '
                              'elijas.'
                        : 'Un mensaje para motivarte los días que elijas.',
                  ),
                  value: settings.trainingReminders,
                  onChanged: (value) => _set(training: value),
                ),
                if (settings.trainingReminders) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        Tooltip(
                          message: _weekdayNames[day - 1],
                          child: FilterChip(
                            showCheckmark: false,
                            label: Text(_weekdayLetters[day - 1]),
                            selected: settings.trainingDays.contains(day),
                            onSelected: (selected) => gymStore
                                .setTrainingDay(day, selected)
                                .catchError(_showError),
                          ),
                        ),
                    ],
                  ),
                  if (settings.trainingDays.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Elegí qué días entrenás.',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                ],
                if (settings.anyEnabled) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: .centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Mandar una de prueba'),
                      onPressed: _sendingTest ? null : _sendTest,
                    ),
                  ),
                ],
                if (gymStore.canManageTrainingMessages) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Mensajes de entrenamiento',
                          style: TextStyle(fontSize: 16, fontWeight: .bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Agregar mensaje',
                        onPressed: _addMessage,
                      ),
                    ],
                  ),
                  Text(
                    'Son de todos: los que agregues les pueden llegar también a '
                    'tus amigos.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  if (gymStore.trainingMessages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No hay mensajes: los días de entrenamiento no va a '
                        'llegar nada.',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  for (final message in gymStore.trainingMessages)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(message.text),
                      onTap: () => _editMessage(message),
                      trailing: Row(
                        mainAxisSize: .min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar mensaje',
                            onPressed: () => _editMessage(message),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Eliminar mensaje',
                            onPressed: () => _deleteMessage(message),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Pide el texto de un mensaje nuevo o, con [initialText], edita uno que ya
/// existe.
class _MessageDialog extends StatefulWidget {
  const _MessageDialog({this.initialText});

  final String? initialText;

  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  late final _text = TextEditingController(text: widget.initialText);
  bool _missing = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _missing = true);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialText == null ? 'Mensaje nuevo' : 'Editar mensaje',
      ),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: 120,
        textCapitalization: .sentences,
        decoration: InputDecoration(
          hintText: 'Hoy gymmm',
          border: const OutlineInputBorder(),
          errorText: _missing ? 'Escribí un mensaje' : null,
        ),
        onChanged: (_) => setState(() => _missing = false),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.initialText == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}
