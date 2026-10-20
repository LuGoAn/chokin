import 'package:uuid/uuid.dart';
import '../entities/inbox_notification.dart';

class NubankCsvEntry {
  final DateTime date;
  final String title;
  final double amount;
  final bool isPayment;
  final bool isRefund;
  final String merchant;
  final int? installmentNumber;
  final int? totalInstallments;

  NubankCsvEntry({
    required this.date,
    required this.title,
    required this.amount,
    required this.merchant,
    this.isPayment = false,
    this.isRefund = false,
    this.installmentNumber,
    this.totalInstallments,
  });
}

class NubankCsvParser {
  static const _uuid = Uuid();

  static List<NubankCsvEntry> parseCsv(String csvContent) {
    final lines = csvContent.split(RegExp(r'\r?\n'));
    final entries = <NubankCsvEntry>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final row = _parseCsvLine(line);
      if (row.length < 3) continue;

      final firstCol = row[0].toLowerCase().trim();
      if (firstCol == 'date' || firstCol == 'data') continue;

      final dateStr = row[0].trim();
      final title = row[1].trim();
      final amountStr = row[2].trim();

      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate == null) continue;

      final parsedAmount = _parseAmount(amountStr);
      if (parsedAmount == null) continue;

      final lowerTitle = title.toLowerCase();
      final isPayment = lowerTitle.contains('pagamento recebido') || lowerTitle.contains('pagamento de fatura');
      final isRefund = lowerTitle.contains('estorno') || parsedAmount < 0;

      final installmentRegex = RegExp(r'[-–]?\s*Parcela\s+(\d+)\s*/\s*(\d+)', caseSensitive: false);
      final installmentMatch = installmentRegex.firstMatch(title);

      int? instNum;
      int? totalInst;
      String merchant = title;

      if (installmentMatch != null) {
        instNum = int.tryParse(installmentMatch.group(1) ?? '');
        totalInst = int.tryParse(installmentMatch.group(2) ?? '');
        merchant = title.replaceAll(installmentRegex, '').trim();
      }

      if (isRefund) {
        merchant = merchant
            .replaceAll(RegExp(r'^Estorno\s+de\s+compra\s*\(\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*\)$'), '')
            .trim();
      }

      entries.add(
        NubankCsvEntry(
          date: parsedDate,
          title: title,
          amount: parsedAmount,
          merchant: merchant.isNotEmpty ? merchant : title,
          isPayment: isPayment,
          isRefund: isRefund,
          installmentNumber: instNum,
          totalInstallments: totalInst,
        ),
      );
    }

    return entries;
  }

  static List<InboxNotification> convertToInboxNotifications({
    required List<NubankCsvEntry> entries,
    bool includePayments = false,
  }) {
    final notifications = <InboxNotification>[];

    for (final entry in entries) {
      if (entry.isPayment && !includePayments) {
        continue;
      }

      final amount = entry.amount.abs();
      var description = entry.merchant;
      if (entry.totalInstallments != null && entry.totalInstallments! > 1) {
        description = '$description (${entry.installmentNumber}/${entry.totalInstallments})';
      }

      notifications.add(
        InboxNotification(
          id: _uuid.v4(),
          rawId: 'csv_${entry.date.millisecondsSinceEpoch}_${entry.title}_${entry.amount}',
          packageName: 'com.nu.production',
          appName: 'Nubank (Fatura CSV)',
          rawTitle: description,
          rawText: entry.isRefund
              ? 'Estorno importado da fatura: ${entry.title}'
              : 'Compra importada da fatura Nubank: ${entry.title}',
          parsedAmount: amount,
          parsedMerchant: entry.merchant,
          suggestedPaymentMethod: 'creditCard',
          eventTimestamp: entry.date,
          status: InboxStatus.pending,
          detectedSources: const ['Fatura CSV'],
        ),
      );
    }

    return notifications;
  }

  static double? _parseAmount(String text) {
    var cleaned = text
        .replaceAll('"', '')
        .replaceAll('\'', '')
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .trim();

    if (cleaned.isEmpty) return null;

    final isNegative = cleaned.startsWith('-');
    if (isNegative) {
      cleaned = cleaned.substring(1).trim();
    }

    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');

    final val = double.tryParse(cleaned);
    if (val == null) return null;

    return isNegative ? -val : val;
  }

  static List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"' || char == '\'') {
        inQuotes = !inQuotes;
      } else if ((char == ',' || char == ';') && !inQuotes) {
        values.add(sb.toString());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    values.add(sb.toString());

    return values;
  }
}
