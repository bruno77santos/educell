import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../widgets/common.dart';
import 'card_form_screen.dart';
import 'card_invoice_screen.dart';

class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final month = context.watch<SelectedMonth>().month;
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões de crédito')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CardFormScreen())),
        icon: const Icon(Icons.add_card),
        label: const Text('Novo cartão'),
      ),
      body: Column(
        children: [
          const MonthSelector(),
          Expanded(
            child: StreamBuilder<List<CardSummary>>(
              stream: db.watchCardSummaries(month),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cards = snap.data!;
                if (cards.isEmpty) {
                  return const EmptyState(
                    icon: Icons.credit_card_off_outlined,
                    message:
                        'Nenhum cartão cadastrado.\n'
                        'Cadastre seus cartões para controlar faturas, '
                        'limite e compras parceladas.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  children: [
                    for (final s in cards)
                      CreditCardWidget(summary: s, month: month),
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

/// Cartão estilizado com fatura do mês e limite disponível.
class CreditCardWidget extends StatelessWidget {
  const CreditCardWidget({
    super.key,
    required this.summary,
    required this.month,
  });

  final CardSummary summary;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final card = summary.card;
    final base = Color(card.color);
    const onCard = Colors.white;
    final usedRatio = card.limitCents == 0
        ? 0.0
        : summary.usedCents / card.limitCents;
    final status = summary.invoiceTotalCents == 0
        ? 'Sem lançamentos'
        : summary.invoicePaid
        ? 'Paga'
        : 'Vence ${formatDayMonth(invoiceDueDate(month, card.dueDay))}';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [base, Color.lerp(base, Colors.black, 0.35)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CardInvoiceScreen(card: card, initialMonth: month),
              ),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(color: onCard),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card, color: onCard),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            card.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Editar cartão',
                          color: onCard,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CardFormScreen(existing: card),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fatura de ${formatMonthYear(month)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      formatMoney(summary.invoiceTotalCents),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(status, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: usedRatio.clamp(0, 1).toDouble(),
                        minHeight: 6,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Disponível ${formatMoney(summary.availableCents)} '
                      'de ${formatMoney(card.limitCents)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
