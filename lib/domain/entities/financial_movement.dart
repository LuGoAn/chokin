enum MovementType {
  income,                 // Entrada de dinheiro (Salário, Mesada, Pix recebido)
  expensePaid,            // Saída imediata de dinheiro (Pix, Dinheiro)
  invoicePayment,         // Saída de dinheiro por pagamento de fatura
  transferToReserve,      // Transferência automática da sobra para a caixinha
  reserveCompensation,    // Retirada automática da caixinha para cobrir gastos
  reimbursementReceived,  // Entrada de dinheiro por reembolso de terceiro
  refund,                 // Estorno/devolução de compra (total ou parcial)
  manualAdjustment,       // Ajuste manual de saldo
}

class FinancialMovement {
  final String id;
  final String? transactionId;
  final String? invoiceId;
  final String? reimbursementId;
  final MovementType type;
  final double amount;
  final DateTime movementDate;
  final String description;

  const FinancialMovement({
    required this.id,
    this.transactionId,
    this.invoiceId,
    this.reimbursementId,
    required this.type,
    required this.amount,
    required this.movementDate,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'invoiceId': invoiceId,
      'reimbursementId': reimbursementId,
      'type': type.name,
      'amount': amount,
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
        orElse: () => MovementType.manualAdjustment,
      ),
      amount: (map['amount'] as num).toDouble(),
      movementDate: DateTime.parse(map['movementDate'] as String),
      description: map['description'] as String,
    );
  }
}
