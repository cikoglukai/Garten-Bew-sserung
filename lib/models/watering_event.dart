/// A record of one completed watering, kept for the history calendar.
///
/// [pumpName] is snapshotted at the time of watering so the log still reads
/// correctly even if the pump is later renamed.
class WateringEvent {
  final String pumpId;
  final String pumpName;
  final int durationSeconds;
  final DateTime timestamp;

  WateringEvent({
    required this.pumpId,
    required this.pumpName,
    required this.durationSeconds,
    required this.timestamp,
  });

  // Persisted via SettingsService. The timestamp is stored as an ISO-8601
  // string and parsed back in fromJson.
  Map<String, dynamic> toJson() => {
        'pumpId': pumpId,
        'pumpName': pumpName,
        'durationSeconds': durationSeconds,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WateringEvent.fromJson(Map<String, dynamic> json) => WateringEvent(
        pumpId: json['pumpId'] as String,
        pumpName: json['pumpName'] as String? ?? 'Pump',
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
