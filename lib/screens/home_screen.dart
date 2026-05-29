import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pump.dart';
import '../state/app_state.dart';
import '../widgets/no_stretch_scroll_behavior.dart';
import '../widgets/pump_card.dart';
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

    // Until load() finishes reading from disk (a few milliseconds), keep a
    // plain green screen that matches the native launch splash, so the two
    // read as a single, continuous splash.
    if (!state.loaded) {
      return const Scaffold(backgroundColor: Color(0xFF2E7D32));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garden Watering'),
        actions: [
          // Connection indicator: red when the Pi is unreachable over SSH,
          // green when it's connected.
          _ConnectionDot(connected: state.connected),
          // Top-right: open the history calendar and the settings page.
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Watering history',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // If there's no Pi configured yet, show a tappable warning
          // banner above the list that jumps to Settings.
          if (!state.config.isComplete)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('No Raspberry Pi configured'),
                subtitle: const Text('Tap to set the connection details.'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                  // "Water all" plus a dropdown to pick which pumps this run
                  // should include. Enabled only when there's somewhere to send
                  // commands, the Pi is reachable, at least one pump is selected,
                  // and nothing is currently running.
                  _WaterAllRow(
                    enabled:
                        state.config.isComplete &&
                        state.connected &&
                        state.runSelectionCount > 0 &&
                        !state.anyWatering,
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

/// Small status dot shown in the app bar: red when the Pi isn't reachable
/// over SSH, green when it is. Carries a matching tooltip for clarity.
class _ConnectionDot extends StatelessWidget {
  final bool connected;

  const _ConnectionDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? Colors.green : Colors.red;
    return Tooltip(
      message: connected ? 'Connected to Raspberry Pi' : 'Not connected',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row holding the "Water all" button and a dropdown for choosing which pumps
/// a single run should water. The button fills the remaining width; the
/// dropdown sits to its right.
class _WaterAllRow extends StatelessWidget {
  final bool enabled;

  const _WaterAllRow({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.allSelectedForRun;
    // Reflect a partial selection in the label so it's clear what will run.
    final label = all ? 'Water all' : 'Water ${state.runSelectionCount} selected';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              // Passing null for onPressed renders the button as disabled.
              onPressed: enabled
                  ? () => context.read<AppState>().waterAll()
                  : null,
              icon: const Icon(Icons.water_drop),
              label: Text(label),
            ),
          ),
          const SizedBox(width: 8),
          _PumpSelectMenu(pumps: state.pumps),
        ],
      ),
    );
  }
}

/// Dropdown of checkboxes for choosing which pumps the next "Water all" run
/// includes. Selections live in [AppState] and reset to "all" after each run.
class _PumpSelectMenu extends StatelessWidget {
  final List<Pump> pumps;

  const _PumpSelectMenu({required this.pumps});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MenuAnchor(
      builder: (context, controller, child) => IconButton.outlined(
        icon: const Icon(Icons.tune),
        tooltip: 'Choose pumps for this run',
        // No pumps to choose from -> nothing to open.
        onPressed: pumps.isEmpty
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        for (final pump in pumps)
          // CheckboxMenuButton keeps the menu open as items are toggled.
          CheckboxMenuButton(
            value: state.isSelectedForRun(pump.id),
            onChanged: (_) =>
                context.read<AppState>().toggleRunSelection(pump.id),
            child: Text(pump.name),
          ),
      ],
    );
  }
}
