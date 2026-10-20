import '../../core/utils/money.dart';

enum InvoiceStatus {
  open,
  closed,
  paid,
}

class Invoice {
  final String id;
  final String cardId;
  final int month;
  final int year;
  final DateTime closingDate;
  final DateTime dueDate;
  final DateTime effectiveDueDate;
  final int totalAmountCents;
  final InvoiceStatus status;
  final DateTime? paidAt;
  final int? paidAmountCents;

  const Invoice({
    required this.id,
    required this.cardId,
    required this.month,
    required this.year,
    required this.closingDate,
    required this.dueDate,
    required this.effectiveDueDate,
    this.totalAmountCents = 0,
    this.status = InvoiceStatus.open,
    this.paidAt,
    this.paidAmountCents,
  });

  bool get isPaid => status == InvoiceStatus.paid;

  double get totalAmount => Money.toReais(totalAmountCents);
  double? get paidAmount => paidAmountCents == null ? null : Money.toReais(paidAmountCents!);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cardId': cardId,
      'month': month,
      'year': year,
      'closingDate': closingDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'effectiveDueDate': effectiveDueDate.toIso8601String(),
      'totalAmountCents': totalAmountCents,
      'status': status.name,
      'paidAt': paidAt?.toIso8601String(),
      'paidAmountCents': paidAmountCents,
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
      totalAmountCents: map['totalAmountCents'] as int? ?? 0,
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InvoiceStatus.open,
      ),
      paidAt: map['paidAt'] != null ? DateTime.parse(map['paidAt'] as String) : null,
      paidAmountCents: map['paidAmountCents'] as int?,
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
    int? totalAmountCents,
    InvoiceStatus? status,
    DateTime? paidAt,
    int? paidAmountCents,
  }) {
    return Invoice(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      month: month ?? this.month,
      year: year ?? this.year,
      closingDate: closingDate ?? this.closingDate,
      dueDate: dueDate ?? this.dueDate,
      effectiveDueDate: effectiveDueDate ?? this.effectiveDueDate,
      totalAmountCents: totalAmountCents ?? this.totalAmountCents,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      paidAmountCents: paidAmountCents ?? this.paidAmountCents,
    );
  }
}
