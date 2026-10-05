import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teclado numérico para digitar o PIN, com indicadores de dígitos.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.onCompleted,
    this.extraAction,
    this.enabled = true,
  });

  /// Quantidade de dígitos; quando atingida, [onCompleted] é chamado.
  final int length;
  final Future<void> Function(String pin) onCompleted;

  /// Botão opcional no canto inferior esquerdo (ex.: biometria).
  final Widget? extraAction;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;

  Future<void> _press(String digit) async {
    if (_busy || !widget.enabled || _pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    if (_pin.length == widget.length) {
      _busy = true;
      try {
        await widget.onCompleted(_pin);
      } finally {
        if (mounted) setState(() => _pin = '');
        _busy = false;
      }
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${_pin.length} de ${widget.length} dígitos',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? scheme.primary
                        : Colors.transparent,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 88, height: 72, child: widget.extraAction),
            _key('0'),
            SizedBox(
              width: 88,
              height: 72,
              child: IconButton(
                tooltip: 'Apagar',
                onPressed: _backspace,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _key(String digit) => Padding(
    padding: const EdgeInsets.all(8),
    child: SizedBox(
      width: 72,
      height: 56,
      child: FilledButton.tonal(
        onPressed: widget.enabled ? () => _press(digit) : null,
        child: Text(digit, style: const TextStyle(fontSize: 24)),
      ),
    ),
  );
}
