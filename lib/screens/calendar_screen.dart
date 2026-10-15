import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/person_filter.dart';
import 'routine_editor_screen.dart';

const _monthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const _weekdayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Vista mensual con los días en que se entrenó. Como en el historial, se
/// puede elegir de quiénes se quieren ver. Al tocar un día marcado se abre
/// la rutina de ese día.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Igual que en el historial: se guardan las ocultas para que un amigo
  // recién conectado aparezca sin tocar el filtro.
  Set<String> _hidden = {};
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _moveMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Días entrenados')),
      body: ListenableBuilder(
        listenable: gymStore,
        builder: (context, _) {
          final allIds = {for (final p in gymStore.people) p.id};
          final selected = allIds.difference(_hidden);
          final people = [
            for (final p in gymStore.people)
              if (selected.contains(p.id)) p,
          ];

          // Día -> rutinas de ese día del mes que hizo alguien elegido.
          final byDay = <int, List<Routine>>{};
          for (final routine in gymStore.routines) {
            final date = routine.date;
            if (date.year != _month.year || date.month != _month.month) {
              continue;
            }
            if (!routine.personIds.any(selected.contains)) continue;
            byDay.putIfAbsent(date.day, () => []).add(routine);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              PersonFilter(
                people: gymStore.people,
                selected: selected,
                onChanged: (value) =>
                    setState(() => _hidden = allIds.difference(value)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Mes anterior',
                    onPressed: () => _moveMonth(-1),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_month.month - 1]} ${_month.year}',
                      textAlign: .center,
                      style: const TextStyle(fontSize: 18, fontWeight: .bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Mes siguiente',
                    onPressed: () => _moveMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MonthGrid(
                month: _month,
                byDay: byDay,
                selected: selected,
                showInitials: people.length > 1,
              ),
              const SizedBox(height: 16),
              for (final person in people)
                _DaysCount(
                  person: person,
                  days: byDay.values
                      .where(
                        (routines) => routines.any(
                          (r) => r.personIds.contains(person.id),
                        ),
                      )
                      .length,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selected,
    required this.showInitials,
  });

  final DateTime month;
  final Map<int, List<Routine>> byDay;
  final Set<String> selected;

  /// Con más de una persona elegida, cada día muestra las iniciales de
  /// quiénes fueron.
  final bool showInitials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Lugares vacíos antes del día 1 (la semana empieza el lunes).
    final offset = DateTime(month.year, month.month).weekday - 1;
    final today = dateOnly(DateTime.now());
    final cells = offset + daysInMonth;

    return Column(
      children: [
        Row(
          children: [
            for (final initial in _weekdayInitials)
              Expanded(
                child: Text(
                  initial,
                  textAlign: .center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: .w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row * 7 < cells; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: switch (row * 7 + col - offset + 1) {
                    final day when day >= 1 && day <= daysInMonth => _DayCell(
                      day: day,
                      routines: byDay[day] ?? const [],
                      selected: selected,
                      showInitials: showInitials,
                      isToday: DateTime(month.year, month.month, day) == today,
                    ),
                    _ => const SizedBox(),
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.routines,
    required this.selected,
    required this.showInitials,
    required this.isToday,
  });

  final int day;
  final List<Routine> routines;
  final Set<String> selected;
  final bool showInitials;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trained = routines.isNotEmpty;
    final initials = [
      for (final person in gymStore.people)
        if (selected.contains(person.id) &&
            routines.any((r) => r.personIds.contains(person.id)))
          person.name.isEmpty ? '?' : person.name[0].toUpperCase(),
    ].join(' ');

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: trained ? scheme.primary : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isToday
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide.none,
          ),
          clipBehavior: .antiAlias,
          child: InkWell(
            onTap: trained
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RoutineEditorScreen(routine: routines.first),
                    ),
                  )
                : null,
            child: Column(
              mainAxisAlignment: .center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: trained || isToday ? .bold : .normal,
                    color: trained ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
                if (trained && showInitials)
                  Text(
                    initials,
                    maxLines: 1,
                    overflow: .clip,
                    style: TextStyle(fontSize: 10, color: scheme.onPrimary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Cami: 12 días este mes".
class _DaysCount extends StatelessWidget {
  const _DaysCount({required this.person, required this.days});

  final Person person;
  final int days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${person.name}: ',
              style: const TextStyle(fontWeight: .w600),
            ),
            TextSpan(text: days == 1 ? '1 día' : '$days días'),
            const TextSpan(text: ' este mes'),
          ],
        ),
      ),
    );
  }
}
