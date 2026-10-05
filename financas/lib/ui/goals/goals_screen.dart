import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/category_style.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../widgets/common.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GoalFormScreen())),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Nova meta'),
      ),
      body: StreamBuilder<List<Goal>>(
        stream: db.watchGoals(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data!.isEmpty) {
            return const EmptyState(
              icon: Icons.savings_outlined,
              message:
                  'Nenhuma meta ainda.\n'
                  'Crie metas como "Reserva de emergência" ou "Viagem".',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [for (final g in snap.data!) _GoalCard(goal: g)],
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final Goal goal;

  /// Quanto guardar por mês para chegar à meta no prazo.
  String? _monthlyHint() {
    final deadline = goal.deadline;
    final missing = goal.targetCents - goal.savedCents;
    if (deadline == null || missing <= 0) return null;
    final now = monthOf(DateTime.now());
    final months =
        (deadline.year - now.year) * 12 + deadline.month - now.month + 1;
    if (months <= 0) return 'Prazo encerrado';
    return 'Guarde ${formatMoney((missing / months).ceil())}/mês até '
        '${formatDate(deadline)}';
  }

  Future<void> _adjust(BuildContext context, {required bool deposit}) async {
    final controller = TextEditingController();
    final cents = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(deposit ? 'Guardar dinheiro' : 'Retirar dinheiro'),
        content: MoneyField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, parseMoneyToCents(controller.text)),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (cents == null || cents == 0 || !context.mounted) return;
    await context.read<AppDatabase>().adjustGoal(
      goal.id,
      deposit ? cents : -cents,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = goal.targetCents == 0
        ? 0.0
        : goal.savedCents / goal.targetCents;
    final hint = _monthlyHint();
    final color = Color(goal.color);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalFormScreen(existing: goal)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (ratio >= 1)
                    const Chip(
                      avatar: Icon(Icons.check_circle, size: 18),
                      label: Text('Concluída'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatMoney(goal.savedCents)} de '
                '${formatMoney(goal.targetCents)}',
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: goal.savedCents == 0
                        ? null
                        : () => _adjust(context, deposit: false),
                    child: const Text('Retirar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => _adjust(context, deposit: true),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalFormScreen extends StatefulWidget {
  const GoalFormScreen({super.key, this.existing});

  final Goal? existing;

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _saved = TextEditingController();
  DateTime? _deadline;
  int _color = palette[8];

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    if (g != null) {
      _name.text = g.name;
      _target.text = formatMoneyPlain(g.targetCents);
      _saved.text = formatMoneyPlain(g.savedCents);
      _deadline = g.deadline;
      _color = g.color;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppDatabase>().saveGoal(
      GoalsCompanion(
        id: widget.existing == null
            ? const Value.absent()
            : Value(widget.existing!.id),
        name: Value(_name.text.trim()),
        targetCents: Value(parseMoneyToCents(_target.text)),
        savedCents: Value(parseMoneyToCents(_saved.text)),
        deadline: Value(_deadline),
        color: Value(_color),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir meta?',
      message: '"${widget.existing!.name}" será excluída.',
    );
    if (!ok || !mounted) return;
    await context.read<AppDatabase>().deleteGoal(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 50),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Nova meta' : 'Editar meta'),
      actions: [
        if (widget.existing != null)
          IconButton(
            tooltip: 'Excluir',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome da meta',
              hintText: 'Ex.: Reserva de emergência',
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
          ),
          MoneyField(controller: _target, label: 'Valor da meta'),
          const SizedBox(height: 12),
          MoneyField(controller: _saved, label: 'Já guardado', allowZero: true),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDeadline,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Prazo (opcional)',
                suffixIcon: _deadline == null
                    ? const Icon(Icons.calendar_today)
                    : IconButton(
                        tooltip: 'Remover prazo',
                        onPressed: () => setState(() => _deadline = null),
                        icon: const Icon(Icons.clear),
                      ),
              ),
              child: Text(
                _deadline == null ? 'Sem prazo' : formatDate(_deadline!),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Cor', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ColorPicker(
            selected: _color,
            onSelected: (c) => setState(() => _color = c),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}
