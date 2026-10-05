import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../widgets/common.dart';
import 'entry_form_screen.dart';
import 'entry_tile.dart';

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  EntryType? _filter;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final month = context.watch<SelectedMonth>().month;
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos')),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Novo lançamento',
        onPressed: () => openNewEntry(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const MonthSelector(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<EntryType?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Todos')),
                ButtonSegment(value: EntryType.income, label: Text('Receitas')),
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Despesas'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EntryDetails>>(
              stream: db.watchEntriesOfMonth(month),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data!
                    .where((d) => _filter == null || d.entry.type == _filter)
                    .toList();
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message:
                        'Nenhum lançamento neste mês.\n'
                        'Toque em + para adicionar.',
                  );
                }
                final total = items.fold<int>(
                  0,
                  (sum, d) => sum + d.signedCents,
                );
                return ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        '${items.length} lançamento(s) · total ${formatMoney(total)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    ..._groupedByDay(context, items),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Agrupa por dia. Compras no cartão aparecem no mês da fatura, mas com a
  /// data real da compra.
  List<Widget> _groupedByDay(BuildContext context, List<EntryDetails> items) {
    final widgets = <Widget>[];
    DateTime? currentDay;
    for (final d in items) {
      final day = dateOnly(d.entry.date);
      if (day != currentDay) {
        currentDay = day;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              formatLongDay(day),
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        );
      }
      widgets.add(EntryTile(details: d));
    }
    return widgets;
  }
}

void openNewEntry(BuildContext context, {EntryType type = EntryType.expense}) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => EntryFormScreen(initialType: type)));
}
