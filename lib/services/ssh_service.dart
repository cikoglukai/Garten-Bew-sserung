import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_config.dart';

/// Result of running a command on the Pi.
///
/// [success] is true only on exit code 0. [output] is trimmed stdout; [error]
/// carries stderr (or a connection/exit-code message) when something failed.
class SshResult {
  final bool success;
  final String output;
  final String error;

  SshResult({required this.success, this.output = '', this.error = ''});
}

/// Thin wrapper around dartssh2 that opens a connection, runs a single
/// command, and tears the connection down again.
class SshService {
  /// Opens a connection and runs [command]. The connection is closed before
  /// returning so each action is self-contained.
  ///
  /// [registerCancel], if given, is invoked once the command is running with a
  /// callback that tears the connection down. Calling it aborts the in-flight
  /// command so `run` returns promptly instead of waiting out [timeout] — used
  /// to stop a long watering early.
  static Future<SshResult> run(
    SshConfig config,
    String command, {
    Duration timeout = const Duration(seconds: 120),
    void Function(void Function() cancel)? registerCancel,
  }) async {
    // Declared outside the try so the finally block can always close them,
    // even if connecting throws partway through.
    SSHClient? client;
    SSHSocket? socket;
    try {
      // 1. Open the TCP socket (short, fixed timeout — this is just reachability).
      socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 10),
      );

      // 2. Authenticate with password auth, supplying the saved password.
      client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => config.password,
      );

      // 3. Run the command and collect stdout/stderr bytes as they stream in.
      final session = await client.execute(command);

      // Hand the caller a way to abort this session. Closing the connection
      // makes the `session.done` await below throw, which the catch turns into
      // a failure result — the caller decides what that means.
      registerCancel?.call(() {
        client?.close();
        socket?.close();
      });
      final stdout = <int>[];
      final stderr = <int>[];
      session.stdout.listen(stdout.addAll);
      session.stderr.listen(stderr.addAll);

      // 4. Wait for it to finish (bounded by [timeout], which the caller sizes
      //    to the watering duration), then read the exit code.
      await session.done.timeout(timeout);
      final code = session.exitCode ?? -1;

      final stderrText = utf8.decode(stderr, allowMalformed: true).trim();
      return SshResult(
        success: code == 0,
        output: utf8.decode(stdout, allowMalformed: true).trim(),
        // On failure prefer stderr; fall back to a generic exit-code message.
        error: code == 0
            ? ''
            : (stderrText.isEmpty
                ? 'Command exited with code $code'
                : stderrText),
      );
    } catch (e) {
      // Any connect/auth/timeout failure becomes a friendly result, never an
      // exception the UI has to catch.
      return SshResult(success: false, error: e.toString());
    } finally {
      // Always release the connection, success or not.
      client?.close();
      socket?.close();
    }
  }

  /// Opens a connection and runs `echo ok` to confirm the credentials and
  /// host are reachable. Used by the "Test connection" button in Settings.
  static Future<SshResult> testConnection(SshConfig config) {
    return run(config, 'echo ok', timeout: const Duration(seconds: 15));
  }
}
