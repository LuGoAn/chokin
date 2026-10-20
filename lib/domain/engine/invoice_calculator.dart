import 'package:uuid/uuid.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/utils/money.dart';
import '../entities/credit_card.dart';
import '../entities/invoice.dart';
import '../entities/installment.dart';
import '../entities/transaction.dart';

class InvoiceCalculator {
  static const _uuid = Uuid();

  static ({int month, int year}) getInvoicePeriodForPurchase({
    required DateTime purchaseDate,
    required int closingDay,
  }) {
    if (purchaseDate.day >= closingDay) {
      final nextMonthDate = DateTime(purchaseDate.year, purchaseDate.month + 1, 1);
      return (month: nextMonthDate.month, year: nextMonthDate.year);
    } else {
      return (month: purchaseDate.month, year: purchaseDate.year);
    }
  }

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
      totalAmountCents: 0,
      status: InvoiceStatus.open,
    );
  }

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
    final amounts = Money.splitInstallments(transaction.amountCents, totalInstallments);

    final installments = <Installment>[];

    var currentYear = initialPeriod.year;
    var currentMonth = initialPeriod.month;

    for (var i = 1; i <= totalInstallments; i++) {
      final invoiceId = 'inv_${card.id}_${currentYear}_$currentMonth';
      
      final invoiceExists = existingInvoices.any((inv) => inv.id == invoiceId);
      if (!invoiceExists) {
        final newInv = createInvoiceForPeriod(
          card: card,
          month: currentMonth,
          year: currentYear,
        );
        onNewInvoiceNeeded(newInv);
      }

      installments.add(
        Installment(
          id: _uuid.v4(),
          transactionId: transaction.id,
          invoiceId: invoiceId,
          installmentNumber: i,
          totalInstallments: totalInstallments,
          amountCents: amounts[i - 1],
          personId: transaction.personId == 'ME' ? null : transaction.personId,
        ),
      );

      currentMonth++;
      if (currentMonth > 12) {
        currentMonth = 1;
        currentYear++;
      }
    }

    return installments;
  }
}
