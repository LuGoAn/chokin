import 'package:flutter_test/flutter_test.dart';
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
    creditLimit: 5000.0,
  );

  final personBob = Person(
    id: 'p_bob',
    name: 'Bob',
    createdAt: DateTime(2026, 1, 1),
  );

  FinancialState getInitialState({double available = 1000.0, double reserve = 500.0}) {
    return FinancialState(
      availableBalance: available,
      reserveBalance: reserve,
      cards: [defaultCard],
      people: [Person(id: 'ME', name: 'Eu', createdAt: DateTime(2026, 1, 1)), personBob],
    );
  }

  group('Motor de Recorrência Automática (syncRecurringTransactions)', () {
    test('Projeta transações recorrentes ativas para meses futuros até o targetMonth', () {
      final baseTx = FinancialTransaction(
        id: 'tx_salary',
        description: 'Salário Mensal',
        amount: 3000.0,
        purchaseDate: DateTime(2026, 7, 5),
        categoryId: 'cat_income',
        type: TransactionType.income,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
        recurringGroupId: 'group_salary',
      );

      final state = FinancialState(
        availableBalance: 1000.0,
        reserveBalance: 500.0,
        transactions: [baseTx],
      );

      // Projeta até Setembro de 2026
      final syncedState = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 9,
        targetYear: 2026,
      );

      // Deve ter gerado ocorrência para Agosto (mês 8) e Setembro (mês 9)
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
        amount: 55.90,
        purchaseDate: DateTime(2026, 7, 10),
        categoryId: 'cat_stream',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
        recurringGroupId: 'group_netflix',
        recurrenceExceptions: ['2026-08'], // Pula agosto
      );

      final state = FinancialState(
        transactions: [baseTx],
      );

      final syncedState = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 9,
        targetYear: 2026,
      );

      // Julho (original) e Setembro (gerado), Agosto não deve existir
      expect(syncedState.transactions.length, 2);
      expect(syncedState.transactions.any((t) => t.purchaseDate.month == 8), isFalse);
      expect(syncedState.transactions.any((t) => t.purchaseDate.month == 9), isTrue);
    });

    test('Respeita recurrenceEndedAt e para de gerar ocorrências', () {
      final baseTx = FinancialTransaction(
        id: 'tx_gym',
        description: 'Academia',
        amount: 120.0,
        purchaseDate: DateTime(2026, 7, 1),
        categoryId: 'cat_gym',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
        recurringGroupId: 'group_gym',
        recurrenceEndedAt: DateTime(2026, 8, 1), // Encerra em 1º de agosto
      );

      final state = FinancialState(
        transactions: [baseTx],
      );

      final syncedState = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 10,
        targetYear: 2026,
      );

      // Apenas a original de Julho existe, Agosto e posteriores não geram
      expect(syncedState.transactions.length, 1);
      expect(syncedState.transactions.first.purchaseDate.month, 7);
    });

    test('Projeta recorrência semanal corretamente', () {
      final baseTx = FinancialTransaction(
        id: 'tx_therapy',
        description: 'Terapia Semanal',
        amount: 150.0,
        purchaseDate: DateTime(2026, 9, 1), // Terça-feira
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

      // Em setembro de 2026: dia 1, dia 8, dia 15, dia 22, dia 29 (5 ocorrências)
      final sepTxs = syncedState.transactions.where((t) => t.effectiveRecurringGroupId == 'group_therapy').toList();
      expect(sepTxs.length, 5);
      expect(sepTxs.map((t) => t.purchaseDate.day).toList(), [1, 8, 15, 22, 29]);
    });

    test('Cancelamento "daqui para frente" preserva meses passados e impede futuras projeções', () {
      // Cria transação em Setembro de 2026
      final baseTx = FinancialTransaction(
        id: 'tx_mesada',
        description: 'Mesada',
        amount: 500.0,
        purchaseDate: DateTime(2026, 9, 10),
        categoryId: 'cat_income',
        type: TransactionType.income,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
        recurringGroupId: 'group_mesada',
      );

      // Projeta até Dezembro de 2026 (Setembro, Outubro, Novembro, Dezembro)
      var state = FinancialMovementEngine.syncRecurringTransactions(
        currentState: FinancialState(transactions: [baseTx]),
        targetMonth: 12,
        targetYear: 2026,
      );
      expect(state.transactions.length, 4);

      // O usuário decide cancelar a partir de Novembro (currentMonth: 11, currentYear: 2026)
      // Simula a lógica de RecurringDeleteOption.fromNowOn
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

      // Verificação 1: Setembro e Outubro devem continuar salvos
      expect(state.transactions.length, 2);
      expect(state.transactions.any((t) => t.purchaseDate.month == 9), isTrue);
      expect(state.transactions.any((t) => t.purchaseDate.month == 10), isTrue);
      expect(state.transactions.any((t) => t.purchaseDate.month == 11), isFalse);
      expect(state.transactions.any((t) => t.purchaseDate.month == 12), isFalse);

      // Verificação 2: Se o app tentar sincronizar para 2027, nada a partir de Novembro é gerado
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
        creditLimit: 5000.0,
      );

      // Compra normal de Setembro (cai na fatura de Outubro porque purchaseDate.day 24 >= closingDay 1)
      final normalTx = FinancialTransaction(
        id: 'tx_normal',
        description: 'Supermercado',
        amount: 200.0,
        purchaseDate: DateTime(2026, 9, 24),
        categoryId: 'cat_groceries',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
      );

      // Despesa recorrente de faculdade no cartão: R$ 600/mês
      final tuitionTx = FinancialTransaction(
        id: 'tx_tuition',
        description: 'Mensalidade Faculdade',
        amount: 600.0,
        purchaseDate: DateTime(2026, 9, 20),
        categoryId: 'cat_education',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
      );

      // Despesa recorrente de streaming no cartão: R$ 50/mês
      final streamingTx = FinancialTransaction(
        id: 'tx_stream',
        description: 'Streaming',
        amount: 50.0,
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

      // Projeta as recorrências 12 meses à frente (até Setembro de 2027)
      state = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: 9,
        targetYear: 2027,
      );

      // A soma burra de todas as faturas futuras abertas daria mais de R$ 8.000 (estourando o limite de R$ 5.000)
      final rawSum = state.invoices.where((i) => i.cardId == 'card_nubank' && !i.isPaid).fold<double>(0.0, (acc, i) => acc + i.totalAmount);
      expect(rawSum, greaterThan(8000.0));

      // Com calculateCardUsedLimit no dia 24/09/2026:
      // O ciclo ativo é Outubro/2026: R$ 200 (normal) + R$ 600 (facul) + R$ 50 (stream) = R$ 850
      // Nenhuma recorrência de Novembro em diante consome limite agora!
      final usedLimit = FinancialMovementEngine.calculateCardUsedLimit(
        state: state,
        cardId: 'card_nubank',
        referenceDate: DateTime(2026, 9, 24),
      );
      expect(usedLimit, 850.0);

      // Agora adiciona uma compra parcelada REAL: 5x de R$ 100 (total R$ 500)
      final installmentTx = FinancialTransaction(
        id: 'tx_installments',
        description: 'Eletrodoméstico 5x',
        amount: 500.0,
        purchaseDate: DateTime(2026, 9, 24),
        categoryId: 'cat_appliances',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        totalInstallments: 5,
      );
      state = FinancialMovementEngine.processNewTransaction(currentState: state, transaction: installmentTx);

      // Limite usado deve ser:
      // Fatura de Outubro (R$ 850 + R$ 100 Parcela 1) = R$ 950
      // + 4 parcelas futuras da compra parcelada real (4 x R$ 100 = R$ 400)
      // Total = R$ 1.350,00! (Recorrências futuras continuam devidamente excluídas)
      final usedWithInstallments = FinancialMovementEngine.calculateCardUsedLimit(
        state: state,
        cardId: 'card_nubank',
        referenceDate: DateTime(2026, 9, 24),
      );
      expect(usedWithInstallments, 1350.0);
    });
  });

  group('Saldo e Caixinha Históricos (calculateHistoricalBalances)', () {
    test('Reverte movimentações de meses posteriores para reproduzir o saldo de fechamento do mês anterior', () {
      final augIncome = FinancialMovement(
        id: 'm1',
        transactionId: 't1',
        type: MovementType.income,
        amount: 200.0,
        movementDate: DateTime(2026, 8, 10),
        description: 'Salário de Agosto',
      );
      final augReserve = FinancialMovement(
        id: 'm2',
        transactionId: null,
        type: MovementType.transferToReserve,
        amount: 300.0,
        movementDate: DateTime(2026, 8, 20),
        description: 'Transferência para caixinha',
      );
      final sepIncome = FinancialMovement(
        id: 'm3',
        transactionId: 't2',
        type: MovementType.income,
        amount: 500.0,
        movementDate: DateTime(2026, 9, 2),
        description: 'Freelance em Setembro',
      );
      final sepExpense = FinancialMovement(
        id: 'm4',
        transactionId: 't3',
        type: MovementType.expensePaid,
        amount: 100.0,
        movementDate: DateTime(2026, 9, 3),
        description: 'Mercado em Setembro',
      );

      final state = FinancialState(
        availableBalance: 1500.0,
        reserveBalance: 800.0,
        movements: [augIncome, augReserve, sepIncome, sepExpense],
      );

      // Calcular o saldo no fim de Agosto (31/08/2026):
      // Movimentações após 31/08:
      //  - sepExpense (expensePaid 100): desfaz somando 100 ao disponível
      //  - sepIncome (income 500): desfaz subtraindo 500 do disponível
      // Saldo no fim de Agosto esperado:
      // Disponível: 1500 + 100 - 500 = 1100.0
      // Caixinha: 800.0 (sem alterações na caixinha em setembro)
      final (histAvail, histRes) = FinancialMovementEngine.calculateHistoricalBalances(
        state: state,
        month: 8,
        year: 2026,
      );

      expect(histAvail, 1100.0);
      expect(histRes, 800.0);
    });
  });

  group('Segregação de Cobranças por Mês (calculateReimbursementDueForMonth)', () {
    test('Compras de terceiros ficam no mês da compra e parcelas avançam mês a mês', () {
      // 1. Compra à vista no cartão de R$ 50 para o Bob feita em 15/08/2026
      final tx1 = FinancialTransaction(
        id: 'tx_bob_1x',
        description: 'Lanche Bob',
        amount: 50.0,
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
        totalAmount: 50.0,
        remainingAmount: 50.0,
        createdAt: tx1.purchaseDate,
      );

      // Em Agosto (mês 8): Devido = R$ 50,00
      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonth(
          transaction: tx1,
          reimbursement: r1,
          targetMonth: 8,
          targetYear: 2026,
        ),
        50.0,
      );

      // Em Setembro (mês 9): Devido = R$ 0,00
      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonth(
          transaction: tx1,
          reimbursement: r1,
          targetMonth: 9,
          targetYear: 2026,
        ),
        0.0,
      );

      // 2. Compra parcelada em 3x de R$ 100 para o Bob feita em 10/08/2026
      final tx2 = FinancialTransaction(
        id: 'tx_bob_3x',
        description: 'Tênis Bob',
        amount: 300.0,
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
        totalAmount: 300.0,
        remainingAmount: 300.0,
        createdAt: tx2.purchaseDate,
      );

      // Parcela 1 cai no mês da compra (Agosto): R$ 100,00
      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonth(
          transaction: tx2,
          reimbursement: r2,
          targetMonth: 8,
          targetYear: 2026,
        ),
        100.0,
      );

      // Parcela 2 cai no mês seguinte (Setembro): R$ 100,00
      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonth(
          transaction: tx2,
          reimbursement: r2,
          targetMonth: 9,
          targetYear: 2026,
        ),
        100.0,
      );

      // Parcela 3 cai no 3º mês (Outubro): R$ 100,00
      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonth(
          transaction: tx2,
          reimbursement: r2,
          targetMonth: 10,
          targetYear: 2026,
        ),
        100.0,
      );

      // No 4º mês (Novembro): R$ 0,00
      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonth(
          transaction: tx2,
          reimbursement: r2,
          targetMonth: 11,
          targetYear: 2026,
        ),
        0.0,
      );

      // 3. Quitação do mês de Agosto (Bob paga R$ 100,00 da 1ª parcela)
      // remainingAmount passa de 300 para 200
      final r2AfterAugPayment = Reimbursement(
        id: 'r2',
        transactionId: tx2.id,
        personId: personBob.id,
        totalAmount: 300.0,
        remainingAmount: 200.0,
        createdAt: tx2.purchaseDate,
      );

      // Em Agosto (mês 8): Agora o devido é R$ 0,00 pois a 1ª parcela já foi quitada!
      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonth(
          transaction: tx2,
          reimbursement: r2AfterAugPayment,
          targetMonth: 8,
          targetYear: 2026,
        ),
        0.0,
      );

      // Em Setembro (mês 9): Continua R$ 100,00 para a 2ª parcela pendente
      expect(
        FinancialMovementEngine.calculateReimbursementDueForMonth(
          transaction: tx2,
          reimbursement: r2AfterAugPayment,
          targetMonth: 9,
          targetYear: 2026,
        ),
        100.0,
      );
    });
  });

  group('Cancelamento de Quitação (revertReimbursementPayment)', () {
    test('Desfaz pagamento de parcela: restaura saldo devedor, estorna do saldo em conta e remove movimentação', () {
      final r = Reimbursement(
        id: 'r_test',
        transactionId: 'tx_1',
        personId: personBob.id,
        totalAmount: 300.0,
        remainingAmount: 300.0,
        createdAt: DateTime(2026, 8, 10),
      );

      final initialState = FinancialState(
        availableBalance: 1000.0,
        reserveBalance: 500.0,
        reimbursements: [r],
        movements: [],
      );

      // Realiza o pagamento da 1ª parcela de R$ 100,00
      final paidState = FinancialMovementEngine.processReimbursementPayment(
        currentState: initialState,
        reimbursementId: r.id,
        amountReceived: 100.0,
        paymentDate: DateTime(2026, 8, 15),
        notes: 'Parcela 1/3',
      );

      expect(paidState.availableBalance, 1100.0);
      expect(paidState.reimbursements.first.remainingAmount, 200.0);
      expect(paidState.reimbursements.first.status, ReimbursementStatus.partiallyPaid);
      expect(paidState.reimbursements.first.payments.length, 1);
      final paymentId = paidState.reimbursements.first.payments.first.id;
      expect(paidState.movements.length, 1);
      expect(paidState.movements.first.type, MovementType.reimbursementReceived);

      // Agora desfaz a quitação desta parcela
      final revertedState = FinancialMovementEngine.revertReimbursementPayment(
        currentState: paidState,
        reimbursementId: r.id,
        paymentId: paymentId,
      );

      // O saldo disponível volta para 1000.0 (estorna os R$ 100)
      expect(revertedState.availableBalance, 1000.0);
      // O saldo devedor volta para 300.0
      expect(revertedState.reimbursements.first.remainingAmount, 300.0);
      // O status volta para pendente
      expect(revertedState.reimbursements.first.status, ReimbursementStatus.pending);
      // A lista de payments fica vazia
      expect(revertedState.reimbursements.first.payments.isEmpty, isTrue);
      // A movimentação financeira é removida do extrato
      expect(revertedState.movements.isEmpty, isTrue);
    });

    test('Desfaz quitação total legada sem lista de payments', () {
      final rSettled = Reimbursement(
        id: 'r_legacy',
        transactionId: 'tx_legacy',
        personId: personBob.id,
        totalAmount: 150.0,
        remainingAmount: 0.0,
        status: ReimbursementStatus.settled,
        createdAt: DateTime(2026, 8, 5),
        payments: const [],
      );

      final legacyMov = FinancialMovement(
        id: 'mov_legacy',
        transactionId: null,
        reimbursementId: 'r_legacy',
        type: MovementType.reimbursementReceived,
        amount: 150.0,
        movementDate: DateTime(2026, 8, 5),
        description: 'Reembolso recebido',
      );

      final state = FinancialState(
        availableBalance: 500.0,
        reserveBalance: 200.0,
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
      expect(reverted.movements.isEmpty, isTrue);
    });
  });

  group('Vigência Mensal e Período de Referência de Cobranças e Quitações', () {
    test('isReimbursementActiveInMonth: compras não poluem meses anteriores nem posteriores', () {
      final tx1xAug = FinancialTransaction(
        id: 'tx1',
        description: 'Almoço',
        amount: 50.0,
        purchaseDate: DateTime(2026, 8, 15),
        categoryId: 'cat_food',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.pix,
        totalInstallments: 1,
        personId: personBob.id,
      );

      // Em Julho/2026: NÃO ativo
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx1xAug, targetMonth: 7, targetYear: 2026), isFalse);
      // Em Agosto/2026: ATIVO
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx1xAug, targetMonth: 8, targetYear: 2026), isTrue);
      // Em Setembro/2026: NÃO ativo
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx1xAug, targetMonth: 9, targetYear: 2026), isFalse);

      final tx3xAug = FinancialTransaction(
        id: 'tx2',
        description: 'Tênis 3x',
        amount: 300.0,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_clothes',
        type: TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        totalInstallments: 3,
        personId: personBob.id,
      );

      // Em Julho/2026: NÃO ativo
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 7, targetYear: 2026), isFalse);
      // Em Agosto, Setembro e Outubro: ATIVO
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 8, targetYear: 2026), isTrue);
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 9, targetYear: 2026), isTrue);
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 10, targetYear: 2026), isTrue);
      // Em Novembro/2026: NÃO ativo
      expect(FinancialMovementEngine.isReimbursementActiveInMonth(transaction: tx3xAug, targetMonth: 11, targetYear: 2026), isFalse);
    });

    test('getReimbursementPaymentReferencePeriod: quitação de Agosto realizada em Setembro pertence a Agosto', () {
      final txAug = FinancialTransaction(
        id: 'tx1',
        description: 'Almoço Agosto',
        amount: 100.0,
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
        totalAmount: 100.0,
        remainingAmount: 0.0,
        createdAt: txAug.purchaseDate,
      );

      // Pagamento com paymentDate em Setembro, mas notas de Agosto
      final payWithNotes = ReimbursementPayment(
        id: 'p1',
        reimbursementId: 'r1',
        amount: 100.0,
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
        amount: 1000.0,
        movementDate: DateTime(2026, 8, 5),
        description: 'Salário Agosto',
      );

      final state = FinancialState(
        availableBalance: 1000.0,
        reserveBalance: 0.0,
        movements: [augMov],
      );

      // Em Julho/2026 (antes de qualquer movimentação):
      final (availJul, resJul) = FinancialMovementEngine.calculateHistoricalBalances(
        state: state,
        month: 7,
        year: 2026,
      );
      expect(availJul, 0.0);
      expect(resJul, 0.0);

      // Em Agosto/2026 (mês da movimentação):
      final (availAug, resAug) = FinancialMovementEngine.calculateHistoricalBalances(
        state: state,
        month: 8,
        year: 2026,
      );
      expect(availAug, 1000.0);
      expect(resAug, 0.0);
    });

    test('calculateHistoricalBalances: avançar no tempo e retornar ao mês atual não inflaciona o saldo atual', () {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Base: Transação recorrente de salário de R$ 2.000 no dia 5 deste mês
      final salaryTx = FinancialTransaction(
        id: 'tx_rec_salary',
        description: 'Salário Mensal',
        amount: 2000.0,
        purchaseDate: DateTime(currentYear, currentMonth, 5),
        categoryId: 'cat_income',
        type: TransactionType.income,
        paymentMethod: PaymentMethod.pix,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
      );

      var state = FinancialState(
        availableBalance: 3000.0,
        reserveBalance: 500.0,
        transactions: [salaryTx],
        movements: [
          FinancialMovement(
            id: 'mov_salary_curr',
            transactionId: salaryTx.id,
            type: MovementType.income,
            amount: 2000.0,
            movementDate: DateTime(currentYear, currentMonth, 5),
            description: 'Receita: Salário Mensal',
          ),
        ],
      );

      // Saldo no mês atual inicialmente: R$ 3000 disponível
      final (initialAvail, initialRes) = FinancialMovementEngine.calculateHistoricalBalances(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(initialAvail, equals(3000.0));
      expect(initialRes, equals(500.0));

      // Usuário avança no tempo para 3 meses no futuro (ex: targetMonth + 3)
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

      // O saldo disponível atual em conta NÃO é inflacionado por recorrências futuras: permanece R$ 3000.0
      expect(state.availableBalance, equals(3000.0));

      // No mês futuro projetado: o saldo reflete o acúmulo (R$ 9000)
      final (futureAvail, _) = FinancialMovementEngine.calculateHistoricalBalances(
        state: state,
        month: futureTargetMonth,
        year: futureTargetYear,
      );
      expect(futureAvail, equals(9000.0));

      // AO RETORNAR PARA O MÊS ATUAL:
      // O saldo DEVE voltar a ser R$ 3000.0, sem estar inflacionado pelos meses futuros!
      final (revertedAvail, revertedRes) = FinancialMovementEngine.calculateHistoricalBalances(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(revertedAvail, equals(3000.0));
      expect(revertedRes, equals(500.0));

      // DashboardSummary do mês atual também reflete o saldo real e patrimônio desinflacionados
      final summaryCurr = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(summaryCurr.availableBalance, equals(3000.0));
      expect(summaryCurr.reserveBalance, equals(500.0));
      expect(summaryCurr.totalNetWorth, equals(3500.0));
      expect(summaryCurr.freeBalance, equals(3500.0));
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

      // Despesa recorrente no cartão de crédito de R$ 500 todo mês
      final recCardTx = FinancialTransaction(
        id: 'tx_rec_card',
        description: 'Assinatura Software',
        amount: 500.0,
        purchaseDate: DateTime(currentYear, currentMonth, 10),
        categoryId: 'cat_sub',
        paymentMethod: PaymentMethod.creditCard,
        cardId: card.id,
        isRecurring: true,
        recurrence: RecurrenceFrequency.monthly,
      );

      var state = FinancialState(
        availableBalance: 3000.0,
        reserveBalance: 0.0,
        cards: [card],
        transactions: [],
        invoices: [],
        installments: [],
      );

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: recCardTx,
      );

      // No mês presente: Saldo Livre deve ser 3000 - 500 = 2500
      final summaryBeforeTravel = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(summaryBeforeTravel.committedBalance, equals(500.0));
      expect(summaryBeforeTravel.freeBalance, equals(2500.0));

      // Usuário avança 5 meses no futuro
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

      // Faturas foram geradas para os meses futuros (total de 6 faturas de R$ 500 = R$ 3000)
      final allOpenInvoices = state.invoices.where((i) => !i.isPaid).fold<double>(0.0, (acc, i) => acc + i.totalAmount);
      expect(allOpenInvoices, equals(3000.0));

      // RETORNANDO AO MÊS ATUAL:
      // O committedBalance do mês atual NÃO deve ser 3000.0 (todas as faturas do futuro)!
      // Deve ser APENAS os 500.0 da fatura do mês atual!
      // E o freeBalance NÃO deve ficar negativo, mas exatamente 2500.0!
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

      var state = const FinancialState(
        availableBalance: 2000.0,
        reserveBalance: 500.0,
      );

      // Adiciona uma receita futura (mês que vem)
      final futureDate = DateTime(currentYear, currentMonth + 1, 10);
      final futureTx = FinancialTransaction(
        id: 'tx_future_income',
        description: 'Receita Futura',
        amount: 5000.0,
        purchaseDate: futureDate,
        categoryId: 'cat_income',
        paymentMethod: PaymentMethod.pix,
        type: TransactionType.income,
      );

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: futureTx,
      );

      // O saldo em conta HOJE deve continuar 2000.0 (não pode inflacionar para 7000.0)
      expect(state.availableBalance, equals(2000.0));
      // Não deve ter gerado movimentação no ledger
      expect(state.movements.any((m) => m.transactionId == futureTx.id), isFalse);

      // Saldo do mês atual no dashboard é 2000.0
      final (currAvail, _) = FinancialMovementEngine.calculateHistoricalBalances(
        state: state,
        month: currentMonth,
        year: currentYear,
      );
      expect(currAvail, equals(2000.0));

      // Saldo projetado no mês futuro reflete a receita futura
      final (futureAvail, _) = FinancialMovementEngine.calculateHistoricalBalances(
        state: state,
        month: futureDate.month,
        year: futureDate.year,
      );
      expect(futureAvail, equals(7000.0));

      // Exclusão de transação futura não afeta o saldo atual de R$ 2000.0
      state = FinancialMovementEngine.deleteTransaction(
        currentState: state,
        transactionId: futureTx.id,
      );
      expect(state.availableBalance, equals(2000.0));
    });
  });
}
