import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:financas/app.dart';
import 'package:financas/data/database.dart';
import 'package:financas/security/lock_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Deixa o banco (assíncrono de verdade) responder entre os frames; o
/// pumpAndSettle não serve porque os indicadores de carregamento giram.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('navega pelas abas e lança uma compra parcelada no cartão', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(() => tester.runAsync(db.close));
    await tester.runAsync(
      () => db.saveCard(
        CreditCardsCompanion.insert(
          name: 'Nubank',
          limitCents: 500000,
          closingDay: 3,
          dueDay: 10,
          color: 0xFF8E24AA,
        ),
      ),
    );
    final lock = LockController()
      ..initialized = true
      ..hasPin = true
      ..locked = false;

    await tester.pumpWidget(FinancasApp(database: db, lock: lock));
    await settle(tester);
    expect(find.text('Saldo em conta hoje'), findsOneWidget);

    // Novo lançamento: R$ 1.200,00 em 12x no cartão.
    await tester.tap(find.byTooltip('Novo lançamento').first);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '120000');
    await tester.enterText(find.byType(TextFormField).at(1), 'Celular');

    await tester.tap(find.text('Categoria'));
    await settle(tester);
    await tester.tap(find.text('Compras').last);
    await settle(tester);

    await tester.tap(find.text('Conta / dinheiro / Pix'));
    await settle(tester);
    await tester.tap(find.text('Nubank').last);
    await settle(tester);

    await tester.tap(find.text('À vista'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('12x').last,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('12x').last);
    await settle(tester);
    expect(find.textContaining('12x de R\$'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await settle(tester);
    expect(find.text('Novo lançamento'), findsNothing);

    final all = (await tester.runAsync(() => db.select(db.entries).get()))!;
    expect(all, hasLength(12));
    expect(all.every((e) => e.amountCents == 10000), isTrue);

    for (final tab in ['Lançamentos', 'Cartões', 'Relatórios', 'Mais']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
    }
    await tester.tap(find.text('Metas'));
    await settle(tester);
    expect(find.text('Nova meta'), findsOneWidget);

    // Bloquear mostra a tela de PIN.
    lock.lock();
    await settle(tester);
    expect(find.text('Digite seu PIN'), findsOneWidget);
  });
}
