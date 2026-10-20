import 'dart:math' as math;

import 'package:uuid/uuid.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/money.dart';
import '../entities/credit_card.dart';
import '../entities/dashboard_summary.dart';
import '../entities/financial_movement.dart';
import '../entities/installment.dart';
import '../entities/invoice.dart';
import '../entities/person.dart';
import '../entities/reimbursement.dart';
import '../entities/transaction.dart';
import 'invoice_calculator.dart';
import 'ledger.dart';

class FinancialState {
  final List<FinancialTransaction> transactions;
  final List<Invoice> invoices;
  final List<Installment> installments;
  final List<Reimbursement> reimbursements;
  final List<FinancialMovement> movements;
  final List<CreditCard> cards;
  final List<Person> people;

  const FinancialState({
    this.transactions = const [],
    this.invoices = const [],
    this.installments = const [],
    this.reimbursements = const [],
    this.movements = const [],
    this.cards = const [],
    this.people = const [],
  });

  factory FinancialState.reconciled({
    int availableCents = 0,
    int reserveCents = 0,
    List<FinancialTransaction> transactions = const [],
    List<Invoice> invoices = const [],
    List<Installment> installments = const [],
    List<Reimbursement> reimbursements = const [],
    List<FinancialMovement> movements = const [],
    List<CreditCard> cards = const [],
    List<Person> people = const [],
    DateTime? openingDate,
  }) {
    final earliest = movements.isEmpty
        ? (openingDate ?? DateTime(2000))
        : movements.map((m) => m.movementDate).reduce((a, b) => a.isBefore(b) ? a : b);
    return FinancialState(
      transactions: transactions,
      invoices: invoices,
      installments: installments,
      reimbursements: reimbursements,
      movements: [
        ...Ledger.openingAdjustments(
          movements: movements,
          targetAvailableCents: availableCents,
          targetReserveCents: reserveCents,
          date: earliest,
        ),
        ...movements,
      ],
      cards: cards,
      people: people,
    );
  }

  static final Expando<LedgerBalances> _balancesCache = Expando('balances');

  LedgerBalances get balances => _balancesCache[this] ??= Ledger.balances(movements);

  int get availableCents => balances.available;
  int get reserveCents => balances.reserve;

  double get availableBalance => Money.toReais(availableCents);
  double get reserveBalance => Money.toReais(reserveCents);

  FinancialState copyWith({
    List<FinancialTransaction>? transactions,
    List<Invoice>? invoices,
    List<Installment>? installments,
    List<Reimbursement>? reimbursements,
    List<FinancialMovement>? movements,
    List<CreditCard>? cards,
    List<Person>? people,
  }) {
    return FinancialState(
      transactions: transactions ?? this.transactions,
      invoices: invoices ?? this.invoices,
      installments: installments ?? this.installments,
      reimbursements: reimbursements ?? this.reimbursements,
      movements: movements ?? this.movements,
      cards: cards ?? this.cards,
      people: people ?? this.people,
    );
  }
}

class FinancialMovementEngine {
  static const _uuid = Uuid();

  static List<FinancialMovement> _cashOut({
    required int availableCents,
    required int amountCents,
    required MovementType type,
    required DateTime date,
    required String description,
    required String compensationDescription,
    String? transactionId,
    String? invoiceId,
  }) {
    final deficit = amountCents - math.max<int>(0, availableCents);
    return [
      FinancialMovement(
        id: _uuid.v4(),
        transactionId: transactionId,
        invoiceId: invoiceId,
        type: type,
        amountCents: amountCents,
        movementDate: date,
        description: description,
      ),
      if (deficit > 0)
        FinancialMovement(
          id: _uuid.v4(),
          transactionId: transactionId,
          invoiceId: invoiceId,
          type: MovementType.reserveCompensation,
          amountCents: deficit,
          movementDate: date,
          description: compensationDescription,
        ),
    ];
  }

  static List<FinancialMovement> _movementsForImmediate(FinancialTransaction tx, int availableCents) {
    if (tx.type == TransactionType.income) {
      return [
        FinancialMovement(
          id: _uuid.v4(),
          transactionId: tx.id,
          type: MovementType.income,
          amountCents: tx.amountCents,
          movementDate: tx.purchaseDate,
          description: 'Receita: ${tx.description}',
        ),
      ];
    }
    return _cashOut(
      availableCents: availableCents,
      amountCents: tx.amountCents,
      type: MovementType.expensePaid,
      date: tx.purchaseDate,
      transactionId: tx.id,
      description: 'Despesa: ${tx.description}',
      compensationDescription: 'Complemento de despesas pela reserva',
    );
  }

  static List<Invoice> _recalculateInvoiceTotals(List<Invoice> invoices, List<Installment> installments) {
    final totals = <String, int>{};
    for (final inst in installments) {
      totals[inst.invoiceId] = (totals[inst.invoiceId] ?? 0) + inst.amountCents;
    }
    return [
      for (final inv in invoices) inv.copyWith(totalAmountCents: totals[inv.id] ?? 0),
    ];
  }

  static FinancialState processNewTransaction({
    required FinancialState currentState,
    required FinancialTransaction transaction,
  }) {
    final state = currentState;
    final updatedTransactions = List<FinancialTransaction>.from(state.transactions)..add(transaction);
    final updatedMovements = List<FinancialMovement>.from(state.movements);
    var updatedInvoices = List<Invoice>.from(state.invoices);
    final updatedInstallments = List<Installment>.from(state.installments);
    final updatedReimbursements = List<Reimbursement>.from(state.reimbursements);

    final isFuture = transaction.purchaseDate.isAfter(DateTime.now());

    if (transaction.type == TransactionType.expense && transaction.paymentMethod == PaymentMethod.creditCard) {
      final card = state.cards.firstWhere(
        (c) => c.id == transaction.cardId,
        orElse: () => throw Exception('Cartão de crédito não encontrado para a transação'),
      );

      final newInstallments = InvoiceCalculator.generateInstallments(
        transaction: transaction,
        card: card,
        existingInvoices: updatedInvoices,
        onNewInvoiceNeeded: (newInv) => updatedInvoices.add(newInv),
      );
      updatedInstallments.addAll(newInstallments);
      updatedInvoices = _recalculateInvoiceTotals(updatedInvoices, updatedInstallments);
    } else if (!isFuture) {
      updatedMovements.addAll(_movementsForImmediate(transaction, state.availableCents));
    }

    if (transaction.type == TransactionType.expense && transaction.isForThirdParty) {
      updatedReimbursements.add(
        Reimbursement(
          id: _uuid.v4(),
          personId: transaction.personId,
          transactionId: transaction.id,
          totalAmountCents: transaction.amountCents,
          remainingAmountCents: transaction.amountCents,
          status: ReimbursementStatus.pending,
          createdAt: transaction.purchaseDate,
        ),
      );
    }

    return state.copyWith(
      transactions: updatedTransactions,
      movements: updatedMovements,
      invoices: updatedInvoices,
      installments: updatedInstallments,
      reimbursements: updatedReimbursements,
    );
  }

  static FinancialState transferSurplusToReserve({
    required FinancialState currentState,
    required DateTime periodDate,
  }) {
    final surplus = currentState.availableCents;
    if (surplus <= 0) return currentState;

    final now = DateTime.now();
    final date = periodDate.isAfter(now) ? now : periodDate;

    return currentState.copyWith(
      movements: [
        ...currentState.movements,
        FinancialMovement(
          id: _uuid.v4(),
          type: MovementType.transferToReserve,
          amountCents: surplus,
          movementDate: date,
          description: 'Transferência automática para reserva',
        ),
      ],
    );
  }

  static FinancialState adjustBalances({
    required FinancialState currentState,
    required int availableCents,
    int? reserveCents,
    DateTime? date,
  }) {
    final when = date ?? DateTime.now();
    final isFirst = currentState.movements.isEmpty;
    final diffAvailable = availableCents - currentState.availableCents;
    final diffReserve = reserveCents == null ? 0 : reserveCents - currentState.reserveCents;
    if (diffAvailable == 0 && diffReserve == 0) return currentState;

    return currentState.copyWith(
      movements: [
        ...currentState.movements,
        if (diffAvailable != 0)
          FinancialMovement(
            id: _uuid.v4(),
            type: MovementType.manualAdjustment,
            amountCents: diffAvailable,
            movementDate: when,
            description: isFirst ? 'Saldo inicial' : 'Ajuste de saldo',
          ),
        if (diffReserve != 0)
          FinancialMovement(
            id: _uuid.v4(),
            type: MovementType.reserveAdjustment,
            amountCents: diffReserve,
            movementDate: when,
            description: isFirst ? 'Saldo inicial da caixinha' : 'Ajuste da caixinha',
          ),
      ],
    );
  }

  static FinancialState processInvoicePayment({
    required FinancialState currentState,
    required String invoiceId,
    required DateTime paymentDate,
    int? customAmountCents,
  }) {
    final invoiceIndex = currentState.invoices.indexWhere((inv) => inv.id == invoiceId);
    if (invoiceIndex == -1) throw Exception('Fatura não encontrada');

    final invoice = currentState.invoices[invoiceIndex];
    final amountToPay = customAmountCents ?? invoice.totalAmountCents;

    final updatedMovements = List<FinancialMovement>.from(currentState.movements)
      ..addAll(_cashOut(
        availableCents: currentState.availableCents,
        amountCents: amountToPay,
        type: MovementType.invoicePayment,
        date: paymentDate,
        invoiceId: invoiceId,
        description: 'Pagamento de fatura ${invoice.month}/${invoice.year}',
        compensationDescription: 'Complemento de fatura pela reserva',
      ));

    final updatedInvoices = List<Invoice>.from(currentState.invoices);
    updatedInvoices[invoiceIndex] = invoice.copyWith(
      status: InvoiceStatus.paid,
      paidAt: paymentDate,
      paidAmountCents: amountToPay,
    );

    return currentState.copyWith(
      invoices: updatedInvoices,
      movements: updatedMovements,
    );
  }

  static FinancialState processReimbursementPayment({
    required FinancialState currentState,
    required String reimbursementId,
    required int amountReceivedCents,
    required DateTime paymentDate,
    String? notes,
  }) {
    final reimbIndex = currentState.reimbursements.indexWhere((r) => r.id == reimbursementId);
    if (reimbIndex == -1) throw Exception('Reembolso não encontrado');

    final reimbursement = currentState.reimbursements[reimbIndex];
    final newRemaining = math.max<int>(0, reimbursement.remainingAmountCents - amountReceivedCents);

    final newPayment = ReimbursementPayment(
      id: _uuid.v4(),
      reimbursementId: reimbursementId,
      amountCents: amountReceivedCents,
      paymentDate: paymentDate,
      notes: notes,
    );

    final updatedReimbursements = List<Reimbursement>.from(currentState.reimbursements);
    updatedReimbursements[reimbIndex] = reimbursement.copyWith(
      remainingAmountCents: newRemaining,
      status: newRemaining == 0 ? ReimbursementStatus.settled : ReimbursementStatus.partiallyPaid,
      payments: [...reimbursement.payments, newPayment],
    );

    return currentState.copyWith(
      reimbursements: updatedReimbursements,
      movements: [
        ...currentState.movements,
        FinancialMovement(
          id: _uuid.v4(),
          reimbursementId: reimbursementId,
          type: MovementType.reimbursementReceived,
          amountCents: amountReceivedCents,
          movementDate: paymentDate,
          description: 'Reembolso recebido',
        ),
      ],
    );
  }

  static FinancialState revertReimbursementPayment({
    required FinancialState currentState,
    required String reimbursementId,
    String? paymentId,
  }) {
    final reimbIndex = currentState.reimbursements.indexWhere((r) => r.id == reimbursementId);
    if (reimbIndex == -1) throw Exception('Reembolso não encontrado');

    final reimbursement = currentState.reimbursements[reimbIndex];
    final updatedReimbursements = List<Reimbursement>.from(currentState.reimbursements);
    final updatedMovements = List<FinancialMovement>.from(currentState.movements);

    if (reimbursement.payments.isEmpty) {
      if (reimbursement.paidAmountCents <= 0) return currentState;

      updatedReimbursements[reimbIndex] = reimbursement.copyWith(
        remainingAmountCents: reimbursement.totalAmountCents,
        status: ReimbursementStatus.pending,
      );
      final movIndex = updatedMovements.lastIndexWhere((m) =>
          m.reimbursementId == reimbursementId && m.type == MovementType.reimbursementReceived);
      if (movIndex != -1) updatedMovements.removeAt(movIndex);

      return currentState.copyWith(reimbursements: updatedReimbursements, movements: updatedMovements);
    }

    final paymentIndex = paymentId != null
        ? reimbursement.payments.indexWhere((p) => p.id == paymentId)
        : reimbursement.payments.length - 1;
    if (paymentIndex == -1) throw Exception('Pagamento não encontrado no reembolso');

    final paymentToRevert = reimbursement.payments[paymentIndex];
    final amountToRevert = paymentToRevert.amountCents;
    final updatedPayments = List<ReimbursementPayment>.from(reimbursement.payments)..removeAt(paymentIndex);
    final newRemaining = math.min<int>(reimbursement.totalAmountCents, reimbursement.remainingAmountCents + amountToRevert);

    updatedReimbursements[reimbIndex] = reimbursement.copyWith(
      remainingAmountCents: newRemaining,
      status: newRemaining >= reimbursement.totalAmountCents
          ? ReimbursementStatus.pending
          : ReimbursementStatus.partiallyPaid,
      payments: updatedPayments,
    );

    final movIndex = updatedMovements.lastIndexWhere((m) =>
        m.reimbursementId == reimbursementId &&
        m.type == MovementType.reimbursementReceived &&
        m.amountCents == amountToRevert);
    if (movIndex != -1) updatedMovements.removeAt(movIndex);

    return currentState.copyWith(reimbursements: updatedReimbursements, movements: updatedMovements);
  }

  static FinancialState deleteTransaction({
    required FinancialState currentState,
    required String transactionId,
  }) {
    if (!currentState.transactions.any((t) => t.id == transactionId)) {
      throw Exception('Transação não encontrada');
    }

    final updatedInstallments =
        currentState.installments.where((inst) => inst.transactionId != transactionId).toList();

    return currentState.copyWith(
      transactions: currentState.transactions.where((t) => t.id != transactionId).toList(),
      installments: updatedInstallments,
      invoices: _recalculateInvoiceTotals(currentState.invoices, updatedInstallments),
      reimbursements: currentState.reimbursements.where((r) => r.transactionId != transactionId).toList(),
      movements: currentState.movements.where((m) => m.transactionId != transactionId).toList(),
    );
  }

  static FinancialState processTransactionRefund({
    required FinancialState currentState,
    required String transactionId,
    required int refundAmountCents,
    required PaymentMethod refundMethod,
    DateTime? refundDate,
    String? notes,
  }) {
    final txIndex = currentState.transactions.indexWhere((t) => t.id == transactionId);
    if (txIndex == -1) {
      throw Exception('Transação não encontrada');
    }

    final tx = currentState.transactions[txIndex];
    final refundable = tx.amountCents - tx.refundAmountCents;
    final validRefund = refundAmountCents.clamp(0, math.max<int>(0, refundable));
    if (validRefund <= 0) return currentState;

    final date = refundDate ?? DateTime.now();
    final updatedTransactions = List<FinancialTransaction>.from(currentState.transactions);
    updatedTransactions[txIndex] = tx.copyWith(
      refundAmountCents: tx.refundAmountCents + validRefund,
      refundedAt: date,
      refundMethod: refundMethod,
      refundNotes: notes,
    );

    final updatedMovements = List<FinancialMovement>.from(currentState.movements);
    var updatedInvoices = currentState.invoices;
    final updatedInstallments = List<Installment>.from(currentState.installments);
    final updatedReimbursements = List<Reimbursement>.from(currentState.reimbursements);

    if (refundMethod == PaymentMethod.pix || refundMethod == PaymentMethod.cash || refundMethod == PaymentMethod.other) {
      updatedMovements.add(
        FinancialMovement(
          id: _uuid.v4(),
          transactionId: tx.id,
          type: MovementType.refund,
          amountCents: validRefund,
          movementDate: date,
          description: 'Estorno (${tx.description}): crédito em ${refundMethod == PaymentMethod.pix ? "Pix" : "Dinheiro"}',
        ),
      );
    } else if (tx.paymentMethod == PaymentMethod.creditCard && refundMethod == PaymentMethod.creditCard) {
      var remainingToAbate = validRefund;
      for (var i = updatedInstallments.length - 1; i >= 0 && remainingToAbate > 0; i--) {
        final inst = updatedInstallments[i];
        if (inst.transactionId != tx.id) continue;
        final abate = math.min<int>(remainingToAbate, inst.amountCents);
        remainingToAbate -= abate;
        updatedInstallments[i] = Installment(
          id: inst.id,
          transactionId: inst.transactionId,
          invoiceId: inst.invoiceId,
          installmentNumber: inst.installmentNumber,
          totalInstallments: inst.totalInstallments,
          amountCents: inst.amountCents - abate,
          personId: inst.personId,
        );
      }
      updatedInvoices = _recalculateInvoiceTotals(currentState.invoices, updatedInstallments);

      updatedMovements.add(
        FinancialMovement(
          id: _uuid.v4(),
          transactionId: tx.id,
          type: MovementType.cardRefund,
          amountCents: validRefund,
          movementDate: date,
          description: 'Estorno na fatura (${tx.description}): crédito de ${CurrencyUtils.formatCents(validRefund)}',
        ),
      );
    }

    if (tx.isForThirdParty) {
      final reimbIndex = updatedReimbursements.indexWhere((r) => r.transactionId == tx.id);
      if (reimbIndex != -1) {
        final r = updatedReimbursements[reimbIndex];
        final newRemaining = math.max<int>(0, r.remainingAmountCents - validRefund);
        updatedReimbursements[reimbIndex] = r.copyWith(
          remainingAmountCents: newRemaining,
          status: newRemaining == 0 ? ReimbursementStatus.settled : r.status,
        );
      }
    }

    return currentState.copyWith(
      transactions: updatedTransactions,
      invoices: updatedInvoices,
      installments: updatedInstallments,
      reimbursements: updatedReimbursements,
      movements: updatedMovements,
    );
  }

  static LedgerBalances calculateHistoricalBalancesCents({
    required FinancialState state,
    required int month,
    required int year,
  }) {
    final now = DateTime.now();
    final isPastMonth = year < now.year || (year == now.year && month < now.month);
    final isCurrentMonth = year == now.year && month == now.month;
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    if (isCurrentMonth) return state.balances;
    if (isPastMonth) return Ledger.balances(state.movements, upTo: endOfMonth);

    var projectedAvailable = state.availableCents;
    var projectedReserve = state.reserveCents;

    final futureTx = state.transactions
        .where((t) => !t.isCancelled && t.purchaseDate.isAfter(now) && !t.purchaseDate.isAfter(endOfMonth))
        .toList()
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    for (final t in futureTx) {
      if (t.type == TransactionType.income) {
        projectedAvailable += t.amountCents;
      } else if (!t.isCreditCard) {
        final deficit = t.amountCents - math.max<int>(0, projectedAvailable);
        projectedAvailable -= t.amountCents;
        if (deficit > 0) {
          projectedAvailable += deficit;
          projectedReserve -= deficit;
        }
      }
    }

    return (available: projectedAvailable, reserve: projectedReserve);
  }

  static (double available, double reserve) calculateHistoricalBalances({
    required FinancialState state,
    required int month,
    required int year,
  }) {
    final b = calculateHistoricalBalancesCents(state: state, month: month, year: year);
    return (Money.toReais(b.available), Money.toReais(b.reserve));
  }

  static FinancialState realizeMaturedTransactions(FinancialState state, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    final realized = {
      for (final m in state.movements)
        if (m.transactionId != null) m.transactionId!,
    };

    final matured = state.transactions
        .where((tx) => !tx.isCancelled && !tx.isCreditCard && !tx.purchaseDate.isAfter(refNow) && !realized.contains(tx.id))
        .toList()
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    if (matured.isEmpty) return state;

    var available = state.availableCents;
    final updatedMovements = List<FinancialMovement>.from(state.movements);
    for (final tx in matured) {
      final newMovements = _movementsForImmediate(tx, available);
      for (final m in newMovements) {
        available += Ledger.effectOf(m).available;
      }
      updatedMovements.addAll(newMovements);
    }

    return state.copyWith(movements: updatedMovements);
  }

  static FinancialState syncRecurringTransactions({
    required FinancialState currentState,
    required int targetMonth,
    required int targetYear,
  }) {
    var state = currentState;

    final Map<String, FinancialTransaction> groupBaseMap = {};
    for (final tx in state.transactions) {
      if (!tx.isRecurring || tx.isCancelled || tx.recurrence == RecurrenceFrequency.none) continue;
      final gid = tx.effectiveRecurringGroupId;
      final existing = groupBaseMap[gid];
      if (existing == null || tx.purchaseDate.isBefore(existing.purchaseDate)) {
        groupBaseMap[gid] = tx;
      }
    }

    String occurrenceKey(String groupId, RecurrenceFrequency freq, DateTime date) {
      final byMonth = freq == RecurrenceFrequency.monthly || freq == RecurrenceFrequency.yearly;
      return byMonth ? '$groupId|${date.year}-${date.month}' : '$groupId|${date.year}-${date.month}-${date.day}';
    }

    final existingKeys = <String>{};
    for (final t in state.transactions) {
      if (t.isCancelled) continue;
      final base = groupBaseMap[t.effectiveRecurringGroupId];
      if (base != null) existingKeys.add(occurrenceKey(t.effectiveRecurringGroupId, base.recurrence, t.purchaseDate));
    }

    final targetBoundary = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59);

    for (final baseTx in groupBaseMap.values) {
      final rootId = baseTx.effectiveRecurringGroupId;
      final baseDate = baseTx.purchaseDate;
      final freq = baseTx.recurrence;

      var step = 1;
      const maxSteps = 730;

      while (step <= maxSteps) {
        final nextDate = _nextOccurrence(baseDate, freq, step);

        if (nextDate.isAfter(targetBoundary)) break;

        if (baseTx.recurrenceEndedAt != null && !nextDate.isBefore(baseTx.recurrenceEndedAt!)) break;

        final monthKey = '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}';
        final dateKey = '$monthKey-${nextDate.day.toString().padLeft(2, '0')}';
        final isException = baseTx.recurrenceExceptions.contains(monthKey) ||
            baseTx.recurrenceExceptions.contains(dateKey);

        final key = occurrenceKey(rootId, freq, nextDate);
        if (!isException && !existingKeys.contains(key)) {
          final occTx = baseTx.copyWith(
            id: _uuid.v4(),
            purchaseDate: nextDate,
            recurringGroupId: rootId,
            isRecurring: true,
            totalInstallments: 1,
            createdAt: DateTime.now(),
          );
          state = processNewTransaction(currentState: state, transaction: occTx);
          existingKeys.add(key);
        }

        step++;
      }
    }

    return realizeMaturedTransactions(state);
  }

  static DateTime _nextOccurrence(DateTime baseDate, RecurrenceFrequency freq, int step) {
    switch (freq) {
      case RecurrenceFrequency.daily:
        return baseDate.add(Duration(days: step));
      case RecurrenceFrequency.weekly:
        return baseDate.add(Duration(days: 7 * step));
      case RecurrenceFrequency.biweekly:
        return baseDate.add(Duration(days: 14 * step));
      case RecurrenceFrequency.yearly:
        final nextYear = baseDate.year + step;
        final lastDay = DateTime(nextYear, baseDate.month + 1, 0).day;
        return DateTime(nextYear, baseDate.month, baseDate.day.clamp(1, lastDay), baseDate.hour, baseDate.minute);
      case RecurrenceFrequency.monthly:
      case RecurrenceFrequency.none:
        final totalMonths = (baseDate.year * 12) + (baseDate.month - 1) + step;
        final nextYear = totalMonths ~/ 12;
        final nextMonth = (totalMonths % 12) + 1;
        final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
        return DateTime(nextYear, nextMonth, baseDate.day.clamp(1, lastDay), baseDate.hour, baseDate.minute);
    }
  }

  static int calculateCardUsedLimitCents({
    required FinancialState state,
    required String cardId,
    DateTime? referenceDate,
  }) {
    final card = state.cards.where((c) => c.id == cardId).firstOrNull;
    if (card == null) return 0;

    final now = referenceDate ?? DateTime.now();
    final activePeriod = InvoiceCalculator.getInvoicePeriodForPurchase(
      purchaseDate: now,
      closingDay: card.closingDay,
    );
    bool isUpToActive(Invoice inv) =>
        inv.year < activePeriod.year || (inv.year == activePeriod.year && inv.month <= activePeriod.month);

    var totalUsed = 0;
    final futureInvoiceIds = <String>{};
    for (final inv in state.invoices) {
      if (inv.cardId != cardId || inv.isPaid) continue;
      if (isUpToActive(inv)) {
        totalUsed += inv.totalAmountCents;
      } else {
        futureInvoiceIds.add(inv.id);
      }
    }

    final txById = {for (final t in state.transactions) t.id: t};
    for (final inst in state.installments) {
      if (!futureInvoiceIds.contains(inst.invoiceId)) continue;
      final tx = txById[inst.transactionId];
      if (tx == null || tx.isCancelled) continue;
      if (tx.totalInstallments > 1 && !tx.isRecurring) {
        totalUsed += inst.amountCents;
      }
    }

    return math.max<int>(0, totalUsed);
  }

  static DashboardSummary calculateDashboardSummary({
    required FinancialState state,
    required int month,
    required int year,
    int pendingInboxCount = 0,
  }) {
    final balances = calculateHistoricalBalancesCents(state: state, month: month, year: year);
    bool inPeriod(DateTime d) => d.month == month && d.year == year;

    final committed = state.invoices
        .where((inv) => !inv.isPaid && (inv.year < year || (inv.year == year && inv.month <= month)))
        .fold<int>(0, (acc, inv) => acc + inv.totalAmountCents);

    final reimbSummary = calculateReimbursementsSummary(
      state: state,
      targetMonth: month,
      targetYear: year,
    );

    var incomes = 0;
    var immediateExpenses = 0;
    var creditPurchases = 0;
    var pixExpenses = 0;
    final targetMonthIndex = (year * 12) + (month - 1);

    for (final t in state.transactions) {
      if (t.type == TransactionType.income) {
        if (inPeriod(t.purchaseDate)) incomes += t.netAmountCents;
        continue;
      }
      if (t.isForThirdParty) continue;

      if (!t.isCreditCard) {
        if (inPeriod(t.purchaseDate)) {
          immediateExpenses += t.netAmountCents;
          if (t.isPix) pixExpenses += t.netAmountCents;
        }
        continue;
      }

      if (t.isCancelled) continue;
      if (t.totalInstallments <= 1) {
        if (inPeriod(t.purchaseDate)) creditPurchases += t.netAmountCents;
      } else {
        final diffMonths = targetMonthIndex - ((t.purchaseDate.year * 12) + (t.purchaseDate.month - 1));
        if (diffMonths >= 0 && diffMonths < t.totalInstallments) {
          creditPurchases += Money.installmentAt(t.netAmountCents, t.totalInstallments, diffMonths + 1);
        }
      }
    }

    return DashboardSummary(
      availableCents: balances.available,
      reserveCents: balances.reserve,
      committedCents: committed,
      pendingReimbursementsCents: reimbSummary.monthDueCents,
      totalPendingReimbursementsCents: reimbSummary.totalPendingCents,
      periodIncomesCents: incomes,
      periodPaidExpensesCents: immediateExpenses + creditPurchases,
      periodCreditPurchasesCents: creditPurchases,
      periodPixExpensesCents: pixExpenses,
      pendingInboxCount: pendingInboxCount,
    );
  }

  static int calculateReimbursementDueForMonthCents({
    required FinancialTransaction transaction,
    required Reimbursement reimbursement,
    required int targetMonth,
    required int targetYear,
  }) {
    if (reimbursement.isSettled) return 0;

    if (transaction.totalInstallments <= 1) {
      final inMonth = transaction.purchaseDate.month == targetMonth && transaction.purchaseDate.year == targetYear;
      return inMonth ? reimbursement.remainingAmountCents : 0;
    }

    final totalPaid = reimbursement.paidAmountCents;
    final parts = Money.splitInstallments(transaction.amountCents, transaction.totalInstallments);
    final purchaseMonthIndex = (transaction.purchaseDate.year * 12) + (transaction.purchaseDate.month - 1);
    final targetMonthIndex = (targetYear * 12) + (targetMonth - 1);

    var instStart = 0;
    var dueThisMonth = 0;
    for (var i = 0; i < parts.length; i++) {
      final amt = parts[i];
      final instEnd = instStart + amt;
      if (purchaseMonthIndex + i == targetMonthIndex) {
        final paidForThisInst = (totalPaid - instStart).clamp(0, amt);
        dueThisMonth += amt - paidForThisInst;
      }
      instStart = instEnd;
    }

    return dueThisMonth.clamp(0, math.max<int>(0, reimbursement.remainingAmountCents));
  }

  static bool isReimbursementActiveInMonth({
    required FinancialTransaction transaction,
    required int targetMonth,
    required int targetYear,
  }) {
    final purchaseMonthIndex = (transaction.purchaseDate.year * 12) + (transaction.purchaseDate.month - 1);
    final targetMonthIndex = (targetYear * 12) + (targetMonth - 1);
    final months = math.max<int>(1, transaction.totalInstallments);
    return targetMonthIndex >= purchaseMonthIndex && targetMonthIndex < purchaseMonthIndex + months;
  }

  static ({int month, int year}) getReimbursementPaymentReferencePeriod({
    required FinancialTransaction transaction,
    required Reimbursement reimbursement,
    ReimbursementPayment? payment,
    int? paymentIndex,
  }) {
    if (payment?.notes != null) {
      final match = RegExp(r'm[êe]s\s+(\d+)/(\d+)', caseSensitive: false).firstMatch(payment!.notes!);
      if (match != null) {
        final m = int.tryParse(match.group(1)!);
        final y = int.tryParse(match.group(2)!);
        if (m != null && y != null) {
          return (month: m, year: y);
        }
      }
    }

    if (transaction.totalInstallments <= 1) {
      return (month: transaction.purchaseDate.month, year: transaction.purchaseDate.year);
    }

    final idx = paymentIndex ?? (payment != null ? reimbursement.payments.indexOf(payment) : 0);
    final instNumber = (idx >= 0 ? idx : 0) + 1;
    final totalMonths = (transaction.purchaseDate.year * 12) + (transaction.purchaseDate.month - 1) + (instNumber - 1);
    return (month: (totalMonths % 12) + 1, year: totalMonths ~/ 12);
  }

  static ({
    int monthDueCents,
    int totalPendingCents,
    int activeDebtorsCount,
    List<Person> activeDebtorsInMonth,
    Map<String, int> personMonthDueCentsMap,
  }) calculateReimbursementsSummary({
    required FinancialState state,
    required int targetMonth,
    required int targetYear,
  }) {
    final txById = {for (final t in state.transactions) t.id: t};
    FinancialTransaction txFor(Reimbursement r) =>
        txById[r.transactionId] ??
        FinancialTransaction(
          id: r.transactionId,
          description: '',
          amountCents: r.totalAmountCents,
          purchaseDate: r.createdAt,
          categoryId: 'cat_other',
          paymentMethod: PaymentMethod.pix,
        );

    final pendingTotal = state.reimbursements
        .where((r) => !r.isSettled)
        .fold<int>(0, (acc, r) => acc + r.remainingAmountCents);

    final debtorsInMonth = <Person>[];
    final personMonthDueMap = <String, int>{};
    var totalDue = 0;

    for (final person in state.people) {
      if (person.isMe) continue;
      final personReimbs = state.reimbursements.where((r) => r.personId == person.id && !r.isSettled).toList();
      final isActive = personReimbs.any((r) => isReimbursementActiveInMonth(
            transaction: txFor(r),
            targetMonth: targetMonth,
            targetYear: targetYear,
          ));
      if (!isActive) continue;

      debtorsInMonth.add(person);
      final personDue = personReimbs.fold<int>(
        0,
        (acc, r) => acc +
            calculateReimbursementDueForMonthCents(
              transaction: txFor(r),
              reimbursement: r,
              targetMonth: targetMonth,
              targetYear: targetYear,
            ),
      );
      personMonthDueMap[person.id] = personDue;
      totalDue += personDue;
    }

    return (
      monthDueCents: totalDue,
      totalPendingCents: pendingTotal,
      activeDebtorsCount: debtorsInMonth.length,
      activeDebtorsInMonth: debtorsInMonth,
      personMonthDueCentsMap: personMonthDueMap,
    );
  }
}
