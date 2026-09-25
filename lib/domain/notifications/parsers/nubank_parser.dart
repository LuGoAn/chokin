import '../notification_payload.dart';
import 'notification_parser.dart';

class NubankParser implements NotificationParser {
  @override
  bool canHandle(RawNotificationPayload payload) {
    final pkg = payload.packageName.toLowerCase();
    final app = payload.appName.toLowerCase();
    return pkg.contains('com.nu.production') || pkg.contains('nubank') || app.contains('nubank');
  }

  @override
  ParsedTransactionDraft? parse(RawNotificationPayload payload) {
    final text = '${payload.rawTitle} ${payload.rawText}'.trim();

    // Filtra avisos, promoções ou notificações sem valor
    if (NotificationParser.isPromotionalOrSpam(text)) {
      return null;
    }

    final amount = NotificationParser.extractAmount(text);
    if (amount == null || amount <= 0) {
      return null;
    }

    String paymentMethod = 'creditCard';
    final isPix = text.toLowerCase().contains('pix');
    if (isPix) {
      paymentMethod = 'pix';
    }

    final merchant = _extractMerchant(payload.rawTitle, payload.rawText, text, isPix);

    return ParsedTransactionDraft(
      amount: amount,
      merchant: merchant,
      paymentMethod: paymentMethod,
      date: payload.timestamp,
      sourceApp: 'Nubank',
    );
  }

  static String? _extractMerchant(String title, String rawText, String fullText, bool isPix) {
    if (isPix) {
      final pixRegex = RegExp(
        r'(?:enviado para|enviada para|pago a|transferência para|transferencia para|para|recebido de|de)\s+([A-Za-z0-9\u00C0-\u00FF\s\.\-_]+?)(?:\s+no valor|\s+de R\$|\.|$)',
        caseSensitive: false,
      );
      final pixMatch = pixRegex.firstMatch(fullText);
      if (pixMatch != null) {
        final m = pixMatch.group(1)?.trim();
        if (m != null && m.isNotEmpty && !m.toLowerCase().startsWith('r\$')) {
          return _cleanMerchantName(m);
        }
      }
      return null;
    }

    // 1. Formato específico do Nubank no corpo da notificação:
    // "Compra de R$ 9,80 APROVADA em CANTINA DONA AMELIA para o cartão com final 9844."
    final nuApprovedRegex = RegExp(
      r'APROVADA\s+em\s+([A-Za-z0-9\u00C0-\u00FF\s\.\-_]+?)(?:\s+para\s+o\s+cart[aã]o|\s+no\s+cart[aã]o|\s+com\s+final|\.|$)',
      caseSensitive: false,
    );
    final nuMatch = nuApprovedRegex.firstMatch(rawText) ?? nuApprovedRegex.firstMatch(fullText);
    if (nuMatch != null) {
      final m = nuMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty && !_isGenericPhrase(m)) return _cleanMerchantName(m);
    }

    // 2. Verifica formato "Estabelecimento: ..." no title ou rawText
    final colonRegex = RegExp(r'^([A-Za-z0-9\u00C0-\u00FF\s\.\-_]{3,40}):', caseSensitive: false);
    final colonMatchTitle = colonRegex.firstMatch(title.trim());
    if (colonMatchTitle != null) {
      final m = colonMatchTitle.group(1)?.trim();
      if (m != null && !_isGenericPhrase(m)) return _cleanMerchantName(m);
    }
    final colonMatchText = colonRegex.firstMatch(rawText.trim());
    if (colonMatchText != null) {
      final m = colonMatchText.group(1)?.trim();
      if (m != null && !_isGenericPhrase(m)) return _cleanMerchantName(m);
    }

    // 3. Extrai de títulos com prefixo: "Compra no crédito aprovada PlayStation Store", "Compra aprovada em X"
    final prefixRegex = RegExp(
      r'^(?:Compra\s+no\s+cr[eé]dito\s+aprovada|Compra\s+no\s+d[eé]bito\s+aprovada|Compra\s+aprovada|Compra\s+no\s+cart[aã]o\s+aprovada)\s*(?:em|no|na|:)?\s+([A-Za-z0-9\u00C0-\u00FF\s\.\-_]+?)(?:\s+no\s+valor|\s+de\s+R\$|\s+no\s+cart[aã]o|\.|$)',
      caseSensitive: false,
    );
    final prefixMatchTitle = prefixRegex.firstMatch(title.trim());
    if (prefixMatchTitle != null) {
      final m = prefixMatchTitle.group(1)?.trim();
      if (m != null && m.isNotEmpty && !_isGenericPhrase(m)) return _cleanMerchantName(m);
    }

    // 4. Padrão "em / no / na <Estabelecimento>" no texto geral (apenas se não for crédito/débito)
    final cardRegex = RegExp(
      r'(?:em|no|na)\s+([A-Za-z0-9\u00C0-\u00FF\s\.\-_]+?)(?:\s+aprovada|\s+no\s+cart[aã]o|\s+no\s+seu|\s+com\s+sucesso|\s+para\s+o\s+cart[aã]o|\s+de\s+R\$|\.|$)',
      caseSensitive: false,
    );
    final cardMatch = cardRegex.firstMatch(fullText);
    if (cardMatch != null) {
      final m = cardMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty && !_isGenericPhrase(m)) return _cleanMerchantName(m);
    }

    // 5. Se o título não for frase genérica nem o nome do banco, usa o título limpo
    if (!_isGenericPhrase(title)) {
      return _cleanMerchantName(title);
    }

    return null;
  }

  static bool _isGenericPhrase(String text) {
    final lower = text.toLowerCase().trim();
    return lower == 'compra no crédito aprovada' ||
        lower == 'compra no credito aprovada' ||
        lower == 'compra no débito aprovada' ||
        lower == 'compra no debito aprovada' ||
        lower == 'compra aprovada' ||
        lower == 'compra no cartão' ||
        lower == 'compra no cartao' ||
        lower == 'crédito' ||
        lower == 'credito' ||
        lower == 'débito' ||
        lower == 'debito' ||
        lower == 'cartão' ||
        lower == 'cartao' ||
        lower == 'nubank' ||
        lower == 'nu' ||
        lower.isEmpty;
  }

  static String _cleanMerchantName(String merchant) {
    var cleaned = merchant
        .replaceAll(RegExp(r'\s+para\s+o\s+cart[aã]o.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+com\s+final\s+\d+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+no\s+cart[aã]o.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+no\s+seu\s+cart[aã]o.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+de\s+R\$.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+aprovada.*$', caseSensitive: false), '')
        .trim();
    return cleaned;
  }
}
