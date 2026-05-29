/// A snapshot of current conditions plus a short rain outlook, used to show
/// the weather and to suggest whether watering can be skipped.
///
/// Built by WeatherService by folding two OpenWeather endpoints (current +
/// 3-hour forecast) into one object. The two getters below are the "business
/// logic": given the numbers, should you water, and why.
class Weather {
  final String cityName;
  final double tempC;
  final int humidity;
  final String description;

  /// OpenWeather icon code, e.g. "10d". Mapped to a Material icon in the UI.
  final String iconCode;

  /// Rain in the last hour (mm), from the current-weather endpoint.
  final double rainLastHourMm;

  /// Total expected rain (mm) over roughly the next 24 hours, summed from the
  /// 3-hour forecast.
  final double expectedRain24hMm;

  /// Highest precipitation probability (0..1) over the next ~24 hours.
  final double maxPop24h;

  Weather({
    required this.cityName,
    required this.tempC,
    required this.humidity,
    required this.description,
    required this.iconCode,
    required this.rainLastHourMm,
    required this.expectedRain24hMm,
    required this.maxPop24h,
  });

  // Thresholds above which watering is suggested to be skipped. Defined once
  // here so shouldSkipWatering and hint can't drift apart.
  static const _recentRainMm = 1.0;
  static const _expectedRainMm = 2.0;
  static const _rainProbability = 0.6;

  /// True when recent or upcoming rain makes watering likely unnecessary.
  /// Drives the colour of the hint banner on the weather card.
  bool get shouldSkipWatering =>
      rainLastHourMm >= _recentRainMm ||
      expectedRain24hMm >= _expectedRainMm ||
      maxPop24h >= _rainProbability;

  /// A short, human-readable reason for the watering hint. Checks the same
  /// three signals as [shouldSkipWatering], in priority order, and returns the
  /// first that fires (or an all-clear message).
  String get hint {
    if (rainLastHourMm >= _recentRainMm) {
      return 'It rained recently (${rainLastHourMm.toStringAsFixed(1)} mm) — '
          'you can probably skip watering today.';
    }
    if (expectedRain24hMm >= _expectedRainMm) {
      return '${expectedRain24hMm.toStringAsFixed(1)} mm of rain expected in the '
          'next 24h — you can probably skip watering.';
    }
    if (maxPop24h >= _rainProbability) {
      return 'Rain likely soon (${(maxPop24h * 100).round()}% chance) — '
          'consider waiting before watering.';
    }
    return 'No significant rain expected — a good time to water.';
  }
}
