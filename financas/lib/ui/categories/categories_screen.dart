import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/category_style.dart';
import '../../data/database.dart';
import '../widgets/common.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Categorias'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Despesas'),
              Tab(text: 'Receitas'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          tooltip: 'Nova categoria',
          onPressed: () {
            final type = DefaultTabController.of(context).index == 0
                ? EntryType.expense
                : EntryType.income;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CategoryFormScreen(type: type)),
            );
          },
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            _CategoryList(type: EntryType.expense),
            _CategoryList(type: EntryType.income),
          ],
        ),
      ),
    ),
  );
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.type});

  final EntryType type;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Category>>(
    stream: context.read<AppDatabase>().watchCategories(type: type),
    builder: (context, snap) {
      final cats = snap.data ?? const <Category>[];
      return ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          for (final c in cats)
            ListTile(
              leading: CategoryAvatar(category: c),
              title: Text(c.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryFormScreen(type: type, existing: c),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key, required this.type, this.existing});

  final EntryType type;
  final Category? existing;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _icon = 'more_horiz';
  int _color = palette[5];

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _name.text = c.name;
      _icon = c.icon;
      _color = c.color;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppDatabase>().saveCategory(
      CategoriesCompanion(
        id: widget.existing == null
            ? const Value.absent()
            : Value(widget.existing!.id),
        name: Value(_name.text.trim()),
        type: Value(widget.type),
        icon: Value(_icon),
        color: Value(_color),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir categoria?',
      message:
          'Se já houver lançamentos nela, a categoria será apenas '
          'arquivada para manter o histórico.',
    );
    if (!ok || !mounted) return;
    final archived = await context.read<AppDatabase>().deleteOrArchiveCategory(
      widget.existing!.id,
    );
    if (!mounted) return;
    showSnack(context, archived ? 'Categoria arquivada' : 'Categoria excluída');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Nova categoria' : 'Editar categoria',
        ),
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
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            Text('Ícone', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(:key, :value) in categoryIcons.entries)
                  IconButton(
                    isSelected: key == _icon,
                    style: IconButton.styleFrom(
                      backgroundColor: key == _icon
                          ? Color(_color).withValues(alpha: 0.2)
                          : scheme.surfaceContainerHighest,
                    ),
                    onPressed: () => setState(() => _icon = key),
                    icon: Icon(
                      value,
                      color: key == _icon ? Color(_color) : null,
                    ),
                  ),
              ],
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
}
