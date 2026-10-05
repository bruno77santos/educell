import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../security/lock_controller.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import '../goals/goals_screen.dart';
import '../lock/lock_screens.dart';
import '../widgets/common.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        children: [
          const SectionHeader('Planejamento'),
          ListTile(
            leading: const Icon(Icons.donut_large),
            title: const Text('Orçamentos por categoria'),
            onTap: () => _open(context, const BudgetsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Metas'),
            onTap: () => _open(context, const GoalsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categorias'),
            onTap: () => _open(context, const CategoriesScreen()),
          ),
          const SectionHeader('Segurança'),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Alterar PIN'),
            onTap: () => _open(
              context,
              Builder(
                builder: (ctx) => PinSetupScreen(
                  onDone: () {
                    Navigator.pop(ctx);
                    showSnack(context, 'PIN alterado');
                  },
                ),
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Desbloquear com biometria'),
            subtitle: lock.biometricAvailable
                ? null
                : const Text('Nenhuma biometria cadastrada no aparelho'),
            value: lock.biometricEnabled,
            onChanged: lock.biometricAvailable
                ? (v) => lock.setBiometricEnabled(v)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Bloquear agora'),
            subtitle: Text(
              'O app também bloqueia após '
              '${LockController.relockAfter.inSeconds} s em segundo plano.',
            ),
            onTap: lock.lock,
          ),
          const SectionHeader('Sobre'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Minhas Finanças'),
            subtitle: Text('Seus dados ficam apenas neste aparelho.'),
          ),
        ],
      ),
    );
  }
}
