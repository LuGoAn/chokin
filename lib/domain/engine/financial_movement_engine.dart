import 'package:uuid/uuid.dart';
import '../../core/utils/currency_utils.dart';
import '../entities/credit_card.dart';
import '../entities/dashboard_summary.dart';
import '../entities/financial_movement.dart';
import '../entities/installment.dart';
import '../entities/invoice.dart';
import '../entities/person.dart';
import '../entities/reimbursement.dart';
import '../entities/transaction.dart';
import 'invoice_calculator.dart';

class FinancialState {
  final double availableBalance;
  final double reserveBalance;
  final List<FinancialTransaction> transactions;
  final List<Invoice> invoices;
  final List<Installment> installments;
  final List<Reimbursement> reimbursements;
  final List<FinancialMovement> movements;
  final List<CreditCard> cards;
  final List<Person> people;

  const FinancialState({
    this.availableBalance = 0.0,
    this.reserveBalance = 0.0,
    this.transactions = const [],
    this.invoices = const [],
    this.installments = const [],
    this.reimbursements = const [],
    this.movements = const [],
    this.cards = const [],
    this.people = const [],
  });

  FinancialState copyWith({
    double? availableBalance,
    double? reserveBalance,
    List<FinancialTransaction>? transactions,
    List<Invoice>? invoices,
    List<Installment>? installments,
    List<Reimbursement>? reimbursements,
    List<FinancialMovement>? movements,
    List<CreditCard>? cards,
    List<Person>? people,
  }) {
    return FinancialState(
      availableBalance: availableBalance ?? this.availableBalance,
      reserveBalance: reserveBalance ?? this.reserveBalance,
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

  /// Processa a adição de uma nova transação financeira
  static FinancialState processNewTransaction({
    required FinancialState currentState,
    required FinancialTransaction transaction,
  }) {
    var state = currentState;
    final updatedTransactions = List<FinancialTransaction>.from(state.transactions)..add(transaction);
    final updatedMovements = List<FinancialMovement>.from(state.movements);
    final updatedInvoices = List<Invoice>.from(state.invoices);
    final updatedInstallments = List<Installment>.from(state.installments);
    final updatedReimbursements = List<Reimbursement>.from(state.reimbursements);

    var newAvailable = state.availableBalance;
    var newReserve = state.reserveBalance;

    final isFuture = transaction.purchaseDate.isAfter(DateTime.now());

    if (transaction.type == TransactionType.income) {
      // 1. Receita: Incrementa o saldo disponível apenas se a transação for do presente ou passado
      if (!isFuture) {
        newAvailable += transaction.amount;
        updatedMovements.add(
          FinancialMovement(
            id: _uuid.v4(),
            transactionId: transaction.id,
            type: MovementType.income,
            amount: transaction.amount,
            movementDate: transaction.purchaseDate,
            description: 'Receita: ${transaction.description}',
          ),
        );
      }
    } else {
      // 2. Despesa
      if (transaction.paymentMethod == PaymentMethod.creditCard) {
        // 2.1 Cartão de crédito: NÃO retira dinheiro na hora da compra!
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

        // Recalcula o total de cada fatura afetada
        for (var i = 0; i < updatedInvoices.length; i++) {
          final inv = updatedInvoices[i];
          final invoiceInstallments = updatedInstallments.where((inst) => inst.invoiceId == inv.id);
          final sum = invoiceInstallments.fold<double>(0.0, (acc, inst) => acc + inst.amount);
          updatedInvoices[i] = inv.copyWith(totalAmount: sum);
        }

        // Se for para terceiro, cria reembolso
        if (transaction.isForThirdParty) {
          updatedReimbursements.add(
            Reimbursement(
              id: _uuid.v4(),
              personId: transaction.personId,
              transactionId: transaction.id,
              totalAmount: transaction.amount,
              remainingAmount: transaction.amount,
              status: ReimbursementStatus.pending,
              createdAt: transaction.purchaseDate,
            ),
          );
        }
      } else {
        // 2.2 Despesa Imediata (Pix, Dinheiro, Débito)
        // O dinheiro sai imediatamente apenas se a transação já ocorreu ou é de hoje
        if (!isFuture) {
          if (newAvailable >= transaction.amount) {
            newAvailable -= transaction.amount;
            updatedMovements.add(
              FinancialMovement(
                id: _uuid.v4(),
                transactionId: transaction.id,
                type: MovementType.expensePaid,
                amount: transaction.amount,
                movementDate: transaction.purchaseDate,
                description: 'Despesa: ${transaction.description}',
              ),
            );
          } else {
            // Gasto maior que a receita disponível: usa a caixinha/reserva para cobrir o déficit
            final deficit = transaction.amount - newAvailable;
            newAvailable = 0.0;
            newReserve -= deficit;

            // Registra a saída da despesa
            updatedMovements.add(
              FinancialMovement(
                id: _uuid.v4(),
                transactionId: transaction.id,
                type: MovementType.expensePaid,
                amount: transaction.amount,
                movementDate: transaction.purchaseDate,
                description: 'Despesa: ${transaction.description}',
              ),
            );

            // Registra o complemento automático pela reserva
            updatedMovements.add(
              FinancialMovement(
                id: _uuid.v4(),
                transactionId: transaction.id,
                type: MovementType.reserveCompensation,
                amount: deficit,
                movementDate: transaction.purchaseDate,
                description: 'Complemento de despesas pela reserva',
              ),
            );
          }
        }

        // Se a despesa imediata foi para terceiro, registra o valor a receber
        if (transaction.isForThirdParty) {
          updatedReimbursements.add(
            Reimbursement(
              id: _uuid.v4(),
              personId: transaction.personId,
              transactionId: transaction.id,
              totalAmount: transaction.amount,
              remainingAmount: transaction.amount,
              status: ReimbursementStatus.pending,
              createdAt: transaction.purchaseDate,
            ),
          );
        }
      }
    }

    return state.copyWith(
      availableBalance: double.parse(newAvailable.toStringAsFixed(2)),
      reserveBalance: double.parse(newReserve.toStringAsFixed(2)),
      transactions: updatedTransactions,
      movements: updatedMovements,
      invoices: updatedInvoices,
      installments: updatedInstallments,
      reimbursements: updatedReimbursements,
    );
  }

  /// Transfere automaticamente a sobra mensal para a caixinha
  static FinancialState transferSurplusToReserve({
    required FinancialState currentState,
    required DateTime periodDate,
  }) {
    if (currentState.availableBalance <= 0) return currentState;

    final surplus = currentState.availableBalance;
    final updatedMovements = List<FinancialMovement>.from(currentState.movements)
      ..add(
        FinancialMovement(
          id: _uuid.v4(),
          type: MovementType.transferToReserve,
          amount: surplus,
          movementDate: periodDate,
          description: 'Transferência automática para reserva',
        ),
      );

    return currentState.copyWith(
      availableBalance: 0.0,
      reserveBalance: double.parse((currentState.reserveBalance + surplus).toStringAsFixed(2)),
      movements: updatedMovements,
    );
  }

  /// Processa o pagamento de uma fatura de cartão de crédito
  static FinancialState processInvoicePayment({
    required FinancialState currentState,
    required String invoiceId,
    required DateTime paymentDate, // Data real do pagamento (ex: 04/09 em vez de 08/09)
    double? customAmount,
  }) {
    final invoiceIndex = currentState.invoices.indexWhere((inv) => inv.id == invoiceId);
    if (invoiceIndex == -1) throw Exception('Fatura não encontrada');

    final invoice = currentState.invoices[invoiceIndex];
    final amountToPay = customAmount ?? invoice.totalAmount;

    var newAvailable = currentState.availableBalance;
    var newReserve = currentState.reserveBalance;
    final updatedMovements = List<FinancialMovement>.from(currentState.movements);

    // Retira do disponível ou complementa com a caixinha
    if (newAvailable >= amountToPay) {
      newAvailable -= amountToPay;
    } else {
      final deficit = amountToPay - newAvailable;
      newAvailable = 0.0;
      newReserve -= deficit;

      updatedMovements.add(
        FinancialMovement(
          id: _uuid.v4(),
          invoiceId: invoiceId,
          type: MovementType.reserveCompensation,
          amount: deficit,
          movementDate: paymentDate,
          description: 'Complemento de fatura pela reserva',
        ),
      );
    }

    // Registra a movimentação de pagamento da fatura
    updatedMovements.add(
      FinancialMovement(
        id: _uuid.v4(),
        invoiceId: invoiceId,
        type: MovementType.invoicePayment,
        amount: amountToPay,
        movementDate: paymentDate,
        description: 'Pagamento de fatura ${invoice.month}/${invoice.year}',
      ),
    );

    // Atualiza status da fatura
    final updatedInvoices = List<Invoice>.from(currentState.invoices);
    updatedInvoices[invoiceIndex] = invoice.copyWith(
      status: InvoiceStatus.paid,
      paidAt: paymentDate,
      paidAmount: amountToPay,
    );

    return currentState.copyWith(
      availableBalance: double.parse(newAvailable.toStringAsFixed(2)),
      reserveBalance: double.parse(newReserve.toStringAsFixed(2)),
      invoices: updatedInvoices,
      movements: updatedMovements,
    );
  }

  /// Processa um reembolso recebido de terceiro (total ou parcial)
  static FinancialState processReimbursementPayment({
    required FinancialState currentState,
    required String reimbursementId,
    required double amountReceived,
    required DateTime paymentDate,
    String? notes,
  }) {
    final reimbIndex = currentState.reimbursements.indexWhere((r) => r.id == reimbursementId);
    if (reimbIndex == -1) throw Exception('Reembolso não encontrado');

    final reimbursement = currentState.reimbursements[reimbIndex];
    final newRemaining = double.parse((reimbursement.remainingAmount - amountReceived).toStringAsFixed(2));
    final newStatus = (newRemaining <= 0.001) ? ReimbursementStatus.settled : ReimbursementStatus.partiallyPaid;

    final newPayment = ReimbursementPayment(
      id: _uuid.v4(),
      reimbursementId: reimbursementId,
      amount: amountReceived,
      paymentDate: paymentDate,
      notes: notes,
    );

    final updatedPayments = List<ReimbursementPayment>.from(reimbursement.payments)..add(newPayment);
    final updatedReimbursements = List<Reimbursement>.from(currentState.reimbursements);
    updatedReimbursements[reimbIndex] = reimbursement.copyWith(
      remainingAmount: newRemaining < 0 ? 0.0 : newRemaining,
      status: newStatus,
      payments: updatedPayments,
    );

    // Entrada de dinheiro no disponível
    final newAvailable = currentState.availableBalance + amountReceived;
    final updatedMovements = List<FinancialMovement>.from(currentState.movements)
      ..add(
        FinancialMovement(
          id: _uuid.v4(),
          reimbursementId: reimbursementId,
          type: MovementType.reimbursementReceived,
          amount: amountReceived,
          movementDate: paymentDate,
          description: 'Reembolso recebido',
        ),
      );

    return currentState.copyWith(
      availableBalance: double.parse(newAvailable.toStringAsFixed(2)),
      reimbursements: updatedReimbursements,
      movements: updatedMovements,
    );
  }

  /// Desfaz / cancela a quitação (ou pagamento parcial) de um reembolso
  static FinancialState revertReimbursementPayment({
    required FinancialState currentState,
    required String reimbursementId,
    String? paymentId,
  }) {
    final reimbIndex = currentState.reimbursements.indexWhere((r) => r.id == reimbursementId);
    if (reimbIndex == -1) throw Exception('Reembolso não encontrado');

    final reimbursement = currentState.reimbursements[reimbIndex];
    if (reimbursement.payments.isEmpty) {
      final amountToRevert = reimbursement.totalAmount - reimbursement.remainingAmount;
      if (amountToRevert <= 0) return currentState;

      final updatedReimbursements = List<Reimbursement>.from(currentState.reimbursements);
      updatedReimbursements[reimbIndex] = reimbursement.copyWith(
        remainingAmount: reimbursement.totalAmount,
        status: ReimbursementStatus.pending,
      );

      final newAvailable = (currentState.availableBalance - amountToRevert).clamp(0.0, double.infinity);
      final updatedMovements = List<FinancialMovement>.from(currentState.movements);
      final movIndex = updatedMovements.lastIndexWhere((m) =>
          m.reimbursementId == reimbursementId && m.type == MovementType.reimbursementReceived);
      if (movIndex != -1) {
        updatedMovements.removeAt(movIndex);
      }

      return currentState.copyWith(
        availableBalance: double.parse(newAvailable.toStringAsFixed(2)),
        reimbursements: updatedReimbursements,
        movements: updatedMovements,
      );
    }

    final paymentIndex = paymentId != null
        ? reimbursement.payments.indexWhere((p) => p.id == paymentId)
        : reimbursement.payments.length - 1;

    if (paymentIndex == -1) throw Exception('Pagamento não encontrado no reembolso');

    final paymentToRevert = reimbursement.payments[paymentIndex];
    final amountToRevert = paymentToRevert.amount;

    final updatedPayments = List<ReimbursementPayment>.from(reimbursement.payments)..removeAt(paymentIndex);
    final newRemaining = double.parse((reimbursement.remainingAmount + amountToRevert).toStringAsFixed(2));
    final newStatus = (newRemaining >= reimbursement.totalAmount - 0.001)
        ? ReimbursementStatus.pending
        : ReimbursementStatus.partiallyPaid;

    final updatedReimbursements = List<Reimbursement>.from(currentState.reimbursements);
    updatedReimbursements[reimbIndex] = reimbursement.copyWith(
      remainingAmount: newRemaining > reimbursement.totalAmount ? reimbursement.totalAmount : newRemaining,
      status: newStatus,
      payments: updatedPayments,
    );

    final newAvailable = (currentState.availableBalance - amountToRevert).clamp(0.0, double.infinity);

    final updatedMovements = List<FinancialMovement>.from(currentState.movements);
    final movIndex = updatedMovements.lastIndexWhere((m) =>
        m.reimbursementId == reimbursementId &&
        m.type == MovementType.reimbursementReceived &&
        (m.amount - amountToRevert).abs() < 0.01);
    if (movIndex != -1) {
      updatedMovements.removeAt(movIndex);
    }

    return currentState.copyWith(
      availableBalance: double.parse(newAvailable.toStringAsFixed(2)),
      reimbursements: updatedReimbursements,
      movements: updatedMovements,
    );
  }

  /// Exclui uma transação e recalcula atomicamente todo o impacto financeiro
  static FinancialState deleteTransaction({
    required FinancialState currentState,
    required String transactionId,
  }) {
    final transaction = currentState.transactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => throw Exception('Transação não encontrada'),
    );

    // Remove transação
    final updatedTransactions = currentState.transactions.where((t) => t.id != transactionId).toList();
    
    // Remove parcelas associadas
    final updatedInstallments = currentState.installments.where((inst) => inst.transactionId != transactionId).toList();

    // Remove reembolsos associados
    final updatedReimbursements = currentState.reimbursements.where((r) => r.transactionId != transactionId).toList();

    // Recalcula totais das faturas
    final updatedInvoices = currentState.invoices.map((inv) {
      final invoiceInstallments = updatedInstallments.where((inst) => inst.invoiceId == inv.id);
      final sum = invoiceInstallments.fold<double>(0.0, (acc, inst) => acc + inst.amount);
      return inv.copyWith(totalAmount: sum);
    }).toList();

    // Reverte saldo se era receita ou despesa imediata E se essa transação já tinha gerado movimentação no saldo
    var newAvailable = currentState.availableBalance;
    var newReserve = currentState.reserveBalance;
    final hadMovement = currentState.movements.any((m) => m.transactionId == transactionId);
    final updatedMovements = currentState.movements.where((m) => m.transactionId != transactionId).toList();

    if (hadMovement) {
      if (transaction.type == TransactionType.income) {
        newAvailable -= transaction.amount;
      } else if (transaction.paymentMethod != PaymentMethod.creditCard) {
        newAvailable += transaction.amount;
      }
    }

    return currentState.copyWith(
      availableBalance: double.parse(newAvailable.toStringAsFixed(2)),
      reserveBalance: double.parse(newReserve.toStringAsFixed(2)),
      transactions: updatedTransactions,
      invoices: updatedInvoices,
      installments: updatedInstallments,
      reimbursements: updatedReimbursements,
      movements: updatedMovements,
    );
  }

  /// Processa o estorno (total ou parcial) de uma transação financeira
  static FinancialState processTransactionRefund({
    required FinancialState currentState,
    required String transactionId,
    required double refundAmount,
    required PaymentMethod refundMethod,
    DateTime? refundDate,
    String? notes,
  }) {
    final txIndex = currentState.transactions.indexWhere((t) => t.id == transactionId);
    if (txIndex == -1) {
      throw Exception('Transação não encontrada');
    }

    final tx = currentState.transactions[txIndex];
    final validRefundAmount = refundAmount.clamp(0.0, tx.amount);
    if (validRefundAmount <= 0) return currentState;

    final date = refundDate ?? DateTime.now();
    final updatedTx = tx.copyWith(
      refundAmount: validRefundAmount,
      refundedAt: date,
      refundMethod: refundMethod,
      refundNotes: notes,
    );

    final updatedTransactions = List<FinancialTransaction>.from(currentState.transactions);
    updatedTransactions[txIndex] = updatedTx;

    var newAvailable = currentState.availableBalance;
    final updatedMovements = List<FinancialMovement>.from(currentState.movements);
    final updatedInvoices = List<Invoice>.from(currentState.invoices);
    final updatedInstallments = List<Installment>.from(currentState.installments);
    final updatedReimbursements = List<Reimbursement>.from(currentState.reimbursements);

    // 1. Tratamento do Saldo em Conta / Dinheiro
    // Se o estorno foi recebido via Pix/Dinheiro (seja a compra original Pix, Dinheiro ou Cartão)
    if (refundMethod == PaymentMethod.pix || refundMethod == PaymentMethod.cash || refundMethod == PaymentMethod.other) {
      newAvailable += validRefundAmount;
      updatedMovements.add(
        FinancialMovement(
          id: _uuid.v4(),
          transactionId: tx.id,
          type: MovementType.refund,
          amount: validRefundAmount,
          movementDate: date,
          description: 'Estorno (${tx.description}): crédito em ${refundMethod == PaymentMethod.pix ? "Pix" : "Dinheiro"}',
        ),
      );
    } else if (tx.paymentMethod == PaymentMethod.creditCard && refundMethod == PaymentMethod.creditCard) {
      // 2. Estorno direto na fatura do cartão de crédito
      // Abate das parcelas da transação começando da última para a primeira
      var remainingToAbate = validRefundAmount;
      for (var i = updatedInstallments.length - 1; i >= 0; i--) {
        final inst = updatedInstallments[i];
        if (inst.transactionId == tx.id && remainingToAbate > 0) {
          final abate = remainingToAbate.clamp(0.0, inst.amount);
          final newInstAmount = inst.amount - abate;
          remainingToAbate -= abate;
          updatedInstallments[i] = Installment(
            id: inst.id,
            transactionId: inst.transactionId,
            invoiceId: inst.invoiceId,
            installmentNumber: inst.installmentNumber,
            totalInstallments: inst.totalInstallments,
            amount: double.parse(newInstAmount.toStringAsFixed(2)),
            personId: inst.personId,
          );
        }
      }

      // Recalcula totais das faturas afetadas
      for (var i = 0; i < updatedInvoices.length; i++) {
        final inv = updatedInvoices[i];
        final invoiceInstallments = updatedInstallments.where((inst) => inst.invoiceId == inv.id);
        final sum = invoiceInstallments.fold<double>(0.0, (acc, inst) => acc + inst.amount);
        updatedInvoices[i] = inv.copyWith(totalAmount: double.parse(sum.toStringAsFixed(2)));
      }

      updatedMovements.add(
        FinancialMovement(
          id: _uuid.v4(),
          transactionId: tx.id,
          type: MovementType.refund,
          amount: validRefundAmount,
          movementDate: date,
          description: 'Estorno na fatura (${tx.description}): crédito de ${CurrencyUtils.format(validRefundAmount)}',
        ),
      );
    }

    // 3. Se a compra era para terceiro (Reembolso), abate a dívida do terceiro
    if (tx.isForThirdParty) {
      final reimbIndex = updatedReimbursements.indexWhere((r) => r.transactionId == tx.id);
      if (reimbIndex != -1) {
        final r = updatedReimbursements[reimbIndex];
        final newRemaining = (r.remainingAmount - validRefundAmount).clamp(0.0, r.totalAmount);
        final isSettled = newRemaining <= 0;
        updatedReimbursements[reimbIndex] = r.copyWith(
          remainingAmount: double.parse(newRemaining.toStringAsFixed(2)),
          status: isSettled ? ReimbursementStatus.settled : r.status,
        );
      }
    }

    return currentState.copyWith(
      availableBalance: double.parse(newAvailable.toStringAsFixed(2)),
      transactions: updatedTransactions,
      invoices: updatedInvoices,
      installments: updatedInstallments,
      reimbursements: updatedReimbursements,
      movements: updatedMovements,
    );
  }

  /// Calcula os saldos históricos ou projetados no final de um determinado mês a partir do ledger
  static (double available, double reserve) calculateHistoricalBalances({
    required FinancialState state,
    required int month,
    required int year,
  }) {
    final now = DateTime.now();
    final isPastMonth = year < now.year || (year == now.year && month < now.month);
    final isCurrentMonth = year == now.year && month == now.month;
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    // Mês Atual: O saldo é exatamente o saldo disponível e reserva em conta HOJE
    if (isCurrentMonth) {
      return (
        double.parse(state.availableBalance.clamp(0.0, double.infinity).toStringAsFixed(2)),
        double.parse(state.reserveBalance.clamp(0.0, double.infinity).toStringAsFixed(2)),
      );
    }

    // Mês Passado: Reverte as movimentações que ocorreram após o final do mês selecionado até o presente
    if (isPastMonth) {
      final hasAnyActivityUpToMonth = state.movements.any((m) => !m.movementDate.isAfter(endOfMonth)) ||
          state.transactions.any((t) => !t.purchaseDate.isAfter(endOfMonth));

      if (!hasAnyActivityUpToMonth) {
        return (0.0, 0.0);
      }

      var histAvailable = state.availableBalance;
      var histReserve = state.reserveBalance;

      final laterMovements = state.movements
          .where((m) => m.movementDate.isAfter(endOfMonth) && !m.movementDate.isAfter(now))
          .toList()
        ..sort((a, b) => b.movementDate.compareTo(a.movementDate));

      for (final m in laterMovements) {
        switch (m.type) {
          case MovementType.income:
          case MovementType.reimbursementReceived:
          case MovementType.refund:
            histAvailable -= m.amount;
            break;
          case MovementType.expensePaid:
            histAvailable += m.amount;
            break;
          case MovementType.invoicePayment:
            final compensations = laterMovements.where((other) =>
                other.type == MovementType.reserveCompensation &&
                other.invoiceId == m.invoiceId &&
                other.movementDate == m.movementDate);
            final def = compensations.fold<double>(0.0, (acc, c) => acc + c.amount);
            histReserve += def;
            histAvailable += (m.amount - def);
            break;
          case MovementType.reserveCompensation:
            break;
          case MovementType.transferToReserve:
            histAvailable += m.amount;
            histReserve -= m.amount;
            break;
          case MovementType.manualAdjustment:
            break;
        }
      }

      return (
        double.parse(histAvailable.clamp(0.0, double.infinity).toStringAsFixed(2)),
        double.parse(histReserve.clamp(0.0, double.infinity).toStringAsFixed(2)),
      );
    }

    // Mês Futuro: Projeta o saldo a partir do saldo atual aplicando receitas e despesas imediatas planejadas até o final daquele mês
    var projectedAvailable = state.availableBalance;
    var projectedReserve = state.reserveBalance;

    final futureTx = state.transactions
        .where((t) => !t.isCancelled && t.purchaseDate.isAfter(now) && !t.purchaseDate.isAfter(endOfMonth))
        .toList()
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    for (final t in futureTx) {
      if (t.type == TransactionType.income) {
        projectedAvailable += t.amount;
      } else if (t.type == TransactionType.expense && !t.isCreditCard) {
        if (projectedAvailable >= t.amount) {
          projectedAvailable -= t.amount;
        } else {
          final deficit = t.amount - projectedAvailable;
          projectedAvailable = 0.0;
          projectedReserve -= deficit;
        }
      }
    }

    return (
      double.parse(projectedAvailable.clamp(0.0, double.infinity).toStringAsFixed(2)),
      double.parse(projectedReserve.clamp(0.0, double.infinity).toStringAsFixed(2)),
    );
  }

  /// Converte transações agendadas/recorrentes cuja data de compra já chegou (<= now)
  /// e que ainda não geraram movimentação no ledger em movimentações financeiras efetivas.
  static FinancialState realizeMaturedTransactions(FinancialState state, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    var currentState = state;
    final updatedMovements = List<FinancialMovement>.from(currentState.movements);
    var newAvailable = currentState.availableBalance;
    var newReserve = currentState.reserveBalance;
    var changed = false;

    for (final tx in currentState.transactions) {
      if (tx.isCancelled || tx.isCreditCard) continue;
      if (tx.purchaseDate.isAfter(refNow)) continue;

      final hasMovement = updatedMovements.any((m) => m.transactionId == tx.id);
      if (!hasMovement) {
        changed = true;
        if (tx.type == TransactionType.income) {
          newAvailable += tx.amount;
          updatedMovements.add(
            FinancialMovement(
              id: _uuid.v4(),
              transactionId: tx.id,
              type: MovementType.income,
              amount: tx.amount,
              movementDate: tx.purchaseDate,
              description: 'Receita: ${tx.description}',
            ),
          );
        } else if (tx.type == TransactionType.expense) {
          if (newAvailable >= tx.amount) {
            newAvailable -= tx.amount;
            updatedMovements.add(
              FinancialMovement(
                id: _uuid.v4(),
                transactionId: tx.id,
                type: MovementType.expensePaid,
                amount: tx.amount,
                movementDate: tx.purchaseDate,
                description: 'Despesa: ${tx.description}',
              ),
            );
          } else {
            final deficit = tx.amount - newAvailable;
            newAvailable = 0.0;
            newReserve -= deficit;

            updatedMovements.add(
              FinancialMovement(
                id: _uuid.v4(),
                transactionId: tx.id,
                type: MovementType.expensePaid,
                amount: tx.amount,
                movementDate: tx.purchaseDate,
                description: 'Despesa: ${tx.description}',
              ),
            );
            updatedMovements.add(
              FinancialMovement(
                id: _uuid.v4(),
                transactionId: tx.id,
                type: MovementType.reserveCompensation,
                amount: deficit,
                movementDate: tx.purchaseDate,
                description: 'Complemento de despesas pela reserva',
              ),
            );
          }
        }
      }
    }

    if (!changed) return currentState;

    return currentState.copyWith(
      availableBalance: double.parse(newAvailable.toStringAsFixed(2)),
      reserveBalance: double.parse(newReserve.toStringAsFixed(2)),
      movements: updatedMovements,
    );
  }

  /// Sincroniza e projeta transações recorrentes ativas até o mês/ano alvo
  static FinancialState syncRecurringTransactions({
    required FinancialState currentState,
    required int targetMonth,
    required int targetYear,
  }) {
    var state = currentState;

    // Encontra todas as transações base que são recorrentes agrupadas por effectiveRecurringGroupId
    final recurringTxs = state.transactions.where((t) {
      return t.isRecurring && !t.isCancelled && t.recurrence != RecurrenceFrequency.none;
    }).toList();

    final Map<String, FinancialTransaction> groupBaseMap = {};
    for (final tx in recurringTxs) {
      final gid = tx.effectiveRecurringGroupId;
      final existing = groupBaseMap[gid];
      if (existing == null || tx.purchaseDate.isBefore(existing.purchaseDate)) {
        groupBaseMap[gid] = tx;
      }
    }
    final recurringBases = groupBaseMap.values.toList();

    final targetBoundary = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59);

    for (final baseTx in recurringBases) {
      final rootId = baseTx.effectiveRecurringGroupId;
      final baseDate = baseTx.purchaseDate;
      final freq = baseTx.recurrence;

      if (freq == RecurrenceFrequency.none) continue;

      var step = 1;
      const maxSteps = 730; // Limite de segurança de 2 anos para evitar loops infinitos

      while (step <= maxSteps) {
        DateTime nextDate;

        switch (freq) {
          case RecurrenceFrequency.daily:
            nextDate = baseDate.add(Duration(days: step));
            break;
          case RecurrenceFrequency.weekly:
            nextDate = baseDate.add(Duration(days: 7 * step));
            break;
          case RecurrenceFrequency.biweekly:
            nextDate = baseDate.add(Duration(days: 14 * step));
            break;
          case RecurrenceFrequency.yearly:
            final nextYear = baseDate.year + step;
            final nextMonth = baseDate.month;
            final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
            final day = baseDate.day.clamp(1, lastDay);
            nextDate = DateTime(nextYear, nextMonth, day, baseDate.hour, baseDate.minute);
            break;
          case RecurrenceFrequency.monthly:
          default:
            final totalMonths = (baseDate.year * 12) + (baseDate.month - 1) + step;
            final nextYear = totalMonths ~/ 12;
            final nextMonth = (totalMonths % 12) + 1;
            final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
            final day = baseDate.day.clamp(1, lastDay);
            nextDate = DateTime(nextYear, nextMonth, day, baseDate.hour, baseDate.minute);
            break;
        }

        if (nextDate.isAfter(targetBoundary)) {
          break;
        }

        // Verifica se a série recorrente foi encerrada antes desta data
        if (baseTx.recurrenceEndedAt != null && !nextDate.isBefore(baseTx.recurrenceEndedAt!)) {
          break;
        }

        final monthKey = '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}';
        final dateKey = '$monthKey-${nextDate.day.toString().padLeft(2, '0')}';
        final isException = baseTx.recurrenceExceptions.contains(monthKey) ||
            baseTx.recurrenceExceptions.contains(dateKey);

        if (!isException) {
          final alreadyExists = state.transactions.any((t) {
            if (t.isCancelled || t.effectiveRecurringGroupId != rootId) return false;
            if (freq == RecurrenceFrequency.monthly || freq == RecurrenceFrequency.yearly) {
              return t.purchaseDate.year == nextDate.year && t.purchaseDate.month == nextDate.month;
            } else {
              return t.purchaseDate.year == nextDate.year &&
                  t.purchaseDate.month == nextDate.month &&
                  t.purchaseDate.day == nextDate.day;
            }
          });

          if (!alreadyExists) {
            final occTx = baseTx.copyWith(
              id: _uuid.v4(),
              purchaseDate: nextDate,
              recurringGroupId: rootId,
              isRecurring: true,
              totalInstallments: 1,
              createdAt: DateTime.now(),
            );

            state = processNewTransaction(
              currentState: state,
              transaction: occTx,
            );
          }
        }

        step++;
      }
    }

    return realizeMaturedTransactions(state);
  }

  /// Calcula com precisão bancária o limite utilizado de um cartão de crédito.
  /// Considera:
  /// 1. Faturas anteriores em aberto (não pagas) e a fatura atual do ciclo ativo.
  /// 2. Parcelas futuras de compras parceladas REAIS (totalInstallments > 1 e !isRecurring).
  /// EXCLUI:
  /// - Recorrências automáticas projetadas para ciclos futuros (ex: Netflix, mensalidades de meses seguintes),
  ///   pois assinaturas futuras não consomem limite de crédito antecipadamente no cartão real.
  static double calculateCardUsedLimit({
    required FinancialState state,
    required String cardId,
    DateTime? referenceDate,
  }) {
    final card = state.cards.where((c) => c.id == cardId).firstOrNull;
    if (card == null) return 0.0;

    final now = referenceDate ?? DateTime.now();
    // Determina o ciclo ativo da fatura atual com base no dia de fechamento
    final activePeriod = InvoiceCalculator.getInvoicePeriodForPurchase(
      purchaseDate: now,
      closingDay: card.closingDay,
    );

    double totalUsed = 0.0;

    // 1. Faturas não pagas até o ciclo de fechamento ativo (passadas em aberto + atual em aberto)
    final activeAndPastInvoices = state.invoices.where((inv) {
      if (inv.cardId != cardId || inv.isPaid) return false;
      return (inv.year < activePeriod.year) ||
          (inv.year == activePeriod.year && inv.month <= activePeriod.month);
    });

    for (final inv in activeAndPastInvoices) {
      totalUsed += inv.totalAmount;
    }

    // 2. Parcelas futuras de compras parceladas REAIS já contratadas
    final futureInvoices = state.invoices.where((inv) {
      if (inv.cardId != cardId || inv.isPaid) return false;
      return (inv.year > activePeriod.year) ||
          (inv.year == activePeriod.year && inv.month > activePeriod.month);
    });
    final futureInvoiceIds = futureInvoices.map((inv) => inv.id).toSet();

    for (final inst in state.installments) {
      if (!futureInvoiceIds.contains(inst.invoiceId)) continue;

      final tx = state.transactions.where((t) => t.id == inst.transactionId).firstOrNull;
      if (tx == null || tx.isCancelled) continue;

      // Apenas parcelas de compras reais parceladas contratadas no cartão (ignora projeções recorrentes)
      if (tx.totalInstallments > 1 && !tx.isRecurring) {
        totalUsed += inst.amount;
      }
    }

    return double.parse(totalUsed.clamp(0.0, double.infinity).toStringAsFixed(2));
  }

  /// Calcula o sumário completo para o Dashboard em um período (mês/ano)
  static DashboardSummary calculateDashboardSummary({
    required FinancialState state,
    required int month,
    required int year,
    int pendingInboxCount = 0,
  }) {
    final now = DateTime.now();
    final isPastMonth = year < now.year || (year == now.year && month < now.month);
    final (availBal, resBal) = calculateHistoricalBalances(state: state, month: month, year: year);

    // 1. Saldo comprometido (Faturas não pagas até o período visualizado)
    final openInvoices = state.invoices.where((inv) {
      if (inv.isPaid) return false;
      return (inv.year < year) || (inv.year == year && inv.month <= month);
    });
    final committedBalance = openInvoices.fold<double>(0.0, (acc, inv) => acc + inv.totalAmount);

    // 2. A receber (Reembolsos pendentes devidos no período - exatamente idêntico a Cobranças & Reembolsos)
    final reimbSummary = calculateReimbursementsSummary(
      state: state,
      targetMonth: month,
      targetYear: year,
    );
    final pendingReimbursements = reimbSummary.monthDue;
    final totalPendingReimbursements = reimbSummary.totalPending;

    // 3. Receitas do período
    final periodIncomes = state.transactions
        .where((t) => t.type == TransactionType.income && t.purchaseDate.month == month && t.purchaseDate.year == year)
        .fold<double>(0.0, (acc, t) => acc + t.netAmount);

    // 4. Despesas imediatas pessoais (Pix, Dinheiro, Débito)
    final periodImmediateExpenses = state.transactions
        .where((t) => t.type == TransactionType.expense && !t.isCreditCard && !t.isForThirdParty && t.purchaseDate.month == month && t.purchaseDate.year == year)
        .fold<double>(0.0, (acc, t) => acc + t.netAmount);

    // 5. Compras pessoais no cartão no período
    // Considera compras à vista (1x) no mês da compra e parcelas (Nx) distribuídas mês a mês a partir do mês da compra
    double periodCreditPurchases = 0.0;
    for (final t in state.transactions) {
      if (!t.isCreditCard || t.isForThirdParty || t.isCancelled) continue;

      if (t.totalInstallments <= 1) {
        if (t.purchaseDate.month == month && t.purchaseDate.year == year) {
          periodCreditPurchases += t.netAmount;
        }
      } else {
        final totalMonthsPurchase = (t.purchaseDate.year * 12) + (t.purchaseDate.month - 1);
        final totalMonthsTarget = (year * 12) + (month - 1);
        final diffMonths = totalMonthsTarget - totalMonthsPurchase;

        if (diffMonths >= 0 && diffMonths < t.totalInstallments) {
          final instNum = diffMonths + 1;
          final baseAmt = double.parse((t.netAmount / t.totalInstallments).toStringAsFixed(2));
          final lastAmt = double.parse((t.netAmount - (baseAmt * (t.totalInstallments - 1))).toStringAsFixed(2));
          final amt = (instNum == t.totalInstallments) ? lastAmt : baseAmt;
          periodCreditPurchases += amt;
        }
      }
    }

    // 6. Gastos pessoais via Pix no período
    final periodPixExpenses = state.transactions
        .where((t) => t.isPix && !t.isForThirdParty && t.purchaseDate.month == month && t.purchaseDate.year == year)
        .fold<double>(0.0, (acc, t) => acc + t.netAmount);

    // Total de despesas pessoais do período (Imediatas + Cartão)
    final periodPersonalExpenses = double.parse((periodImmediateExpenses + periodCreditPurchases).toStringAsFixed(2));

    return DashboardSummary(
      availableBalance: availBal,
      reserveBalance: resBal,
      committedBalance: committedBalance,
      pendingReimbursements: pendingReimbursements,
      totalPendingReimbursements: totalPendingReimbursements,
      periodIncomes: periodIncomes,
      periodPaidExpenses: periodPersonalExpenses,
      periodCreditPurchases: periodCreditPurchases,
      periodPixExpenses: periodPixExpenses,
      pendingInboxCount: pendingInboxCount,
    );
  }

  /// Calcula o valor devido por uma compra de terceiro em um mês e ano específicos.
  /// Compras à vista pertencem ao mês da compra.
  /// Para compras parceladas, a Parcela 1 fica no mês da compra, Parcela 2 no mês subsequente, etc.
  /// Abate os pagamentos já realizados pelo devedor respeitando a ordem cronológica das parcelas.
  static double calculateReimbursementDueForMonth({
    required FinancialTransaction transaction,
    required Reimbursement reimbursement,
    required int targetMonth,
    required int targetYear,
  }) {
    if (reimbursement.isSettled || reimbursement.remainingAmount <= 0.001) return 0.0;

    final totalPaid = (reimbursement.totalAmount - reimbursement.remainingAmount).clamp(0.0, reimbursement.totalAmount);

    if (transaction.totalInstallments <= 1) {
      // Compra à vista (Cartão 1x, Pix, Dinheiro):
      if (transaction.purchaseDate.month == targetMonth && transaction.purchaseDate.year == targetYear) {
        return reimbursement.remainingAmount;
      }
      return 0.0;
    }

    // Compra parcelada:
    final totalInsts = transaction.totalInstallments;
    final installmentAmount = double.parse((transaction.amount / totalInsts).toStringAsFixed(2));
    final sumBase = installmentAmount * (totalInsts - 1);
    final lastInstallmentAmount = double.parse((transaction.amount - sumBase).toStringAsFixed(2));

    double cumulativeThreshold = 0.0;
    double dueThisMonth = 0.0;

    for (var i = 1; i <= totalInsts; i++) {
      final amt = (i == totalInsts) ? lastInstallmentAmount : installmentAmount;
      final instStart = cumulativeThreshold;
      final instEnd = cumulativeThreshold + amt;
      cumulativeThreshold = instEnd;

      final totalMonths = (transaction.purchaseDate.year * 12) + (transaction.purchaseDate.month - 1) + (i - 1);
      final instYear = totalMonths ~/ 12;
      final instMonth = (totalMonths % 12) + 1;

      if (instYear == targetYear && instMonth == targetMonth) {
        if (totalPaid >= instEnd - 0.001) {
          // Essa parcela já foi totalmente paga pelo devedor
          dueThisMonth += 0.0;
        } else if (totalPaid <= instStart) {
          // Nada dessa parcela foi pago ainda
          dueThisMonth += amt;
        } else {
          // Parcialmente paga
          final paidForThisInst = totalPaid - instStart;
          dueThisMonth += (amt - paidForThisInst).clamp(0.0, amt);
        }
      }
    }

    return double.parse(dueThisMonth.clamp(0.0, reimbursement.remainingAmount).toStringAsFixed(2));
  }

  /// Retorna se uma compra de terceiro possui vigência/parcela no mês e ano especificados.
  static bool isReimbursementActiveInMonth({
    required FinancialTransaction transaction,
    required int targetMonth,
    required int targetYear,
  }) {
    if (transaction.totalInstallments <= 1) {
      return transaction.purchaseDate.month == targetMonth && transaction.purchaseDate.year == targetYear;
    }

    final totalInsts = transaction.totalInstallments;
    for (var i = 1; i <= totalInsts; i++) {
      final totalMonths = (transaction.purchaseDate.year * 12) + (transaction.purchaseDate.month - 1) + (i - 1);
      final instYear = totalMonths ~/ 12;
      final instMonth = (totalMonths % 12) + 1;
      if (instYear == targetYear && instMonth == targetMonth) {
        return true;
      }
    }
    return false;
  }

  /// Determina a data/mês de referência de uma quitação ou pagamento de reembolso.
  /// Se houver notas indicando 'mês M/Y', usa esse mês.
  /// Para compras à vista, a referência é o mês da própria compra.
  /// Para parcelas, calcula o mês da parcela correspondente à ordem do pagamento.
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
    final instYear = totalMonths ~/ 12;
    final instMonth = (totalMonths % 12) + 1;
    return (month: instMonth, year: instYear);
  }

  /// Retorna o resumo consolidado de cobranças e reembolsos (devido no mês e total pendente acumulado)
  /// idêntico ao exibido na tela de Cobranças & Reembolsos.
  static ({
    double monthDue,
    double totalPending,
    int activeDebtorsCount,
    List<Person> activeDebtorsInMonth,
    Map<String, double> personMonthDueMap,
  }) calculateReimbursementsSummary({
    required FinancialState state,
    required int targetMonth,
    required int targetYear,
  }) {
    final reimbursements = state.reimbursements;
    final people = state.people;

    final pendingTotal = reimbursements
        .where((r) => !r.isSettled)
        .fold<double>(0.0, (acc, r) => acc + r.remainingAmount);

    final debtorsInMonth = people.where((p) {
      if (p.isMe) return false;
      final personReimbs = reimbursements.where((r) => r.personId == p.id && !r.isSettled);
      return personReimbs.any((r) {
        final tx = state.transactions.firstWhere(
          (t) => t.id == r.transactionId,
          orElse: () => FinancialTransaction(
            id: r.transactionId,
            description: '',
            amount: r.totalAmount,
            purchaseDate: r.createdAt,
            categoryId: 'cat_other',
            paymentMethod: PaymentMethod.pix,
          ),
        );
        return isReimbursementActiveInMonth(
          transaction: tx,
          targetMonth: targetMonth,
          targetYear: targetYear,
        );
      });
    }).toList();

    double totalDueInSelectedMonth = 0.0;
    final Map<String, double> personMonthDueMap = {};

    for (final person in debtorsInMonth) {
      final personReimbs = reimbursements.where((r) => r.personId == person.id && !r.isSettled).toList();
      double personMonthDue = 0.0;

      for (final r in personReimbs) {
        final tx = state.transactions.firstWhere(
          (t) => t.id == r.transactionId,
          orElse: () => FinancialTransaction(
            id: '',
            description: '',
            amount: r.totalAmount,
            purchaseDate: r.createdAt,
            categoryId: 'cat_other',
            paymentMethod: PaymentMethod.pix,
          ),
        );

        final monthDue = calculateReimbursementDueForMonth(
          transaction: tx,
          reimbursement: r,
          targetMonth: targetMonth,
          targetYear: targetYear,
        );
        personMonthDue += monthDue;
      }
      personMonthDueMap[person.id] = double.parse(personMonthDue.toStringAsFixed(2));
      totalDueInSelectedMonth += personMonthDue;
    }

    return (
      monthDue: double.parse(totalDueInSelectedMonth.toStringAsFixed(2)),
      totalPending: double.parse(pendingTotal.toStringAsFixed(2)),
      activeDebtorsCount: debtorsInMonth.length,
      activeDebtorsInMonth: debtorsInMonth,
      personMonthDueMap: personMonthDueMap,
    );
  }
}
