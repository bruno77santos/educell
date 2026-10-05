import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../widgets/common.dart';

/// Cadastro e edição de lançamentos. Na edição, cada parcela é alterada
/// individualmente; forma de pagamento e parcelamento ficam fixos.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    this.existing,
    this.initialType = EntryType.expense,
  });

  final EntryDetails? existing;
  final EntryType initialType;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  static const maxInstallments = 48;

  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _note = TextEditingController();

  late EntryType _type;
  int? _categoryId;
  late DateTime _date;
  int? _cardId;
  int _installments = 1;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      final e = existing.entry;
      _type = e.type;
      _amount.text = formatMoneyPlain(e.amountCents);
      _description.text = e.description;
      _note.text = e.note ?? '';
      _categoryId = e.categoryId;
      _date = e.date;
      _cardId = e.cardId;
      _installments = e.installmentCount;
    } else {
      _type = widget.initialType;
      final month = context.read<SelectedMonth>().month;
      final now = DateTime.now();
      _date = month == monthOf(now) ? dateOnly(now) : month;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final db = context.read<AppDatabase>();
    final cents = parseMoneyToCents(_amount.text);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final description = _description.text.trim();
    try {
      if (_editing) {
        await db.updateEntry(
          widget.existing!.entry,
          description: description,
          amountCents: cents,
          categoryId: _categoryId!,
          date: _date,
          note: note,
        );
      } else {
        final card = _cardId == null
            ? null
            : (await db.watchCards().first).firstWhere((c) => c.id == _cardId);
        await db.addEntry(
          description: description,
          totalCents: cents,
          type: _type,
          categoryId: _categoryId!,
          date: _date,
          card: card,
          installments: _installments,
          note: note,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final db = context.read<AppDatabase>();
    final e = widget.existing!.entry;
    if (e.groupId == null) {
      final ok = await confirm(
        context,
        title: 'Excluir lançamento?',
        message: '"${e.description}" será excluído.',
      );
      if (!ok) return;
      await db.deleteEntry(e.id);
    } else {
      final choice = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Excluir parcelas'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 0),
              child: Text(
                'Só esta parcela (${e.installmentNumber}/${e.installmentCount})',
              ),
            ),
            if (e.installmentNumber < e.installmentCount)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 1),
                child: const Text('Esta e as próximas'),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 2),
              child: const Text('Todas as parcelas'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      switch (choice) {
        case 0:
          await db.deleteEntry(e.id);
        case 1:
          await db.deleteInstallments(
            e.groupId!,
            fromInstallment: e.installmentNumber,
          );
        case 2:
          await db.deleteInstallments(e.groupId!);
        default:
          return;
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final isExpense = _type == EntryType.expense;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar lançamento' : 'Novo lançamento'),
        actions: [
          if (_editing)
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
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Despesa'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: EntryType.income,
                  label: Text('Receita'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _editing
                  ? null
                  : (s) => setState(() {
                      _type = s.first;
                      _categoryId = null;
                      if (_type == EntryType.income) {
                        _cardId = null;
                      }
                    }),
            ),
            if (_editing && widget.existing!.isInstallment)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      'Parcela ${widget.existing!.entry.installmentNumber} '
                      'de ${widget.existing!.entry.installmentCount}',
                    ),
                    subtitle: const Text(
                      'As alterações valem só para esta parcela.',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            MoneyField(
              controller: _amount,
              autofocus: !_editing,
              label: _installments > 1 && !_editing ? 'Valor total' : 'Valor',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Descrição'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Informe uma descrição' : null,
            ),
            StreamBuilder<List<Category>>(
              stream: db.watchCategories(type: _type),
              builder: (context, snap) {
                final cats = [...?snap.data];
                // Mantém visível uma categoria arquivada já usada na edição.
                if (_editing &&
                    _categoryId == widget.existing!.category.id &&
                    cats.every((c) => c.id != _categoryId)) {
                  cats.add(widget.existing!.category);
                }
                return DropdownButtonFormField<int>(
                  key: ValueKey('cat-$_type-${cats.length}'),
                  initialValue: cats.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final c in cats)
                      DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            CategoryAvatar(category: c, radius: 12),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) => v == null ? 'Escolha uma categoria' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _cardId != null ? 'Data da compra' : 'Data',
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(formatDate(_date)),
              ),
            ),
            if (isExpense) ...[
              const SizedBox(height: 12),
              _paymentField(db),
              if (!_editing) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _installments,
                  decoration: const InputDecoration(labelText: 'Parcelas'),
                  items: [
                    for (var i = 1; i <= maxInstallments; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(i == 1 ? 'À vista' : '${i}x'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _installments = v ?? 1),
                ),
                _installmentPreview(db),
              ],
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentField(AppDatabase db) {
    if (_editing) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Forma de pagamento'),
        child: Text(widget.existing!.card?.name ?? 'Conta / dinheiro'),
      );
    }
    return StreamBuilder<List<CreditCard>>(
      stream: db.watchCards(),
      builder: (context, snap) {
        final cards = snap.data ?? const <CreditCard>[];
        return DropdownButtonFormField<int?>(
          key: ValueKey('cards-${cards.length}'),
          initialValue: cards.any((c) => c.id == _cardId) ? _cardId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Forma de pagamento'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Conta / dinheiro / Pix',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            for (final c in cards)
              DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Icon(Icons.credit_card, color: Color(c.color)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _cardId = v),
        );
      },
    );
  }

  /// Mostra "10x de R$ 100,00" e, no cartão, em qual fatura cai a 1ª parcela.
  Widget _installmentPreview(AppDatabase db) {
    final total = parseMoneyToCents(_amount.text);
    if (total == 0 || (_installments == 1 && _cardId == null)) {
      return const SizedBox.shrink();
    }
    final parts = splitInstallments(total, _installments);
    return StreamBuilder<List<CreditCard>>(
      stream: db.watchCards(),
      builder: (context, snap) {
        final card = snap.data?.where((c) => c.id == _cardId).firstOrNull;
        final firstInvoice = card == null
            ? null
            : invoiceMonthFor(_date, card.closingDay, card.dueDay);
        final lines = <String>[
          if (_installments > 1)
            parts.first == parts.last
                ? '${_installments}x de ${formatMoney(parts.first)}'
                : '1x de ${formatMoney(parts.first)} + '
                      '${_installments - 1}x de ${formatMoney(parts.last)}',
          if (firstInvoice != null)
            _installments > 1
                ? 'Faturas de ${formatMonthYear(firstInvoice)} a '
                      '${formatMonthYear(addMonths(firstInvoice, _installments - 1))}'
                : 'Entra na fatura de ${formatMonthYear(firstInvoice)}'
          else if (_installments > 1)
            'Última parcela em ${formatDate(addMonthsClamped(_date, _installments - 1))}',
        ];
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            lines.join('\n'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        );
      },
    );
  }
}
