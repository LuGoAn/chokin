import '../../core/utils/money.dart';

enum PaymentMethod {
  pix,
  creditCard,
  cash,
  other,
}

enum TransactionType {
  income,
  expense,
}

enum RecurrenceFrequency {
  none,
  daily,
  weekly,
  biweekly,
  monthly,
  yearly,
}

class FinancialTransaction {
  final String id;
  final String description;
  final int amountCents;
  final DateTime purchaseDate;
  final String categoryId;
  final TransactionType type;
  final PaymentMethod paymentMethod;
  final String personId;
  final String? cardId;
  final int totalInstallments;
  final String? notes;
  final String? sourceNotificationId;
  final bool isCancelled;
  final bool isRecurring;
  final RecurrenceFrequency recurrence;
  final String? recurringGroupId;
  final DateTime? recurrenceEndedAt;
  final List<String> recurrenceExceptions;
  final DateTime? createdAt;
  
  final int refundAmountCents;
  final DateTime? refundedAt;
  final PaymentMethod? refundMethod;
  final String? refundNotes;

  const FinancialTransaction({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.purchaseDate,
    required this.categoryId,
    this.type = TransactionType.expense,
    required this.paymentMethod,
    this.personId = 'ME',
    this.cardId,
    this.totalInstallments = 1,
    this.notes,
    this.sourceNotificationId,
    this.isCancelled = false,
    this.isRecurring = false,
    this.recurrence = RecurrenceFrequency.none,
    this.recurringGroupId,
    this.recurrenceEndedAt,
    this.recurrenceExceptions = const [],
    this.createdAt,
    this.refundAmountCents = 0,
    this.refundedAt,
    this.refundMethod,
    this.refundNotes,
  });

  bool get isForThirdParty => personId != 'ME';
  bool get isCreditCard => paymentMethod == PaymentMethod.creditCard;
  bool get isPix => paymentMethod == PaymentMethod.pix;
  bool get isInstallment => totalInstallments > 1;
  DateTime get effectiveCreatedAt => createdAt ?? purchaseDate;
  String get effectiveRecurringGroupId => (recurringGroupId != null && recurringGroupId!.isNotEmpty) ? recurringGroupId! : id;

  bool get isRefunded => refundAmountCents > 0;
  bool get isFullyRefunded => refundAmountCents >= amountCents && amountCents > 0;
  bool get isPartiallyRefunded => refundAmountCents > 0 && refundAmountCents < amountCents;
  int get netAmountCents => (amountCents - refundAmountCents).clamp(0, amountCents);

  double get amount => Money.toReais(amountCents);
  double get refundAmount => Money.toReais(refundAmountCents);
  double get netAmount => Money.toReais(netAmountCents);

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case PaymentMethod.pix:
        return 'PIX';
      case PaymentMethod.creditCard:
        return 'CARTÃO';
      case PaymentMethod.cash:
        return 'DINHEIRO';
      case PaymentMethod.other:
      default:
        return 'OUTRO';
    }
  }

  String get recurrenceLabel {
    switch (recurrence) {
      case RecurrenceFrequency.daily:
        return 'Diária';
      case RecurrenceFrequency.weekly:
        return 'Semanal';
      case RecurrenceFrequency.biweekly:
        return 'Quinzenal';
      case RecurrenceFrequency.monthly:
        return 'Mensal';
      case RecurrenceFrequency.yearly:
        return 'Anual';
      case RecurrenceFrequency.none:
      default:
        return 'Única';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amountCents': amountCents,
      'purchaseDate': purchaseDate.toIso8601String(),
      'categoryId': categoryId,
      'type': type.name,
      'paymentMethod': paymentMethod.name,
      'personId': personId,
      'cardId': cardId,
      'totalInstallments': totalInstallments,
      'notes': notes,
      'sourceNotificationId': sourceNotificationId,
      'isCancelled': isCancelled ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'recurrence': recurrence.name,
      'recurringGroupId': recurringGroupId,
      'recurrenceEndedAt': recurrenceEndedAt?.toIso8601String(),
      'recurrenceExceptions': recurrenceExceptions.join(','),
      'createdAt': (createdAt ?? purchaseDate).toIso8601String(),
      'refundAmountCents': refundAmountCents,
      'refundedAt': refundedAt?.toIso8601String(),
      'refundMethod': refundMethod?.name,
      'refundNotes': refundNotes,
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as String,
      description: map['description'] as String,
      amountCents: map['amountCents'] as int,
      purchaseDate: DateTime.parse(map['purchaseDate'] as String),
      categoryId: map['categoryId'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'],
        orElse: () => PaymentMethod.pix,
      ),
      personId: map['personId'] as String? ?? 'ME',
      cardId: map['cardId'] as String?,
      totalInstallments: map['totalInstallments'] as int? ?? 1,
      notes: map['notes'] as String?,
      sourceNotificationId: map['sourceNotificationId'] as String?,
      isCancelled: (map['isCancelled'] as int? ?? 0) == 1,
      isRecurring: (map['isRecurring'] as int? ?? 0) == 1,
      recurrence: RecurrenceFrequency.values.firstWhere(
        (e) => e.name == map['recurrence'],
        orElse: () => RecurrenceFrequency.none,
      ),
      recurringGroupId: map['recurringGroupId'] as String?,
      recurrenceEndedAt: map['recurrenceEndedAt'] != null ? DateTime.parse(map['recurrenceEndedAt'] as String) : null,
      recurrenceExceptions: (map['recurrenceExceptions'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? const [],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
      refundAmountCents: map['refundAmountCents'] as int? ?? 0,
      refundedAt: map['refundedAt'] != null ? DateTime.parse(map['refundedAt'] as String) : null,
      refundMethod: map['refundMethod'] != null
          ? PaymentMethod.values.firstWhere(
              (e) => e.name == map['refundMethod'],
              orElse: () => PaymentMethod.pix,
            )
          : null,
      refundNotes: map['refundNotes'] as String?,
    );
  }

  FinancialTransaction copyWith({
    String? id,
    String? description,
    int? amountCents,
    DateTime? purchaseDate,
    String? categoryId,
    TransactionType? type,
    PaymentMethod? paymentMethod,
    String? personId,
    String? cardId,
    int? totalInstallments,
    String? notes,
    String? sourceNotificationId,
    bool? isCancelled,
    bool? isRecurring,
    RecurrenceFrequency? recurrence,
    String? recurringGroupId,
    DateTime? recurrenceEndedAt,
    List<String>? recurrenceExceptions,
    DateTime? createdAt,
    int? refundAmountCents,
    DateTime? refundedAt,
    PaymentMethod? refundMethod,
    String? refundNotes,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      personId: personId ?? this.personId,
      cardId: cardId ?? this.cardId,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      notes: notes ?? this.notes,
      sourceNotificationId: sourceNotificationId ?? this.sourceNotificationId,
      isCancelled: isCancelled ?? this.isCancelled,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: recurrence ?? this.recurrence,
      recurringGroupId: recurringGroupId ?? this.recurringGroupId,
      recurrenceEndedAt: recurrenceEndedAt ?? this.recurrenceEndedAt,
      recurrenceExceptions: recurrenceExceptions ?? this.recurrenceExceptions,
      createdAt: createdAt ?? this.createdAt,
      refundAmountCents: refundAmountCents ?? this.refundAmountCents,
      refundedAt: refundedAt ?? this.refundedAt,
      refundMethod: refundMethod ?? this.refundMethod,
      refundNotes: refundNotes ?? this.refundNotes,
    );
  }
}
