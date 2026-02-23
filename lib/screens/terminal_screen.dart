import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import '../services/ssh_service.dart';

class TerminalScreen extends StatefulWidget {
  final SshService ssh;
  const TerminalScreen({super.key, required this.ssh});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with AutomaticKeepAliveClientMixin {
  final _terminal = Terminal(maxLines: 10000);
  SSHSession? _shell;
  bool _ready = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startShell();
  }

  Future<void> _startShell() async {
    try {
      _shell = await widget.ssh.openShell();

      _terminal.onOutput = (data) {
        _shell?.write(utf8.encode(data));
      };

      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _shell?.resizeTerminal(width, height);
      };

      _shell!.stdout.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      _shell!.stderr.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      _shell!.done.then((_) {
        if (mounted) {
          _terminal.write('\r\n[Sessão encerrada]\r\n');
        }
      });

      setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        _terminal.write('Erro ao abrir shell: $e\r\n');
        setState(() => _ready = true);
      }
    }
  }

  @override
  void dispose() {
    _shell?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return TerminalView(
      _terminal,
      autofocus: true,
      hardwareKeyboardOnly: false,
    );
  }
}
