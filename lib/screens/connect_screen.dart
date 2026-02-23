import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ssh_service.dart';
import 'remote_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _connecting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _hostController.text = prefs.getString('ssh_host') ?? '';
    _portController.text = prefs.getString('ssh_port') ?? '22';
    _userController.text = prefs.getString('ssh_user') ?? '';
    _passController.text = prefs.getString('ssh_pass') ?? '';
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssh_host', _hostController.text);
    await prefs.setString('ssh_port', _portController.text);
    await prefs.setString('ssh_user', _userController.text);
    await prefs.setString('ssh_pass', _passController.text);
  }

  Future<void> _connect() async {
    if (_hostController.text.isEmpty ||
        _userController.text.isEmpty ||
        _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos')),
      );
      return;
    }

    setState(() => _connecting = true);

    final ssh = SshService();
    try {
      await ssh.connect(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text) ?? 22,
        username: _userController.text.trim(),
        password: _passController.text,
      );
      await _save();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RemoteScreen(ssh: ssh)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Linux Remote')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            const Icon(Icons.computer, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 24),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host / IP',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Porta',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: 'Usuário',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _connecting ? null : _connect,
                icon: _connecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(_connecting ? 'Conectando...' : 'Conectar'),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
