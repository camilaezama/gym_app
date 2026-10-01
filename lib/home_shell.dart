import 'package:flutter/material.dart';

import 'format.dart';
import 'models.dart';
import 'screens/exercises_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/routine_editor_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/timer_screen.dart';
import 'widgets/who_trains_dialog.dart';

class _Tab {
  const _Tab(this.label, this.icon);

  final String label;
  final IconData icon;
}

const _tabs = [
  _Tab('Rutinas', Icons.list_alt_outlined),
  _Tab('Ejercicios', Icons.fitness_center_outlined),
  _Tab('Temporizador', Icons.timer_outlined),
  _Tab('Perfil', Icons.person_outline),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Agrega la rutina del día: primero pregunta quiénes entrenan.
  Future<void> _onAdd() async {
    final personIds = await showWhoTrainsDialog(context);
    if (personIds == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RoutineEditorScreen(
          routine: Routine(
            date: dateOnly(DateTime.now()),
            personIds: personIds,
            entries: const [],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _index = 0);
  }

  Widget _tabButton(int i) {
    final selected = i == _index;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Icon(_tabs[i].icon, color: color),
            Text(
              _tabs[i].label,
              style: TextStyle(fontSize: 11, color: color),
              overflow: .ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            const RoutinesScreen(),
            const ExercisesScreen(),
            const TimerScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAdd,
        tooltip: 'Agregar rutina',
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: .centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        padding: .zero,
        height: 64,
        child: Row(
          children: [
            _tabButton(0),
            _tabButton(1),
            // Hueco para el botón +.
            const SizedBox(width: 72),
            _tabButton(2),
            _tabButton(3),
          ],
        ),
      ),
    );
  }
}
