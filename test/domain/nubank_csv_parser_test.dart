import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/domain/parsers/nubank_csv_parser.dart';

void main() {
  group('NubankCsvParser Tests', () {
    const sampleCsv = '''date,title,amount
2026-09-24,Vitoriaregialealv,"12,84"
2026-09-24,Cantina Dona Amelia,"9,80"
2026-09-23,Cantina Dona Amelia,"15,80"
2026-09-23,Vitoriaregialealv,"3,99"
2026-09-22,Google One,"23,99"
2026-09-08,Estorno de compra (Dm *Wondershare),"- 174,49"
2026-09-08,Parcelamento de Fatura (10/Agosto) - 1/3,"272,70"
2026-09-05,Pagamento recebido,"- 1.809,95"
2026-09-01,Mp *Aliexpress - Parcela 2/4,"75,71"
2026-09-01,Carajas Construcoes - Parcela 2/10,"99,89"''';

    test('Parses entries with amounts, installments, refunds, and payments correctly', () {
      final entries = NubankCsvParser.parseCsv(sampleCsv);
      expect(entries.length, equals(10));

      final first = entries[0];
      expect(first.title, equals('Vitoriaregialealv'));
      expect(first.amount, equals(12.84));
      expect(first.isPayment, isFalse);
      expect(first.isRefund, isFalse);

      final refund = entries.firstWhere((e) => e.title.contains('Wondershare'));
      expect(refund.isRefund, isTrue);
      expect(refund.amount, equals(-174.49));
      expect(refund.merchant, equals('Dm *Wondershare'));

      final payment = entries.firstWhere((e) => e.title.contains('Pagamento recebido'));
      expect(payment.isPayment, isTrue);
      expect(payment.amount, equals(-1809.95));

      final installment = entries.firstWhere((e) => e.title.contains('Carajas Construcoes'));
      expect(installment.merchant, equals('Carajas Construcoes'));
      expect(installment.installmentNumber, equals(2));
      expect(installment.totalInstallments, equals(10));
      expect(installment.amount, equals(99.89));
    });

    test('Converts CSV entries to InboxNotification items excluding invoice payments by default', () {
      final entries = NubankCsvParser.parseCsv(sampleCsv);
      final notifs = NubankCsvParser.convertToInboxNotifications(entries: entries);

      // 10 entries - 1 invoice payment = 9 inbox notifications
      expect(notifs.length, equals(9));
      expect(notifs.any((n) => n.parsedMerchant == 'Cantina Dona Amelia' && n.parsedAmount == 9.80), isTrue);
      expect(notifs.any((n) => n.parsedMerchant == 'Carajas Construcoes'), isTrue);
    });
  });
}
