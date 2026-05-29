import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pump.dart';
import '../state/app_state.dart';
import '../utils/date_format.dart';

/// A card for one pump: name, GPIO pin, a duration slider, and a
/// "Water now" button.
class PumpCard extends StatelessWidget {
  final Pump pump;

  const PumpCard({super.key, required this.pump});

  @override
  Widget build(BuildContext context) {
    // watch() => rebuild whenever AppState changes. Pull this pump's live bits.
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final watering = state.isWatering(pump.id);
    final status = state.statusFor(pump.id);
    final lastWatered = state.lastWateredFor(pump.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: drop icon, name (takes the slack), GPIO pin.
            Row(
              children: [
                Icon(Icons.water_drop, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pump.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text('GPIO ${pump.gpioPin}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            // Current duration setting.
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Duration: ${pump.durationSeconds}s'),
              ],
            ),
            const SizedBox(height: 4),
            // "Last watered" line, formatted relative to today (or "never").
            Row(
              children: [
                Icon(Icons.history, size: 18,
                    color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  lastWatered == null
                      ? 'Last watered: never'
                      : 'Last watered: ${DateFormatting.lastWatered(lastWatered)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            // Duration slider (1–300s). Disabled while watering; each change
            // persists immediately via updatePump(copyWith()).
            Slider(
              min: 1,
              max: 300,
              divisions: 299,
              value: pump.durationSeconds.toDouble(),
              label: '${pump.durationSeconds}s',
              onChanged: watering
                  ? null
                  : (v) => context
                      .read<AppState>()
                      .updatePump(pump.copyWith(durationSeconds: v.round())),
            ),
            const SizedBox(height: 4),
            // Action button. While watering it's disabled and shows a spinner;
            // otherwise it triggers AppState.water(pump).
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: watering
                    ? null
                    : () => context.read<AppState>().water(pump),
                icon: watering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(watering ? 'Watering…' : 'Water now'),
              ),
            ),
            // Last status line, if any. Coloured red on error, accent otherwise
            // — read straight off PumpStatus.isError, no string parsing.
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(
                status.message,
                style: theme.textTheme.bodySmall?.copyWith(
                      color: status.isError
                          ? theme.colorScheme.error
                          : theme.colorScheme.secondary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
