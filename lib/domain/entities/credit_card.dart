import '../../core/utils/money.dart';

class CreditCard {
  final String id;
  final String name;
  final int closingDay;
  final int dueDay;
  final int? creditLimitCents;
  final String? flag;
  final String colorHex;

  const CreditCard({
    required this.id,
    required this.name,
    required this.closingDay,
    required this.dueDay,
    this.creditLimitCents,
    this.flag,
    this.colorHex = '0xFF6366F1',
  });

  double? get creditLimit => creditLimitCents == null ? null : Money.toReais(creditLimitCents!);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'closingDay': closingDay,
      'dueDay': dueDay,
      'creditLimitCents': creditLimitCents,
      'flag': flag,
      'colorHex': colorHex,
    };
  }

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      id: map['id'] as String,
      name: map['name'] as String,
      closingDay: map['closingDay'] as int,
      dueDay: map['dueDay'] as int,
      creditLimitCents: map['creditLimitCents'] as int?,
      flag: map['flag'] as String?,
      colorHex: map['colorHex'] as String? ?? '0xFF6366F1',
    );
  }
}
