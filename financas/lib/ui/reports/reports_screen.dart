import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/category_style.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  EntryType _type = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final month = context.watch<SelectedMonth>().month;
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const MonthSelector(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Despesas'),
                ),
                ButtonSegment(value: EntryType.income, label: Text('Receitas')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ),
          SectionHeader(
            _type == EntryType.expense
                ? 'Despesas por categoria'
                : 'Receitas por categoria',
          ),
          StreamBuilder<List<EntryDetails>>(
            stream: db.watchEntriesOfMonth(month),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox(height: 240);
              final slices = CategorySlice.fromEntries(
                snap.data!.where((d) => d.entry.type == _type),
              );
              if (slices.isEmpty) {
                return const EmptyState(
                  icon: Icons.pie_chart_outline,
                  message: 'Sem lançamentos neste mês.',
                );
              }
              return CategoryBreakdown(slices: slices);
            },
          ),
          const SectionHeader('Receitas x despesas (6 meses)'),
          StreamBuilder<List<MonthTotals>>(
            stream: db.watchMonthlyTotals(month, 6),
            builder: (context, snap) => snap.hasData
                ? MonthlyBarChart(totals: snap.data!)
                : const SizedBox(height: 260),
          ),
        ],
      ),
    );
  }
}

class CategorySlice {
  CategorySlice(this.name, this.color, this.icon, this.cents);

  final String name;
  final Color color;
  final IconData icon;
  final int cents;

  /// Fatias acima deste número viram "Outros" para o gráfico continuar legível.
  static const maxSlices = 7;

  static List<CategorySlice> fromEntries(Iterable<EntryDetails> entries) {
    final byCategory = <int, (Category, int)>{};
    for (final d in entries) {
      final current = byCategory[d.category.id]?.$2 ?? 0;
      byCategory[d.category.id] = (d.category, current + d.entry.amountCents);
    }
    final sorted = byCategory.values.toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final slices = [
      for (final (c, cents) in sorted)
        CategorySlice(c.name, Color(c.color), iconFor(c.icon), cents),
    ];
    if (slices.length <= maxSlices) return slices;
    final rest = slices.skip(maxSlices - 1).fold<int>(0, (s, e) => s + e.cents);
    return [
      ...slices.take(maxSlices - 1),
      CategorySlice(
        'Outras categorias',
        const Color(0xFF9E9E9E),
        Icons.more_horiz,
        rest,
      ),
    ];
  }
}

/// Rosca com o total no centro + lista com valor e percentual de cada
/// categoria (a lista é a legenda e também a "tabela" dos dados).
class CategoryBreakdown extends StatefulWidget {
  const CategoryBreakdown({super.key, required this.slices});

  final List<CategorySlice> slices;

  @override
  State<CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<CategoryBreakdown> {
  int? _touched;

  @override
  void didUpdateWidget(CategoryBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_touched != null && _touched! >= widget.slices.length) _touched = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slices = widget.slices;
    final total = slices.fold<int>(0, (s, e) => s + e.cents);
    final selected = _touched == null ? null : slices[_touched!];
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 64,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      final i = response?.touchedSection?.touchedSectionIndex;
                      setState(
                        () => _touched = (i == null || i < 0) ? null : i,
                      );
                    },
                  ),
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].cents.toDouble(),
                        color: slices[i].color,
                        radius: i == _touched ? 44 : 36,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected?.name ?? 'Total',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    formatMoney(selected?.cents ?? total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selected != null)
                    Text(
                      _percent(selected.cents, total),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
        for (var i = 0; i < slices.length; i++)
          ListTile(
            dense: true,
            selected: i == _touched,
            onTap: () => setState(() => _touched = i == _touched ? null : i),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: slices[i].color.withValues(alpha: 0.18),
              child: Icon(slices[i].icon, size: 16, color: slices[i].color),
            ),
            title: Text(slices[i].name),
            subtitle: BudgetBar(
              ratio: total == 0 ? 0 : slices[i].cents / total,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(slices[i].cents),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _percent(slices[i].cents, total),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _percent(int part, int total) => total == 0
      ? '0%'
      : NumberFormat.decimalPercentPattern(
          locale: 'pt_BR',
          decimalDigits: 1,
        ).format(part / total);
}

/// Barras agrupadas (receita e despesa) por mês, com um único eixo em reais.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, required this.totals});

  final List<MonthTotals> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = incomeColorFor(context);
    final expense = expenseColorFor(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final compact = NumberFormat.compact(locale: 'pt_BR');
    final maxCents = totals.fold<int>(
      0,
      (m, t) =>
          [m, t.incomeCents, t.expenseCents].reduce((a, b) => a > b ? a : b),
    );
    final maxY = maxCents == 0 ? 100.0 : maxCents / 100 * 1.15;

    BarChartRodData rod(int cents, Color color) => BarChartRodData(
      toY: cents / 100,
      color: color,
      width: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          compact.format(value),
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          formatShortMonth(totals[value.toInt()].month),
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final t = totals[groupIndex];
                      return BarTooltipItem(
                        '${formatMonthYear(t.month)}\n',
                        TextStyle(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text:
                                'Receitas ${formatMoney(t.incomeCents)}\n'
                                'Despesas ${formatMoney(t.expenseCents)}\n'
                                'Resultado ${formatMoney(t.resultCents)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < totals.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 2,
                      barRods: [
                        rod(totals[i].incomeCents, income),
                        rod(totals[i].expenseCents, expense),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: income, label: 'Receitas'),
              const SizedBox(width: 24),
              _LegendDot(color: expense, label: 'Despesas'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}
