import 'package:flutter/material.dart';

import '../config.dart';
import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import 'calendar_screen.dart';
import 'muscles_screen.dart';
import 'notifications_screen.dart';
import 'payments_screen.dart';
import '../widgets/save_error.dart';

/// Muestra el usuario que inició sesión y permite elegir qué amigos quedan
/// conectados, cargar los pagos del gimnasio y abrir la configuración de
/// los músculos.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: gymStore,
      builder: (context, _) {
        final user = gymStore.currentUser;
        if (user == null) return const SizedBox();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text('Perfil', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(
              children: [
                _Avatar(person: user, radius: 28),
                const SizedBox(width: 12),
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 20, fontWeight: .w600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Amigos conectados',
              style: TextStyle(fontSize: 16, fontWeight: .bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Elegí de quiénes querés ver rutinas y pesos además de los '
              'tuyos. Queda guardado hasta que lo cambies.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final other in gymStore.otherUsers)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: _Avatar(person: other, radius: 20),
                title: Text(other.name),
                value: gymStore.friendIds.contains(other.id),
                onChanged: (value) => trySaving(
                  ScaffoldMessenger.of(context),
                  () => gymStore.setFriend(other.id, value),
                ),
              ),
            const SizedBox(height: 24),
            // No es const para que se vuelva a armar cuando cambian los pagos.
            _PaymentSection(),
            const SizedBox(height: 24),
            const Text(
              'Notificaciones',
              style: TextStyle(fontSize: 16, fontWeight: .bold),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined),
              title: Text(_notificationsSummary()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Temporizador',
              style: TextStyle(fontSize: 16, fontWeight: .bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('Tiempo de preparación')),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Menos segundos',
                  onPressed: gymStore.prepSeconds <= minPrepSeconds
                      ? null
                      : () => gymStore.setPrepSeconds(gymStore.prepSeconds - 1),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${gymStore.prepSeconds} s',
                    textAlign: .center,
                    style: const TextStyle(fontSize: 16, fontWeight: .w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Más segundos',
                  onPressed: gymStore.prepSeconds >= maxPrepSeconds
                      ? null
                      : () => gymStore.setPrepSeconds(gymStore.prepSeconds + 1),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Asistencia',
              style: TextStyle(fontSize: 16, fontWeight: .bold),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Calendario de días entrenados'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const CalendarScreen()),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Músculos',
              style: TextStyle(fontSize: 16, fontWeight: .bold),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.accessibility_new),
              title: const Text('Configurar músculos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const MusclesScreen()),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              onPressed: gymStore.signOut,
            ),
            const SizedBox(height: 24),
            // Sirve para saber qué versión está abierta: el código coincide
            // con el que muestra Vercel en cada publicación.
            Text(
              'Versión $appVersion',
              textAlign: .center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

/// "Desactivadas", "Pago y entrenamiento"...
String _notificationsSummary() {
  final settings = gymStore.notificationSettings;
  return switch ((settings.paymentReminders, settings.trainingReminders)) {
    (true, true) => 'Pago y entrenamiento',
    (true, false) => 'Recordatorio de pago',
    (false, true) => 'Días de entrenamiento',
    (false, false) => 'Desactivadas',
  };
}

/// El último pago del gimnasio y un botón para agregar otro. Al tocarlo se
/// abre el historial de pagos.
class _PaymentSection extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _PaymentSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = gymStore.lastPayment;
    final days = gymStore.daysUntilPaymentDue;
    final warn = days != null && days <= paymentWarningDays;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const Text(
          'Pago del gimnasio',
          style: TextStyle(fontSize: 16, fontWeight: .bold),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(
            last == null
                ? 'Sin pagos cargados'
                : [
                    'Último pago: ${formatDate(last.date)}',
                    if (last.amount case final amount?) formatMoney(amount),
                  ].join(' · '),
          ),
          subtitle: last == null
              ? null
              : Text(
                  warn
                      ? paymentDueText(days)
                      : 'Vence el ${formatDate(last.dueDate)}',
                  style: warn
                      ? TextStyle(
                          color: days < 0 ? scheme.error : scheme.tertiary,
                          fontWeight: .w600,
                        )
                      : null,
                ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PaymentsScreen()),
          ),
        ),
        Align(
          alignment: .centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Agregar pago'),
            onPressed: () => showAddPaymentDialog(context),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person, required this.radius});

  final Person person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      child: Text(
        person.name.isEmpty ? '?' : person.name[0],
        style: TextStyle(fontSize: radius * 0.8),
      ),
    );
  }
}
