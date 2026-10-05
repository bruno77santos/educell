import 'package:flutter/material.dart';

/// Ícones disponíveis para categorias. Guardamos a chave no banco (e não o
/// codePoint) para que o Flutter consiga remover ícones não usados do APK.
const categoryIcons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'shopping_cart': Icons.shopping_cart,
  'home': Icons.home,
  'directions_car': Icons.directions_car,
  'local_hospital': Icons.local_hospital,
  'school': Icons.school,
  'sports_esports': Icons.sports_esports,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'subscriptions': Icons.subscriptions,
  'pets': Icons.pets,
  'flight': Icons.flight,
  'checkroom': Icons.checkroom,
  'fitness_center': Icons.fitness_center,
  'local_gas_station': Icons.local_gas_station,
  'phone_android': Icons.phone_android,
  'child_care': Icons.child_care,
  'volunteer_activism': Icons.volunteer_activism,
  'work': Icons.work,
  'laptop': Icons.laptop,
  'trending_up': Icons.trending_up,
  'card_giftcard': Icons.card_giftcard,
  'savings': Icons.savings,
  'account_balance': Icons.account_balance,
  'more_horiz': Icons.more_horiz,
};

IconData iconFor(String key) => categoryIcons[key] ?? Icons.label;

/// Paleta usada em categorias, cartões e metas.
const palette = <int>[
  0xFFE53935, // vermelho
  0xFFD81B60, // rosa
  0xFF8E24AA, // roxo
  0xFF5E35B1, // violeta
  0xFF3949AB, // índigo
  0xFF1E88E5, // azul
  0xFF00ACC1, // ciano
  0xFF00897B, // verde-azulado
  0xFF43A047, // verde
  0xFF7CB342, // verde-claro
  0xFFFDD835, // amarelo
  0xFFFFB300, // âmbar
  0xFFFB8C00, // laranja
  0xFF6D4C41, // marrom
  0xFF546E7A, // cinza-azulado
  0xFF212121, // grafite
];
