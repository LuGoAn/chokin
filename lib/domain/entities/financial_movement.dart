import '../../core/utils/money.dart';

enum MovementType {
  income,
  expensePaid,
  invoicePayment,
  transferToReserve,
  reserveCompensation,
  reimbursementReceived,
  refund,
  manualAdjustment,
  reserveAdjustment,
  cardRefund,
}

class FinancialMovement {
  final String id;
  final String? transactionId;
  final String? invoiceId;
  final String? reimbursementId;
  final MovementType type;
  final int amountCents;
  final DateTime movementDate;
  final String description;

  const FinancialMovement({
    required this.id,
    this.transactionId,
    this.invoiceId,
    this.reimbursementId,
    required this.type,
    required this.amountCents,
    required this.movementDate,
    required this.description,
  });

  double get amount => Money.toReais(amountCents);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'invoiceId': invoiceId,
      'reimbursementId': reimbursementId,
      'type': type.name,
      'amountCents': amountCents,
      'movementDate': movementDate.toIso8601String(),
      'description': description,
    };
  }

  factory FinancialMovement.fromMap(Map<String, dynamic> map) {
    return FinancialMovement(
      id: map['id'] as String,
      transactionId: map['transactionId'] as String?,
      invoiceId: map['invoiceId'] as String?,
      reimbursementId: map['reimbursementId'] as String?,
      type: MovementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => throw FormatException('Tipo de movimentação desconhecido: ${map['type']}'),
      ),
      amountCents: map['amountCents'] as int,
      movementDate: DateTime.parse(map['movementDate'] as String),
      description: map['description'] as String,
    );
  }
}
