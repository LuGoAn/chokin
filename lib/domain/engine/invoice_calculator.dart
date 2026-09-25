import 'package:uuid/uuid.dart';
import '../../core/utils/date_time_utils.dart';
import '../entities/credit_card.dart';
import '../entities/invoice.dart';
import '../entities/installment.dart';
import '../entities/transaction.dart';

class InvoiceCalculator {
  static const _uuid = Uuid();

  /// Determina para qual fatura (mês/ano) uma compra cai com base no dia de fechamento
  static ({int month, int year}) getInvoicePeriodForPurchase({
    required DateTime purchaseDate,
    required int closingDay,
  }) {
    // Se a compra foi feita no dia de fechamento ou após, vai para a fatura do mês seguinte
    if (purchaseDate.day >= closingDay) {
      final nextMonthDate = DateTime(purchaseDate.year, purchaseDate.month + 1, 1);
      return (month: nextMonthDate.month, year: nextMonthDate.year);
    } else {
      return (month: purchaseDate.month, year: purchaseDate.year);
    }
  }

  /// Gera ou recupera uma fatura para um cartão e período
  static Invoice createInvoiceForPeriod({
    required CreditCard card,
    required int month,
    required int year,
  }) {
    final closingDate = DateTimeUtils.calculateClosingDate(year, month, card.closingDay);
    final dueDate = DateTimeUtils.calculateDueDate(year, month, card.dueDay);

    return Invoice(
      id: 'inv_${card.id}_${year}_$month',
      cardId: card.id,
      month: month,
      year: year,
      closingDate: closingDate,
      dueDate: dueDate,
      effectiveDueDate: dueDate,
      totalAmount: 0.0,
      status: InvoiceStatus.open,
    );
  }

  /// Desmembra uma compra parcelada e cria as parcelas vinculadas
  static List<Installment> generateInstallments({
    required FinancialTransaction transaction,
    required CreditCard card,
    required List<Invoice> existingInvoices,
    required void Function(Invoice newInvoice) onNewInvoiceNeeded,
  }) {
    if (!transaction.isCreditCard) return [];

    final initialPeriod = getInvoicePeriodForPurchase(
      purchaseDate: transaction.purchaseDate,
      closingDay: card.closingDay,
    );

    final totalInstallments = transaction.totalInstallments;
    final installmentAmount = double.parse((transaction.amount / totalInstallments).toStringAsFixed(2));
    
    // Tratamento de arredondamento de centavos na última parcela
    final sumBase = installmentAmount * (totalInstallments - 1);
    final lastInstallmentAmount = double.parse((transaction.amount - sumBase).toStringAsFixed(2));

    final installments = <Installment>[];

    var currentYear = initialPeriod.year;
    var currentMonth = initialPeriod.month;

    for (var i = 1; i <= totalInstallments; i++) {
      final invoiceId = 'inv_${card.id}_${currentYear}_$currentMonth';
      
      // Checa se a fatura já existe na lista
      final invoiceExists = existingInvoices.any((inv) => inv.id == invoiceId);
      if (!invoiceExists) {
        final newInv = createInvoiceForPeriod(
          card: card,
          month: currentMonth,
          year: currentYear,
        );
        onNewInvoiceNeeded(newInv);
      }

      final amount = (i == totalInstallments) ? lastInstallmentAmount : installmentAmount;

      installments.add(
        Installment(
          id: _uuid.v4(),
          transactionId: transaction.id,
          invoiceId: invoiceId,
          installmentNumber: i,
          totalInstallments: totalInstallments,
          amount: amount,
          personId: transaction.personId == 'ME' ? null : transaction.personId,
        ),
      );

      // Avança para o próximo mês para a próxima parcela
      currentMonth++;
      if (currentMonth > 12) {
        currentMonth = 1;
        currentYear++;
      }
    }

    return installments;
  }
}
