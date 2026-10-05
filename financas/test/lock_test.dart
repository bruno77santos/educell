import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:financas/app.dart';
import 'package:financas/data/database.dart';
import 'package:financas/security/lock_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.widgetWithText(FilledButton, d));
    await tester.pump();
  }
  await settle(tester);
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('cria PIN no primeiro uso, bloqueia e desbloqueia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});

    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(() => tester.runAsync(db.close));
    final lock = LockController();
    await tester.runAsync(lock.init);
    expect(lock.hasPin, isFalse);

    await tester.pumpWidget(FinancasApp(database: db, lock: lock));
    await settle(tester);
    expect(find.text('Proteja suas finanças'), findsOneWidget);

    await typePin(tester, '1234');
    expect(find.text('Confirme o PIN'), findsOneWidget);
    await typePin(tester, '1299');
    expect(find.text('Os PINs não conferem. Tente de novo.'), findsOneWidget);

    await typePin(tester, '1234');
    await typePin(tester, '1234');
    expect(lock.hasPin, isTrue);
    expect(lock.locked, isFalse);
    expect(find.text('Saldo em conta hoje'), findsOneWidget);

    lock.lock();
    await settle(tester);
    expect(find.text('Digite seu PIN'), findsOneWidget);

    await typePin(tester, '0000');
    expect(find.text('PIN incorreto'), findsOneWidget);
    expect(lock.locked, isTrue);

    await typePin(tester, '1234');
    expect(lock.locked, isFalse);
    expect(find.text('Digite seu PIN'), findsNothing);
  });

  test('bloqueia por 30 s após 5 PINs errados', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    final lock = LockController();
    await lock.setPin('4321');
    lock.lock();
    for (var i = 0; i < LockController.maxAttempts; i++) {
      expect(await lock.unlockWithPin('0000'), isFalse);
    }
    expect(lock.isLockedOut, isTrue);
    // Nem o PIN correto funciona durante o bloqueio.
    expect(await lock.unlockWithPin('4321'), isFalse);
  });
}
