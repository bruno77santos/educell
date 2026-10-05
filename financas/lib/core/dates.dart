import 'dart:math';

import 'package:intl/intl.dart';

/// Primeiro dia do mês de [date] (meia-noite local). Todas as referências de
/// mês do app usam essa forma normalizada.
DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

/// Soma meses mantendo o primeiro dia do mês.
DateTime addMonths(DateTime month, int months) =>
    DateTime(month.year, month.month + months);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Soma meses a uma data, ajustando o dia quando o mês de destino é mais curto
/// (31/01 + 1 mês = 28/02 ou 29/02).
DateTime addMonthsClamped(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months);
  final day = min(date.day, daysInMonth(target.year, target.month));
  return DateTime(target.year, target.month, day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dia [day] do mês [month], limitado ao último dia do mês (dia 31 em
/// fevereiro vira 28/29).
DateTime dayInMonth(DateTime month, int day) => DateTime(
  month.year,
  month.month,
  min(day, daysInMonth(month.year, month.month)),
);

/// Mês de vencimento da fatura em que cai uma compra no cartão.
///
/// Compras feitas a partir do dia de fechamento entram na fatura seguinte.
/// Se o vencimento é depois do fechamento no calendário (ex.: fecha 3, vence
/// 10), a fatura vence no mesmo mês em que fecha; senão vence no mês seguinte.
DateTime invoiceMonthFor(DateTime purchase, int closingDay, int dueDay) {
  var closingMonth = monthOf(purchase);
  if (purchase.day >= dayInMonth(closingMonth, closingDay).day) {
    closingMonth = addMonths(closingMonth, 1);
  }
  return addMonths(closingMonth, dueDay > closingDay ? 0 : 1);
}

/// Data de fechamento da fatura que vence em [invoiceMonth].
DateTime invoiceClosingDate(DateTime invoiceMonth, int closingDay, int dueDay) {
  final closingMonth = addMonths(invoiceMonth, dueDay > closingDay ? 0 : -1);
  return dayInMonth(closingMonth, closingDay);
}

DateTime invoiceDueDate(DateTime invoiceMonth, int dueDay) =>
    dayInMonth(invoiceMonth, dueDay);

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Outubro de 2026"
String formatMonthYear(DateTime d) =>
    _capitalize(DateFormat.yMMMM('pt_BR').format(d));

/// "Out/26"
String formatShortMonth(DateTime d) =>
    _capitalize(DateFormat('MMM/yy', 'pt_BR').format(d).replaceAll('.', ''));

/// "05/10/2026"
String formatDate(DateTime d) => DateFormat('dd/MM/yyyy', 'pt_BR').format(d);

/// "05/10"
String formatDayMonth(DateTime d) => DateFormat('dd/MM', 'pt_BR').format(d);

/// "Segunda-feira, 5 de outubro"
String formatLongDay(DateTime d) =>
    _capitalize(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d));
