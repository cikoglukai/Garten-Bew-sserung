// Application entry point.
//
// Architecture at a glance (data flows bottom-up, actions flow top-down):
//
//   models/     plain data classes (Pump, SshConfig, Weather, …) with JSON
//   services/   talk to the outside world (device storage, SSH, OpenWeather)
//   state/      AppState — the single source of truth; wires services to UI
//   widgets/    reusable pieces (pump card, weather card, …)
//   screens/    full pages (home, settings, history)
//
// AppState is a ChangeNotifier provided once at the root here. Widgets read it
// with context.watch (rebuild on change) or context.read (one-off actions).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'state/app_state.dart';

void main() {
  runApp(const GardenWateringApp());
}

class GardenWateringApp extends StatelessWidget {
  const GardenWateringApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create AppState and immediately kick off load() (reads saved config,
    // pumps and history from disk). Everything below `child` can then access
    // it via Provider. `..load()` is fire-and-forget — the UI shows a spinner
    // until AppState.loaded flips true.
    return ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: MaterialApp(
        title: 'Garden Watering',
        debugShowCheckedModeBanner: false,
        // Green-seeded Material 3 theme, with matching light and dark variants
        // selected automatically from the device setting.
        theme: ThemeData(
          colorSchemeSeed: Colors.green,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.green,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
