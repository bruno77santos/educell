import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../security/lock_controller.dart';
import '../budgets/budgets_screen.dart';
import '../cards/card_invoice_screen.dart';
import '../entries/entries_screen.dart';
import '../entries/entry_tile.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final month = context.watch<SelectedMonth>().month;
    final endOfToday = dateOnly(DateTime.now())
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Finanças'),
        actions: [
          IconButton(
            tooltip: 'Bloquear agora',
            onPressed: () => context.read<LockController>().lock(),
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Novo lançamento',
        onPressed: () => openNewEntry(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          _BalanceCard(stream: db.watchBalance(endOfToday)),
          const MonthSelector(),
          StreamBuilder<List<EntryDetails>>(
            stream: db.watchEntriesOfMonth(month),
            builder: (context, snap) {
              final items = snap.data ?? const <EntryDetails>[];
              final income = items
                  .where((d) => d.isIncome)
                  .fold<int>(0, (s, d) => s + d.entry.amountCents);
              final expense = items
                  .where((d) => !d.isIncome)
                  .fold<int>(0, (s, d) => s + d.entry.amountCents);
              return Column(
                children: [
                  _MonthSummary(income: income, expense: expense),
                  const SectionHeader('Últimos lançamentos'),
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'Nenhum lançamento neste mês.',
                    )
                  else
                    for (final d in items.take(5))
                      EntryTile(details: d, showDate: true),
                ],
              );
            },
          ),
          _CardsSection(month: month),
          _BudgetsSection(month: month),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.stream});

  final Stream<int> stream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo em conta hoje',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            StreamBuilder<int>(
              stream: stream,
              builder: (context, snap) => Text(
                snap.hasData ? formatMoney(snap.data!) : '—',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Receitas e despesas fora do cartão até hoje, menos faturas pagas.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.income, required this.expense});

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, int cents, Color color, IconData icon) =>
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(cents),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    final result = income - expense;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          tile('Receitas', income, incomeColorFor(context), Icons.arrow_upward),
          tile(
            'Despesas',
            expense,
            expenseColorFor(context),
            Icons.arrow_downward,
          ),
          tile(
            'Resultado',
            result,
            result >= 0 ? incomeColorFor(context) : expenseColorFor(context),
            Icons.balance,
          ),
        ],
      ),
    );
  }
}

class _CardsSection extends StatelessWidget {
  const _CardsSection({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CardSummary>>(
    stream: context.read<AppDatabase>().watchCardSummaries(month),
    builder: (context, snap) {
      final cards = snap.data ?? const <CardSummary>[];
      if (cards.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Faturas de ${formatMonthYear(month)}'),
          for (final s in cards)
            ListTile(
              leading: Icon(Icons.credit_card, color: Color(s.card.color)),
              title: Text(s.card.name),
              subtitle: Text(
                s.invoicePaid
                    ? 'Paga'
                    : 'Vence ${formatDayMonth(invoiceDueDate(month, s.card.dueDay))}'
                          ' · disponível ${formatMoney(s.availableCents)}',
              ),
              trailing: Text(
                formatMoney(s.invoiceTotalCents),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CardInvoiceScreen(card: s.card, initialMonth: month),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _BudgetsSection extends StatelessWidget {
  const _BudgetsSection({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BudgetProgress>>(
    stream: context.read<AppDatabase>().watchBudgetProgress(month),
    builder: (context, snap) {
      final budgets =
          (snap.data ?? const <BudgetProgress>[])
              .where((b) => b.hasBudget)
              .toList()
            ..sort((a, b) => b.ratio.compareTo(a.ratio));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Orçamentos',
            action: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const BudgetsScreen())),
              child: Text(budgets.isEmpty ? 'Definir' : 'Ver todos'),
            ),
          ),
          if (budgets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Defina limites mensais por categoria para '
                'acompanhar seus gastos.',
              ),
            )
          else
            for (final b in budgets.take(4)) BudgetTile(progress: b),
        ],
      );
    },
  );
}
