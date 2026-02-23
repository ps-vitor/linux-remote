import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/ssh_service.dart';
import 'terminal_screen.dart';

class RemoteScreen extends StatefulWidget {
  final SshService ssh;
  const RemoteScreen({super.key, required this.ssh});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Uint8List? _screenshot;
  Timer? _screenTimer;
  bool _mirroring = false;
  String _volume = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchVolume();
  }

  Future<void> _fetchVolume() async {
    try {
      final vol = await widget.ssh.getVolume();
      if (mounted) setState(() => _volume = vol);
    } catch (_) {}
  }

  Future<void> _exec(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _toggleMirror() {
    if (_mirroring) {
      _screenTimer?.cancel();
      setState(() {
        _mirroring = false;
        _screenshot = null;
      });
    } else {
      setState(() => _mirroring = true);
      _captureLoop();
    }
  }

  Future<void> _captureLoop() async {
    while (_mirroring && mounted) {
      try {
        final data = await widget.ssh.captureScreen();
        if (mounted && _mirroring && data != null) {
          setState(() => _screenshot = data);
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void _confirmShutdown() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desligar'),
        content: const Text('Escolha uma ação:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exec(widget.ssh.suspend);
            },
            child: const Text('Suspender'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exec(widget.ssh.reboot);
            },
            child: const Text('Reiniciar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exec(widget.ssh.shutdown);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Desligar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _screenTimer?.cancel();
    _mirroring = false;
    _tabController.dispose();
    widget.ssh.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle Remoto'),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () {
            widget.ssh.disconnect();
            Navigator.of(context).pop();
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.gamepad), text: 'Controle'),
            Tab(icon: Icon(Icons.volume_up), text: 'Mídia'),
            Tab(icon: Icon(Icons.screen_share), text: 'Tela'),
            Tab(icon: Icon(Icons.terminal), text: 'Terminal'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildControlTab(),
          _buildMediaTab(),
          _buildScreenTab(),
          TerminalScreen(ssh: widget.ssh),
        ],
      ),
    );
  }

  Widget _buildControlTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Arrow keys
          _arrowButton(Icons.keyboard_arrow_up, widget.ssh.arrowUp),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _arrowButton(Icons.keyboard_arrow_left, widget.ssh.arrowLeft),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: () => _exec(widget.ssh.enter),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              _arrowButton(Icons.keyboard_arrow_right, widget.ssh.arrowRight),
            ],
          ),
          _arrowButton(Icons.keyboard_arrow_down, widget.ssh.arrowDown),
          const SizedBox(height: 32),
          // Super key & Shutdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionButton(
                Icons.window,
                'Super',
                () => _exec(widget.ssh.superKey),
              ),
              _actionButton(
                Icons.power_settings_new,
                'Energia',
                _confirmShutdown,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Volume
          const Icon(Icons.volume_up, size: 48, color: Colors.blueGrey),
          const SizedBox(height: 8),
          Text(
            _volume.isNotEmpty ? _volume : '--',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actionButton(Icons.volume_down, 'Vol -', () async {
                await _exec(widget.ssh.volumeDown);
                _fetchVolume();
              }),
              const SizedBox(width: 16),
              _actionButton(Icons.volume_off, 'Mudo', () async {
                await _exec(widget.ssh.toggleMute);
                _fetchVolume();
              }),
              const SizedBox(width: 16),
              _actionButton(Icons.volume_up, 'Vol +', () async {
                await _exec(widget.ssh.volumeUp);
                _fetchVolume();
              }),
            ],
          ),
          const SizedBox(height: 40),
          // Playback
          const Icon(Icons.music_note, size: 48, color: Colors.blueGrey),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actionButton(Icons.skip_previous, 'Anterior',
                  () => _exec(widget.ssh.prevTrack)),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                height: 80,
                child: ElevatedButton(
                  onPressed: () => _exec(widget.ssh.playPause),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.play_arrow, size: 36),
                ),
              ),
              const SizedBox(width: 16),
              _actionButton(Icons.skip_next, 'Próxima',
                  () => _exec(widget.ssh.nextTrack)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _toggleMirror,
            icon: Icon(_mirroring ? Icons.stop : Icons.screen_share),
            label: Text(_mirroring ? 'Parar espelhamento' : 'Iniciar espelhamento'),
          ),
        ),
        if (_mirroring && _screenshot == null)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_screenshot != null)
          Expanded(
            child: InteractiveViewer(
              child: Image.memory(
                _screenshot!,
                gaplessPlayback: true,
                fit: BoxFit.contain,
              ),
            ),
          ),
        if (!_mirroring && _screenshot == null)
          const Expanded(
            child: Center(
              child: Text(
                'Espelhamento de tela via screenshots SSH\n'
                '(requer grim ou scrot no PC)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _arrowButton(IconData icon, Future<void> Function() action) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 64,
        height: 64,
        child: ElevatedButton(
          onPressed: () => _exec(action),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Icon(icon, size: 32),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed,
      {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.zero,
              backgroundColor: color,
            ),
            child: Icon(icon, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
