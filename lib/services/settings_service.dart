import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pump.dart';
import '../models/ssh_config.dart';
import '../models/watering_event.dart';
import '../models/weather_config.dart';

/// Persists the SSH config, weather config, pump list and watering history to
/// local device storage as JSON.
///
/// Everything is keyed under the four `_*Key` strings below. The three private
/// helpers (_load / _loadList / _save) hold the actual SharedPreferences +
/// JSON plumbing, so each public method is a one-liner that just names the key,
/// the (de)serialiser, and the default.
class SettingsService {
  static const _configKey = 'ssh_config';
  static const _pumpsKey = 'pumps';
  static const _weatherKey = 'weather_config';
  static const _historyKey = 'watering_history';

  // SharedPreferences.getInstance() is async but the instance is a singleton,
  // so we fetch it once and reuse the future for every read/write.
  Future<SharedPreferences>? _prefsFuture;
  Future<SharedPreferences> get _prefs =>
      _prefsFuture ??= SharedPreferences.getInstance();

  /// Reads a single JSON object at [key], or returns [orElse] if none is stored.
  Future<T> _load<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
    T Function() orElse,
  ) async {
    final raw = (await _prefs).getString(key);
    if (raw == null) return orElse();
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Reads a JSON list at [key], or returns [orElse] if none is stored.
  Future<List<T>> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
    List<T> Function() orElse,
  ) async {
    final raw = (await _prefs).getString(key);
    if (raw == null) return orElse();
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Encodes [json] (a Map or List) and writes it under [key].
  Future<void> _save(String key, Object json) async =>
      (await _prefs).setString(key, jsonEncode(json));

  // --- SSH connection config (falls back to an empty SshConfig) ---
  Future<SshConfig> loadConfig() =>
      _load(_configKey, SshConfig.fromJson, SshConfig.new);

  Future<void> saveConfig(SshConfig config) =>
      _save(_configKey, config.toJson());

  // --- Pumps (falls back to the five built-in defaults on first launch) ---
  Future<List<Pump>> loadPumps() =>
      _loadList(_pumpsKey, Pump.fromJson, Pump.defaults);

  Future<void> savePumps(List<Pump> pumps) =>
      _save(_pumpsKey, pumps.map((p) => p.toJson()).toList());

  // --- Weather config (falls back to an empty WeatherConfig) ---
  Future<WeatherConfig> loadWeatherConfig() =>
      _load(_weatherKey, WeatherConfig.fromJson, WeatherConfig.new);

  Future<void> saveWeatherConfig(WeatherConfig config) =>
      _save(_weatherKey, config.toJson());

  // --- Watering history (falls back to an empty list) ---
  Future<List<WateringEvent>> loadHistory() =>
      _loadList(_historyKey, WateringEvent.fromJson, () => <WateringEvent>[]);

  Future<void> saveHistory(List<WateringEvent> history) =>
      _save(_historyKey, history.map((e) => e.toJson()).toList());
}
