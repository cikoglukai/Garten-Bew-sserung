import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pump.dart';
import '../models/ssh_config.dart';
import '../models/watering_event.dart';
import '../models/weather.dart';
import '../models/weather_config.dart';
import '../services/settings_service.dart';
import '../services/ssh_service.dart';
import '../services/weather_service.dart';

/// A short status line for a pump action, plus whether it represents a
/// failure, so the UI can colour it without parsing the message text.
class PumpStatus {
  final String message;
  final bool isError;
  const PumpStatus(this.message, {this.isError = false});
}

/// Holds the app's configuration and the live watering state, and exposes
/// the actions the UI calls. Backed by [SettingsService] for persistence
/// and [SshService] for talking to the Pi.
///
/// This is the single source of truth. UI reads it via Provider and calls the
/// action methods (load / water / updatePump / refreshWeather / …); every
/// method that changes visible state ends with notifyListeners() to rebuild
/// the widgets watching it.
class AppState extends ChangeNotifier {
  final SettingsService _settings = SettingsService();

  // --- Persisted configuration (loaded once in load(), saved on edit) ---
  SshConfig config = SshConfig();
  WeatherConfig weatherConfig = WeatherConfig();
  List<Pump> pumps = [];

  /// Flips true once load() finishes; the home screen shows a plain green
  /// splash (matching the native launch splash) until then.
  bool loaded = false;

  /// Log of completed waterings, newest first. Used for the calendar and the
  /// per-pump "last watered" label.
  List<WateringEvent> history = [];

  /// Keep the log from growing without bound.
  static const _maxHistory = 1000;

  // --- Live weather state (fetched on demand, owned by refreshWeather()) ---
  /// Latest fetched weather, or null if not yet loaded.
  Weather? weather;
  bool weatherLoading = false;
  String? weatherError;

  /// IDs of pumps that are currently watering. A Set gives O(1) isWatering().
  final Set<String> _watering = {};

  /// Per-pump callback that aborts the in-flight SSH session, registered while
  /// a pump is watering and cleared when it finishes. Used by stopWatering().
  final Map<String, void Function()> _cancels = {};

  /// IDs of pumps a manual stop is handling. water() checks this on completion
  /// so it leaves the "Stopped" status alone and skips the history entry.
  final Set<String> _stopRequested = {};

  /// True while waterAll() is iterating the pumps. Set to false by stopWatering()
  /// to abort the whole sequence instead of just letting it advance to the next
  /// pump after the current one is stopped.
  bool _waterAllRunning = false;

  /// Last status message per pump, shown on its card.
  final Map<String, PumpStatus> _status = {};

  /// Which pumps the next "Water all" run should include. null means "all
  /// pumps" (the default); once the user deselects any, it becomes an explicit
  /// id set. Reset back to null after each run so the selection is per-run.
  Set<String>? _runSelection;

  // --- Live SSH connectivity (driven by a background reachability poll) ---
  /// Whether the Pi is currently reachable over SSH. The home screen shows a
  /// red dot and disables every "start watering" button while this is false.
  /// Starts false and flips true once a poll succeeds.
  bool _connected = false;

  /// Repeats the reachability check so the indicator and button-enabled state
  /// stay current on their own. Cancelled in dispose().
  Timer? _connectivityTimer;
  static const _connectivityInterval = Duration(seconds: 15);

  // Read-only views the widgets use to render a single pump's live state.
  bool isWatering(String pumpId) => _watering.contains(pumpId);
  PumpStatus? statusFor(String pumpId) => _status[pumpId];

  /// Whether the Pi is currently reachable. The UI gates the watering buttons
  /// and the connection dot on this.
  bool get connected => _connected;

  /// Whether any pump is currently watering. Disables the "Water all" button.
  bool get anyWatering => _watering.isNotEmpty;

  /// Whether [pumpId] is included in the next "Water all" run. With no explicit
  /// selection (the default) every pump is included.
  bool isSelectedForRun(String pumpId) =>
      _runSelection?.contains(pumpId) ?? true;

  /// How many pumps the next run will water.
  int get runSelectionCount => _runSelection?.length ?? pumps.length;

  /// True when the run includes every pump (the default state).
  bool get allSelectedForRun => runSelectionCount == pumps.length;

  /// Toggles whether [pumpId] is part of the next run. Materialises the "all"
  /// default into a concrete set on first deselect, and collapses back to the
  /// null "all" state once everything is selected again.
  void toggleRunSelection(String pumpId) {
    final selection = _runSelection ?? pumps.map((p) => p.id).toSet();
    if (selection.contains(pumpId)) {
      selection.remove(pumpId);
    } else {
      selection.add(pumpId);
    }
    _runSelection = selection.length == pumps.length ? null : selection;
    notifyListeners();
  }

  /// When [pumpId] was last watered, or null if there's no record. History is
  /// newest-first, so the first match is the most recent.
  DateTime? lastWateredFor(String pumpId) {
    for (final e in history) {
      if (e.pumpId == pumpId) return e.timestamp;
    }
    return null;
  }

  /// Waterings recorded on the same calendar day as [day]. Used by the history
  /// calendar both as the day-cell event loader and for the selected-day list.
  List<WateringEvent> eventsForDay(DateTime day) {
    return history
        .where(
          (e) =>
              e.timestamp.year == day.year &&
              e.timestamp.month == day.month &&
              e.timestamp.day == day.day,
        )
        .toList();
  }

  /// Loads everything from disk on startup, then (if weather is configured)
  /// kicks off a first weather fetch. Called once from main().
  Future<void> load() async {
    config = await _settings.loadConfig();
    weatherConfig = await _settings.loadWeatherConfig();
    pumps = await _settings.loadPumps();
    history = await _settings.loadHistory();
    loaded = true;
    notifyListeners();
    // Begin polling SSH reachability so the connection dot and the watering
    // buttons reflect the live state without the user doing anything.
    _startConnectivityPolling();
    if (weatherConfig.isComplete) {
      // Fire-and-forget; the card shows its own loading/error state.
      refreshWeather();
    }
  }

  /// Saves a new SSH config and notifies the UI.
  Future<void> updateConfig(SshConfig newConfig) async {
    config = newConfig;
    await _settings.saveConfig(config);
    notifyListeners();
    // Re-check reachability right away against the new connection details.
    _startConnectivityPolling();
  }

  /// (Re)starts the background reachability poll: checks once now, then on a
  /// fixed interval. Safe to call repeatedly — it cancels any prior timer.
  void _startConnectivityPolling() {
    _connectivityTimer?.cancel();
    _checkConnection();
    _connectivityTimer = Timer.periodic(
      _connectivityInterval,
      (_) => _checkConnection(),
    );
  }

  /// One reachability probe. Marks the Pi unreachable when there's no complete
  /// config; otherwise runs the lightweight test command and flips [_connected]
  /// to its result. Only notifies when the value actually changes.
  Future<void> _checkConnection() async {
    final reachable =
        config.isComplete && (await SshService.testConnection(config)).success;
    if (_connected != reachable) {
      _connected = reachable;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  /// Saves a new weather config; if it's now complete, fetch straight away.
  Future<void> updateWeatherConfig(WeatherConfig newConfig) async {
    weatherConfig = newConfig;
    await _settings.saveWeatherConfig(weatherConfig);
    notifyListeners();
    if (weatherConfig.isComplete) refreshWeather();
  }

  /// Fetches the latest weather for the configured city. Drives the three
  /// weather* fields, notifying before (loading=true) and after (result).
  Future<void> refreshWeather() async {
    if (!weatherConfig.isComplete) {
      weatherError = 'Set the weather API key and city in Settings.';
      notifyListeners();
      return;
    }
    weatherLoading = true;
    weatherError = null;
    notifyListeners();

    final result = await WeatherService.fetch(weatherConfig);
    weatherLoading = false;
    if (result.success) {
      weather = result.weather;
      weatherError = null;
    } else {
      weatherError = result.error;
    }
    notifyListeners();
  }

  /// Replaces a pump in the list (matched by id) and persists. Used by the
  /// Settings name/pin fields and the duration slider on each card.
  Future<void> updatePump(Pump pump) async {
    final i = pumps.indexWhere((p) => p.id == pump.id);
    if (i == -1) return;
    pumps[i] = pump;
    await _settings.savePumps(pumps);
    notifyListeners();
  }

  /// Runs the configured command for [pump] over SSH for its set duration.
  ///
  /// Flow: guard (config set? not already running?) -> mark watering + show a
  /// status -> build & send the command -> on the result, clear the watering
  /// flag, set a done/failed status, and on success append to history.
  Future<SshResult> water(Pump pump) async {
    // Guard 1: no connection configured yet.
    if (!config.isComplete) {
      final r = SshResult(
        success: false,
        error: 'Set the Raspberry Pi connection in Settings first.',
      );
      _status[pump.id] = PumpStatus(r.error, isError: true);
      notifyListeners();
      return r;
    }
    // Guard 2: this pump is already running — ignore the duplicate request.
    if (_watering.contains(pump.id)) {
      return SshResult(success: false, error: 'Already watering.');
    }

    // Optimistically flip the card into its "watering…" state.
    _watering.add(pump.id);
    _status[pump.id] = PumpStatus('Watering for ${pump.durationSeconds}s…');
    notifyListeners();

    final command = config.buildCommand(
      pin: pump.gpioPin,
      duration: pump.durationSeconds,
    );
    // Allow the SSH session a little longer than the watering itself.
    final result = await SshService.run(
      config,
      command,
      timeout: Duration(seconds: pump.durationSeconds + 30),
      // Let stopWatering() abort this session before the duration is up.
      registerCancel: (cancel) => _cancels[pump.id] = cancel,
    );
    _cancels.remove(pump.id);

    // A manual stop already cleared _watering, set the "Stopped" status and
    // (deliberately) skipped history — leave all of that as-is.
    if (_stopRequested.remove(pump.id)) {
      notifyListeners();
      return result;
    }

    // Done: clear the running flag and record the outcome on the card.
    _watering.remove(pump.id);
    _status[pump.id] = result.success
        ? PumpStatus('Done — watered ${pump.durationSeconds}s')
        : PumpStatus('Failed: ${result.error}', isError: true);

    // Only successful waterings go into the history log.
    if (result.success) {
      history.insert(
        0,
        WateringEvent(
          pumpId: pump.id,
          pumpName: pump.name,
          durationSeconds: pump.durationSeconds,
          timestamp: DateTime.now(),
        ),
      );
      // Trim the oldest entries if we've exceeded the cap.
      if (history.length > _maxHistory) {
        history.removeRange(_maxHistory, history.length);
      }
      await _settings.saveHistory(history);
    }

    notifyListeners();
    return result;
  }

  /// Stops a pump that's currently watering, before its duration is up.
  ///
  /// Flips the card out of its watering state straight away, sends the stop
  /// command (which forces the GPIO pin low so the pump shuts off even though
  /// the original watering command is still sleeping on the Pi), then aborts
  /// that lingering SSH session. The watering's own future sees _stopRequested
  /// and bows out without touching the status or logging history.
  Future<void> stopWatering(Pump pump) async {
    // Nothing to stop if this pump isn't running.
    if (!_watering.contains(pump.id)) return;

    // Stopping the running pump also stops the whole "Water all" sequence, so
    // it doesn't carry on to the next zone after this one shuts off.
    _waterAllRunning = false;

    // Hand control of this pump's status/history to us, and update the card now.
    _stopRequested.add(pump.id);
    _watering.remove(pump.id);
    _status[pump.id] = const PumpStatus('Stopped');
    notifyListeners();

    // Force the pin low on the Pi so water actually stops flowing now.
    final result = await SshService.run(
      config,
      config.buildStopCommand(pin: pump.gpioPin),
      timeout: const Duration(seconds: 15),
    );

    // Abort the still-open watering session so its run() returns promptly
    // instead of holding the connection for the rest of the duration.
    _cancels.remove(pump.id)?.call();

    // Surface a stop that didn't take — the pump may still be running.
    if (!result.success) {
      _status[pump.id] = PumpStatus(
        'Stop failed: ${result.error}',
        isError: true,
      );
      notifyListeners();
    }
  }

  /// Waters every selected pump that isn't already running, one after another
  /// so the Pi only handles a single SSH session at a time. Iterates a copy so
  /// the list can't change under us mid-loop. The per-run selection (see
  /// [toggleRunSelection]) is reset to "all" once the sequence finishes.
  ///
  /// Hitting Stop on the running pump clears [_waterAllRunning], which breaks
  /// the loop so the sequence stops entirely instead of advancing to the next
  /// pump.
  Future<void> waterAll() async {
    _waterAllRunning = true;
    for (final pump in List<Pump>.from(pumps)) {
      if (!_waterAllRunning) break;
      // Skip pumps the user left out of this run's selection.
      if (!isSelectedForRun(pump.id)) continue;
      if (!_watering.contains(pump.id)) {
        await water(pump);
      }
    }
    _waterAllRunning = false;
    // The selection is per-run: reset to "all pumps" for the next time.
    _runSelection = null;
    notifyListeners();
  }

  /// One-off connectivity check for the Settings "Test connection" button.
  Future<SshResult> testConnection() => SshService.testConnection(config);
}
