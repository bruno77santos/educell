import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../widgets/common.dart';
import 'entry_form_screen.dart';

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.details, this.showDate = false});

  final EntryDetails details;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final e = details.entry;
    final subtitle = [
      details.category.name,
      if (showDate) formatDayMonth(e.date),
      if (details.card != null) details.card!.name,
      if (details.isInstallment)
        'Parcela ${e.installmentNumber}/${e.installmentCount}',
    ].join(' · ');
    return ListTile(
      leading: CategoryAvatar(category: details.category),
      title: Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${details.isIncome ? '+' : '−'} ${formatMoney(e.amountCents)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: details.isIncome
              ? incomeColorFor(context)
              : expenseColorFor(context),
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EntryFormScreen(existing: details)),
      ),
    );
  }
}
