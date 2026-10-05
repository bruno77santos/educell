import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/database.dart';
import 'security/lock_controller.dart';
import 'ui/home_shell.dart';
import 'ui/lock/lock_screens.dart';
import 'ui/widgets/common.dart';

class FinancasApp extends StatelessWidget {
  const FinancasApp({super.key, required this.database, required this.lock});

  final AppDatabase database;
  final LockController lock;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00897B);
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<LockController>.value(value: lock),
        ChangeNotifierProvider(create: (_) => SelectedMonth()),
      ],
      child: MaterialApp(
        title: 'Minhas Finanças',
        debugShowCheckedModeBanner: false,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const HomeShell(),
        // O bloqueio fica acima do Navigator: nenhuma tela do app aparece
        // enquanto o PIN não for informado.
        builder: (context, child) => Consumer<LockController>(
          builder: (context, lock, _) => Stack(
            children: [
              child!,
              if (!lock.hasPin)
                _overlay('setup', const PinSetupScreen(firstRun: true))
              else if (lock.locked)
                _overlay('lock', const LockScreen()),
            ],
          ),
        ),
      ),
    );
  }

  /// As telas de bloqueio ficam fora do Navigator, então precisam do próprio
  /// Overlay (usado por tooltips e seleção de texto). A key garante um
  /// Overlay novo ao alternar entre cadastro de PIN e bloqueio.
  static Widget _overlay(String key, Widget screen) => Overlay(
    key: ValueKey(key),
    initialEntries: [OverlayEntry(builder: (_) => screen)],
  );
}
