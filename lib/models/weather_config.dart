/// Settings for fetching weather from the OpenWeather API.
class WeatherConfig {
  /// OpenWeather API key (https://openweathermap.org/api — free tier works).
  String apiKey;

  /// City lookup string, e.g. "Munich,DE" or "Berlin".
  String city;

  WeatherConfig({
    this.apiKey = '',
    this.city = '',
  });

  /// We only attempt a fetch once both fields are filled in; the UI uses this
  /// to decide whether to show the weather card or a "set it up" prompt.
  bool get isComplete => apiKey.isNotEmpty && city.isNotEmpty;

  WeatherConfig copyWith({String? apiKey, String? city}) {
    return WeatherConfig(
      apiKey: apiKey ?? this.apiKey,
      city: city ?? this.city,
    );
  }

  // Persisted via SettingsService.
  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'city': city,
      };

  factory WeatherConfig.fromJson(Map<String, dynamic> json) => WeatherConfig(
        apiKey: json['apiKey'] as String? ?? '',
        city: json['city'] as String? ?? '',
      );
}
