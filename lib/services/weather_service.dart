import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';
import '../models/weather_config.dart';

/// Result of a weather fetch. [success] is derived: we have a [weather] object
/// or we have an [error] string, never both meaningfully set.
class WeatherResult {
  final Weather? weather;
  final String error;

  WeatherResult({this.weather, this.error = ''});

  bool get success => weather != null;
}

/// Fetches current conditions and a short rain outlook from OpenWeather.
class WeatherService {
  static const _base = 'https://api.openweathermap.org/data/2.5';

  /// Calls the current-weather and 5-day/3-hour forecast endpoints and folds
  /// them into a single [Weather] snapshot.
  static Future<WeatherResult> fetch(WeatherConfig config) async {
    if (!config.isComplete) {
      return WeatherResult(error: 'Set the weather API key and city first.');
    }
    // Build both request URLs (city is URL-encoded; units=metric => °C).
    final city = Uri.encodeQueryComponent(config.city);
    final key = config.apiKey;
    final currentUrl = Uri.parse(
        '$_base/weather?q=$city&appid=$key&units=metric');
    final forecastUrl = Uri.parse(
        '$_base/forecast?q=$city&appid=$key&units=metric');

    try {
      // Fire both requests at once and wait for both (faster than serial).
      final responses = await Future.wait([
        http.get(currentUrl).timeout(const Duration(seconds: 15)),
        http.get(forecastUrl).timeout(const Duration(seconds: 15)),
      ]);
      final current = responses[0];
      final forecast = responses[1];

      // The current-weather call is the one we can't do without; if it failed,
      // translate the status code into a readable message and bail.
      if (current.statusCode != 200) {
        return WeatherResult(error: _describeError(current));
      }

      // Pull the fields we display out of the current-weather payload. Every
      // access is null-tolerant because the API occasionally omits sections
      // (e.g. `rain` is absent when it isn't raining).
      final cur = jsonDecode(current.body) as Map<String, dynamic>;
      final weatherList = cur['weather'] as List<dynamic>?;
      final first =
          (weatherList != null && weatherList.isNotEmpty)
              ? weatherList.first as Map<String, dynamic>
              : const <String, dynamic>{};
      final main = cur['main'] as Map<String, dynamic>? ?? const {};
      final rain = cur['rain'] as Map<String, dynamic>?;

      // Fold the next ~24h (eight 3-hour slots) of the forecast into a total
      // expected rainfall and the peak precipitation probability. The forecast
      // is best-effort: if it failed we just leave these at 0.
      double expectedRain = 0;
      double maxPop = 0;
      if (forecast.statusCode == 200) {
        final fc = jsonDecode(forecast.body) as Map<String, dynamic>;
        final list = (fc['list'] as List<dynamic>? ?? const []).take(8);
        for (final entry in list) {
          final e = entry as Map<String, dynamic>;
          final r = e['rain'] as Map<String, dynamic>?;
          expectedRain += (r?['3h'] as num?)?.toDouble() ?? 0;
          final pop = (e['pop'] as num?)?.toDouble() ?? 0;
          if (pop > maxPop) maxPop = pop;
        }
      }

      // Assemble the snapshot the UI consumes (and that drives shouldSkip/hint).
      return WeatherResult(
        weather: Weather(
          cityName: cur['name'] as String? ?? config.city,
          tempC: (main['temp'] as num?)?.toDouble() ?? 0,
          humidity: (main['humidity'] as num?)?.toInt() ?? 0,
          description: first['description'] as String? ?? '—',
          iconCode: first['icon'] as String? ?? '',
          rainLastHourMm: (rain?['1h'] as num?)?.toDouble() ?? 0,
          expectedRain24hMm: expectedRain,
          maxPop24h: maxPop,
        ),
      );
    } catch (e) {
      // Network error, timeout, malformed JSON, etc. -> readable error result.
      return WeatherResult(error: e.toString());
    }
  }

  /// Turns a non-200 current-weather response into a user-facing message,
  /// special-casing the two common cases (bad key / unknown city).
  static String _describeError(http.Response r) {
    if (r.statusCode == 401) {
      return 'Invalid API key (401). New OpenWeather keys can take a '
          'few hours to activate.';
    }
    if (r.statusCode == 404) return 'City not found (404). Check the city name.';
    // Otherwise try to surface the API's own message field.
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final msg = body['message'];
      if (msg is String && msg.isNotEmpty) return 'Weather error: $msg';
    } catch (_) {}
    return 'Weather request failed (${r.statusCode}).';
  }
}
