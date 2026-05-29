/// Connection details for the Raspberry Pi that controls the pumps.
class SshConfig {
  /// Default command run on the Pi to drive a pump, used until one is saved.
  ///
  /// Turns a GPIO pin on, waits, then turns it off. {pin} and {duration} are
  /// substituted per pump by [buildCommand].
  static const defaultCommandTemplate =
      'raspi-gpio set {pin} op && raspi-gpio set {pin} dl && sleep {duration} && raspi-gpio set {pin} dh';

  /// Default command run on the Pi to stop a pump early, used until one is
  /// saved. Forces the pin low immediately so the pump shuts off even while
  /// the original watering command is still sleeping. {pin} is substituted by
  /// [buildStopCommand].
  static const defaultStopCommandTemplate = 'raspi-gpio set {pin} dh';

  String host;
  int port;
  String username;
  String password;

  /// Shell command run on the Pi to drive a pump. Supports two placeholders:
  ///   {pin}      -> the pump's GPIO pin
  ///   {duration} -> the watering duration in seconds
  String commandTemplate;

  /// Shell command run on the Pi to stop a pump mid-watering. Supports the
  /// {pin} placeholder (the watering duration is irrelevant when stopping).
  String stopCommandTemplate;

  SshConfig({
    this.host = '',
    this.port = 22,
    this.username = 'pi',
    this.password = '',
    this.commandTemplate = defaultCommandTemplate,
    this.stopCommandTemplate = defaultStopCommandTemplate,
  });

  /// Host + username are the minimum needed to attempt a connection; the UI
  /// blocks watering and shows a banner until this is true.
  bool get isComplete => host.isNotEmpty && username.isNotEmpty;

  /// Builds the concrete command for a pump from the template, substituting
  /// the placeholders. Called by AppState.water() before sending over SSH.
  String buildCommand({required int pin, required int duration}) {
    return commandTemplate
        .replaceAll('{pin}', '$pin')
        .replaceAll('{duration}', '$duration');
  }

  /// Builds the concrete stop command for a pump from the template. Called by
  /// AppState.stopWatering() to shut a running pump off early.
  String buildStopCommand({required int pin}) {
    return stopCommandTemplate.replaceAll('{pin}', '$pin');
  }

  SshConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? commandTemplate,
    String? stopCommandTemplate,
  }) {
    return SshConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      commandTemplate: commandTemplate ?? this.commandTemplate,
      stopCommandTemplate: stopCommandTemplate ?? this.stopCommandTemplate,
    );
  }

  // Persisted via SettingsService. Note the password is stored in plain text
  // in local device storage — fine for a home-LAN hobby app, not for secrets.
  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'commandTemplate': commandTemplate,
        'stopCommandTemplate': stopCommandTemplate,
      };

  factory SshConfig.fromJson(Map<String, dynamic> json) => SshConfig(
        host: json['host'] as String? ?? '',
        port: json['port'] as int? ?? 22,
        username: json['username'] as String? ?? 'pi',
        password: json['password'] as String? ?? '',
        commandTemplate:
            json['commandTemplate'] as String? ?? defaultCommandTemplate,
        // Older saves predate the stop command; fall back to the default.
        stopCommandTemplate: json['stopCommandTemplate'] as String? ??
            defaultStopCommandTemplate,
      );
}
