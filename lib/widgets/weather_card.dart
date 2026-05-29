import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weather.dart';
import '../state/app_state.dart';
import '../screens/settings_screen.dart';

/// Shows current conditions and a watering hint based on recent/upcoming rain.
///
/// Three display states, in order:
///   1. not configured  -> a "set it up" tile linking to Settings
///   2. configured, no data yet -> icon + "Loading weather…" (or an error)
///   3. configured, data -> conditions + the coloured hint banner
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // State 1 — not configured yet: gently point to Settings.
    if (!state.weatherConfig.isComplete) {
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Add weather'),
          subtitle: const Text(
              'Set an OpenWeather API key and city to get a watering hint.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      );
    }

    // States 2 & 3 — configured. `weather` is null until the first fetch lands.
    final weather = state.weather;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Condition icon (mapped from the OpenWeather code), or a
                // placeholder cloud until data arrives.
                Icon(
                  weather != null
                      ? _iconFor(weather.iconCode)
                      : Icons.cloud_outlined,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                // Middle: the loading/conditions/error text block.
                Expanded(child: _summary(state, weather, theme)),
                // Right: manual refresh (spinner while a fetch is in flight).
                IconButton(
                  tooltip: 'Refresh',
                  icon: state.weatherLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: state.weatherLoading
                      ? null
                      : () => context.read<AppState>().refreshWeather(),
                ),
              ],
            ),
            // The skip-watering recommendation only shows once we have data.
            if (weather != null) ...[
              const SizedBox(height: 12),
              _HintBanner(weather: weather),
            ],
          ],
        ),
      ),
    );
  }

  /// The text block beside the weather icon: loading, conditions, or error.
  /// Split out so the three cases read as plain if-returns instead of a nested
  /// ternary inside the widget tree.
  Widget _summary(AppState state, Weather? weather, ThemeData theme) {
    // First fetch still running and nothing to show yet.
    if (state.weatherLoading && weather == null) {
      return const Text('Loading weather…');
    }
    // Fetch finished but failed (or never produced data): show the error.
    if (weather == null) {
      return Text(
        state.weatherError ?? 'Weather unavailable',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      );
    }
    // We have data: temperature + city, then description + humidity.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${weather.tempC.round()}°C  ·  ${weather.cityName}',
          style: theme.textTheme.titleMedium,
        ),
        Text(
          '${_capitalize(weather.description)}  ·  ${weather.humidity}% humidity',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Maps an OpenWeather icon code (e.g. "10d") to a Material icon.
  static IconData _iconFor(String code) {
    if (code.isEmpty) return Icons.cloud_outlined;
    final c = code.substring(0, code.length - 1); // drop the d/n suffix
    switch (c) {
      case '01':
        return Icons.wb_sunny;
      case '02':
        return Icons.cloud_queue;
      case '03':
      case '04':
        return Icons.cloud;
      case '09':
        return Icons.grain;
      case '10':
        return Icons.umbrella;
      case '11':
        return Icons.thunderstorm;
      case '13':
        return Icons.ac_unit;
      case '50':
        return Icons.foggy;
      default:
        return Icons.cloud_outlined;
    }
  }
}

/// Colored banner with the skip-watering recommendation. Tertiary palette when
/// you can skip (rain coming), secondary when watering is advised.
class _HintBanner extends StatelessWidget {
  final Weather weather;
  const _HintBanner({required this.weather});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skip = weather.shouldSkipWatering;
    final bg = skip
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.secondaryContainer;
    final fg = skip
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(skip ? Icons.umbrella : Icons.water_drop, size: 20, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              weather.hint, // human-readable reason from the Weather model
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
