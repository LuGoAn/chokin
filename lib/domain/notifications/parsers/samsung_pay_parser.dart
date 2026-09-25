import '../notification_payload.dart';
import 'notification_parser.dart';

class SamsungPayParser implements NotificationParser {
  @override
  bool canHandle(RawNotificationPayload payload) {
    final pkg = payload.packageName.toLowerCase();
    final app = payload.appName.toLowerCase();
    return pkg.contains('samsung') || pkg.contains('spay') || app.contains('samsung pay') || app.contains('samsung wallet');
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

    String? merchant;
    final merchantRegex = RegExp(r'(?:em|no|na|pago em)\s+([A-Za-z0-9\s\.\-_]+?)(?:\s+aprovado|\.|$)', caseSensitive: false);
    final match = merchantRegex.firstMatch(text);
    if (match != null) {
      merchant = match.group(1)?.trim();
    }

    return ParsedTransactionDraft(
      amount: amount,
      merchant: merchant,
      paymentMethod: 'creditCard',
      date: payload.timestamp,
      sourceApp: 'Samsung Pay',
    );
  }
}
