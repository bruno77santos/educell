import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../widgets/common.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final month = context.watch<SelectedMonth>().month;
    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos')),
      body: StreamBuilder<List<BudgetProgress>>(
        stream: db.watchBudgetProgress(month),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final withBudget = all.where((b) => b.hasBudget).toList();
          final totalLimit = withBudget.fold<int>(
            0,
            (s, b) => s + b.limitCents!,
          );
          final totalSpent = withBudget.fold<int>(
            0,
            (s, b) => s + b.spentCents,
          );
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const MonthSelector(),
              if (withBudget.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total orçado'),
                        Text(
                          '${formatMoney(totalSpent)} de ${formatMoney(totalLimit)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        BudgetBar(
                          ratio: totalLimit == 0 ? 0 : totalSpent / totalLimit,
                        ),
                      ],
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Toque em uma categoria para definir o limite '
                  'mensal. O orçamento vale para todos os meses.',
                ),
              ),
              for (final b in all) BudgetTile(progress: b, editable: true),
            ],
          );
        },
      ),
    );
  }
}

class BudgetTile extends StatelessWidget {
  const BudgetTile({super.key, required this.progress, this.editable = false});

  final BudgetProgress progress;
  final bool editable;

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(
      text: progress.limitCents == null
          ? ''
          : formatMoneyPlain(progress.limitCents!),
    );
    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Orçamento: ${progress.category.name}'),
        content: MoneyField(
          controller: controller,
          label: 'Limite mensal',
          autofocus: true,
          allowZero: true,
        ),
        actions: [
          if (progress.hasBudget)
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Remover'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, parseMoneyToCents(controller.text)),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    await context.read<AppDatabase>().setBudget(progress.category.id, result);
  }

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final remaining = (p.limitCents ?? 0) - p.spentCents;
    return ListTile(
      leading: CategoryAvatar(category: p.category),
      title: Text(p.category.name),
      onTap: editable ? () => _edit(context) : null,
      subtitle: p.hasBudget
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                BudgetBar(ratio: p.ratio),
                const SizedBox(height: 4),
                Text(
                  remaining >= 0
                      ? 'Restam ${formatMoney(remaining)}'
                      : 'Estourou ${formatMoney(-remaining)}',
                  style: TextStyle(
                    color: remaining < 0 ? expenseColorFor(context) : null,
                  ),
                ),
              ],
            )
          : Text('Gasto: ${formatMoney(p.spentCents)} · sem orçamento'),
      trailing: p.hasBudget
          ? Text(
              '${formatMoney(p.spentCents)}\nde ${formatMoney(p.limitCents!)}',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : (editable ? const Icon(Icons.add) : null),
    );
  }
}
