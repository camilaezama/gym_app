import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/save_error.dart';

/// A partir de cuántos días antes del vencimiento se muestra el aviso.
const paymentWarningDays = 3;

/// A partir de cuántos días antes del vencimiento se muestra la alerta
/// chica en el historial de rutinas (menos de una semana).
const paymentReminderDays = 6;

/// "Faltan 3 días para pagar", "Hoy vence el pago"...
String paymentDueText(int days) {
  if (days > 1) return 'Faltan $days días para pagar';
  if (days == 1) return 'Falta 1 día para pagar';
  if (days == 0) return 'Hoy vence el pago';
  if (days == -1) return 'El pago venció hace 1 día';
  return 'El pago venció hace ${-days} días';
}

/// Pide la fecha de un pago, cuánto se pagó y quiénes pagaron (el usuario
/// actual y sus amigos conectados) y lo guarda.
Future<void> showAddPaymentDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _PaymentDialog(),
);

/// Permite cambiar la fecha y el monto de [payment].
Future<void> showEditPaymentDialog(BuildContext context, Payment payment) =>
    showDialog<void>(
      context: context,
      builder: (context) => _PaymentDialog(payment: payment),
    );

/// Historial de los pagos del gimnasio del usuario actual, con un aviso
/// cuando está por vencer.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  Future<void> _delete(BuildContext context, Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar pago?'),
        content: Text('Se borra el pago del ${formatDate(payment.date)}.'),
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
      () => gymStore.deletePayment(payment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pagos del gimnasio')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar pago'),
        onPressed: () => showAddPaymentDialog(context),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: gymStore,
          builder: (context, _) {
            final payments = gymStore.payments;
            final days = gymStore.daysUntilPaymentDue;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (days != null && days <= paymentWarningDays) ...[
                  _DueBanner(days: days),
                  const SizedBox(height: 16),
                ],
                if (payments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text(
                      'Todavía no cargaste ningún pago.',
                      textAlign: .center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                for (final (i, payment) in payments.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.receipt_long_outlined,
                      color: i == 0 ? scheme.primary : null,
                    ),
                    title: Text(
                      formatDate(payment.date),
                      style: TextStyle(fontWeight: i == 0 ? .bold : null),
                    ),
                    subtitle: Text(
                      [
                        if (payment.amount case final amount?)
                          formatMoney(amount),
                        'Vence el ${formatDate(payment.dueDate)}',
                      ].join(' · '),
                    ),
                    onTap: () => showEditPaymentDialog(context, payment),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar pago',
                      onPressed: () => _delete(context, payment),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cartel de que el pago está por vencer o ya venció.
class _DueBanner extends StatelessWidget {
  const _DueBanner({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = days < 0;
    final background = overdue
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = overdue
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            overdue ? Icons.error_outline : Icons.notifications_active_outlined,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              paymentDueText(days),
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: .w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Agrega un pago, o edita [payment] si se pasa. Guarda antes de cerrarse:
/// si falla queda abierto con lo que se escribió.
class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({this.payment});

  final Payment? payment;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late DateTime _date = widget.payment?.date ?? dateOnly(DateTime.now());
  late final _amount = TextEditingController(
    text: switch (widget.payment?.amount) {
      final amount? => formatWeight(amount),
      null => '',
    },
  );
  bool _amountInvalid = false;
  bool _saving = false;

  // Arranca con el usuario actual: los amigos se marcan si pagaron con él.
  late final Set<String> _selected = {?gymStore.currentUser?.id};

  bool get _editing => widget.payment != null;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
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

  Future<void> _save() async {
    // El monto es opcional, pero si se escribe tiene que ser un número.
    final text = _amount.text.trim();
    final amount = parseWeight(text.replaceAll('\$', '').replaceAll('.', ''));
    if (text.isNotEmpty && (amount == null || amount < 0)) {
      setState(() => _amountInvalid = true);
      return;
    }
    setState(() => _saving = true);
    final payment = widget.payment;
    final saved = await trySaving(
      ScaffoldMessenger.of(context),
      () => payment != null
          ? gymStore.updatePayment(
              payment.copyWith(
                date: _date,
                amount: amount,
                clearAmount: amount == null,
              ),
            )
          : gymStore.addPayment(_date, [
              for (final person in gymStore.people)
                if (_selected.contains(person.id)) person.id,
            ], amount: amount),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = gymStore.people;
    return AlertDialog(
      title: Text(_editing ? 'Editar pago' : 'Agregar pago'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(formatDate(_date)),
              onPressed: _pickDate,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: !_editing && _selected.length > 1
                    ? 'Monto por persona'
                    : 'Monto',
                prefixText: '\$ ',
                hintText: '25000',
                border: const OutlineInputBorder(),
                errorText: _amountInvalid ? 'Ingresá un número' : null,
              ),
              onChanged: (_) {
                if (_amountInvalid) setState(() => _amountInvalid = false);
              },
            ),
            // Al editar se cambia solo el pago propio, no el de los demás.
            if (!_editing && people.length > 1) ...[
              const SizedBox(height: 16),
              const Text('¿Quiénes pagaron?'),
              for (final person in people)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty || _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
