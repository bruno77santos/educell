import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/category_style.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';

/// Mês selecionado, compartilhado entre as abas do app.
class SelectedMonth extends ChangeNotifier {
  DateTime _month = monthOf(DateTime.now());

  DateTime get month => _month;

  set month(DateTime value) {
    _month = monthOf(value);
    notifyListeners();
  }

  void previous() => month = addMonths(_month, -1);
  void next() => month = addMonths(_month, 1);
}

/// Seletor "< Outubro de 2026 >" ligado ao [SelectedMonth] global, ou a um
/// mês local quando [month] e [onChanged] são informados.
class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, this.month, this.onChanged});

  final DateTime? month;
  final ValueChanged<DateTime>? onChanged;

  @override
  Widget build(BuildContext context) {
    final global = month == null ? context.watch<SelectedMonth>() : null;
    final current = month ?? global!.month;
    void change(int delta) {
      final m = addMonths(current, delta);
      if (onChanged != null) {
        onChanged!(m);
      } else {
        global!.month = m;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: () => change(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 180,
          child: Text(
            formatMonthYear(current),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: () => change(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

const incomeColor = Color(0xFF2E7D32);
const expenseColor = Color(0xFFC62828);

Color incomeColorFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF81C784)
    : incomeColor;

Color expenseColorFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFE57373)
    : expenseColor;

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.radius = 20});

  final Category category;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: Color(category.color).withValues(alpha: 0.18),
    child: Icon(
      iconFor(category.icon),
      color: Color(category.color),
      size: radius,
    ),
  );
}

/// Campo de valor em reais com digitação estilo app de banco.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.label = 'Valor',
    this.autofocus = false,
    this.allowZero = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final bool allowZero;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      CurrencyInputFormatter(),
    ],
    decoration: InputDecoration(
      labelText: label,
      prefixText: r'R$ ',
      hintText: '0,00',
    ),
    onChanged: onChanged,
    validator: (v) => !allowZero && parseMoneyToCents(v ?? '') == 0
        ? 'Informe um valor'
        : null,
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).disabledColor),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      ],
    ),
  );
}

/// Barra de progresso que fica laranja perto do limite e vermelha ao estourar.
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final color = ratio > 1
        ? expenseColorFor(context)
        : ratio >= 0.8
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio.clamp(0, 1).toDouble(),
        minHeight: 8,
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
  }
}

/// Grade de cores da [palette] para escolher a cor de um item.
class ColorPicker extends StatelessWidget {
  const ColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final c in palette)
        Semantics(
          button: true,
          selected: c == selected,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onSelected(c),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(c),
              child: c == selected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ),
    ],
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Excluir',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
