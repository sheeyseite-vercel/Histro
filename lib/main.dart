import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'ui/splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HistoApp());
}

class HistoApp extends StatefulWidget {
  const HistoApp({super.key});

  @override
  State<HistoApp> createState() => _HistoAppState();
}

class _HistoAppState extends State<HistoApp> {
  final AppState state = AppState();

  @override
  void initState() {
    super.initState();
    state.load();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'HISTO',
          debugShowCheckedModeBanner: false,
          locale: Locale(state.lang),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(state.lang),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
