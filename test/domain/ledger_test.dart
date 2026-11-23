import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/core/utils/money.dart';
import 'package:chokin/domain/engine/financial_movement_engine.dart';
import 'package:chokin/domain/engine/ledger.dart';
import 'package:chokin/domain/entities/credit_card.dart';
import 'package:chokin/domain/entities/financial_movement.dart';
import 'package:chokin/domain/entities/person.dart';
import 'package:chokin/domain/entities/transaction.dart';

void main() {
  const card = CreditCard(id: 'card', name: 'Nubank', closingDay: 3, dueDay: 10, creditLimitCents: 500000);
  final me = Person(id: 'ME', name: 'Eu', createdAt: DateTime(2026, 1, 1));

  FinancialTransaction pix(String id, int cents, DateTime date, {TransactionType type = TransactionType.expense}) {
    return FinancialTransaction(
      id: id,
      description: id,
      amountCents: cents,
      purchaseDate: date,
      categoryId: 'cat_other',
      type: type,
      paymentMethod: PaymentMethod.pix,
    );
  }

  group('Dinheiro em centavos', () {
    test('Parcelas somam exatamente o total, com a diferença na última', () {
      expect(Money.splitInstallments(20000, 3), [6667, 6667, 6666]);
      expect(Money.splitInstallments(10000, 3), [3333, 3333, 3334]);
      expect(Money.splitInstallments(9990, 7).reduce((a, b) => a + b), 9990);
      expect(Money.splitInstallments(4590, 1), [4590]);
    });

    test('Somar muitos centavos não acumula erro de arredondamento', () {
      var state = FinancialState(people: [me]);
      for (var i = 0; i < 10; i++) {
        state = FinancialMovementEngine.processNewTransaction(
          currentState: state,
          transaction: pix('r$i', 10, DateTime(2026, 8, 1 + i), type: TransactionType.income),
        );
      }
      expect(state.availableCents, 100);
      expect(state.availableBalance, 1.0);
    });

    test('Conversão de reais lida com resíduos de ponto flutuante', () {
      expect(Money.fromReais(5564.1999999999999), 556420);
      expect(Money.fromReais(912.4299999999998), 91243);
      expect(Money.fromReais(0.1 + 0.2), 30);
    });
  });

  group('Saldos vêm do livro-razão', () {
    test('Excluir uma despesa devolve o dinheiro ao saldo', () {
      var state = FinancialState.reconciled(availableCents: 50000, people: [me]);

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: pix('mercado', 30000, DateTime(2026, 8, 10)),
      );
      expect(state.availableCents, 20000);

      state = FinancialMovementEngine.deleteTransaction(currentState: state, transactionId: 'mercado');
      expect(state.availableCents, 50000);
    });

    test('Saldo de um mês passado não conta o que entrou depois', () {
      var state = FinancialState.reconciled(availableCents: 10000, people: [me]);
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: pix('aluguel', 30000, DateTime(2026, 8, 10)),
      );
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: pix('salario', 200000, DateTime(2026, 9, 5), type: TransactionType.income),
      );

      final august = FinancialMovementEngine.calculateHistoricalBalanceCents(state: state, month: 8, year: 2026);
      expect(august, -20000);
    });

    test('Movimentos antigos da caixinha não mudam o saldo total', () {
      final movements = [
        FinancialMovement(
          id: 'a',
          type: MovementType.manualAdjustment,
          amountCents: 80000,
          movementDate: DateTime(2026, 8, 1),
          description: 'Saldo inicial',
        ),
        FinancialMovement(
          id: 'b',
          type: MovementType.transferToReserve,
          amountCents: 50000,
          movementDate: DateTime(2026, 8, 2),
          description: 'Transferência automática para reserva',
        ),
        FinancialMovement(
          id: 'c',
          type: MovementType.reserveCompensation,
          amountCents: 20000,
          movementDate: DateTime(2026, 8, 3),
          description: 'Complemento de despesas pela reserva',
        ),
      ];
      expect(Ledger.balance(movements), 80000);
    });

    test('Ajustar o saldo registra a diferença: saldo inicial e depois ajuste', () {
      var state = FinancialState(people: [me]);
      state = FinancialMovementEngine.adjustBalances(currentState: state, availableCents: 200000);
      expect(state.availableCents, 200000);
      expect(state.movements.single.description, 'Saldo inicial');

      state = FinancialMovementEngine.adjustBalances(currentState: state, availableCents: 195000);
      expect(state.availableCents, 195000);
      final adjustment = state.movements.last;
      expect(adjustment.description, 'Ajuste de saldo');
      expect(adjustment.amountCents, -5000);

      final unchanged = FinancialMovementEngine.adjustBalances(currentState: state, availableCents: 195000);
      expect(unchanged.movements.length, state.movements.length);
    });
  });

  group('Estornos', () {
    test('Estornos parciais se acumulam e nunca passam do valor da compra', () {
      var state = FinancialState.reconciled(availableCents: 100000, people: [me]);
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: pix('tenis', 30000, DateTime(2026, 8, 10)),
      );

      for (var i = 0; i < 3; i++) {
        state = FinancialMovementEngine.processTransactionRefund(
          currentState: state,
          transactionId: 'tenis',
          refundAmountCents: 15000,
          refundMethod: PaymentMethod.pix,
          refundDate: DateTime(2026, 8, 12),
        );
      }

      final tx = state.transactions.single;
      expect(tx.refundAmountCents, 30000);
      expect(tx.isFullyRefunded, isTrue);
      expect(state.availableCents, 100000);
    });

    test('Estorno na fatura abate as parcelas e não entra no saldo em conta', () {
      var state = FinancialState.reconciled(availableCents: 100000, cards: [card], people: [me]);
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tv',
          description: 'TV',
          amountCents: 20000,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_other',
          paymentMethod: PaymentMethod.creditCard,
          cardId: 'card',
          totalInstallments: 3,
        ),
      );
      state = FinancialMovementEngine.processTransactionRefund(
        currentState: state,
        transactionId: 'tv',
        refundAmountCents: 10000,
        refundMethod: PaymentMethod.creditCard,
        refundDate: DateTime(2026, 8, 15),
      );

      final amounts = state.installments.map((i) => i.amountCents).toList();
      expect(amounts, [6667, 3333, 0]);
      expect(state.invoices.fold<int>(0, (acc, i) => acc + i.totalAmountCents), 10000);
      expect(state.availableCents, 100000);
    });
  });
}
