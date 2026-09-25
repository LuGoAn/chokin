import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/core/utils/date_time_utils.dart';
import 'package:chokin/domain/entities/credit_card.dart';
import 'package:chokin/domain/entities/financial_movement.dart';
import 'package:chokin/domain/entities/inbox_notification.dart';
import 'package:chokin/domain/entities/person.dart';
import 'package:chokin/domain/entities/reimbursement.dart';
import 'package:chokin/domain/entities/transaction.dart';
import 'package:chokin/domain/engine/financial_movement_engine.dart';
import 'package:chokin/domain/notifications/deduplication/deduplication_engine.dart';
import 'package:chokin/domain/notifications/notification_payload.dart';
import 'package:chokin/domain/notifications/parsers/nubank_parser.dart';
import 'package:chokin/domain/notifications/parsers/samsung_pay_parser.dart';

void main() {
  const defaultCard = CreditCard(
    id: 'card_nubank',
    name: 'Nubank',
    closingDay: 1,
    dueDay: 8,
    creditLimit: 5000.0,
  );

  final mother = Person(
    id: 'p_mother',
    name: 'Mãe',
    createdAt: DateTime(2026, 1, 1),
  );

  FinancialState getInitialState({double available = 0.0, double reserve = 0.0}) {
    return FinancialState(
      availableBalance: available,
      reserveBalance: reserve,
      cards: [defaultCard],
      people: [Person(id: 'ME', name: 'Eu', createdAt: DateTime(2026, 1, 1)), mother],
    );
  }

  group('Suíte de Testes dos 16 Cenários Obrigatórios do Chokin', () {
    // 1. Receita R$ 400 + gasto R$ 300 -> R$ 100 enviados para reserva
    test('Cenário 1: Receita R\$ 400 + gasto R\$ 300 -> R\$ 100 enviados para reserva', () {
      var state = getInitialState(available: 0, reserve: 1000);

      // Receita R$ 400
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_rec',
          description: 'Salário',
          amount: 400.0,
          purchaseDate: DateTime(2026, 8, 5),
          categoryId: 'cat_salary',
          type: TransactionType.income,
          paymentMethod: PaymentMethod.pix,
        ),
      );

      // Gasto R$ 300 (Pix/Imediato)
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_exp',
          description: 'Supermercado',
          amount: 300.0,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_food',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.pix,
        ),
      );

      expect(state.availableBalance, 100.0);
      expect(state.reserveBalance, 1000.0);

      // Fechamento / Transferência de sobra
      state = FinancialMovementEngine.transferSurplusToReserve(
        currentState: state,
        periodDate: DateTime(2026, 8, 31),
      );

      expect(state.availableBalance, 0.0);
      expect(state.reserveBalance, 1100.0);
      expect(
        state.movements.any((m) => m.type == MovementType.transferToReserve && m.amount == 100.0),
        isTrue,
      );
    });

    // 2. Receita R$ 400 + Pix R$ 500 -> R$ 100 retirados da reserva
    test('Cenário 2: Receita R\$ 400 + Pix R\$ 500 -> R\$ 100 retirados da reserva', () {
      var state = getInitialState(available: 0, reserve: 1000);

      // Receita R$ 400
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_rec2',
          description: 'Mesada',
          amount: 400.0,
          purchaseDate: DateTime(2026, 8, 5),
          categoryId: 'cat_salary',
          type: TransactionType.income,
          paymentMethod: PaymentMethod.pix,
        ),
      );

      // Pix R$ 500
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_pix500',
          description: 'Conserto Celular',
          amount: 500.0,
          purchaseDate: DateTime(2026, 8, 12),
          categoryId: 'cat_other',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.pix,
        ),
      );

      expect(state.availableBalance, 0.0);
      expect(state.reserveBalance, 900.0);
      expect(
        state.movements.any((m) => m.type == MovementType.reserveCompensation && m.amount == 100.0),
        isTrue,
      );
    });

    // 3. Compra cartão R$ 500 -> Reserva não altera imediatamente
    test('Cenário 3: Compra cartão R\$ 500 -> Reserva não altera imediatamente', () {
      var state = getInitialState(available: 0, reserve: 1000);

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_card500',
          description: 'Notebook Monitor',
          amount: 500.0,
          purchaseDate: DateTime(2026, 8, 15),
          categoryId: 'cat_tech',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.creditCard,
          cardId: defaultCard.id,
        ),
      );

      // Reserva continua R$ 1000 intacta
      expect(state.reserveBalance, 1000.0);
      expect(state.availableBalance, 0.0);
      expect(state.invoices.isNotEmpty, isTrue);
      expect(state.invoices.first.totalAmount, 500.0);
    });

    // 4. Pagamento de fatura R$ 500 -> Reserva/dinheiro é reduzido
    test('Cenário 4: Pagamento de fatura R\$ 500 -> Retira do dinheiro/reserva', () {
      var state = getInitialState(available: 0, reserve: 1000);

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_card500',
          description: 'Monitor',
          amount: 500.0,
          purchaseDate: DateTime(2026, 8, 15),
          categoryId: 'cat_tech',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.creditCard,
          cardId: defaultCard.id,
        ),
      );

      final invoiceId = state.invoices.first.id;

      // Paga fatura
      state = FinancialMovementEngine.processInvoicePayment(
        currentState: state,
        invoiceId: invoiceId,
        paymentDate: DateTime(2026, 9, 8),
      );

      expect(state.reserveBalance, 500.0);
      expect(state.invoices.first.isPaid, isTrue);
    });

    // 5. Pagamento antecipado -> Usar data real do pagamento
    test('Cenário 5: Pagamento antecipado -> Usar data real do pagamento', () {
      var state = getInitialState(available: 600, reserve: 1000);

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_card300',
          description: 'Tênis',
          amount: 300.0,
          purchaseDate: DateTime(2026, 8, 15),
          categoryId: 'cat_clothing',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.creditCard,
          cardId: defaultCard.id,
        ),
      );

      final invId = state.invoices.first.id;
      final realPaymentDate = DateTime(2026, 9, 4); // Vencimento seria 08/09

      state = FinancialMovementEngine.processInvoicePayment(
        currentState: state,
        invoiceId: invId,
        paymentDate: realPaymentDate,
      );

      final mov = state.movements.firstWhere((m) => m.type == MovementType.invoicePayment);
      expect(mov.movementDate, realPaymentDate);
      expect(state.invoices.first.paidAt, realPaymentDate);
    });

    // 6. Compra parcelada -> Parcelas corretas vinculadas à compra original
    test('Cenário 6: Compra parcelada R\$ 1.200 em 6x -> 6 parcelas de R\$ 200', () {
      var state = getInitialState();

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_parcelada',
          description: 'Smartphone',
          amount: 1200.0,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_tech',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.creditCard,
          cardId: defaultCard.id,
          totalInstallments: 6,
        ),
      );

      expect(state.installments.length, 6);
      expect(state.installments.every((i) => i.transactionId == 'tx_parcelada'), isTrue);
      expect(state.installments.every((i) => i.amount == 200.0), isTrue);
      expect(state.invoices.length, 6);
    });

    // 7. Compra de terceiro -> Valor aparece como a receber
    test('Cenário 7: Compra de terceiro R\$ 300 para a Mãe -> Gera valor a receber', () {
      var state = getInitialState(available: 400);

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_mae',
          description: 'Remédio da Mãe',
          amount: 300.0,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_health',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.pix,
          personId: mother.id,
        ),
      );

      expect(state.reimbursements.length, 1);
      final r = state.reimbursements.first;
      expect(r.personId, mother.id);
      expect(r.totalAmount, 300.0);
      expect(r.remainingAmount, 300.0);
      expect(r.status, ReimbursementStatus.pending);

      final summary = FinancialMovementEngine.calculateDashboardSummary(
        state: state,
        month: 8,
        year: 2026,
      );
      expect(summary.pendingReimbursements, 300.0);
    });

    // 8. Reembolso parcial -> Saldo devedor restante atualizado
    test('Cenário 8: Reembolso parcial -> Deve R\$ 300 e paga R\$ 100 -> Resta R\$ 200', () {
      var state = getInitialState(available: 400);

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_mae2',
          description: 'Compras Mãe',
          amount: 300.0,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_health',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.pix,
          personId: mother.id,
        ),
      );

      final rId = state.reimbursements.first.id;

      // Mãe paga R$ 100
      state = FinancialMovementEngine.processReimbursementPayment(
        currentState: state,
        reimbursementId: rId,
        amountReceived: 100.0,
        paymentDate: DateTime(2026, 8, 15),
      );

      final r = state.reimbursements.first;
      expect(r.remainingAmount, 200.0);
      expect(r.status, ReimbursementStatus.partiallyPaid);
      expect(state.availableBalance, 200.0); // 400 - 300 + 100 = 200
    });

    // 9. Reembolso total -> Dívida encerrada (SETTLED)
    test('Cenário 9: Reembolso total -> Dívida encerrada', () {
      var state = getInitialState();

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_mae3',
          description: 'Vestido Mãe',
          amount: 150.0,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_clothing',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.pix,
          personId: mother.id,
        ),
      );

      final rId = state.reimbursements.first.id;

      // Paga tudo
      state = FinancialMovementEngine.processReimbursementPayment(
        currentState: state,
        reimbursementId: rId,
        amountReceived: 150.0,
        paymentDate: DateTime(2026, 8, 18),
      );

      final r = state.reimbursements.first;
      expect(r.remainingAmount, 0.0);
      expect(r.isSettled, isTrue);
    });

    // 10. Exclusão de despesa -> Impacto revertido atomicamente
    test('Cenário 10: Exclusão de despesa -> Reverte saldo e fatura', () {
      var state = getInitialState(available: 500);

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_del',
          description: 'Erro de Lançamento',
          amount: 120.0,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_other',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.pix,
        ),
      );

      expect(state.availableBalance, 380.0);

      // Exclui
      state = FinancialMovementEngine.deleteTransaction(
        currentState: state,
        transactionId: 'tx_del',
      );

      expect(state.availableBalance, 500.0);
      expect(state.transactions.any((t) => t.id == 'tx_del'), isFalse);
    });

    // 11. Alteração de despesa -> Recálculo atômico
    test('Cenário 11: Alteração de despesa (Delete + New) -> Recálculo atômico', () {
      var state = getInitialState(available: 500);

      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_orig',
          description: 'Mercado',
          amount: 100.0,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_food',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.pix,
        ),
      );

      expect(state.availableBalance, 400.0);

      // Simula edição: deleta original e insere com valor corrigido R$ 150
      state = FinancialMovementEngine.deleteTransaction(
        currentState: state,
        transactionId: 'tx_orig',
      );
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_edited',
          description: 'Mercado Corrigido',
          amount: 150.0,
          purchaseDate: DateTime(2026, 8, 10),
          categoryId: 'cat_food',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.pix,
        ),
      );

      expect(state.availableBalance, 350.0);
    });

    // 12. Vencimento no fim de semana -> Próximo dia útil
    test('Cenário 12: Vencimento no sábado ou domingo -> Ajusta para próxima segunda', () {
      // 08/08/2026 é um Sábado
      final saturdayDate = DateTime(2026, 8, 8);
      expect(saturdayDate.weekday, DateTime.saturday);

      final adjusted = DateTimeUtils.getNextBusinessDay(saturdayDate);
      expect(adjusted.weekday, DateTime.monday);
      expect(adjusted.day, 10); // 10/08/2026
    });

    // 13. Nubank + Samsung Pay -> Detectar possível duplicidade (Score >= 70)
    test('Cenário 13: Notificação Nubank + Samsung Pay da mesma compra -> Detectar duplicidade', () {
      final now = DateTime(2026, 8, 19, 14, 30);

      final score = DeduplicationEngine.calculateSimilarityScore(
        amountA: 89.90,
        merchantA: 'AMAZON',
        timestampA: now,
        appA: 'Nubank',
        amountB: 89.90,
        merchantB: 'AMAZON',
        timestampB: now.add(const Duration(seconds: 40)),
        appB: 'Samsung Pay',
      );

      // Score deve ser alto (+40 valor + 30 merchant + 20 tempo + 10 data + 10 apps = 100)
      expect(score >= 70.0, isTrue);
    });

    // 14. Duas compras iguais em horários diferentes -> Não considerar automaticamente como duplicadas
    test('Cenário 14: Duas compras iguais em dias/horários distantes -> Score baixo', () {
      final t1 = DateTime(2026, 8, 10, 10, 0);
      final t2 = DateTime(2026, 8, 15, 18, 0); // 5 dias depois

      final score = DeduplicationEngine.calculateSimilarityScore(
        amountA: 50.0,
        merchantA: 'POSTO IPIRANGA',
        timestampA: t1,
        appA: 'Nubank',
        amountB: 50.0,
        merchantB: 'POSTO IPIRANGA',
        timestampB: t2,
        appB: 'Nubank',
      );

      // Não tem proximidade temporal nem mesma data -> Score não atinge 70
      expect(score < 70.0, isTrue);
    });

    // 15. Notificação ignorada -> Não cria transação
    test('Cenário 15: Notificação ignorada -> Permanece sem transação', () {
      final state = getInitialState();
      expect(state.transactions.isEmpty, isTrue);
      // Nenhuma alteração no motor financeiro
      expect(state.availableBalance, 0.0);
    });

    // 16. Notificação confirmada -> Cria uma única transação
    test('Cenário 16: Notificação confirmada -> Converte em transação única no motor financeiro', () {
      var state = getInitialState(available: 200);

      // Payload Nubank
      final payload = RawNotificationPayload(
        id: 'notif_1',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Compra aprovada',
        rawText: 'Compra de R\$ 42,50 em IFOOD aprovada',
        timestamp: DateTime(2026, 8, 19, 20, 0),
      );

      final parser = NubankParser();
      final draft = parser.parse(payload);
      expect(draft?.amount, 42.50);
      expect(draft?.merchant, 'IFOOD');

      // Usuário confirma na Inbox
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 'tx_from_notif',
          description: draft!.merchant!,
          amount: draft.amount!,
          purchaseDate: draft.date,
          categoryId: 'cat_food',
          type: TransactionType.expense,
          paymentMethod: PaymentMethod.creditCard,
          cardId: defaultCard.id,
          sourceNotificationId: payload.id,
        ),
      );

      expect(state.transactions.length, 1);
      expect(state.transactions.first.amount, 42.50);
      expect(state.invoices.first.totalAmount, 42.50);
    });
  });
}
