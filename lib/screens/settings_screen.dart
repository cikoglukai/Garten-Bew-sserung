import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pump.dart';
import '../models/ssh_config.dart';
import '../models/weather_config.dart';
import '../state/app_state.dart';
import '../widgets/no_stretch_scroll_behavior.dart';

/// Settings: SSH connection to the Pi, the command template, and per-pump
/// names / GPIO pins.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // This is a Form with one controller per text field. The controllers hold a
  // local working copy of the settings; nothing is pushed to AppState until
  // the user hits Save/Test/Fetch. The three bools track field-toggle state.
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _host;
  late TextEditingController _port;
  late TextEditingController _username;
  late TextEditingController _password;
  late TextEditingController _command;
  late TextEditingController _stopCommand;
  late TextEditingController _weatherApiKey;
  late TextEditingController _weatherCity;
  bool _obscure = true; // hide the SSH password
  bool _obscureApiKey = true; // hide the weather API key
  bool _testing = false; // a connection test is in flight

  @override
  void initState() {
    super.initState();
    // Seed every controller from the values currently in AppState.
    final state = context.read<AppState>();
    final c = state.config;
    _host = TextEditingController(text: c.host);
    _port = TextEditingController(text: c.port.toString());
    _username = TextEditingController(text: c.username);
    _password = TextEditingController(text: c.password);
    _command = TextEditingController(text: c.commandTemplate);
    _stopCommand = TextEditingController(text: c.stopCommandTemplate);
    _weatherApiKey = TextEditingController(text: state.weatherConfig.apiKey);
    _weatherCity = TextEditingController(text: state.weatherConfig.city);
  }

  @override
  void dispose() {
    // Controllers must be disposed to free their listeners.
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _command.dispose();
    _stopCommand.dispose();
    _weatherApiKey.dispose();
    _weatherCity.dispose();
    super.dispose();
  }

  // Build config objects from the current field text (the port falls back to
  // 22 if it isn't a number). These read the controllers; they don't save.
  SshConfig _currentConfig() => SshConfig(
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 22,
        username: _username.text.trim(),
        password: _password.text,
        commandTemplate: _command.text.trim(),
        stopCommandTemplate: _stopCommand.text.trim(),
      );

  WeatherConfig _currentWeatherConfig() => WeatherConfig(
        apiKey: _weatherApiKey.text.trim(),
        city: _weatherCity.text.trim(),
      );

  /// Save button: validate the required fields, persist both configs, confirm.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    await appState.updateConfig(_currentConfig());
    await appState.updateWeatherConfig(_currentWeatherConfig());
    // After an await the widget may be gone; guard before touching context.
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  /// Saves just the weather config; updateWeatherConfig() itself triggers the
  /// fetch when complete, so here we only report what's happening.
  Future<void> _saveAndRefreshWeather() async {
    final cfg = _currentWeatherConfig();
    await context.read<AppState>().updateWeatherConfig(cfg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cfg.isComplete
            ? 'Fetching weather for ${cfg.city}…'
            : 'Enter both an API key and a city.'),
      ),
    );
  }

  /// Test-connection button: persist current values, run `echo ok` over SSH,
  /// and show the result. `_testing` drives the button's spinner.
  Future<void> _test() async {
    setState(() => _testing = true);
    final appState = context.read<AppState>();
    // Save first so the test uses the latest values.
    await appState.updateConfig(_currentConfig());
    final result = await appState.testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Connected to the Pi successfully'
            : 'Connection failed: ${result.error}'),
        backgroundColor: result.success ? Colors.green.shade700 : null,
      ),
    );
  }

  /// Decoration for an obscurable field with a show/hide toggle.
  InputDecoration _obscuredField(
          String label, bool obscured, VoidCallback onToggle) =>
      InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(obscured ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pumps = context.watch<AppState>().pumps;
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ScrollConfiguration(
          behavior: const NoStretchScrollBehavior(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // --- Section 1: Raspberry Pi connection (host/port/user/password) ---
              _SettingsSection(
                icon: Icons.dns_outlined,
                title: 'Raspberry Pi connection',
                children: [
                  // Host takes the slack; the port sits narrow beside it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _host,
                          decoration: const InputDecoration(
                            labelText: 'Host, IP or Tailscale name',
                            hintText: '192.168.1.50 or my-pi.tailnet.ts.net',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lan_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _port,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'pi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: _obscuredField('Password', _obscure,
                        () => setState(() => _obscure = !_obscure)),
                  ),
                ],
              ),
              // --- Section 2: the command template + Test/Save actions ---
              _SettingsSection(
                icon: Icons.terminal,
                title: 'Watering command',
                subtitle:
                    'Run on the Pi for each pump. Use {pin} for the GPIO pin '
                    'and {duration} for the seconds.',
                children: [
                  TextFormField(
                    controller: _command,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Command template',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Run on the Pi to stop a pump early. Use {pin} for the '
                    'GPIO pin.',
                    style: hintStyle,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stopCommand,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Stop command template',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _test,
                          icon: _testing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: const Text('Test'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // --- Section 3: weather (API key + city) + save-and-fetch ---
              _SettingsSection(
                icon: Icons.cloud_outlined,
                title: 'Weather',
                subtitle:
                    'Shows current conditions and a watering hint. Get a free '
                    'API key at openweathermap.org.',
                children: [
                  TextFormField(
                    controller: _weatherApiKey,
                    obscureText: _obscureApiKey,
                    decoration: _obscuredField(
                        'OpenWeather API key',
                        _obscureApiKey,
                        () =>
                            setState(() => _obscureApiKey = !_obscureApiKey)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weatherCity,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      hintText: 'Munich,DE',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saveAndRefreshWeather,
                      icon: const Icon(Icons.cloud_sync),
                      label: const Text('Save & fetch weather'),
                    ),
                  ),
                ],
              ),
              // --- Section 4: one editable row per pump (name + GPIO pin) ---
              _SettingsSection(
                icon: Icons.water_drop_outlined,
                title: 'Pumps',
                subtitle: 'Name each pump and set its GPIO pin. '
                    'Changes save automatically.',
                children: [
                  for (var i = 0; i < pumps.length; i++)
                    _PumpSettingsTile(pump: pumps[i], index: i + 1),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled card grouping a set of related settings fields, with an icon
/// badge and an optional explanatory subtitle.
class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SettingsSection({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Editable name + GPIO pin for a single pump. Unlike the connection fields,
/// these write through to AppState on every keystroke (onChanged), so there's
/// no separate save step for pump edits.
class _PumpSettingsTile extends StatelessWidget {
  final Pump pump;
  final int index;
  const _PumpSettingsTile({required this.pump, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Small number badge so the rows read as an ordered list of pumps.
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: pump.name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  context.read<AppState>().updatePump(pump.copyWith(name: v)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: pump.gpioPin.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'GPIO pin',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                // Ignore non-numeric input; only commit a valid pin.
                final pin = int.tryParse(v);
                if (pin != null) {
                  context
                      .read<AppState>()
                      .updatePump(pump.copyWith(gpioPin: pin));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
