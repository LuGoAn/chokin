import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/core/utils/currency_utils.dart';
import 'package:chokin/domain/entities/person.dart';
import 'package:chokin/domain/entities/transaction.dart';
import 'package:chokin/domain/entities/credit_card.dart';
import 'package:chokin/domain/engine/financial_movement_engine.dart';
import 'package:flutter/services.dart';

void main() {
  group('CurrencyUtils & CurrencyTextInputFormatter Tests', () {
    test('CurrencyUtils.parse parses single dot, comma, and formatted currency correctly', () {
      expect(CurrencyUtils.parse('25.36'), equals(25.36));
      expect(CurrencyUtils.parse('25,36'), equals(25.36));
      expect(CurrencyUtils.parse('R\$ 25,36'), equals(25.36));
      expect(CurrencyUtils.parse('1.250,50'), equals(1250.50));
      expect(CurrencyUtils.parse('1,250.50'), equals(1250.50));
      expect(CurrencyUtils.parse('1000'), equals(1000.0));
      expect(CurrencyUtils.parse('0,05'), equals(0.05));
    });

    test('CurrencyTextInputFormatter formats numeric input progressivelty as Brazilian currency', () {
      final formatter = CurrencyTextInputFormatter();

      // Digitando '2' -> 0,02
      var result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '2'),
      );
      expect(result.text, equals('0,02'));

      // Digitando '25' -> 0,25
      result = formatter.formatEditUpdate(
        const TextEditingValue(text: '0,02'),
        const TextEditingValue(text: '0025'),
      );
      expect(result.text, equals('0,25'));

      // Digitando '2536' -> 25,36
      result = formatter.formatEditUpdate(
        const TextEditingValue(text: '0,25'),
        const TextEditingValue(text: '2536'),
      );
      expect(result.text, equals('25,36'));
    });
  });

  group('Person Entity & Third Party Isolation Tests', () {
    test('Person entity copyWith and serialization', () {
      final p1 = Person(
        id: 'p_1',
        name: 'Mãe',
        phone: '8599999999',
        createdAt: DateTime(2026, 1, 1),
      );

      final p2 = p1.copyWith(name: 'Mãe Celular Novo');
      expect(p2.name, equals('Mãe Celular Novo'));
      expect(p2.phone, equals('8599999999'));

      final map = p1.toMap();
      final fromMap = Person.fromMap(map);
      expect(fromMap.id, equals('p_1'));
      expect(fromMap.name, equals('Mãe'));
    });

    test('Dashboard Summary freeBalance correctly offsets third party credit card debt with receivables', () {
      final initialCard = CreditCard(
        id: 'card_nubank',
        name: 'Nubank',
        closingDay: 1,
        dueDay: 8,
      );

      var state = FinancialState(
        availableBalance: 0.0,
        reserveBalance: 0.0,
        transactions: [],
        invoices: [],
        installments: [],
        reimbursements: [],
        movements: [],
        cards: [initialCard],
        people: [
          Person(id: 'ME', name: 'Eu', createdAt: DateTime.now()),
          Person(id: 'p_pai', name: 'Pai', createdAt: DateTime.now()),
        ],
      );

      // Compra de R$ 1.000 em 10x para o Pai
      final tvTx = FinancialTransaction(
        id: 'tx_tv',
        description: 'TV Sala para o Pai',
        amount: 1000.0,
        purchaseDate: DateTime(2026, 8, 10),
        categoryId: 'cat_electronics',
        paymentMethod: PaymentMethod.creditCard,
        personId: 'p_pai',
        cardId: 'card_nubank',
        totalInstallments: 10,
      );

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: tvTx,
      );

      // Em Agosto (mês da compra):
      // A compra parcela 1/10 está prevista para Agosto e o total pendente é R$ 1.000
      final summaryAug = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 8,
        year: 2026,
      );
      expect(summaryAug.committedBalance, equals(0.0));
      expect(summaryAug.pendingReimbursements, equals(100.0));
      expect(summaryAug.totalPendingReimbursements, equals(1000.0));
      expect(summaryAug.freeBalance, equals(0.0));
      expect(summaryAug.periodCreditPurchases, equals(0.0));

      // Em Setembro (mês seguinte da 2ª parcela de R$ 100 da TV):
      final summarySep = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 9,
        year: 2026,
      );
      // Saldo Comprometido da fatura de Setembro = R$ 100
      expect(summarySep.committedBalance, equals(100.0));
      // Total a Receber do Pai em Setembro = R$ 100
      expect(summarySep.pendingReimbursements, equals(100.0));
      expect(summarySep.totalPendingReimbursements, equals(1000.0));
      // Saldo Livre Real NÃO fica negativo: (0 + 0 + 100) - 100 = 0.0
      expect(summarySep.freeBalance, equals(0.0));
    });
  });
}
