/// Connection details for the Raspberry Pi that controls the pumps.
class SshConfig {
  /// Default command run on the Pi to drive a pump, used until one is saved.
  ///
  /// Turns a GPIO pin on, waits, then turns it off. {pin} and {duration} are
  /// substituted per pump by [buildCommand].
  static const defaultCommandTemplate =
      'gpio -g mode {pin} out && gpio -g write {pin} 1 && sleep {duration} && gpio -g write {pin} 0';

  String host;
  int port;
  String username;
  String password;

  /// Shell command run on the Pi to drive a pump. Supports two placeholders:
  ///   {pin}      -> the pump's GPIO pin
  ///   {duration} -> the watering duration in seconds
  String commandTemplate;

  SshConfig({
    this.host = '',
    this.port = 22,
    this.username = 'pi',
    this.password = '',
    this.commandTemplate = defaultCommandTemplate,
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

  SshConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? commandTemplate,
  }) {
    return SshConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      commandTemplate: commandTemplate ?? this.commandTemplate,
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
      };

  factory SshConfig.fromJson(Map<String, dynamic> json) => SshConfig(
        host: json['host'] as String? ?? '',
        port: json['port'] as int? ?? 22,
        username: json['username'] as String? ?? 'pi',
        password: json['password'] as String? ?? '',
        commandTemplate:
            json['commandTemplate'] as String? ?? defaultCommandTemplate,
      );
}
