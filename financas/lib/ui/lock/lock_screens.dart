import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../security/lock_controller.dart';
import 'pin_pad.dart';

/// Tela exibida sobre o app enquanto ele está bloqueado.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _error;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final lock = context.read<LockController>();
    if (lock.biometricEnabled && lock.biometricAvailable) {
      await lock.unlockWithBiometrics();
    }
  }

  Future<void> _submit(String pin) async {
    final lock = context.read<LockController>();
    final ok = await lock.unlockWithPin(pin);
    if (!mounted || ok) return;
    if (lock.isLockedOut) {
      setState(
        () => _error =
            'Muitas tentativas. Aguarde ${LockController.lockoutDuration.inSeconds} segundos.',
      );
      _lockoutTimer?.cancel();
      _lockoutTimer = Timer(
        lock.lockoutUntil!.difference(DateTime.now()),
        () => mounted ? setState(() => _error = null) : null,
      );
    } else {
      setState(() => _error = 'PIN incorreto');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockController>();
    final canUseBiometric = lock.biometricEnabled && lock.biometricAvailable;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Minhas Finanças',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Digite seu PIN',
                  style: TextStyle(
                    color: _error != null
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(height: 32),
                PinPad(
                  length: lock.pinLength,
                  enabled: !lock.isLockedOut,
                  onCompleted: _submit,
                  extraAction: canUseBiometric
                      ? IconButton(
                          tooltip: 'Usar biometria',
                          onPressed: _tryBiometric,
                          icon: const Icon(Icons.fingerprint, size: 32),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cadastro (ou troca) do PIN. No primeiro uso também oferece a biometria.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, this.onDone, this.firstRun = false});

  final VoidCallback? onDone;
  final bool firstRun;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Step { create, confirm, biometric }

class _PinSetupScreenState extends State<PinSetupScreen> {
  _Step _step = _Step.create;
  int _length = 4;
  String _first = '';
  String? _error;

  Future<void> _onPin(String pin) async {
    if (_step == _Step.create) {
      setState(() {
        _first = pin;
        _error = null;
        _step = _Step.confirm;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _error = 'Os PINs não conferem. Tente de novo.';
        _step = _Step.create;
      });
      return;
    }
    final lock = context.read<LockController>();
    // No primeiro uso, salvar o PIN remove esta tela; por isso a etapa de
    // biometria vem antes de gravar.
    if (widget.firstRun && lock.biometricAvailable) {
      setState(() => _step = _Step.biometric);
      return;
    }
    await lock.setPin(pin);
    widget.onDone?.call();
  }

  Future<void> _finish({required bool enableBiometric}) async {
    final lock = context.read<LockController>();
    if (enableBiometric) await lock.setBiometricEnabled(true);
    await lock.setPin(_first);
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: widget.firstRun ? null : AppBar(title: const Text('Alterar PIN')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _step == _Step.biometric
                ? _biometricStep(theme)
                : Column(
                    children: [
                      if (widget.firstRun) ...[
                        Icon(
                          Icons.shield_outlined,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Proteja suas finanças',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crie um PIN para abrir o app.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_step == _Step.create)
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 4, label: Text('4 dígitos')),
                            ButtonSegment(value: 6, label: Text('6 dígitos')),
                          ],
                          selected: {_length},
                          onSelectionChanged: (s) =>
                              setState(() => _length = s.first),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        _error ??
                            (_step == _Step.create
                                ? 'Digite o novo PIN'
                                : 'Confirme o PIN'),
                        style: TextStyle(
                          color: _error != null
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      PinPad(
                        // A key força um teclado novo a cada etapa.
                        key: ValueKey('$_step-$_length'),
                        length: _length,
                        onCompleted: _onPin,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _biometricStep(ThemeData theme) => Column(
    children: [
      Icon(Icons.fingerprint, size: 72, color: theme.colorScheme.primary),
      const SizedBox(height: 16),
      Text('Usar biometria?', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
        'Desbloqueie o app com sua digital ou rosto. '
        'O PIN continua valendo como alternativa.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      FilledButton.icon(
        onPressed: () => _finish(enableBiometric: true),
        icon: const Icon(Icons.fingerprint),
        label: const Text('Ativar biometria'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => _finish(enableBiometric: false),
        child: const Text('Agora não'),
      ),
    ],
  );
}
