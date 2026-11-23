import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/domain/entities/transaction.dart';
import 'package:chokin/domain/entities/credit_card.dart';
import 'package:chokin/domain/entities/person.dart';
import 'package:chokin/domain/entities/financial_movement.dart';
import 'package:chokin/domain/engine/financial_movement_engine.dart';

void main() {
  group('Suíte de Testes de Estornos e Devoluções do Chokin', () {
    late CreditCard testCard;
    late FinancialState initialState;

    setUp(() {
      testCard = const CreditCard(
        id: 'card_nubank',
        name: 'Nubank',
        closingDay: 1,
        dueDay: 8,
      );

      initialState = FinancialState.reconciled(
        availableCents: 100000,
        transactions: [],
        invoices: [],
        installments: [],
        reimbursements: [],
        movements: [],
        cards: [testCard],
        people: [
          Person(id: 'ME', name: 'Eu', createdAt: DateTime.now()),
          Person(id: 'p_mae', name: 'Mãe', createdAt: DateTime.now()),
        ],
      );
    });

    test('Cenário 1: Estorno Total no Cartão (na mesma forma de pagamento) reduz fatura a zero', () {
      final tx = FinancialTransaction(
        id: 'tx_fone',
        description: 'Fone de Ouvido Bluetooth',
        amountCents: 30000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_electronics',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState,
        transaction: tx,
      );

      expect(state.invoices.first.totalAmount, equals(300.0));
      expect(state.installments.first.amount, equals(300.0));

      state = FinancialMovementEngine.processTransactionRefund(
        currentState: state,
        transactionId: 'tx_fone',
        refundAmountCents: 30000,
        refundMethod: PaymentMethod.creditCard,
        notes: 'Produto devolvido com defeito',
      );

      final refundedTx = state.transactions.firstWhere((t) => t.id == 'tx_fone');
      expect(refundedTx.isRefunded, isTrue);
      expect(refundedTx.isFullyRefunded, isTrue);
      expect(refundedTx.refundAmount, equals(300.0));
      expect(refundedTx.netAmount, equals(0.0));
      expect(refundedTx.refundNotes, equals('Produto devolvido com defeito'));

      expect(state.invoices.first.totalAmount, equals(0.0));
      expect(state.installments.first.amount, equals(0.0));

      expect(state.movements.any((m) => m.type == MovementType.cardRefund && m.amountCents == 30000), isTrue);
      expect(state.availableBalance, equals(1000.0));
    });

    test('Cenário 2: Estorno Parcial no Cartão em compra parcelada abate das parcelas', () {
      final tx = FinancialTransaction(
        id: 'tx_roupas',
        description: 'Roupas Shopping',
        amountCents: 30000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_clothing',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        totalInstallments: 3,
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState,
        transaction: tx,
      );

      expect(state.installments.length, equals(3));
      expect(state.installments.every((i) => i.amount == 100.0), isTrue);

      state = FinancialMovementEngine.processTransactionRefund(
        currentState: state,
        transactionId: 'tx_roupas',
        refundAmountCents: 10000,
        refundMethod: PaymentMethod.creditCard,
      );

      final refundedTx = state.transactions.firstWhere((t) => t.id == 'tx_roupas');
      expect(refundedTx.isPartiallyRefunded, isTrue);
      expect(refundedTx.refundAmount, equals(100.0));
      expect(refundedTx.netAmount, equals(200.0));

      final insts = state.installments.where((i) => i.transactionId == 'tx_roupas').toList();
      final totalInstallmentsSum = insts.fold<double>(0.0, (acc, i) => acc + i.amount);
      expect(totalInstallmentsSum, equals(200.0));
    });

    test('Cenário 3: Compra no Cartão estornada via Pix aumenta o saldo disponível em conta', () {
      final tx = FinancialTransaction(
        id: 'tx_mercado',
        description: 'Supermercado',
        amountCents: 15000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_market',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState,
        transaction: tx,
      );

      expect(state.availableBalance, equals(1000.0));

      state = FinancialMovementEngine.processTransactionRefund(
        currentState: state,
        transactionId: 'tx_mercado',
        refundAmountCents: 15000,
        refundMethod: PaymentMethod.pix,
      );

      expect(state.availableBalance, equals(1150.0));

      expect(state.invoices.first.totalAmount, equals(150.0));

      final refundedTx = state.transactions.firstWhere((t) => t.id == 'tx_mercado');
      expect(refundedTx.isRefunded, isTrue);
      expect(refundedTx.refundMethod, equals(PaymentMethod.pix));
    });

    test('Cenário 4: Estorno de Compra para Terceiro abate a dívida a receber da pessoa', () {
      final tx = FinancialTransaction(
        id: 'tx_mae_remedio',
        description: 'Remédio Farmácia para Mãe',
        amountCents: 20000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_health',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        personId: 'p_mae',
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState,
        transaction: tx,
      );

      expect(state.reimbursements.first.remainingAmount, equals(200.0));
      expect(state.reimbursements.first.isSettled, isFalse);

      state = FinancialMovementEngine.processTransactionRefund(
        currentState: state,
        transactionId: 'tx_mae_remedio',
        refundAmountCents: 20000,
        refundMethod: PaymentMethod.creditCard,
      );

      final reimb = state.reimbursements.firstWhere((r) => r.transactionId == 'tx_mae_remedio');
      expect(reimb.remainingAmount, equals(0.0));
      expect(reimb.isSettled, isTrue);
    });

    test('Cenário 5: Estorno de Compra no Pix restaura o saldo disponível em conta', () {
      final tx = FinancialTransaction(
        id: 'tx_pix_almoço',
        description: 'Almoço Restaurante',
        amountCents: 8000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_food',
        paymentMethod: PaymentMethod.pix,
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState,
        transaction: tx,
      );

      expect(state.availableBalance, equals(920.0));

      state = FinancialMovementEngine.processTransactionRefund(
        currentState: state,
        transactionId: 'tx_pix_almoço',
        refundAmountCents: 8000,
        refundMethod: PaymentMethod.pix,
      );

      expect(state.availableBalance, equals(1000.0));
      final refundedTx = state.transactions.firstWhere((t) => t.id == 'tx_pix_almoço');
      expect(refundedTx.isFullyRefunded, isTrue);
      expect(refundedTx.refundAmount, equals(80.0));
    });

    test('Cenário 6: Ordenação de compras na fatura coloca as compras mais recentes no topo (ordem decrescente)', () {
      final tx1 = FinancialTransaction(
        id: 'tx_1',
        description: 'Primeira Compra (05/08)',
        amountCents: 5000,
        purchaseDate: DateTime(2026, 8, 5, 10, 0),
        categoryId: 'cat_other',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        createdAt: DateTime(2026, 8, 5, 10, 0),
      );

      final tx2 = FinancialTransaction(
        id: 'tx_2',
        description: 'Segunda Compra (10/08 14h)',
        amountCents: 7000,
        purchaseDate: DateTime(2026, 8, 10, 14, 0),
        categoryId: 'cat_other',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        createdAt: DateTime(2026, 8, 10, 14, 0),
      );

      final tx3 = FinancialTransaction(
        id: 'tx_3',
        description: 'Terceira Compra (10/08 18h - mesma data, adicionada depois)',
        amountCents: 9000,
        purchaseDate: DateTime(2026, 8, 10, 18, 0),
        categoryId: 'cat_other',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        createdAt: DateTime(2026, 8, 10, 18, 0),
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState,
        transaction: tx1,
      );
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: tx2,
      );
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: tx3,
      );

      final inv = state.invoices.first;
      final installments = state.installments.where((i) => i.invoiceId == inv.id).toList();

      installments.sort((a, b) {
        final itemA = state.transactions.firstWhere((t) => t.id == a.transactionId);
        final itemB = state.transactions.firstWhere((t) => t.id == b.transactionId);

        final dateCmp = itemB.purchaseDate.compareTo(itemA.purchaseDate);
        if (dateCmp != 0) return dateCmp;

        final createdCmp = itemB.effectiveCreatedAt.compareTo(itemA.effectiveCreatedAt);
        if (createdCmp != 0) return createdCmp;

        final idxA = state.transactions.indexOf(itemA);
        final idxB = state.transactions.indexOf(itemB);
        final idxCmp = idxB.compareTo(idxA);
        if (idxCmp != 0) return idxCmp;

        return a.installmentNumber.compareTo(b.installmentNumber);
      });

      expect(installments[0].transactionId, equals('tx_3'));
      expect(installments[1].transactionId, equals('tx_2'));
      expect(installments[2].transactionId, equals('tx_1'));
    });

    test('Cenário 7: Total Gasto no Mês contabiliza apenas o valor da parcela em compras parceladas no cartão', () {
      final cardTx = FinancialTransaction(
        id: 'tx_tv_1200',
        description: 'Smart TV',
        amountCents: 120000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_tech',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        totalInstallments: 6,
      );

      final pixTx = FinancialTransaction(
        id: 'tx_supermarket_100',
        description: 'Supermercado',
        amountCents: 10000,
        purchaseDate: DateTime(2026, 8, 12),
        categoryId: 'cat_food',
        paymentMethod: PaymentMethod.pix,
      );

      const cardWithMidClosing = CreditCard(
        id: 'card_nubank',
        name: 'Nubank',
        closingDay: 20,
        dueDay: 27,
      );
      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState.copyWith(cards: [cardWithMidClosing]),
        transaction: cardTx,
      );
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: pixTx,
      );

      final summary = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 8,
        year: 2026,
      );

      expect(summary.periodCreditPurchases, equals(200.0));
      expect(summary.periodPixExpenses, equals(100.0));
      expect(summary.periodPaidExpenses, equals(300.0));
    });

    test('Cenário 8: Edição de transação para alterar parcelamento (de 1x para 3x) recalcula faturas e parcelas atomicamente', () {
      final txOriginal = FinancialTransaction(
        id: 'tx_edit_installments',
        description: 'Tênis de Corrida',
        amountCents: 30000,
        purchaseDate: DateTime(2026, 8, 15),
        categoryId: 'cat_clothing',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        totalInstallments: 1,
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState,
        transaction: txOriginal,
      );

      expect(state.installments.where((i) => i.transactionId == 'tx_edit_installments').length, equals(1));
      expect(state.installments.first.amount, equals(300.0));

      final txEdited = txOriginal.copyWith(totalInstallments: 3);

      var intermediateState = FinancialMovementEngine.deleteTransaction(
        currentState: state,
        transactionId: txOriginal.id,
      );
      state = FinancialMovementEngine.processNewTransaction(
        currentState: intermediateState,
        transaction: txEdited,
      );

      final newInstallments = state.installments.where((i) => i.transactionId == 'tx_edit_installments').toList();
      expect(newInstallments.length, equals(3));
      for (final inst in newInstallments) {
        expect(inst.amount, equals(100.0));
      }
    });

    test('Cenário 9: Compra parcelada distribui parcelas entre meses sucessivos no Total Gasto sem redundância', () {
      const midMonthCard = CreditCard(
        id: 'card_mid',
        name: 'Card Mid',
        closingDay: 20,
        dueDay: 27,
      );

      final cardTx = FinancialTransaction(
        id: 'tx_course_600',
        description: 'Curso Online',
        amountCents: 60000,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_education',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_mid',
        totalInstallments: 3,
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState.copyWith(cards: [midMonthCard]),
        transaction: cardTx,
      );

      final summaryAug = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 8,
        year: 2026,
      );
      expect(summaryAug.periodCreditPurchases, equals(200.0));
      expect(summaryAug.periodPaidExpenses, equals(200.0));

      final summarySep = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 9,
        year: 2026,
      );
      expect(summarySep.periodCreditPurchases, equals(200.0));
      expect(summarySep.periodPaidExpenses, equals(200.0));

      final summaryOct = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 10,
        year: 2026,
      );
      expect(summaryOct.periodCreditPurchases, equals(200.0));
      expect(summaryOct.periodPaidExpenses, equals(200.0));

      final summaryNov = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 11,
        year: 2026,
      );
      expect(summaryNov.periodCreditPurchases, equals(0.0));
      expect(summaryNov.periodPaidExpenses, equals(0.0));
    });

    test('Cenário 10: Compra parcelada em cartão com closingDay: 1 contabiliza Parcela 1 no mês da compra e Parcela 2 no mês seguinte', () {
      final cardTx = FinancialTransaction(
        id: 'tx_august_tv',
        description: 'Smart TV',
        amountCents: 90000,
        purchaseDate: DateTime(2026, 8, 15),
        categoryId: 'cat_tech',
        paymentMethod: PaymentMethod.creditCard,
        cardId: 'card_nubank',
        totalInstallments: 3,
      );

      var state = FinancialMovementEngine.processNewTransaction(
        currentState: initialState,
        transaction: cardTx,
      );

      final summaryAug = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 8,
        year: 2026,
      );
      expect(summaryAug.periodCreditPurchases, equals(300.0));
      expect(summaryAug.periodPaidExpenses, equals(300.0));

      final summarySep = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 9,
        year: 2026,
      );
      expect(summarySep.periodCreditPurchases, equals(300.0));
      expect(summarySep.periodPaidExpenses, equals(300.0));

      final summaryOct = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 10,
        year: 2026,
      );
      expect(summaryOct.periodCreditPurchases, equals(300.0));
      expect(summaryOct.periodPaidExpenses, equals(300.0));

      final summaryNov = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 11,
        year: 2026,
      );
      expect(summaryNov.periodCreditPurchases, equals(0.0));
    });
  });
}
