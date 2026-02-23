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
  bool _mirroring = false;
  String _volume = '';
  String _nowPlaying = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchVolume();
    _fetchNowPlaying();
  }

  Future<void> _fetchVolume() async {
    try {
      final vol = await widget.ssh.getVolume();
      if (mounted) setState(() => _volume = vol);
    } catch (_) {}
  }

  Future<void> _fetchNowPlaying() async {
    try {
      final info = await widget.ssh.getNowPlaying();
      if (mounted) setState(() => _nowPlaying = info.isEmpty || info == ' - ' ? '' : info);
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
            Tab(icon: Icon(Icons.screen_share), text: 'Tela'),
            Tab(icon: Icon(Icons.terminal), text: 'Terminal'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildControlTab(),
          _buildScreenTab(),
          TerminalScreen(ssh: widget.ssh),
        ],
      ),
    );
  }

  Widget _buildControlTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final btnSize = constraints.maxHeight < 400 ? 44.0 : 52.0;
        final iconSize = constraints.maxHeight < 400 ? 24.0 : 28.0;
        final spacing = constraints.maxHeight < 400 ? 2.0 : 4.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Left: arrows + super/power
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _arrowButton(Icons.keyboard_arrow_up, widget.ssh.arrowUp, btnSize, iconSize, spacing),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _arrowButton(Icons.keyboard_arrow_left, widget.ssh.arrowLeft, btnSize, iconSize, spacing),
                              Padding(
                                padding: EdgeInsets.all(spacing + 2),
                                child: SizedBox(
                                  width: btnSize,
                                  height: btnSize,
                                  child: ElevatedButton(
                                    onPressed: () => _exec(widget.ssh.enter),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('OK', style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ),
                              _arrowButton(Icons.keyboard_arrow_right, widget.ssh.arrowRight, btnSize, iconSize, spacing),
                            ],
                          ),
                          _arrowButton(Icons.keyboard_arrow_down, widget.ssh.arrowDown, btnSize, iconSize, spacing),
                          SizedBox(height: spacing * 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _actionButton(Icons.window, 'Super',
                                  () => _exec(widget.ssh.superKey), btnSize, iconSize),
                              const SizedBox(width: 12),
                              _actionButton(Icons.power_settings_new, 'Energia',
                                  _confirmShutdown, btnSize, iconSize, color: Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Right: volume (vertical)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _actionButton(Icons.volume_up, 'Vol +', () async {
                            await _exec(widget.ssh.volumeUp);
                            _fetchVolume();
                          }, btnSize, iconSize),
                          const SizedBox(height: 6),
                          Text(
                            _volume.isNotEmpty ? _volume : '--',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          _actionButton(Icons.volume_off, 'Mudo', () async {
                            await _exec(widget.ssh.toggleMute);
                            _fetchVolume();
                          }, btnSize, iconSize),
                          const SizedBox(height: 6),
                          _actionButton(Icons.volume_down, 'Vol -', () async {
                            await _exec(widget.ssh.volumeDown);
                            _fetchVolume();
                          }, btnSize, iconSize),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Now playing + playback
              if (_nowPlaying.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _nowPlaying,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionButton(Icons.skip_previous, 'Anterior', () async {
                      await _exec(widget.ssh.prevTrack);
                      Future.delayed(const Duration(milliseconds: 500), _fetchNowPlaying);
                    }, btnSize, iconSize),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: btnSize + 12,
                      height: btnSize + 12,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _exec(widget.ssh.playPause);
                          Future.delayed(const Duration(milliseconds: 500), _fetchNowPlaying);
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(10),
                        ),
                        child: Icon(Icons.play_arrow, size: iconSize + 4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _actionButton(Icons.skip_next, 'Próxima', () async {
                      await _exec(widget.ssh.nextTrack);
                      Future.delayed(const Duration(milliseconds: 500), _fetchNowPlaying);
                    }, btnSize, iconSize),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
              minScale: 0.1,
              maxScale: 5.0,
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

  Widget _arrowButton(IconData icon, Future<void> Function() action,
      double size, double iconSz, double spacing) {
    return Padding(
      padding: EdgeInsets.all(spacing),
      child: SizedBox(
        width: size,
        height: size,
        child: ElevatedButton(
          onPressed: () => _exec(action),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Icon(icon, size: iconSz),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed,
      double size, double iconSz, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.zero,
              backgroundColor: color,
            ),
            child: Icon(icon, size: iconSz),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
