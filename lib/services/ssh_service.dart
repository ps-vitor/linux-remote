import 'dart:async';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

class SshService {
  SSHClient? _client;
  bool _connected = false;

  bool get isConnected => _connected;

  Future<void> connect({
    required String host,
    int port = 22,
    required String username,
    required String password,
  }) async {
    final socket = await SSHSocket.connect(host, port);
    _client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
    );
    await _client!.authenticated;
    _connected = true;
  }

  Future<String> runCommand(String command) async {
    if (_client == null || !_connected) {
      throw Exception('Not connected');
    }
    final session = await _client!.execute(command);
    final stdout = StringBuffer();
    await session.stdout
        .map((data) => String.fromCharCodes(data))
        .forEach(stdout.write);
    session.close();
    return stdout.toString().trim();
  }

  // Volume controls (PulseAudio/PipeWire via pactl)
  Future<void> volumeUp() => runCommand(
      'pactl set-sink-volume @DEFAULT_SINK@ +5%');

  Future<void> volumeDown() => runCommand(
      'pactl set-sink-volume @DEFAULT_SINK@ -5%');

  Future<void> toggleMute() => runCommand(
      'pactl set-sink-mute @DEFAULT_SINK@ toggle');

  Future<String> getVolume() => runCommand(
      "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+%' | head -1");

  // Media controls (via xdotool)
  Future<void> playPause() => _sendKey('XF86AudioPlay');
  Future<void> nextTrack() => _sendKey('XF86AudioNext');
  Future<void> prevTrack() => _sendKey('XF86AudioPrev');

  // Arrow keys
  Future<void> arrowUp() => _sendKey('Up');
  Future<void> arrowDown() => _sendKey('Down');
  Future<void> arrowLeft() => _sendKey('Left');
  Future<void> arrowRight() => _sendKey('Right');
  Future<void> enter() => _sendKey('Return');

  // Super key
  Future<void> superKey() => _sendKey('Super_L');

  // Shutdown / Suspend
  Future<void> shutdown() => runCommand('systemctl poweroff');
  Future<void> suspend() => runCommand('systemctl suspend');
  Future<void> reboot() => runCommand('systemctl reboot');

  Future<void> _sendKey(String key) async {
    // Try xdotool first, fall back to ydotool for Wayland
    await runCommand(
      'export DISPLAY=:0; xdotool key $key 2>/dev/null || '
      'ydotool key ${_ydotoolKeycode(key)}',
    );
  }

  String _ydotoolKeycode(String xKey) {
    // Map X11 key names to Linux keycodes for ydotool
    const map = {
      'Up': '103:1 103:0',
      'Down': '108:1 108:0',
      'Left': '105:1 105:0',
      'Right': '106:1 106:0',
      'Return': '28:1 28:0',
      'Super_L': '125:1 125:0',
      'XF86AudioPlay': '164:1 164:0',
      'XF86AudioNext': '163:1 163:0',
      'XF86AudioPrev': '165:1 165:0',
    };
    return map[xKey] ?? xKey;
  }

  // Screen capture - takes a screenshot via SSH and returns the bytes
  Future<Uint8List?> captureScreen() async {
    if (_client == null || !_connected) return null;
    try {
      // Use grim (Wayland) or scrot/import (X11) to capture to stdout
      final session = await _client!.execute(
        'export DISPLAY=:0; '
        '(grim -t jpeg -q 50 - 2>/dev/null || '
        'scrot -o /tmp/.linux_remote_cap.jpg && cat /tmp/.linux_remote_cap.jpg)',
      );
      final chunks = <int>[];
      await session.stdout.forEach((data) => chunks.addAll(data));
      session.close();
      if (chunks.isEmpty) return null;
      return Uint8List.fromList(chunks);
    } catch (_) {
      return null;
    }
  }

  // Interactive shell session for terminal use
  Future<SSHSession> openShell() async {
    if (_client == null || !_connected) {
      throw Exception('Not connected');
    }
    final shell = await _client!.shell(
      pty: SSHPtyConfig(
        width: 80,
        height: 24,
      ),
    );
    return shell;
  }

  void disconnect() {
    _client?.close();
    _client = null;
    _connected = false;
  }
}
