import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/data/gym_repository.dart';
import 'package:gym_app/data/gym_store.dart';
import 'package:gym_app/data/mock_gym_repository.dart';
import 'package:gym_app/format.dart';
import 'package:gym_app/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('formatWeight and parseWeight use comma decimals', () {
    expect(formatWeight(25), '25');
    expect(formatWeight(7.5), '7,5');
    expect(formatWeight(3.75), '3,75');
    expect(formatWeight(100), '100');
    expect(formatWeight(null), '-');
    expect(parseWeight('7,5'), 7.5);
    expect(parseWeight(''), isNull);
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
    expect(find.byTooltip('Editar rutina'), findsNWidgets(2));

    // Perfil: muestra al usuario y a los demás como amigos para conectar.
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Amigos conectados'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Agos'));
    await tester.pumpAndSettle();

    // Perfil: configurar los segundos del tiempo de preparación.
    expect(find.text('3 s'), findsOneWidget);
    await tester.tap(find.byTooltip('Más segundos'));
    await tester.pumpAndSettle();
    expect(find.text('4 s'), findsOneWidget);
    await tester.tap(find.byTooltip('Menos segundos'));
    await tester.pumpAndSettle();
    expect(find.text('3 s'), findsOneWidget);

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
    await tester.enterText(find.byType(TextField), 'Triceps soga');
    await tester.tap(find.text('Guardar'));
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

    await tester.tap(find.text('Guardar'));
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

    // Cerrar sesión vuelve al login.
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
