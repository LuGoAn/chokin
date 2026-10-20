import '../../core/utils/money.dart';

enum ReimbursementStatus {
  pending,
  partiallyPaid,
  settled,
}

class ReimbursementPayment {
  final String id;
  final String reimbursementId;
  final int amountCents;
  final DateTime paymentDate;
  final String? notes;

  const ReimbursementPayment({
    required this.id,
    required this.reimbursementId,
    required this.amountCents,
    required this.paymentDate,
    this.notes,
  });

  double get amount => Money.toReais(amountCents);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reimbursementId': reimbursementId,
      'amountCents': amountCents,
      'paymentDate': paymentDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory ReimbursementPayment.fromMap(Map<String, dynamic> map) {
    return ReimbursementPayment(
      id: map['id'] as String,
      reimbursementId: map['reimbursementId'] as String,
      amountCents: map['amountCents'] as int,
      paymentDate: DateTime.parse(map['paymentDate'] as String),
      notes: map['notes'] as String?,
    );
  }
}

class Reimbursement {
  final String id;
  final String personId;
  final String transactionId;
  final int totalAmountCents;
  final int remainingAmountCents;
  final ReimbursementStatus status;
  final DateTime createdAt;
  final List<ReimbursementPayment> payments;

  const Reimbursement({
    required this.id,
    required this.personId,
    required this.transactionId,
    required this.totalAmountCents,
    required this.remainingAmountCents,
    this.status = ReimbursementStatus.pending,
    required this.createdAt,
    this.payments = const [],
  });

  bool get isSettled => status == ReimbursementStatus.settled || remainingAmountCents <= 0;
  int get paidAmountCents => (totalAmountCents - remainingAmountCents).clamp(0, totalAmountCents);

  double get totalAmount => Money.toReais(totalAmountCents);
  double get remainingAmount => Money.toReais(remainingAmountCents);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'transactionId': transactionId,
      'totalAmountCents': totalAmountCents,
      'remainingAmountCents': remainingAmountCents,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reimbursement.fromMap(Map<String, dynamic> map, {List<ReimbursementPayment> payments = const []}) {
    return Reimbursement(
      id: map['id'] as String,
      personId: map['personId'] as String,
      transactionId: map['transactionId'] as String,
      totalAmountCents: map['totalAmountCents'] as int,
      remainingAmountCents: map['remainingAmountCents'] as int,
      status: ReimbursementStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReimbursementStatus.pending,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      payments: payments,
    );
  }

  Reimbursement copyWith({
    String? id,
    String? personId,
    String? transactionId,
    int? totalAmountCents,
    int? remainingAmountCents,
    ReimbursementStatus? status,
    DateTime? createdAt,
    List<ReimbursementPayment>? payments,
  }) {
    return Reimbursement(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      transactionId: transactionId ?? this.transactionId,
      totalAmountCents: totalAmountCents ?? this.totalAmountCents,
      remainingAmountCents: remainingAmountCents ?? this.remainingAmountCents,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      payments: payments ?? this.payments,
    );
  }
}
