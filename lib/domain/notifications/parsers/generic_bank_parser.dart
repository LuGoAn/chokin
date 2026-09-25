import '../notification_payload.dart';
import 'notification_parser.dart';

class GenericBankParser implements NotificationParser {
  @override
  bool canHandle(RawNotificationPayload payload) {
    final text = '${payload.rawTitle} ${payload.rawText}'.trim();
    // Apenas manipula se for uma notificação financeira real com valor e palavras de transação
    return NotificationParser.isFinancialTransaction(text);
  }

  @override
  ParsedTransactionDraft? parse(RawNotificationPayload payload) {
    final text = '${payload.rawTitle} ${payload.rawText}'.trim();

    if (NotificationParser.isPromotionalOrSpam(text)) {
      return null;
    }

    final amount = NotificationParser.extractAmount(text);
    if (amount == null || amount <= 0) {
      return null;
    }

    String paymentMethod = 'creditCard';
    if (text.toLowerCase().contains('pix')) {
      paymentMethod = 'pix';
    } else if (text.toLowerCase().contains('débito') || text.toLowerCase().contains('debito')) {
      paymentMethod = 'cash';
    }

    String? merchant;
    final merchantRegex = RegExp(r'(?:em|no|na|para|de)\s+([A-Za-z0-9\s\.\-_]+?)(?:\s+aprovado|\s+com sucesso|\.|$)', caseSensitive: false);
    final match = merchantRegex.firstMatch(text);
    if (match != null) {
      merchant = match.group(1)?.trim();
    }

    return ParsedTransactionDraft(
      amount: amount,
      merchant: merchant,
      paymentMethod: paymentMethod,
      date: payload.timestamp,
      sourceApp: payload.appName.isNotEmpty ? payload.appName : 'Banco',
    );
  }
}
