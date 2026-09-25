import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'presentation/state/financial_state_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Trava orientação vertical para interface mobile-first
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final notifier = FinancialStateNotifier();
  runApp(ChokinApp(notifier: notifier));
  notifier.initialize();
}

class ChokinApp extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const ChokinApp({super.key, required this.notifier});

  @override
  State<ChokinApp> createState() => _ChokinAppState();
}

class _ChokinAppState extends State<ChokinApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sempre que o app volta para o primeiro plano, busca notificações acumuladas
      widget.notifier.syncPendingNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chokin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainShellScreen(notifier: widget.notifier),
    );
  }
}
