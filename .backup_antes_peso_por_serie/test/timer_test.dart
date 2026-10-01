import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/app_theme.dart';
import 'package:gym_app/data/gym_store.dart';
import 'package:gym_app/data/mock_gym_repository.dart';
import 'package:gym_app/screens/timer_screen.dart';

void main() {
  Future<void> pumpTimer(WidgetTester tester) async {
    // Tamaño de celular.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: TimerScreen()),
      ),
    );
  }

  testWidgets('Counts down to zero, with pause and repeat', (tester) async {
    await pumpTimer(tester);

    // Por defecto arranca en 1 minuto, sin preparación.
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(find.text('01:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30, milliseconds: 500));
    expect(find.text('00:30'), findsOneWidget);

    // En pausa el tiempo no avanza.
    await tester.tap(find.text('Pausar'));
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('En pausa'), findsOneWidget);

    await tester.tap(find.text('Reanudar'));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('00:20'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('¡Tiempo!'), findsOneWidget);

    // Al terminar el fondo de la pantalla pasa a rojo.
    final background = find.descendant(
      of: find.byType(TimerScreen),
      matching: find.byType(Material),
    );
    expect(tester.widget<Material>(background.first).color, AppColors.error);

    await tester.tap(find.text('Repetir'));
    await tester.pump();
    expect(find.text('01:00'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('Preparation time gives 3 seconds before starting', (
    tester,
  ) async {
    await pumpTimer(tester);

    await tester.tap(find.text('Tiempo de preparación'));
    await tester.pump();
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(find.text('Preparate'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1, milliseconds: 500));
    expect(find.text('2'), findsOneWidget);

    // Terminada la preparación arranca la cuenta completa.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Preparate'), findsNothing);
    expect(find.text('01:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('¡Tiempo!'), findsOneWidget);
  });

  testWidgets('Preparation time uses the seconds set in the profile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await gymStore.setPrepSeconds(5);
    addTearDown(() => gymStore.setPrepSeconds(3));
    await pumpTimer(tester);
    expect(find.text('5 segundos antes de empezar'), findsOneWidget);

    await tester.tap(find.text('Tiempo de preparación'));
    await tester.pump();
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(find.text('5'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4, milliseconds: 500));
    expect(find.text('Preparate'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Preparate'), findsNothing);

    // Se guarda en el dispositivo.
    final reloaded = GymStore(MockGymRepository());
    await reloaded.load();
    expect(reloaded.prepSeconds, 5);
  });

  testWidgets('The wheels set minutes and seconds', (tester) async {
    await pumpTimer(tester);

    // Cada ítem mide 52 px: arrastrar 2 ítems hacia arriba suma 2.
    final wheels = find.byType(CupertinoPicker);
    await tester.drag(wheels.first, const Offset(0, -104));
    await tester.pumpAndSettle();
    await tester.drag(wheels.last, const Offset(0, -52));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(find.text('03:01'), findsOneWidget);
  });
}
