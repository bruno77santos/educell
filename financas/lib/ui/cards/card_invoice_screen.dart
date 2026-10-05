import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../entries/entry_tile.dart';
import '../widgets/common.dart';

/// Fatura de um cartão em um mês: compras, status e pagamento.
class CardInvoiceScreen extends StatefulWidget {
  const CardInvoiceScreen({
    super.key,
    required this.card,
    required this.initialMonth,
  });

  final CreditCard card;
  final DateTime initialMonth;

  @override
  State<CardInvoiceScreen> createState() => _CardInvoiceScreenState();
}

class _CardInvoiceScreenState extends State<CardInvoiceScreen> {
  late DateTime _month = widget.initialMonth;

  Future<void> _pay(CardSummary s) async {
    final ok = await confirm(
      context,
      title: 'Pagar fatura?',
      message:
          'Registrar o pagamento de ${formatMoney(s.invoiceOpenCents)} '
          'hoje. O valor sai do saldo da conta e libera o limite do cartão.',
      confirmLabel: 'Pagar',
    );
    if (!ok || !mounted) return;
    await context.read<AppDatabase>().payInvoice(
      cardId: widget.card.id,
      invoiceMonth: _month,
      amountCents: s.invoiceOpenCents,
      paidAt: DateTime.now(),
    );
  }

  Future<void> _undo() async {
    final ok = await confirm(
      context,
      title: 'Desfazer pagamento?',
      message: 'Os pagamentos registrados nesta fatura serão removidos.',
      confirmLabel: 'Desfazer',
    );
    if (!ok || !mounted) return;
    await context.read<AppDatabase>().undoInvoicePayments(
      widget.card.id,
      _month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final card = widget.card;
    final closing = invoiceClosingDate(_month, card.closingDay, card.dueDay);
    final due = invoiceDueDate(_month, card.dueDay);
    final closed = !DateTime.now().isBefore(closing);

    return Scaffold(
      appBar: AppBar(title: Text(card.name)),
      body: Column(
        children: [
          MonthSelector(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          StreamBuilder<CardSummary?>(
            stream: db.watchCardSummary(card.id, _month),
            builder: (context, snap) {
              final s = snap.data;
              if (s == null) return const SizedBox(height: 120);
              final status = s.invoiceTotalCents == 0
                  ? 'Sem compras'
                  : s.invoicePaid
                  ? 'Paga'
                  : closed
                  ? 'Fechada'
                  : 'Aberta';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatMoney(s.invoiceTotalCents),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          Chip(label: Text(status)),
                        ],
                      ),
                      Text(
                        'Fecha em ${formatDate(closing)} · '
                        'vence em ${formatDate(due)}',
                      ),
                      if (s.invoicePaidCents > 0 && !s.invoicePaid)
                        Text(
                          'Pago: ${formatMoney(s.invoicePaidCents)} · '
                          'restante ${formatMoney(s.invoiceOpenCents)}',
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (s.invoiceOpenCents > 0)
                            FilledButton.icon(
                              onPressed: () => _pay(s),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Pagar fatura'),
                            ),
                          if (s.invoicePaidCents > 0)
                            TextButton(
                              onPressed: _undo,
                              child: const Text('Desfazer pagamento'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<EntryDetails>>(
              stream: db.watchEntriesOfMonth(_month, cardId: card.id),
              builder: (context, snap) {
                final items = snap.data ?? const <EntryDetails>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    message: 'Nenhuma compra nesta fatura.',
                  );
                }
                return ListView(
                  children: [
                    for (final d in items)
                      EntryTile(details: d, showDate: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
