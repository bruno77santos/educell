import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:financas/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Future<int> categoryId(EntryType type) async =>
      (await db.watchCategories(type: type).first).first.id;

  Future<CreditCard> addCard() async {
    await db.saveCard(
      CreditCardsCompanion.insert(
        name: 'Nubank',
        limitCents: 500000,
        closingDay: 3,
        dueDay: 10,
        color: 0xFF8E24AA,
      ),
    );
    return (await db.watchCards().first).single;
  }

  test('cria categorias padrão', () async {
    expect(await db.watchCategories(type: EntryType.expense).first, isNotEmpty);
    expect(await db.watchCategories(type: EntryType.income).first, isNotEmpty);
  });

  test('parcelado fora do cartão gera uma parcela por mês', () async {
    await db.addEntry(
      description: 'Curso',
      totalCents: 30000,
      type: EntryType.expense,
      categoryId: await categoryId(EntryType.expense),
      date: DateTime(2026, 1, 31),
      installments: 3,
    );
    final feb = await db.watchEntriesOfMonth(DateTime(2026, 2)).first;
    expect(feb.single.entry.date, DateTime(2026, 2, 28));
    expect(feb.single.entry.installmentNumber, 2);
    expect(feb.single.entry.amountCents, 10000);
  });

  test('compra parcelada no cartão cai nas faturas certas', () async {
    final card = await addCard();
    await db.addEntry(
      description: 'Notebook',
      totalCents: 100000,
      type: EntryType.expense,
      categoryId: await categoryId(EntryType.expense),
      date: DateTime(2026, 10, 5), // depois do fechamento (dia 3)
      card: card,
      installments: 10,
    );
    expect(await db.watchEntriesOfMonth(DateTime(2026, 10)).first, isEmpty);
    final nov = await db.watchEntriesOfMonth(DateTime(2026, 11)).first;
    expect(nov.single.entry.installmentNumber, 1);
    final last = await db.watchEntriesOfMonth(DateTime(2027, 8)).first;
    expect(last.single.entry.installmentNumber, 10);

    // Todo o valor futuro ocupa o limite.
    var s = (await db.watchCardSummaries(DateTime(2026, 11)).first).single;
    expect(s.usedCents, 100000);
    expect(s.availableCents, 400000);
    expect(s.invoiceTotalCents, 10000);

    await db.payInvoice(
      cardId: card.id,
      invoiceMonth: DateTime(2026, 11),
      amountCents: 10000,
      paidAt: DateTime(2026, 11, 10),
    );
    s = (await db.watchCardSummaries(DateTime(2026, 11)).first).single;
    expect(s.invoicePaid, isTrue);
    expect(s.usedCents, 90000);
  });

  test(
    'saldo considera conta e faturas pagas, não compras no cartão',
    () async {
      final card = await addCard();
      await db.addEntry(
        description: 'Salário',
        totalCents: 500000,
        type: EntryType.income,
        categoryId: await categoryId(EntryType.income),
        date: DateTime(2026, 10, 1),
      );
      await db.addEntry(
        description: 'Mercado',
        totalCents: 20000,
        type: EntryType.expense,
        categoryId: await categoryId(EntryType.expense),
        date: DateTime(2026, 10, 2),
      );
      await db.addEntry(
        description: 'Tênis',
        totalCents: 30000,
        type: EntryType.expense,
        categoryId: await categoryId(EntryType.expense),
        date: DateTime(2026, 10, 2),
        card: card,
      );
      expect(await db.watchBalance(DateTime(2026, 10, 31)).first, 480000);
      await db.payInvoice(
        cardId: card.id,
        invoiceMonth: DateTime(2026, 10),
        amountCents: 30000,
        paidAt: DateTime(2026, 10, 10),
      );
      expect(await db.watchBalance(DateTime(2026, 10, 31)).first, 450000);
      // Lançamentos futuros não entram no saldo de hoje.
      expect(await db.watchBalance(DateTime(2026, 9, 30)).first, 0);
    },
  );

  test('excluir parcelas a partir de uma delas', () async {
    await db.addEntry(
      description: 'Academia',
      totalCents: 60000,
      type: EntryType.expense,
      categoryId: await categoryId(EntryType.expense),
      date: DateTime(2026, 1, 10),
      installments: 6,
    );
    final mar = (await db.watchEntriesOfMonth(DateTime(2026, 3)).first).single;
    await db.deleteInstallments(mar.entry.groupId!, fromInstallment: 3);
    final totals = await db.watchMonthlyTotals(DateTime(2026, 6), 6).first;
    expect(totals.map((t) => t.expenseCents), [10000, 10000, 0, 0, 0, 0]);
  });

  test('orçamento por categoria', () async {
    final cat = await categoryId(EntryType.expense);
    await db.setBudget(cat, 50000);
    await db.addEntry(
      description: 'Jantar',
      totalCents: 45000,
      type: EntryType.expense,
      categoryId: cat,
      date: DateTime(2026, 10, 2),
    );
    final b = (await db.watchBudgetProgress(DateTime(2026, 10)).first)
        .firstWhere((b) => b.category.id == cat);
    expect(b.limitCents, 50000);
    expect(b.spentCents, 45000);
    expect(b.ratio, closeTo(0.9, 0.001));
    await db.setBudget(cat, null);
    final removed = (await db.watchBudgetProgress(DateTime(2026, 10)).first)
        .firstWhere((b) => b.category.id == cat);
    expect(removed.hasBudget, isFalse);
  });

  test('categoria usada é arquivada em vez de excluída', () async {
    final cat = await categoryId(EntryType.expense);
    await db.addEntry(
      description: 'X',
      totalCents: 100,
      type: EntryType.expense,
      categoryId: cat,
      date: DateTime(2026, 10, 2),
    );
    expect(await db.deleteOrArchiveCategory(cat), isTrue);
    final cats = await db.watchCategories(type: EntryType.expense).first;
    expect(cats.any((c) => c.id == cat), isFalse);
  });

  test('metas não ficam negativas', () async {
    await db.saveGoal(
      GoalsCompanion.insert(
        name: 'Viagem',
        targetCents: 100000,
        color: 0xFF1E88E5,
        savedCents: const Value(5000),
      ),
    );
    final g = (await db.watchGoals().first).single;
    await db.adjustGoal(g.id, -9000);
    expect((await db.watchGoals().first).single.savedCents, 0);
  });
}
