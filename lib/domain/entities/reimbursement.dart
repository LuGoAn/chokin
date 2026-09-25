enum ReimbursementStatus {
  pending,
  partiallyPaid,
  settled,
}

class ReimbursementPayment {
  final String id;
  final String reimbursementId;
  final double amount;
  final DateTime paymentDate;
  final String? notes;

  const ReimbursementPayment({
    required this.id,
    required this.reimbursementId,
    required this.amount,
    required this.paymentDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reimbursementId': reimbursementId,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory ReimbursementPayment.fromMap(Map<String, dynamic> map) {
    return ReimbursementPayment(
      id: map['id'] as String,
      reimbursementId: map['reimbursementId'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(map['paymentDate'] as String),
      notes: map['notes'] as String?,
    );
  }
}

class Reimbursement {
  final String id;
  final String personId;
  final String transactionId;
  final double totalAmount;
  final double remainingAmount;
  final ReimbursementStatus status;
  final DateTime createdAt;
  final List<ReimbursementPayment> payments;

  const Reimbursement({
    required this.id,
    required this.personId,
    required this.transactionId,
    required this.totalAmount,
    required this.remainingAmount,
    this.status = ReimbursementStatus.pending,
    required this.createdAt,
    this.payments = const [],
  });

  bool get isSettled => status == ReimbursementStatus.settled || remainingAmount <= 0.001;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'transactionId': transactionId,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reimbursement.fromMap(Map<String, dynamic> map, {List<ReimbursementPayment> payments = const []}) {
    return Reimbursement(
      id: map['id'] as String,
      personId: map['personId'] as String,
      transactionId: map['transactionId'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      remainingAmount: (map['remainingAmount'] as num).toDouble(),
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
    double? totalAmount,
    double? remainingAmount,
    ReimbursementStatus? status,
    DateTime? createdAt,
    List<ReimbursementPayment>? payments,
  }) {
    return Reimbursement(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      transactionId: transactionId ?? this.transactionId,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      payments: payments ?? this.payments,
    );
  }
}
