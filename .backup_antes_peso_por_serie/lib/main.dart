import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';
import 'data/gym_store.dart';
import 'home_shell.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const GymApp());
}

class GymApp extends StatefulWidget {
  const GymApp({super.key});

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> {
  @override
  void initState() {
    super.initState();
    gymStore.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: gymStore,
        builder: (context, _) {
          if (!gymStore.loaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // El login solo aparece si no hay una sesión guardada.
          if (gymStore.currentUser == null) return const LoginScreen();
          return const HomeShell();
        },
      ),
    );
  }
}
