import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../session.dart';

/// Staff-facing message for an API error (or any other failure).
String errorText(BuildContext context, Object e) => S.of(context).error(e);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _emailKey = 'lt_staff_email';
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _remember = true;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // "Remember me" keeps only the e-mail on this device; the session itself lives in the secure keystore.
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString(_emailKey);
      if (saved != null && mounted && _email.text.isEmpty) setState(() => _email.text = saved);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    setState(() => (_busy = true, _error = null));
    try {
      await context.read<Session>().login(email, _password.text);
      final p = await SharedPreferences.getInstance();
      _remember ? await p.setString(_emailKey, email) : await p.remove(_emailKey);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgot() {
    final t = S.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_reset, color: Brand.tomato, size: 32),
        title: Text(t.t('forgotPassword')),
        content: Text(t.t('forgotBody')),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t.t('ok')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final s = context.watch<Session>();
    final width = MediaQuery.sizeOf(context).width;
    InputDecoration field(String label, IconData icon, {Widget? suffix}) => InputDecoration(
          labelText: label,
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 6), child: Icon(icon, color: Brand.charcoal)),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Brand.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Brand.border)),
        );
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F5),
      body: Stack(children: [
        // Watercolour header (Colosseum, tomatoes, basil) fading into the page.
        Positioned(
          top: 0,
          right: 0,
          width: width,
          height: width * 0.9,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.55, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: Image.asset('assets/images/login-header.jpg', fit: BoxFit.cover, alignment: Alignment.centerRight),
          ),
        ),
        SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
            Align(
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [ButtonSegment(value: 'es', label: Text('ES')), ButtonSegment(value: 'en', label: Text('EN'))],
                  selected: {s.lang},
                  onSelectionChanged: (v) => context.read<Session>().setLang(v.first),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset('assets/images/logo.png', height: 92, filterQuality: FilterQuality.medium, semanticLabel: 'La Toscana Pizzería'),
            ),
            const SizedBox(height: 10),
            Text(t.t('adminTagline'), style: const TextStyle(letterSpacing: 6, fontSize: 13, fontWeight: FontWeight.w600, color: Brand.charcoal)),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 44, height: 3, decoration: BoxDecoration(color: Brand.tomato, borderRadius: BorderRadius.circular(2))),
            ),
            SizedBox(height: width * 0.16),
            Text(t.t('signInTitle'), style: const TextStyle(fontFamily: 'Playfair', fontSize: 36, fontWeight: FontWeight.w700, color: Brand.charcoal, height: 1.1)),
            const SizedBox(height: 10),
            Text(t.t('signInBody'), style: const TextStyle(fontSize: 16, color: Brand.muted, height: 1.45)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Brand.border.withValues(alpha: 0.6)),
                boxShadow: const [BoxShadow(color: Color(0x142A1A0A), blurRadius: 30, offset: Offset(0, 10))],
              ),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Brand.tomatoDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Brand.tomatoDark))),
                      ]),
                    ),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: field(t.t('email'), Icons.mail_outline),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: field(
                      t.t('password'),
                      Icons.lock_outline,
                      suffix: IconButton(
                        tooltip: t.t(_obscure ? 'showPassword' : 'hidePassword'),
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Wrap: side by side when there is room, "forgot" drops to its own line on narrow screens / large text.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // The whole "☑ Remember me" area is one tap target, announced as a checkbox.
                      MergeSemantics(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _remember = !_remember),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true), activeColor: Brand.tomato),
                              Text(t.t('rememberMe')),
                            ]),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _forgot,
                        style: TextButton.styleFrom(foregroundColor: Brand.tomato, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: Text(t.t('forgotPassword'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Brand.tomato.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Row(children: [
                              const SizedBox(width: 24),
                              Expanded(child: Text(t.t('signInTitle'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17))),
                              const Icon(Icons.arrow_forward),
                            ]),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 28),
            Text(t.t('footer'), textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  /// [forced]: shown instead of the app until a temporary password is changed; otherwise opened from "More".
  const ChangePasswordScreen({super.key, this.forced = true});
  final bool forced;
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
    if (n.length < 10 || !RegExp(r'[A-Za-z]').hasMatch(n) || !RegExp(r'\d').hasMatch(n)) return setState(() => _error = S.of(context).t('passwordRule'));
    if (n != _repeat.text) return setState(() => _error = S.of(context).t('passwordsDiffer'));
    setState(() => (_busy = true, _error = null));
    try {
      await context.read<Session>().changePassword(_current.text, n);
      if (!widget.forced && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t(widget.forced ? 'newPassword' : 'changePassword')),
        actions: [if (widget.forced) TextButton(onPressed: () => context.read<Session>().logout(), child: Text(t.t('signOutShort')))],
      ),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (widget.forced) Text(t.t('changeTempPassword'), style: TextStyle(color: Brand.muted)),
        const SizedBox(height: 16),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Brand.tomatoDark))),
        TextField(controller: _current, obscureText: true, decoration: InputDecoration(labelText: t.t('currentPassword'))),
        const SizedBox(height: 12),
        TextField(controller: _next, obscureText: true, decoration: InputDecoration(labelText: t.t('newPassword'), helperText: t.t('passwordRule'))),
        const SizedBox(height: 12),
        TextField(controller: _repeat, obscureText: true, decoration: InputDecoration(labelText: t.t('repeatPassword'))),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(t.t('save'))),
      ]),
    );
  }
}
