import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Valores monetários são sempre guardados em centavos (int) para evitar
/// erros de arredondamento de ponto flutuante.
final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _plain = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: '',
  decimalDigits: 2,
);

String formatMoney(int cents) => _currency.format(cents / 100);

/// Formata sem o símbolo, ex.: 123456 -> "1.234,56".
String formatMoneyPlain(int cents) => _plain.format(cents / 100).trim();

/// Converte o texto digitado no campo de valor (ex.: "1.234,56") em centavos.
/// Como o campo é preenchido "da direita para a esquerda", basta considerar
/// os dígitos.
int parseMoneyToCents(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.parse(digits);
}

/// Formatter no estilo dos apps de banco: cada dígito digitado entra pela
/// direita (1 -> 0,01; 12 -> 0,12; 123 -> 1,23 ...).
class CurrencyInputFormatter extends TextInputFormatter {
  static const maxDigits = 12; // até R$ 9.999.999.999,99

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) return oldValue;
    if (digits.isEmpty) return const TextEditingValue();
    final text = formatMoneyPlain(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Divide um valor total em [count] parcelas. A diferença de centavos que não
/// divide igualmente fica na primeira parcela, como fazem as operadoras.
List<int> splitInstallments(int totalCents, int count) {
  if (count < 1) throw ArgumentError.value(count, 'count', 'deve ser >= 1');
  final base = totalCents ~/ count;
  final remainder = totalCents - base * count;
  return [for (var i = 0; i < count; i++) i == 0 ? base + remainder : base];
}
