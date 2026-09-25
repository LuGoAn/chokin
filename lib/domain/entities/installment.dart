class Installment {
  final String id;
  final String transactionId; // ID da compra mãe
  final String invoiceId;     // ID da fatura à qual esta parcela pertence
  final int installmentNumber;// ex: 1
  final int totalInstallments;// ex: 6
  final double amount;        // ex: 200.00
  final String? personId;     // Se for compra para terceiro (ex: mãe, namorada)

  const Installment({
    required this.id,
    required this.transactionId,
    required this.invoiceId,
    required this.installmentNumber,
    required this.totalInstallments,
    required this.amount,
    this.personId,
  });

  String get label => '$installmentNumber/$totalInstallments';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'invoiceId': invoiceId,
      'installmentNumber': installmentNumber,
      'totalInstallments': totalInstallments,
      'amount': amount,
      'personId': personId,
    };
  }

  factory Installment.fromMap(Map<String, dynamic> map) {
    return Installment(
      id: map['id'] as String,
      transactionId: map['transactionId'] as String,
      invoiceId: map['invoiceId'] as String,
      installmentNumber: map['installmentNumber'] as int,
      totalInstallments: map['totalInstallments'] as int,
      amount: (map['amount'] as num).toDouble(),
      personId: map['personId'] as String?,
    );
  }
}
