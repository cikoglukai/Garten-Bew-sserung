import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pump.dart';
import '../state/app_state.dart';
import '../widgets/no_stretch_scroll_behavior.dart';
import '../widgets/pump_card.dart';
import '../widgets/watering_can_loader.dart';
import '../widgets/weather_card.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Main screen: the weather card, a "Water all" button, and the pump cards
/// laid out in two columns.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        // While loading, tint the header to match the green splash backdrop.
        backgroundColor: state.loaded ? null : const Color(0xFF2E7D32),
        foregroundColor: state.loaded ? null : Colors.white,
        title: const Text('Garden Watering'),
        // Hide the navigation actions until loading finishes.
        actions: state.loaded
            ? [
                // Top-right: open the history calendar and the settings page.
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Watering history',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ]
            : null,
      ),
      // Show the filling watering can until AppState.load() has finished
      // reading from disk, on a natural green backdrop.
      body: !state.loaded
          ? Container(
              color: const Color(0xFF2E7D32),
              alignment: Alignment.center,
              child: const WateringCanLoader(label: 'Loading…'),
            )
          : Column(
              children: [
                // If there's no Pi configured yet, show a tappable warning
                // banner above the list that jumps to Settings.
                if (!state.config.isComplete)
                  Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber),
                      title: const Text('No Raspberry Pi configured'),
                      subtitle:
                          const Text('Tap to set the connection details.'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const NoStretchScrollBehavior(),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        const WeatherCard(),
                        // Enabled only when there's somewhere to send commands,
                        // pumps exist, and nothing is currently running.
                        _WaterAllButton(
                          enabled: state.config.isComplete &&
                              state.pumps.isNotEmpty &&
                              !state.anyWatering,
                          onPressed: () =>
                              context.read<AppState>().waterAll(),
                        ),
                        // The pumps, two per row.
                        ..._pumpRows(state.pumps),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Pairs the pumps into rows of two so they render as two columns of
  /// equal-height cards. IntrinsicHeight + stretch makes both cards in a row
  /// match the taller one; an odd final pump gets an empty second slot.
  List<Widget> _pumpRows(List<Pump> pumps) {
    final rows = <Widget>[];
    for (var i = 0; i < pumps.length; i += 2) {
      final left = pumps[i];
      final right = i + 1 < pumps.length ? pumps[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: PumpCard(pump: left)),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink() // keeps the lone card half-width
                    : PumpCard(pump: right),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}

/// Full-width button that triggers watering every configured pump in turn.
class _WaterAllButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _WaterAllButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          // Passing null for onPressed renders the button as disabled.
          onPressed: enabled ? onPressed : null,
          icon: const Icon(Icons.water_drop),
          label: const Text('Water all'),
        ),
      ),
    );
  }
}
