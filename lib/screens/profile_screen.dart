import 'package:flutter/material.dart';

import '../config.dart';
import '../data/gym_store.dart';
import '../models.dart';

/// Muestra el usuario que inició sesión y permite elegir qué amigos quedan
/// conectados.
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
                onChanged: (value) => gymStore.setFriend(other.id, value),
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
