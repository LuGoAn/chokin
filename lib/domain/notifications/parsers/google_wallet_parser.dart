import '../notification_payload.dart';
import 'notification_parser.dart';

class GoogleWalletParser implements NotificationParser {
  @override
  bool canHandle(RawNotificationPayload payload) {
    final pkg = payload.packageName.toLowerCase();
    final app = payload.appName.toLowerCase();
    final title = payload.rawTitle.toLowerCase();
    final text = payload.rawText.toLowerCase();

    return pkg.contains('walletnfcrel') ||
        pkg.contains('google.android.gms') ||
        app.contains('wallet') ||
        app.contains('carteira') ||
        app.contains('google pay') ||
        app.contains('gpay') ||
        title.contains('carteira do google') ||
        title.contains('google pay') ||
        title.contains('gpay') ||
        text.contains('carteira do google') ||
        text.contains('google pay') ||
        text.contains('gpay');
  }

  @override
  ParsedTransactionDraft? parse(RawNotificationPayload payload) {
    final fullText = '${payload.rawTitle} ${payload.rawText}'.trim();

    if (NotificationParser.isPromotionalOrSpam(fullText)) {
      return null;
    }

    final amount = NotificationParser.extractAmount(fullText);
    if (amount == null || amount <= 0) {
      return null;
    }

    String? merchant;
    final text = payload.rawText.isNotEmpty ? payload.rawText : fullText;

    // 1. "em Padaria", "no Restaurante", "na Drogaria", "para Lojas Americanas"
    final merchantRegex = RegExp(
      r'(?:em|no|na|para|no estabelecimento|em\s+loja)\s+([A-Za-z0-9\u00C0-\u00FF\s\.\-_&]+?)(?:\s+usando|\s+com o cartão|\s+com cartão|\s+aprovado|\.|$)',
      caseSensitive: false,
    );
    final match = merchantRegex.firstMatch(text);
    if (match != null) {
      final candidate = match.group(1)?.trim();
      if (candidate != null &&
          candidate.isNotEmpty &&
          !candidate.toLowerCase().startsWith('r\$') &&
          !candidate.toLowerCase().contains('cartão') &&
          !candidate.toLowerCase().contains('cartao')) {
        merchant = candidate;
      }
    }

    // 2. Se não encontrou no texto, verifica se o título é o próprio nome do estabelecimento
    if (merchant == null) {
      final t = payload.rawTitle.trim();
      final lowerTitle = t.toLowerCase();
      if (!lowerTitle.contains('carteira') &&
          !lowerTitle.contains('google') &&
          !lowerTitle.contains('wallet') &&
          !lowerTitle.contains('pay') &&
          t.isNotEmpty) {
        merchant = t;
      }
    }

    String paymentMethod = 'creditCard';
    if (fullText.toLowerCase().contains('débito') || fullText.toLowerCase().contains('debito')) {
      paymentMethod = 'cash';
    }

    return ParsedTransactionDraft(
      amount: amount,
      merchant: merchant,
      paymentMethod: paymentMethod,
      date: payload.timestamp,
      sourceApp: 'Google Wallet',
    );
  }
}
