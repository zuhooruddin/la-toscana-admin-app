import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../session.dart';

String errorText(Object e) {
  if (e is! ApiException) return 'Ha ocurrido un error.';
  return const {
        'NETWORK': 'No se ha podido conectar con el servidor.',
        'INVALID_CREDENTIALS': 'Correo o contraseña incorrectos.',
        'ACCOUNT_LOCKED': 'Cuenta bloqueada temporalmente. Inténtalo más tarde.',
        'RATE_LIMITED': 'Demasiados intentos. Espera un minuto.',
        'NOT_STAFF': 'Esta cuenta no es del equipo. Los repartidores usan la app de reparto.',
        'WEAK_PASSWORD': 'Mínimo 10 caracteres, con letras y números.',
        'FORBIDDEN': 'No tienes permiso para esta acción.',
        'INVALID_TRANSITION': 'Ese cambio de estado ya no es posible.',
        'REASON_REQUIRED': 'Indica el motivo.',
      }[e.code] ??
      e.message;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => (_busy = true, _error = null));
    try {
      await context.read<Session>().login(_email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 40),
          const Icon(Icons.local_pizza, size: 56, color: Brand.tomato),
          const SizedBox(height: 12),
          const Text('La Toscana · Gestión', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Acceso para el equipo', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted)),
          const SizedBox(height: 28),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Brand.tomatoDark))),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Correo electrónico')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'Contraseña'), onSubmitted: (_) => _submit()),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Entrar')),
        ]),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final n = _next.text;
    if (n.length < 10 || !RegExp(r'[A-Za-z]').hasMatch(n) || !RegExp(r'\d').hasMatch(n)) return setState(() => _error = 'Mínimo 10 caracteres, con letras y números.');
    if (n != _repeat.text) return setState(() => _error = 'Las contraseñas no coinciden.');
    setState(() => (_busy = true, _error = null));
    try {
      await context.read<Session>().changePassword(_current.text, n);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña'), actions: [TextButton(onPressed: () => context.read<Session>().logout(), child: const Text('Salir'))]),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Por seguridad, cambia tu contraseña temporal antes de empezar.', style: TextStyle(color: Brand.muted)),
        const SizedBox(height: 16),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Brand.tomatoDark))),
        TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual')),
        const SizedBox(height: 12),
        TextField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña', helperText: 'Mínimo 10 caracteres, con letras y números.')),
        const SizedBox(height: 12),
        TextField(controller: _repeat, obscureText: true, decoration: const InputDecoration(labelText: 'Repite la nueva contraseña')),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Guardar')),
      ]),
    );
  }
}
