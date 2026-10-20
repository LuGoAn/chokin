import '../../core/utils/money.dart';

class Installment {
  final String id;
  final String transactionId;
  final String invoiceId;
  final int installmentNumber;
  final int totalInstallments;
  final int amountCents;
  final String? personId;

  const Installment({
    required this.id,
    required this.transactionId,
    required this.invoiceId,
    required this.installmentNumber,
    required this.totalInstallments,
    required this.amountCents,
    this.personId,
  });

  double get amount => Money.toReais(amountCents);

  String get label => '$installmentNumber/$totalInstallments';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'invoiceId': invoiceId,
      'installmentNumber': installmentNumber,
      'totalInstallments': totalInstallments,
      'amountCents': amountCents,
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
      amountCents: map['amountCents'] as int,
      personId: map['personId'] as String?,
    );
  }
}
