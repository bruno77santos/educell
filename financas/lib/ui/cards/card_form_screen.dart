import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/category_style.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../widgets/common.dart';

class CardFormScreen extends StatefulWidget {
  const CardFormScreen({super.key, this.existing});

  final CreditCard? existing;

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _limit = TextEditingController();
  int _closingDay = 1;
  int _dueDay = 10;
  int _color = palette[3];

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _name.text = c.name;
      _limit.text = formatMoneyPlain(c.limitCents);
      _closingDay = c.closingDay;
      _dueDay = c.dueDay;
      _color = c.color;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppDatabase>().saveCard(
      CreditCardsCompanion(
        id: widget.existing == null
            ? const Value.absent()
            : Value(widget.existing!.id),
        name: Value(_name.text.trim()),
        limitCents: Value(parseMoneyToCents(_limit.text)),
        closingDay: Value(_closingDay),
        dueDay: Value(_dueDay),
        color: Value(_color),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir cartão?',
      message:
          'Se o cartão já tiver compras, ele será apenas arquivado '
          'para manter seu histórico.',
    );
    if (!ok || !mounted) return;
    final archived = await context.read<AppDatabase>().deleteOrArchiveCard(
      widget.existing!.id,
    );
    if (!mounted) return;
    showSnack(context, archived ? 'Cartão arquivado' : 'Cartão excluído');
    Navigator.pop(context);
  }

  Widget _dayField(String label, int value, ValueChanged<int> onChanged) =>
      DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var d = 1; d <= 31; d++)
            DropdownMenuItem(value: d, child: Text('Dia $d')),
        ],
        onChanged: (v) => onChanged(v ?? value),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Novo cartão' : 'Editar cartão'),
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
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome do cartão',
              hintText: 'Ex.: Nubank, Inter, Itaú Visa',
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
          ),
          MoneyField(controller: _limit, label: 'Limite'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dayField(
                  'Fechamento',
                  _closingDay,
                  (v) => setState(() => _closingDay = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _dayField(
                  'Vencimento',
                  _dueDay,
                  (v) => setState(() => _dueDay = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Compras feitas a partir do dia de fechamento entram na '
            'fatura seguinte.',
            style: Theme.of(context).textTheme.bodySmall,
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
