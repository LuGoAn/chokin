class CreditCard {
  final String id;
  final String name;
  final int closingDay;
  final int dueDay;
  final double? creditLimit;
  final String? flag; // 'Mastercard', 'Visa', etc.
  final String colorHex;

  const CreditCard({
    required this.id,
    required this.name,
    required this.closingDay,
    required this.dueDay,
    this.creditLimit,
    this.flag,
    this.colorHex = '0xFF6366F1',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'closingDay': closingDay,
      'dueDay': dueDay,
      'creditLimit': creditLimit,
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
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
      flag: map['flag'] as String?,
      colorHex: map['colorHex'] as String? ?? '0xFF6366F1',
    );
  }
}
