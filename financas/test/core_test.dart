import 'package:financas/core/dates.dart';
import 'package:financas/core/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('dinheiro', () {
    test('formata em reais', () {
      expect(formatMoney(123456), r'R$ 1.234,56'.replaceAll(' ', ' '));
      expect(formatMoneyPlain(5), '0,05');
    });

    test('converte texto para centavos', () {
      expect(parseMoneyToCents('1.234,56'), 123456);
      expect(parseMoneyToCents(''), 0);
    });

    test('campo de valor preenche da direita para a esquerda', () {
      final f = CurrencyInputFormatter();
      TextEditingValue type(String digits) => f.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: digits),
      );
      expect(type('1').text, '0,01');
      expect(type('123').text, '1,23');
      expect(type('123456').text, '1.234,56');
    });

    test('parcelas somam o total e o resto fica na primeira', () {
      expect(splitInstallments(10000, 3), [3334, 3333, 3333]);
      expect(splitInstallments(10000, 4), [2500, 2500, 2500, 2500]);
      expect(splitInstallments(10000, 3).reduce((a, b) => a + b), 10000);
      expect(() => splitInstallments(100, 0), throwsArgumentError);
    });
  });

  group('datas', () {
    test('soma meses ajustando o fim do mês', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(
        addMonthsClamped(DateTime(2026, 11, 15), 3),
        DateTime(2027, 2, 15),
      );
    });

    test('fatura: vencimento depois do fechamento (fecha 3, vence 10)', () {
      // Antes do fechamento: fatura do mesmo mês.
      expect(invoiceMonthFor(DateTime(2026, 10, 2), 3, 10), DateTime(2026, 10));
      // No dia do fechamento ou depois: próxima fatura.
      expect(invoiceMonthFor(DateTime(2026, 10, 3), 3, 10), DateTime(2026, 11));
      expect(invoiceMonthFor(DateTime(2026, 12, 20), 3, 10), DateTime(2027, 1));
    });

    test('fatura: vencimento antes do fechamento (fecha 25, vence 5)', () {
      expect(
        invoiceMonthFor(DateTime(2026, 10, 24), 25, 5),
        DateTime(2026, 11),
      );
      expect(
        invoiceMonthFor(DateTime(2026, 10, 25), 25, 5),
        DateTime(2026, 12),
      );
    });

    test('fechamento no dia 31 em mês curto', () {
      // Fevereiro fecha no dia 28.
      expect(invoiceMonthFor(DateTime(2026, 2, 27), 31, 10), DateTime(2026, 3));
      expect(invoiceMonthFor(DateTime(2026, 2, 28), 31, 10), DateTime(2026, 4));
    });

    test('datas de fechamento e vencimento da fatura', () {
      expect(
        invoiceClosingDate(DateTime(2026, 11), 3, 10),
        DateTime(2026, 11, 3),
      );
      expect(
        invoiceClosingDate(DateTime(2026, 11), 25, 5),
        DateTime(2026, 10, 25),
      );
      expect(invoiceDueDate(DateTime(2026, 2), 31), DateTime(2026, 2, 28));
    });

    test('nome do mês em português', () {
      expect(formatMonthYear(DateTime(2026, 10)), 'Outubro de 2026');
    });
  });
}
