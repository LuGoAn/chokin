enum InvoiceStatus {
  open,    // Fatura ainda aceitando lançamentos
  closed,  // Fatura fechada, aguardando pagamento
  paid,    // Fatura paga
}

class Invoice {
  final String id;
  final String cardId;
  final int month;
  final int year;
  final DateTime closingDate;
  final DateTime dueDate;
  final DateTime effectiveDueDate; // Considera dias úteis e finais de semana
  final double totalAmount;
  final InvoiceStatus status;
  final DateTime? paidAt;
  final double? paidAmount;

  const Invoice({
    required this.id,
    required this.cardId,
    required this.month,
    required this.year,
    required this.closingDate,
    required this.dueDate,
    required this.effectiveDueDate,
    this.totalAmount = 0.0,
    this.status = InvoiceStatus.open,
    this.paidAt,
    this.paidAmount,
  });

  bool get isPaid => status == InvoiceStatus.paid;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cardId': cardId,
      'month': month,
      'year': year,
      'closingDate': closingDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'effectiveDueDate': effectiveDueDate.toIso8601String(),
      'totalAmount': totalAmount,
      'status': status.name,
      'paidAt': paidAt?.toIso8601String(),
      'paidAmount': paidAmount,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as String,
      cardId: map['cardId'] as String,
      month: map['month'] as int,
      year: map['year'] as int,
      closingDate: DateTime.parse(map['closingDate'] as String),
      dueDate: DateTime.parse(map['dueDate'] as String),
      effectiveDueDate: DateTime.parse(map['effectiveDueDate'] as String),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InvoiceStatus.open,
      ),
      paidAt: map['paidAt'] != null ? DateTime.parse(map['paidAt'] as String) : null,
      paidAmount: (map['paidAmount'] as num?)?.toDouble(),
    );
  }

  Invoice copyWith({
    String? id,
    String? cardId,
    int? month,
    int? year,
    DateTime? closingDate,
    DateTime? dueDate,
    DateTime? effectiveDueDate,
    double? totalAmount,
    InvoiceStatus? status,
    DateTime? paidAt,
    double? paidAmount,
  }) {
    return Invoice(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      month: month ?? this.month,
      year: year ?? this.year,
      closingDate: closingDate ?? this.closingDate,
      dueDate: dueDate ?? this.dueDate,
      effectiveDueDate: effectiveDueDate ?? this.effectiveDueDate,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}
