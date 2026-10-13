import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tokens = TokenStore();
  final session = Session(Api(tokens), tokens);
  session.init();
  runApp(ChangeNotifierProvider.value(value: session, child: const AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    final lang = context.select<Session, String>((s) => s.lang);
    return MaterialApp(
      onGenerateTitle: (context) => S.of(context).t('appTitle'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [SDelegate(), GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (!s.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (s.me == null) return const LoginScreen();
    if (s.me!.mustChangePassword) return const ChangePasswordScreen();
    return const HomeScreen();
  }
}
