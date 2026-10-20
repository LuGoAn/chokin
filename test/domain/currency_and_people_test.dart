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

      var result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '2'),
      );
      expect(result.text, equals('0,02'));

      result = formatter.formatEditUpdate(
        const TextEditingValue(text: '0,02'),
        const TextEditingValue(text: '0025'),
      );
      expect(result.text, equals('0,25'));

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

      var state = FinancialState.reconciled(
        availableCents: 0,
        reserveCents: 0,
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

      final tvTx = FinancialTransaction(
        id: 'tx_tv',
        description: 'TV Sala para o Pai',
        amountCents: 100000,
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

      final summarySep = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 9,
        year: 2026,
      );
      expect(summarySep.committedBalance, equals(100.0));
      expect(summarySep.pendingReimbursements, equals(100.0));
      expect(summarySep.totalPendingReimbursements, equals(1000.0));
      expect(summarySep.freeBalance, equals(0.0));
    });
  });
}
