import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/core/utils/money.dart';
import 'package:chokin/domain/entities/credit_card.dart';
import 'package:chokin/domain/entities/financial_movement.dart';
import 'package:chokin/domain/entities/person.dart';
import 'package:chokin/domain/entities/reimbursement.dart';
import 'package:chokin/domain/entities/transaction.dart';
import 'package:chokin/domain/engine/financial_movement_engine.dart';

void main() {
  const defaultCard = CreditCard(
    id: 'card_nubank',
    name: 'Nubank',
    closingDay: 1,
    dueDay: 8,
    creditLimitCents: 500000,
  );

  final personBob = Person(
    id: 'p_bob',
    name: 'Bob',
    createdAt: DateTime(2026, 1, 1),
  );

  FinancialState getInitialState({double available = 1000.0}) {
    return FinancialState.reconciled(
      availableCents: Money.fromReais(available),
      cards: [defaultCard],
      people: [Person(id: 'ME', name: 'Eu', createdAt: DateTime(2026, 1, 1)), personBob],
    );
  }

  group('Motor de Recorrência Automática (syncRecurringTransactions)', () {
    test('Projeta transações recorrentes ativas para meses futuros até o targetMonth', () {
      final baseTx = FinancialTransaction(
        id: 'tx_salary',
        description: 'Salário Mensal',
        amountCents: 300000,
        purchaseDate: DateTime(2026, 7, 5),
        categoryId: 'cat_income',
        type: TransactionType.income,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
        recurringGroupId: 'group_salary',
      );

      final state = FinancialState.reconciled(
        availableCents: 100000,
        transactions: [baseTx],
      );

      final syncedState = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 9,
        targetYear: 2026,
      );

      expect(syncedState.transactions.length, 3);

      final aug = syncedState.transactions.firstWhere((t) => t.purchaseDate.month == 8);
      expect(aug.effectiveRecurringGroupId, 'group_salary');
      expect(aug.description, 'Salário Mensal');
      expect(aug.amount, 3000.0);
      expect(aug.purchaseDate, DateTime(2026, 8, 5));

      final sep = syncedState.transactions.firstWhere((t) => t.purchaseDate.month == 9);
      expect(sep.effectiveRecurringGroupId, 'group_salary');
      expect(sep.purchaseDate, DateTime(2026, 9, 5));
    });

    test('Respeita exceções mensais registradas em recurrenceExceptions', () {
      final baseTx = FinancialTransaction(
        id: 'tx_netflix',
        description: 'Netflix',
        amountCents: 5590,
        purchaseDate: DateTime(2026, 7, 10),
        categoryId: 'cat_stream',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
        recurringGroupId: 'group_netflix',
        recurrenceExceptions: ['2026-08'],
      );

      final state = FinancialState(
        transactions: [baseTx],
      );

      final syncedState = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 9,
        targetYear: 2026,
      );

      expect(syncedState.transactions.length, 2);
      expect(syncedState.transactions.any((t) => t.purchaseDate.month == 8), isFalse);
      expect(syncedState.transactions.any((t) => t.purchaseDate.month == 9), isTrue);
    });

    test('Respeita recurrenceEndedAt e para de gerar ocorrências', () {
      final baseTx = FinancialTransaction(
        id: 'tx_gym',
        description: 'Academia',
        amountCents: 12000,
        purchaseDate: DateTime(2026, 7, 1),
        categoryId: 'cat_gym',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
        recurringGroupId: 'group_gym',
        recurrenceEndedAt: DateTime(2026, 8, 1),
      );

      final state = FinancialState(
        transactions: [baseTx],
      );

      final syncedState = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 10,
        targetYear: 2026,
      );

      expect(syncedState.transactions.length, 1);
      expect(syncedState.transactions.first.purchaseDate.month, 7);
    });

    test('Projeta recorrência semanal corretamente', () {
      final baseTx = FinancialTransaction(
        id: 'tx_therapy',
        description: 'Terapia Semanal',
        amountCents: 15000,
        purchaseDate: DateTime(2026, 9, 1),
        categoryId: 'cat_health',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.weekly,
        recurringGroupId: 'group_therapy',
      );

      final state = FinancialState(transactions: [baseTx]);
      final syncedState = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 9,
        targetYear: 2026,
      );

      final sepTxs = syncedState.transactions.where((t) => t.effectiveRecurringGroupId == 'group_therapy').toList();
      expect(sepTxs.length, 5);
      expect(sepTxs.map((t) => t.purchaseDate.day).toList(), [1, 8, 15, 22, 29]);
    });

    test('Cancelamento "daqui para frente" preserva meses passados e impede futuras projeções', () {
      final baseTx = FinancialTransaction(
        id: 'tx_mesada',
        description: 'Mesada',
        amountCents: 50000,
        purchaseDate: DateTime(2026, 9, 10),
        categoryId: 'cat_income',
        type: TransactionType.income,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
        recurringGroupId: 'group_mesada',
      );

      var state = FinancialMovementEngine.syncRecurringTransactions(
        currentState: FinancialState(transactions: [baseTx]),
        targetMonth: 12,
        targetYear: 2026,
      );
      expect(state.transactions.length, 4);

      final currentMonth = 11;
      final currentYear = 2026;
      final rootId = baseTx.effectiveRecurringGroupId;

      final txsToDelete = state.transactions.where((t) =>
          t.effectiveRecurringGroupId == rootId &&
          (t.purchaseDate.year > currentYear ||
              (t.purchaseDate.year == currentYear && t.purchaseDate.month >= currentMonth))).toList();

      for (final t in txsToDelete) {
        state = FinancialMovementEngine.deleteTransaction(
          currentState: state,
          transactionId: t.id,
        );
      }

      final cutoffDate = DateTime(currentYear, currentMonth, 1);
      final rootIndex = state.transactions.indexWhere((t) => t.effectiveRecurringGroupId == rootId);
      expect(rootIndex, isNot(-1));
      final rootTx = state.transactions[rootIndex];
      final updatedRoot = rootTx.copyWith(recurrenceEndedAt: cutoffDate);
      final updatedTxs = List<FinancialTransaction>.from(state.transactions);
      updatedTxs[rootIndex] = updatedRoot;
      state = state.copyWith(transactions: updatedTxs);

      expect(state.transactions.length, 2);
      expect(state.transactions.any((t) => t.purchaseDate.month == 9), isTrue);
      expect(state.transactions.any((t) => t.purchaseDate.month == 10), isTrue);
      expect(state.transactions.any((t) => t.purchaseDate.month == 11), isFalse);
      expect(state.transactions.any((t) => t.purchaseDate.month == 12), isFalse);

      final futureSync = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 3,
        targetYear: 2027,
      );
      expect(futureSync.transactions.length, 2);
      expect(futureSync.transactions.any((t) => t.purchaseDate.isAfter(DateTime(2026, 10, 31))), isFalse);
    });

    test('calculateCardUsedLimit não inflaciona o limite com projeções de recorrências futuras', () {
      final nubankCard = const CreditCard(
        id: 'card_nubank',
        name: 'Nubank',
        closingDay: 1,
        dueDay: 8,
        creditLimitCents: 500000,
      );

      final normalTx = FinancialTransaction(
        id: 'tx_normal',
        description: 'Supermercado',
        amountCents: 20000,
        purchaseDate: DateTime(2026, 9, 24),
        categoryId: 'cat_groceries',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
      );

      final tuitionTx = FinancialTransaction(
        id: 'tx_tuition',
        description: 'Mensalidade Faculdade',
        amountCents: 60000,
        purchaseDate: DateTime(2026, 9, 20),
        categoryId: 'cat_education',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
      );

      final streamingTx = FinancialTransaction(
        id: 'tx_stream',
        description: 'Streaming',
        amountCents: 5000,
        purchaseDate: DateTime(2026, 9, 15),
        categoryId: 'cat_stream',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
      );

      var state = FinancialState(cards: [nubankCard]);
      state = FinancialMovementEngine.processNewTransaction(currentState: state, transaction: normalTx);
      state = FinancialMovementEngine.processNewTransaction(currentState: state, transaction: tuitionTx);
      state = FinancialMovementEngine.processNewTransaction(currentState: state, transaction: streamingTx);

      state = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 9,
        targetYear: 2027,
      );

      final rawSum = state.invoices.where((i) => i.cardId == 'card_nubank' && !i.isPaid).fold<double>(0.0, (acc, i) => acc + i.totalAmount);
      expect(rawSum, greaterThan(8000.0));

      final usedLimit = FinancialMovementEngine.calculateCardUsedLimitCents(
        state: state,
        cardId: 'card_nubank',
        referenceDate: DateTime(2026, 9, 24),
      );
      expect(usedLimit, 85000);

      final installmentTx = FinancialTransaction(
        id: 'tx_installments',
        description: 'Eletrodoméstico 5x',
        amountCents: 50000,
        purchaseDate: DateTime(2026, 9, 24),
        categoryId: 'cat_appliances',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        totalInstallments: 5,
      );
      state = FinancialMovementEngine.processNewTransaction(currentState: state, transaction: installmentTx);

      final usedWithInstallments = FinancialMovementEngine.calculateCardUsedLimitCents(
        state: state,
        cardId: 'card_nubank',
        referenceDate: DateTime(2026, 9, 24),
      );
      expect(usedWithInstallments, 135000);
    });
  });

  group('Saldo histórico (calculateHistoricalBalance)', () {
    test('Reverte movimentações de meses posteriores para reproduzir o saldo de fechamento do mês anterior', () {
      final augIncome = FinancialMovement(
        id: 'm1',
        transactionId: 't1',
        type: MovementType.income,
        amountCents: 20000,
        movementDate: DateTime(2026, 8, 10),
        description: 'Salário de Agosto',
      );
      final sepIncome = FinancialMovement(
        id: 'm3',
        transactionId: 't2',
        type: MovementType.income,
        amountCents: 50000,
        movementDate: DateTime(2026, 9, 2),
        description: 'Freelance em Setembro',
      );
      final sepExpense = FinancialMovement(
        id: 'm4',
        transactionId: 't3',
        type: MovementType.expensePaid,
        amountCents: 10000,
        movementDate: DateTime(2026, 9, 3),
        description: 'Mercado em Setembro',
      );

      final state = FinancialState.reconciled(
        availableCents: 150000,
        movements: [augIncome, sepIncome, sepExpense],
      );

      final histAvail = FinancialMovementEngine.calculateHistoricalBalance(
        state: state,
        month: 8,
        year: 2026,
      );

      expect(histAvail, 1100.0);
    });
  });

  group('Segregação de Cobranças por Mês (calculateReimbursementDueForMonth)', () {
    test('Compras de terceiros ficam no mês da compra e parcelas avançam mês a mês', () {
      final tx1 = FinancialTransaction(
        id: 'tx_bob_1x',
        description: 'Lanche Bob',
        amountCents: 5000,
        purchaseDate: DateTime(2026, 8, 15),
        categoryId: 'cat_food',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        totalInstallments: 1,
        personId: personBob.id,
      );

      final r1 = Reimbursement(
        id: 'r1',
        transactionId: tx1.id,
        personId: personBob.id,
        totalAmountCents: 5000,
        remainingAmountCents: 5000,
        createdAt: tx1.purchaseDate,
      );

      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonthCents(
          transaction: tx1,
          reimbursement: r1,
          targetMonth: 8,
          targetYear: 2026,
        ),
        5000,
      );

      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonthCents(
          transaction: tx1,
          reimbursement: r1,
          targetMonth: 9,
          targetYear: 2026,
        ),
        0,
      );

      final tx2 = FinancialTransaction(
        id: 'tx_bob_3x',
        description: 'Tênis Bob',
        amountCents: 30000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_clothes',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        totalInstallments: 3,
        personId: personBob.id,
      );

      final r2 = Reimbursement(
        id: 'r2',
        transactionId: tx2.id,
        personId: personBob.id,
        totalAmountCents: 30000,
        remainingAmountCents: 30000,
        createdAt: tx2.purchaseDate,
      );

      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonthCents(
          transaction: tx2,
          reimbursement: r2,
          targetMonth: 8,
          targetYear: 2026,
        ),
        10000,
      );

      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonthCents(
          transaction: tx2,
          reimbursement: r2,
          targetMonth: 9,
          targetYear: 2026,
        ),
        10000,
      );

      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonthCents(
          transaction: tx2,
          reimbursement: r2,
          targetMonth: 10,
          targetYear: 2026,
        ),
        10000,
      );

      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonthCents(
          transaction: tx2,
          reimbursement: r2,
          targetMonth: 11,
          targetYear: 2026,
        ),
        0,
      );

      final r2AfterAugPayment = Reimbursement(
        id: 'r2',
        transactionId: tx2.id,
        personId: personBob.id,
        totalAmountCents: 30000,
        remainingAmountCents: 20000,
        createdAt: tx2.purchaseDate,
      );

      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonthCents(
          transaction: tx2,
          reimbursement: r2AfterAugPayment,
          targetMonth: 8,
          targetYear: 2026,
        ),
        0,
      );

      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonthCents(
          transaction: tx2,
          reimbursement: r2AfterAugPayment,
          targetMonth: 9,
          targetYear: 2026,
        ),
        10000,
      );
    });
  });

  group('Cancelamento de Quitação (revertReimbursementPayment)', () {
    test('Desfaz pagamento de parcela: restaura saldo devedor, estorna do saldo em conta e remove movimentação', () {
      final r = Reimbursement(
        id: 'r_test',
        transactionId: 'tx_1',
        personId: personBob.id,
        totalAmountCents: 30000,
        remainingAmountCents: 30000,
        createdAt: DateTime(2026, 8, 10),
      );

      final initialState = FinancialState.reconciled(
        availableCents: 100000,
        reimbursements: [r],
        movements: [],
      );

      final paidState = FinancialMovementEngine.processReimbursementPayment(
        currentState: initialState,
        reimbursementId: r.id,
        amountReceivedCents: 10000,
        paymentDate: DateTime(2026, 8, 15),
        notes: 'Parcela 1/3',
      );

      expect(paidState.availableBalance, 1100.0);
      expect(paidState.reimbursements.first.remainingAmount, 200.0);
      expect(paidState.reimbursements.first.status, ReimbursementStatus.partiallyPaid);
      expect(paidState.reimbursements.first.payments.length, 1);
      final paymentId = paidState.reimbursements.first.payments.first.id;
      final paymentMovements = paidState.movements.where((m) => m.reimbursementId == r.id).toList();
      expect(paymentMovements.length, 1);
      expect(paymentMovements.first.type, MovementType.reimbursementReceived);

      final revertedState = FinancialMovementEngine.revertReimbursementPayment(
        currentState: paidState,
        reimbursementId: r.id,
        paymentId: paymentId,
      );

      expect(revertedState.availableBalance, 1000.0);
      expect(revertedState.reimbursements.first.remainingAmount, 300.0);
      expect(revertedState.reimbursements.first.status, ReimbursementStatus.pending);
      expect(revertedState.reimbursements.first.payments.isEmpty, isTrue);
      expect(revertedState.movements.where((m) => m.reimbursementId == r.id), isEmpty);
      expect(revertedState.movements.length, initialState.movements.length);
    });

    test('Desfaz quitação total legada sem lista de payments', () {
      final rSettled = Reimbursement(
        id: 'r_legacy',
        transactionId: 'tx_legacy',
        personId: personBob.id,
        totalAmountCents: 15000,
        remainingAmountCents: 0,
        status: ReimbursementStatus.settled,
        createdAt: DateTime(2026, 8, 5),
        payments: const [],
      );

      final legacyMov = FinancialMovement(
        id: 'mov_legacy',
        transactionId: null,
        reimbursementId: 'r_legacy',
        type: MovementType.reimbursementReceived,
        amountCents: 15000,
        movementDate: DateTime(2026, 8, 5),
        description: 'Reembolso recebido',
      );

      final state = FinancialState.reconciled(
        availableCents: 50000,
        reimbursements: [rSettled],
        movements: [legacyMov],
      );

      final reverted = FinancialMovementEngine.revertReimbursementPayment(
        currentState: state,
        reimbursementId: 'r_legacy',
      );

      expect(reverted.availableBalance, 350.0);
      expect(reverted.reimbursements.first.remainingAmount, 150.0);
      expect(reverted.reimbursements.first.status, ReimbursementStatus.pending);
      expect(reverted.movements.where((m) => m.reimbursementId == 'r_legacy'), isEmpty);
    });
  });

  group('Vigência Mensal e Período de Referência de Cobranças e Quitações', () {
    test('isReimbursementActiveInMonth: compras não poluem meses anteriores nem posteriores', () {
      final tx1xAug = FinancialTransaction(
        id: 'tx1',
        description: 'Almoço',
        amountCents: 5000,
        purchaseDate: DateTime(2026, 8, 15),
        categoryId: 'cat_food',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.pix,
        totalInstallments: 1,
        personId: personBob.id,
      );

      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx1xAug, targetMonth: 7, targetYear: 2026), isFalse);
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx1xAug, targetMonth: 8, targetYear: 2026), isTrue);
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx1xAug, targetMonth: 9, targetYear: 2026), isFalse);

      final tx3xAug = FinancialTransaction(
        id: 'tx2',
        description: 'Tênis 3x',
        amountCents: 30000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_clothes',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        totalInstallments: 3,
        personId: personBob.id,
      );

      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 7, targetYear: 2026), isFalse);
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 8, targetYear: 2026), isTrue);
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 9, targetYear: 2026), isTrue);
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 10, targetYear: 2026), isTrue);
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 11, targetYear: 2026), isFalse);
    });

    test('getReimbursementPaymentReferencePeriod: quitação de Agosto realizada em Setembro pertence a Agosto', () {
      final txAug = FinancialTransaction(
        id: 'tx1',
        description: 'Almoço Agosto',
        amountCents: 10000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_food',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.pix,
        totalInstallments: 1,
        personId: personBob.id,
      );

      final r = Reimbursement(
        id: 'r1',
        transactionId: txAug.id,
        personId: personBob.id,
        totalAmountCents: 10000,
        remainingAmountCents: 0,
        createdAt: txAug.purchaseDate,
      );

      final payWithNotes = ReimbursementPayment(
        id: 'p1',
        reimbursementId: 'r1',
        amountCents: 10000,
        paymentDate: DateTime(2026, 9, 8),
        notes: 'Quitação referente ao mês 8/2026',
      );

      final ref = FinancialMovementEngine.getReimbursementPaymentReferencePeriod(
        transaction: txAug,
        reimbursement: r,
        payment: payWithNotes,
      );

      expect(ref.month, 8);
      expect(ref.year, 2026);
    });

    test('calculateHistoricalBalances: retorna (0.0, 0.0) para meses anteriores ao primeiro registro do app', () {
      final augMov = FinancialMovement(
        id: 'm1',
        transactionId: 't1',
        type: MovementType.income,
        amountCents: 100000,
        movementDate: DateTime(2026, 8, 5),
        description: 'Salário Agosto',
      );

      final state = FinancialState.reconciled(
        availableCents: 100000,
        movements: [augMov],
      );

      final availJul = FinancialMovementEngine.calculateHistoricalBalance(
        state: state,
        month: 7,
        year: 2026,
      );
      expect(availJul, 0.0);

      final availAug = FinancialMovementEngine.calculateHistoricalBalance(
        state: state,
        month: 8,
        year: 2026,
      );
      expect(availAug, 1000.0);
    });

    test('calculateHistoricalBalances: avançar no tempo e retornar ao mês atual não inflaciona o saldo atual', () {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final salaryTx = FinancialTransaction(
        id: 'tx_rec_salary',
        description: 'Salário Mensal',
        amountCents: 200000,
        purchaseDate: DateTime(currentYear, currentMonth, 1),
        categoryId: 'cat_income',
        type: TransactionType.income,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
      );

      var state = FinancialState.reconciled(
        availableCents: 300000,
        transactions: [salaryTx],
        movements: [
          FinancialMovement(
            id: 'mov_salary_curr',
            transactionId: salaryTx.id,
            type: MovementType.income,
            amountCents: 200000,
            movementDate: DateTime(currentYear, currentMonth, 5),
            description: 'Receita: Salário Mensal',
          ),
        ],
      );

      final initialAvail = FinancialMovementEngine.calculateHistoricalBalance(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(initialAvail, equals(3000.0));

      var futureTargetMonth = currentMonth + 3;
      var futureTargetYear = currentYear;
      if (futureTargetMonth > 12) {
        futureTargetMonth -= 12;
        futureTargetYear += 1;
      }

      state = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: futureTargetMonth,
        targetYear: futureTargetYear,
      );

      expect(state.availableBalance, equals(3000.0));

      final futureAvail = FinancialMovementEngine.calculateHistoricalBalance(
        state: state,
        month: futureTargetMonth,
        year: futureTargetYear,
      );
      expect(futureAvail, equals(9000.0));

      final revertedAvail = FinancialMovementEngine.calculateHistoricalBalance(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(revertedAvail, equals(3000.0));

      final summaryCurr = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(summaryCurr.availableBalance, equals(3000.0));
      expect(summaryCurr.freeBalance, equals(3000.0));
    });

    test('calculateDashboardSummary: faturas de meses futuros não comprometem o saldo livre do mês presente', () {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final card = CreditCard(
        id: 'card_inter',
        name: 'Inter',
        closingDay: 15,
        dueDay: 25,
      );

      final recCardTx = FinancialTransaction(
        id: 'tx_rec_card',
        description: 'Assinatura Software',
        amountCents: 50000,
        purchaseDate: DateTime(currentYear, currentMonth, 10),
        categoryId: 'cat_sub',
        paymentMethod: PaymentMethod.creditCard,
        cardId: card.id,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
      );

      var state = FinancialState.reconciled(
        availableCents: 300000,
        cards: [card],
        transactions: [],
        invoices: [],
        installments: [],
      );

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: recCardTx,
      );

      final summaryBeforeTravel = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(summaryBeforeTravel.committedBalance, equals(500.0));
      expect(summaryBeforeTravel.freeBalance, equals(2500.0));

      var futureTargetMonth = currentMonth + 5;
      var futureTargetYear = currentYear;
      if (futureTargetMonth > 12) {
        futureTargetMonth -= 12;
        futureTargetYear += 1;
      }

      state = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: futureTargetMonth,
        targetYear: futureTargetYear,
      );

      final allOpenInvoices = state.invoices.where((i) => !i.isPaid).fold<double>(0.0, (acc, i) => acc + i.totalAmount);
      expect(allOpenInvoices, equals(3000.0));

      final summaryAfterTravel = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(summaryAfterTravel.committedBalance, equals(500.0));
      expect(summaryAfterTravel.freeBalance, equals(2500.0));
    });

    test('Transações agendadas para o futuro não alteram availableBalance nem geram movimentações no ledger', () {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      var state = FinancialState.reconciled(
        availableCents: 200000,
      );

      final futureDate = DateTime(currentYear, currentMonth + 1, 10);
      final futureTx = FinancialTransaction(
        id: 'tx_future_income',
        description: 'Receita Futura',
        amountCents: 500000,
        purchaseDate: futureDate,
        categoryId: 'cat_income',
        paymentMethod: PaymentMethod.pix,
        type: TransactionType.income,
      );

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: futureTx,
      );

      expect(state.availableBalance, equals(2000.0));
      expect(state.movements.any((m) => m.transactionId == futureTx.id), isFalse);

      final currAvail = FinancialMovementEngine.calculateHistoricalBalance(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(currAvail, equals(2000.0));

      final futureAvail = FinancialMovementEngine.calculateHistoricalBalance(
        state: state,
        month: futureDate.month,
        year: futureDate.year,
      );
      expect(futureAvail, equals(7000.0));

      state = FinancialMovementEngine.deleteTransaction(
        currentState: state,
        transactionId: futureTx.id,
      );
      expect(state.availableBalance, equals(2000.0));
    });
  });
}
