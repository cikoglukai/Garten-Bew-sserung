/// A single watering pump wired to a GPIO pin on the Raspberry Pi.
///
/// `id` is immutable (used as the stable key everywhere); `name`, `gpioPin`
/// and `durationSeconds` are editable in Settings / on the pump card.
class Pump {
  final String id;
  String name;
  int gpioPin;
  int durationSeconds;

  Pump({
    required this.id,
    required this.name,
    required this.gpioPin,
    this.durationSeconds = 30,
  });

  /// Returns a copy with the given fields replaced (id is always kept). The UI
  /// edits pumps immutably: build a copy, hand it to AppState.updatePump().
  Pump copyWith({String? name, int? gpioPin, int? durationSeconds}) {
    return Pump(
      id: id,
      name: name ?? this.name,
      gpioPin: gpioPin ?? this.gpioPin,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  // toJson / fromJson are the on-disk shape used by SettingsService. fromJson
  // tolerates a missing durationSeconds (older saves) by defaulting to 30.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gpioPin': gpioPin,
        'durationSeconds': durationSeconds,
      };

  factory Pump.fromJson(Map<String, dynamic> json) => Pump(
        id: json['id'] as String,
        name: json['name'] as String,
        gpioPin: json['gpioPin'] as int,
        durationSeconds: json['durationSeconds'] as int? ?? 30,
      );

  /// The five pumps created on first launch. GPIO pins are sensible defaults
  /// (BCM numbering) that you can change in Settings.
  static List<Pump> defaults() => [
        Pump(id: 'pump_1', name: 'Pump 1', gpioPin: 17),
        Pump(id: 'pump_2', name: 'Pump 2', gpioPin: 18),
        Pump(id: 'pump_3', name: 'Pump 3', gpioPin: 27),
        Pump(id: 'pump_4', name: 'Pump 4', gpioPin: 22),
        Pump(id: 'pump_5', name: 'Pump 5', gpioPin: 23),
      ];
}
