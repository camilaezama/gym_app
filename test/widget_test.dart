import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/data/gym_repository.dart';
import 'package:gym_app/data/gym_store.dart';
import 'package:gym_app/data/mock_gym_repository.dart';
import 'package:gym_app/format.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/models.dart';
import 'package:gym_app/screens/payments_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Los tests nunca usan la base real.
    gymStore = GymStore(MockGymRepository());
  });

  test('formatMoney uses dots for thousands and comma for cents', () {
    expect(formatMoney(25000), '\$ 25.000');
    expect(formatMoney(1500.5), '\$ 1.500,50');
    expect(formatMoney(999), '\$ 999');
  });

  test('formatWeight and parseWeight use comma decimals', () {
    expect(formatWeight(25), '25');
    expect(formatWeight(7.5), '7,5');
    expect(formatWeight(3.75), '3,75');
    expect(formatWeight(100), '100');
    expect(formatWeight(null), '-');
    expect(parseWeight('7,5'), 7.5);
    expect(parseWeight(''), isNull);
  });

  test('A payment is due the same day of the next month', () {
    Payment payment(int y, int m, int d) =>
        Payment(personId: 'x', date: DateTime(y, m, d));
    expect(payment(2026, 10, 15).dueDate, DateTime(2026, 11, 15));
    expect(payment(2026, 1, 31).dueDate, DateTime(2026, 2, 28));
    expect(payment(2026, 12, 20).dueDate, DateTime(2027, 1, 20));
    expect(paymentDueText(3), 'Faltan 3 días para pagar');
    expect(paymentDueText(1), 'Falta 1 día para pagar');
    expect(paymentDueText(0), 'Hoy vence el pago');
    expect(paymentDueText(-2), 'El pago venció hace 2 días');
  });

  test('Payments are saved for everyone who paid together', () async {
    await gymStore.signIn(username: 'cami', password: '123');
    await gymStore.setFriend('agos', true);
    final today = dateOnly(DateTime.now());
    await gymStore.addPayment(today, ['cami', 'agos']);
    expect(gymStore.lastPayment?.date, today);
    expect(gymStore.daysUntilPaymentDue, greaterThan(27));

    // Agos ve su pago al iniciar sesión.
    await gymStore.signOut();
    await gymStore.signIn(username: 'agos', password: '123');
    expect(gymStore.lastPayment?.date, today);
    expect(gymStore.payments, hasLength(2));
  });

  test('Notifications start disabled and are saved per user', () async {
    await gymStore.signIn(username: 'cami', password: '123');
    expect(gymStore.notificationSettings.anyEnabled, isFalse);

    // Fuera del navegador no se puede registrar el dispositivo: no se activa.
    await expectLater(
      gymStore.setNotifications(paymentReminders: true),
      throwsA(isA<GymException>()),
    );
    expect(gymStore.notificationSettings.paymentReminders, isFalse);

    await gymStore.setTrainingDay(DateTime.monday, true);
    await gymStore.setTrainingDay(DateTime.friday, true);
    expect(gymStore.notificationSettings.trainingDays, {1, 5});

    // Cami maneja los mensajes de entrenamiento.
    expect(gymStore.canManageTrainingMessages, isTrue);
    final count = gymStore.trainingMessages.length;
    await gymStore.addTrainingMessage('Hoy no vale faltar');
    expect(gymStore.trainingMessages.last.text, 'Hoy no vale faltar');
    await gymStore.updateTrainingMessage(
      gymStore.trainingMessages.last,
      'Hoy no se falta',
    );
    expect(gymStore.trainingMessages.last.text, 'Hoy no se falta');
    await gymStore.deleteTrainingMessage(gymStore.trainingMessages.last);
    expect(gymStore.trainingMessages, hasLength(count));

    // Agos tiene su propia configuración y no ve los mensajes.
    await gymStore.signOut();
    await gymStore.signIn(username: 'agos', password: '123');
    expect(gymStore.notificationSettings.trainingDays, isEmpty);
    expect(gymStore.canManageTrainingMessages, isFalse);
    expect(gymStore.trainingMessages, isEmpty);
  });

  test('Routine changes show up on another device sharing the base', () async {
    // Dos stores con la misma base equivalen a dos celulares.
    final repository = MockGymRepository();
    final phone1 = GymStore(repository);
    final phone2 = GymStore(repository);
    await phone1.signIn(username: 'cami', password: '123');
    await phone2.signIn(username: 'cami', password: '123');

    final routine = phone1.routines.first;
    final extra = phone1.activeExercises.firstWhere(
      (e) => !routine.entries.any((entry) => entry.exerciseId == e.id),
    );
    final updated = routine.copyWith(
      entries: [
        ...routine.entries,
        RoutineEntry(exerciseId: extra.id!, weights: const {}),
      ],
    );
    // Se ve al instante en el que lo cambió, antes de terminar de guardar.
    final saving = phone1.saveRoutine(updated);
    expect(phone1.savingRoutines, isTrue);
    expect(phone1.routineById(routine.id!)!.entries, hasLength(4));
    await saving;
    expect(phone1.savingRoutines, isFalse);

    // El otro lo ve al recargar (con la base real, al avisar el cambio).
    expect(phone2.routineById(routine.id!)!.entries, hasLength(3));
    await phone2.refresh();
    expect(phone2.routineById(routine.id!)!.entries, hasLength(4));

    await phone2.deleteRoutine(routine.id!);
    await phone1.refresh();
    expect(phone1.routineById(routine.id!), isNull);
  });

  test('Session and connected friends survive an app restart', () async {
    final first = GymStore(MockGymRepository());
    await first.load();
    expect(first.currentUser, isNull);
    expect(
      () => first.signIn(username: 'cami', password: 'mal'),
      throwsA(isA<GymException>()),
    );

    await first.signIn(username: 'Agos', password: '123');
    expect(first.people.map((p) => p.name), ['Agos']);
    expect(first.otherUsers.map((p) => p.name), ['Cami', 'Mica']);
    expect(first.routines, hasLength(1));
    await first.setFriend('cami', true);
    expect(first.routines, hasLength(2));

    // Un store nuevo equivale a recargar la app.
    final second = GymStore(MockGymRepository());
    await second.load();
    expect(second.currentUser?.name, 'Agos');
    expect(second.people.map((p) => p.name), ['Agos', 'Cami']);
    expect(second.routines, hasLength(2));

    // Los amigos se guardan por usuario.
    await second.signOut();
    await second.signIn(username: 'mica', password: '123');
    expect(second.people.map((p) => p.name), ['Mica']);
    expect(second.routines, isEmpty);

    await second.signOut();
    final third = GymStore(MockGymRepository());
    await third.load();
    expect(third.currentUser, isNull);
  });

  test(
    'Muscles group exercises and are shared with connected friends',
    () async {
      await gymStore.load();
      await gymStore.signIn(username: 'cami', password: '123');
      String names(BodyPart part) => [
        for (final group in gymStore.groupByMuscle(
          part,
          gymStore.activeExercises,
          (e) => e,
        ))
          '${group.name}:${group.items.length}',
      ].join(' ');

      // Sin músculos, todo va a General.
      expect(names(.superior), 'General:7');
      expect(await gymStore.addMuscle('Triceps', .superior), isTrue);
      expect(await gymStore.addMuscle('triceps', .superior), isFalse);
      expect(await gymStore.addMuscle('General', .inferior), isFalse);
      final triceps = gymStore.musclesOf(.superior).single;

      final exercise = gymStore.activeExercises.first;
      await gymStore.updateExercise(
        exercise,
        name: exercise.name,
        bodyPart: .superior,
        muscleId: triceps.id,
      );
      expect(names(.superior), 'Triceps:1 General:6');

      // Agos ve los músculos de Cami solo si la tiene conectada.
      final agos = GymStore(MockGymRepository());
      await agos.signIn(username: 'agos', password: '123');
      expect(agos.muscles, isEmpty);

      // El ícono se puede cambiar; el nombre no puede quedar repetido.
      expect(MuscleIcon.matching(' Tríceps'), MuscleIcon.triceps);
      expect(MuscleIcon.matching('Brazos'), isNull);
      await gymStore.addMuscle('Pecho', .superior);
      expect(
        await gymStore.updateMuscle(triceps, name: 'pecho', icon: null),
        isFalse,
      );
      expect(
        await gymStore.updateMuscle(
          triceps,
          name: 'Triceps',
          icon: MuscleIcon.triceps,
        ),
        isTrue,
      );
      expect(
        gymStore.muscleOf(gymStore.activeExercises.first)?.icon,
        MuscleIcon.triceps,
      );

      // Al eliminarlo, sus ejercicios vuelven a General.
      await gymStore.deleteMuscle(triceps);
      expect(names(.superior), 'General:7');
    },
  );

  testWidgets('Main flows: login, profile, exercises and adding a routine', (
    WidgetTester tester,
  ) async {
    // Tamaño de celular.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GymApp());
    await tester.pumpAndSettle();

    // Sin sesión guardada arranca en el login.
    expect(find.text('Iniciar sesión'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'cami');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomAppBar),
        matching: find.byType(InkWell),
      ),
      findsNWidgets(4),
    );

    // Rutinas es la pantalla inicial y muestra las 2 rutinas de Cami.
    expect(find.text('Historial'), findsOneWidget);
    // El pago de Cami vence en menos de una semana: se avisa en el historial.
    expect(
      find.text(paymentDueText(gymStore.daysUntilPaymentDue!)),
      findsOneWidget,
    );
    expect(find.byTooltip('Editar rutina'), findsNWidgets(2));

    // Perfil: muestra al usuario y a los demás como amigos para conectar.
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Amigos conectados'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Agos'));
    await tester.pumpAndSettle();

    // Perfil: configurar los segundos del tiempo de preparación.
    await tester.ensureVisible(find.byTooltip('Más segundos'));
    await tester.pumpAndSettle();
    expect(find.text('3 s'), findsOneWidget);
    await tester.tap(find.byTooltip('Más segundos'));
    await tester.pumpAndSettle();
    expect(find.text('4 s'), findsOneWidget);
    await tester.tap(find.byTooltip('Menos segundos'));
    await tester.pumpAndSettle();
    expect(find.text('3 s'), findsOneWidget);

    // Perfil: el último pago de Cami está por vencer; el historial muestra
    // el aviso y permite agregar otro.
    final lastPaid = gymStore.lastPayment!.date;
    final lastPaidText = 'Último pago: ${formatDate(lastPaid)} · \$ 28.000';
    await tester.ensureVisible(find.text(lastPaidText));
    await tester.pumpAndSettle();
    expect(find.text(lastPaidText), findsOneWidget);
    await tester.tap(find.text(lastPaidText));
    await tester.pumpAndSettle();
    expect(find.text('Pagos del gimnasio'), findsOneWidget);
    expect(
      find.text(paymentDueText(gymStore.daysUntilPaymentDue!)),
      findsOneWidget,
    );
    expect(find.byTooltip('Eliminar pago'), findsNWidgets(2));
    await tester.tap(find.text('Agregar pago'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    // El monto es opcional, pero si se escribe tiene que ser un número.
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Ingresá un número'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '30.000');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Eliminar pago'), findsNWidgets(3));
    expect(find.textContaining('para pagar'), findsNothing);

    // Tocar un pago permite corregir el monto; no pregunta quiénes pagaron.
    await tester.tap(find.textContaining('\$ 30.000'));
    await tester.pumpAndSettle();
    expect(find.text('Editar pago'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.widgetWithText(TextField, '30000'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '31000');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('\$ 31.000'), findsOneWidget);
    expect(find.byTooltip('Eliminar pago'), findsNWidgets(3));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.text('Último pago: ${formatDate(DateTime.now())} · \$ 31.000'),
      findsOneWidget,
    );

    // Ejercicios: agregar uno nuevo desde el diálogo.
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar ejercicio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Remo');
    // Hay 3 campos de serie por persona.
    expect(find.byType(TextField), findsNWidgets(7));
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.enterText(find.byType(TextField).at(2), '12,5');
    await tester.enterText(find.byType(TextField).at(3), '15');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Remo'), findsOneWidget);
    expect(find.text('10-12,5-15'), findsOneWidget);

    // Editar un ejercicio: muestra su historial y permite renombrarlo.
    await tester.tap(find.byTooltip('Editar ejercicio').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar ejercicio'), findsOneWidget);
    final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
    expect(find.text(formatDate(fiveDaysAgo)), findsOneWidget);
    expect(find.text('Inicial'), findsOneWidget);
    // No hay botón de guardar: el nombre se guarda al dejar de escribir.
    await tester.enterText(find.byType(TextField), 'Triceps soga');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Triceps soga'), findsOneWidget);
    expect(find.text('Triceps con soga'), findsNothing);
    // El historial de rutinas lo referencia por id: toma el nombre nuevo.
    expect(find.text('Triceps soga', skipOffstage: false), findsNWidgets(2));

    // Botón +: pregunta quiénes entrenan y abre el editor de rutina.
    await tester.tap(find.byTooltip('Agregar rutina'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quiénes entrenan?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Agos'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva rutina'), findsOneWidget);
    expect(find.text(formatDate(DateTime.now())), findsOneWidget);

    // Al agregar un ejercicio trae el último peso de cada una (3,75 y 2,5).
    await tester.tap(find.text('Agregar ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Press plano con barra'));
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('3,75'), findsOneWidget);
    expect(find.text('2,5'), findsOneWidget);

    // Un ejercicio de un solo peso también se puede pasar a peso por serie.
    await tester.tap(find.byTooltip('Editar pesos'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(6));
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('3,75-5'), findsOneWidget);
    expect(find.text('2,5'), findsOneWidget);

    // Un ejercicio con peso por serie trae los pesos de cada serie, y se
    // pueden editar y agregar series.
    await tester.tap(find.text('Agregar ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remo'));
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('10-12,5-15'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar pesos').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(6));
    await tester.enterText(find.byType(TextField).at(2), '20');
    await tester.tap(find.byTooltip('Agregar serie').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), '22,5');
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('10-12,5-20-22,5'), findsOneWidget);

    // No hay botón de guardar: la rutina ya quedó guardada.
    expect(find.text('Guardar'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Historial'), findsOneWidget);
    expect(find.byTooltip('Editar rutina'), findsNWidgets(3));
    expect(find.text('10-12,5-20-22,5'), findsOneWidget);
    // La rutina de ejemplo con peso por serie.
    expect(find.text('20-25-25'), findsOneWidget);
    expect(find.text('30-35-40'), findsOneWidget);

    // Editar la rutina recién creada: agregar otro ejercicio y eliminarlo.
    await tester.tap(find.byTooltip('Editar rutina').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triceps catana'));
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Eliminar ejercicio'), findsNWidgets(3));
    await tester.tap(find.byTooltip('Eliminar ejercicio').last);
    await tester.pumpAndSettle();
    expect(find.text('Triceps catana'), findsNothing);
    expect(find.text('Press plano con barra'), findsOneWidget);

    // Eliminar la rutina completa pide confirmación.
    await tester.tap(find.byTooltip('Eliminar rutina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Historial'), findsOneWidget);
    expect(find.byTooltip('Editar rutina'), findsNWidgets(2));

    // Eliminar un ejercicio: sale del listado pero el historial lo conserva.
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Triceps soga'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar ejercicio').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Triceps soga'), findsNothing);
    expect(
      gymStore.activeExercises.map((e) => e.name),
      isNot(contains('Triceps soga')),
    );
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Triceps soga'), findsOneWidget);

    // Cerrar sesión vuelve al login.
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200);
    // Que no quede debajo del botón +.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
