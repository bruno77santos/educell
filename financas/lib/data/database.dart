import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/dates.dart';
import '../core/money.dart';

part 'database.g.dart';

enum EntryType { income, expense }

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get type => intEnum<EntryType>()();
  IntColumn get color => integer()();
  TextColumn get icon => text()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('CreditCard')
class CreditCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get limitCents => integer()();
  IntColumn get closingDay => integer()();
  IntColumn get dueDay => integer()();
  IntColumn get color => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Um lançamento (receita ou despesa). Compras parceladas geram um
/// lançamento por parcela, ligados pelo mesmo [groupId].
@DataClassName('Entry')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text().withLength(min: 1, max: 80)();
  IntColumn get amountCents => integer()();
  IntColumn get type => intEnum<EntryType>()();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// Data do lançamento. Para parcelas fora do cartão é a data de cada
  /// parcela; no cartão é a data da compra.
  DateTimeColumn get date => dateTime()();

  /// Mês (primeiro dia) em que o lançamento entra no resumo mensal. No cartão
  /// é o mês de vencimento da fatura da parcela.
  DateTimeColumn get refMonth => dateTime()();

  IntColumn get cardId => integer().nullable().references(CreditCards, #id)();
  TextColumn get groupId => text().nullable()();
  IntColumn get installmentNumber => integer().withDefault(const Constant(1))();
  IntColumn get installmentCount => integer().withDefault(const Constant(1))();
  TextColumn get note => text().nullable()();
}

/// Pagamentos de fatura. Saem do saldo da conta e liberam o limite do cartão,
/// mas não contam como despesa (as compras já foram contadas).
class InvoicePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId => integer().references(CreditCards, #id)();
  DateTimeColumn get invoiceMonth => dateTime()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get paidAt => dateTime()();
}

/// Orçamento mensal por categoria de despesa.
class Budgets extends Table {
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get limitCents => integer()();

  @override
  Set<Column> get primaryKey => {categoryId};
}

/// Metas de economia (ex.: "Viagem", "Reserva de emergência").
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get targetCents => integer()();
  IntColumn get savedCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  IntColumn get color => integer()();
}

class EntryDetails {
  EntryDetails(this.entry, this.category, this.card);

  final Entry entry;
  final Category category;
  final CreditCard? card;

  bool get isIncome => entry.type == EntryType.income;
  bool get isInstallment => entry.installmentCount > 1;

  /// Valor com sinal: positivo para receita, negativo para despesa.
  int get signedCents => isIncome ? entry.amountCents : -entry.amountCents;
}

class CardSummary {
  CardSummary({
    required this.card,
    required this.usedCents,
    required this.invoiceTotalCents,
    required this.invoicePaidCents,
  });

  final CreditCard card;

  /// Compras ainda não pagas (inclui parcelas futuras).
  final int usedCents;
  final int invoiceTotalCents;
  final int invoicePaidCents;

  int get availableCents => card.limitCents - usedCents;
  int get invoiceOpenCents =>
      (invoiceTotalCents - invoicePaidCents).clamp(0, invoiceTotalCents);
  bool get invoicePaid => invoiceTotalCents > 0 && invoiceOpenCents == 0;
}

class BudgetProgress {
  BudgetProgress(this.category, this.limitCents, this.spentCents);

  final Category category;
  final int? limitCents;
  final int spentCents;

  bool get hasBudget => limitCents != null;
  double get ratio =>
      limitCents == null || limitCents == 0 ? 0 : spentCents / limitCents!;
}

class MonthTotals {
  const MonthTotals(this.month, this.incomeCents, this.expenseCents);

  final DateTime month;
  final int incomeCents;
  final int expenseCents;

  int get resultCents => incomeCents - expenseCents;
}

@DriftDatabase(
  tables: [Categories, CreditCards, Entries, InvoicePayments, Budgets, Goals],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'financas'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedCategories() async {
    const expenses = [
      ('Alimentação', 'restaurant', 0xFFFB8C00),
      ('Mercado', 'shopping_cart', 0xFF43A047),
      ('Moradia', 'home', 0xFF5E35B1),
      ('Transporte', 'directions_car', 0xFF1E88E5),
      ('Saúde', 'local_hospital', 0xFFE53935),
      ('Educação', 'school', 0xFF3949AB),
      ('Lazer', 'sports_esports', 0xFFD81B60),
      ('Compras', 'shopping_bag', 0xFF8E24AA),
      ('Contas', 'receipt_long', 0xFF546E7A),
      ('Assinaturas', 'subscriptions', 0xFF00ACC1),
      ('Outros', 'more_horiz', 0xFF6D4C41),
    ];
    const incomes = [
      ('Salário', 'work', 0xFF43A047),
      ('Freelance', 'laptop', 0xFF00897B),
      ('Investimentos', 'trending_up', 0xFF1E88E5),
      ('Presentes', 'card_giftcard', 0xFFD81B60),
      ('Outros', 'more_horiz', 0xFF6D4C41),
    ];
    await batch((b) {
      for (final (type, list) in [
        (EntryType.expense, expenses),
        (EntryType.income, incomes),
      ]) {
        for (final (name, icon, color) in list) {
          b.insert(
            categories,
            CategoriesCompanion.insert(
              name: name,
              type: type,
              color: color,
              icon: icon,
            ),
          );
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Categorias
  // ---------------------------------------------------------------------------

  Stream<List<Category>> watchCategories({EntryType? type}) {
    final q = select(categories)
      ..where((c) => c.archived.equals(false))
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    if (type != null) q.where((c) => c.type.equalsValue(type));
    return q.watch();
  }

  Future<void> saveCategory(CategoriesCompanion data) =>
      into(categories).insertOnConflictUpdate(data);

  /// Exclui a categoria; se ela já tiver lançamentos, apenas a arquiva para
  /// preservar o histórico. Retorna `true` se foi arquivada.
  Future<bool> deleteOrArchiveCategory(int id) => transaction(() async {
    final used =
        await (select(entries)
              ..where((e) => e.categoryId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    await (delete(budgets)..where((b) => b.categoryId.equals(id))).go();
    if (used != null) {
      await (update(categories)..where((c) => c.id.equals(id))).write(
        const CategoriesCompanion(archived: Value(true)),
      );
      return true;
    }
    await (delete(categories)..where((c) => c.id.equals(id))).go();
    return false;
  });

  // ---------------------------------------------------------------------------
  // Lançamentos
  // ---------------------------------------------------------------------------

  Stream<List<EntryDetails>> watchEntriesOfMonth(
    DateTime month, {
    int? cardId,
  }) {
    final q =
        select(entries).join([
            innerJoin(categories, categories.id.equalsExp(entries.categoryId)),
            leftOuterJoin(
              creditCards,
              creditCards.id.equalsExp(entries.cardId),
            ),
          ])
          ..where(entries.refMonth.equals(monthOf(month)))
          ..orderBy([
            OrderingTerm.desc(entries.date),
            OrderingTerm.desc(entries.id),
          ]);
    if (cardId != null) q.where(entries.cardId.equals(cardId));
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          EntryDetails(
            r.readTable(entries),
            r.readTable(categories),
            r.readTableOrNull(creditCards),
          ),
      ],
    );
  }

  /// Receitas e despesas de [count] meses terminando em [lastMonth].
  Stream<List<MonthTotals>> watchMonthlyTotals(DateTime lastMonth, int count) {
    final last = monthOf(lastMonth);
    final first = addMonths(last, -(count - 1));
    final q = select(entries)
      ..where((e) => e.refMonth.isBetweenValues(first, last));
    return q.watch().map((rows) {
      final income = <DateTime, int>{};
      final expense = <DateTime, int>{};
      for (final e in rows) {
        final map = e.type == EntryType.income ? income : expense;
        map[e.refMonth] = (map[e.refMonth] ?? 0) + e.amountCents;
      }
      return [
        for (var i = 0; i < count; i++)
          MonthTotals(
            addMonths(first, i),
            income[addMonths(first, i)] ?? 0,
            expense[addMonths(first, i)] ?? 0,
          ),
      ];
    });
  }

  /// Saldo da conta até hoje: receitas e despesas fora do cartão já ocorridas,
  /// menos os pagamentos de fatura.
  Stream<int> watchBalance(DateTime until) {
    final income = EntryType.income.index;
    final expense = EntryType.expense.index;
    return customSelect(
      '''
      SELECT
        COALESCE((SELECT SUM(amount_cents) FROM entries
                  WHERE card_id IS NULL AND type = $income AND date <= ?1), 0)
      - COALESCE((SELECT SUM(amount_cents) FROM entries
                  WHERE card_id IS NULL AND type = $expense AND date <= ?1), 0)
      - COALESCE((SELECT SUM(amount_cents) FROM invoice_payments
                  WHERE paid_at <= ?1), 0) AS balance
      ''',
      variables: [Variable.withDateTime(until)],
      readsFrom: {entries, invoicePayments},
    ).watchSingle().map((row) => row.read<int>('balance'));
  }

  /// Cria um lançamento, gerando as parcelas quando [installments] > 1.
  Future<void> addEntry({
    required String description,
    required int totalCents,
    required EntryType type,
    required int categoryId,
    required DateTime date,
    CreditCard? card,
    int installments = 1,
    String? note,
  }) {
    final amounts = splitInstallments(totalCents, installments);
    final groupId = installments > 1
        ? '${DateTime.now().microsecondsSinceEpoch}-$categoryId'
        : null;
    final firstInvoice = card == null
        ? null
        : invoiceMonthFor(date, card.closingDay, card.dueDay);

    return batch((b) {
      for (var i = 0; i < installments; i++) {
        final entryDate = card == null ? addMonthsClamped(date, i) : date;
        b.insert(
          entries,
          EntriesCompanion.insert(
            description: description,
            amountCents: amounts[i],
            type: type,
            categoryId: categoryId,
            date: entryDate,
            refMonth: card == null
                ? monthOf(entryDate)
                : addMonths(firstInvoice!, i),
            cardId: Value(card?.id),
            groupId: Value(groupId),
            installmentNumber: Value(i + 1),
            installmentCount: Value(installments),
            note: Value(note),
          ),
        );
      }
    });
  }

  /// Atualiza um único lançamento (ou uma única parcela).
  Future<void> updateEntry(
    Entry entry, {
    required String description,
    required int amountCents,
    required int categoryId,
    required DateTime date,
    String? note,
  }) async {
    DateTime refMonth = monthOf(date);
    if (entry.cardId != null) {
      final card = await (select(
        creditCards,
      )..where((c) => c.id.equals(entry.cardId!))).getSingle();
      refMonth = addMonths(
        invoiceMonthFor(date, card.closingDay, card.dueDay),
        entry.installmentNumber - 1,
      );
    }
    await (update(entries)..where((e) => e.id.equals(entry.id))).write(
      EntriesCompanion(
        description: Value(description),
        amountCents: Value(amountCents),
        categoryId: Value(categoryId),
        date: Value(date),
        refMonth: Value(refMonth),
        note: Value(note),
      ),
    );
  }

  Future<void> deleteEntry(int id) =>
      (delete(entries)..where((e) => e.id.equals(id))).go();

  /// Exclui as parcelas do grupo a partir de [fromInstallment] (inclusive).
  Future<void> deleteInstallments(String groupId, {int fromInstallment = 1}) =>
      (delete(entries)..where(
            (e) =>
                e.groupId.equals(groupId) &
                e.installmentNumber.isBiggerOrEqualValue(fromInstallment),
          ))
          .go();

  // ---------------------------------------------------------------------------
  // Cartões de crédito
  // ---------------------------------------------------------------------------

  Stream<List<CreditCard>> watchCards() =>
      (select(creditCards)
            ..where((c) => c.archived.equals(false))
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Stream<List<CardSummary>> watchCardSummaries(DateTime invoiceMonth) {
    return customSelect(
      '''
      SELECT c.*,
        COALESCE((SELECT SUM(amount_cents) FROM entries e
                  WHERE e.card_id = c.id), 0) AS total_charges,
        COALESCE((SELECT SUM(amount_cents) FROM invoice_payments p
                  WHERE p.card_id = c.id), 0) AS total_paid,
        COALESCE((SELECT SUM(amount_cents) FROM entries e
                  WHERE e.card_id = c.id AND e.ref_month = ?1), 0) AS invoice_total,
        COALESCE((SELECT SUM(amount_cents) FROM invoice_payments p
                  WHERE p.card_id = c.id AND p.invoice_month = ?1), 0) AS invoice_paid
      FROM credit_cards c
      WHERE c.archived = 0
      ORDER BY c.name
      ''',
      variables: [Variable.withDateTime(monthOf(invoiceMonth))],
      readsFrom: {creditCards, entries, invoicePayments},
    ).watch().map(
      (rows) => [
        for (final r in rows)
          CardSummary(
            card: creditCards.map(r.data),
            usedCents: r.read<int>('total_charges') - r.read<int>('total_paid'),
            invoiceTotalCents: r.read<int>('invoice_total'),
            invoicePaidCents: r.read<int>('invoice_paid'),
          ),
      ],
    );
  }

  Stream<CardSummary?> watchCardSummary(int cardId, DateTime invoiceMonth) =>
      watchCardSummaries(invoiceMonth)
          .map((list) => list.where((s) => s.card.id == cardId).firstOrNull);

  Future<void> saveCard(CreditCardsCompanion data) =>
      into(creditCards).insertOnConflictUpdate(data);

  /// Exclui o cartão; se já tiver compras, apenas o arquiva. Retorna `true`
  /// se foi arquivado.
  Future<bool> deleteOrArchiveCard(int id) => transaction(() async {
    final used =
        await (select(entries)
              ..where((e) => e.cardId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (used != null) {
      await (update(creditCards)..where((c) => c.id.equals(id))).write(
        const CreditCardsCompanion(archived: Value(true)),
      );
      return true;
    }
    await (delete(invoicePayments)..where((p) => p.cardId.equals(id))).go();
    await (delete(creditCards)..where((c) => c.id.equals(id))).go();
    return false;
  });

  Future<void> payInvoice({
    required int cardId,
    required DateTime invoiceMonth,
    required int amountCents,
    required DateTime paidAt,
  }) => into(invoicePayments).insert(
    InvoicePaymentsCompanion.insert(
      cardId: cardId,
      invoiceMonth: monthOf(invoiceMonth),
      amountCents: amountCents,
      paidAt: paidAt,
    ),
  );

  Future<void> undoInvoicePayments(int cardId, DateTime invoiceMonth) =>
      (delete(invoicePayments)..where(
            (p) =>
                p.cardId.equals(cardId) &
                p.invoiceMonth.equals(monthOf(invoiceMonth)),
          ))
          .go();

  // ---------------------------------------------------------------------------
  // Orçamentos
  // ---------------------------------------------------------------------------

  Stream<List<BudgetProgress>> watchBudgetProgress(DateTime month) {
    return customSelect(
      '''
      SELECT c.*, b.limit_cents AS budget,
        COALESCE((SELECT SUM(amount_cents) FROM entries e
                  WHERE e.category_id = c.id AND e.ref_month = ?1), 0) AS spent
      FROM categories c
      LEFT JOIN budgets b ON b.category_id = c.id
      WHERE c.type = ${EntryType.expense.index} AND c.archived = 0
      ORDER BY c.name
      ''',
      variables: [Variable.withDateTime(monthOf(month))],
      readsFrom: {categories, budgets, entries},
    ).watch().map(
      (rows) => [
        for (final r in rows)
          BudgetProgress(
            categories.map(r.data),
            r.readNullable<int>('budget'),
            r.read<int>('spent'),
          ),
      ],
    );
  }

  /// Define o orçamento mensal da categoria; `null` ou zero remove.
  Future<void> setBudget(int categoryId, int? limitCents) async {
    if (limitCents == null || limitCents <= 0) {
      await (delete(
        budgets,
      )..where((b) => b.categoryId.equals(categoryId))).go();
    } else {
      await into(budgets).insertOnConflictUpdate(
        BudgetsCompanion.insert(
          categoryId: Value(categoryId),
          limitCents: limitCents,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Metas
  // ---------------------------------------------------------------------------

  Stream<List<Goal>> watchGoals() =>
      (select(goals)..orderBy([(g) => OrderingTerm.asc(g.name)])).watch();

  Future<void> saveGoal(GoalsCompanion data) =>
      into(goals).insertOnConflictUpdate(data);

  Future<void> adjustGoal(int id, int deltaCents) => customUpdate(
    'UPDATE goals SET saved_cents = MAX(0, saved_cents + ?1) WHERE id = ?2',
    variables: [Variable.withInt(deltaCents), Variable.withInt(id)],
    updates: {goals},
  );

  Future<void> deleteGoal(int id) =>
      (delete(goals)..where((g) => g.id.equals(id))).go();
}
