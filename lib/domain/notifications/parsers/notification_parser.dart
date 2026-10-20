import '../notification_payload.dart';

abstract class NotificationParser {
  bool canHandle(RawNotificationPayload payload);
  ParsedTransactionDraft? parse(RawNotificationPayload payload);

  static const List<String> promoKeywords = [
    'empréstimo', 'emprestimo', 'limite aumentou', 'aumento de limite', 'novo limite',
    'ajuste seu limite', 'aumentar seu limite', 'cupom', 'desconto', 'cashback', 'ganhe',
    'convide', 'indique', 'informe de rendimentos', 'declaração', 'declaracao', 'irpf',
    'código de segurança', 'codigo de seguranca', 'código de acesso', 'token', 'código:', 'codigo:',
    'fatura fechou', 'fatura disponível', 'fatura disponivel', 'fatura fechada', 'fatura vence',
    'cartão chegou', 'cartao chegou', 'cartão a caminho', 'cartao a caminho', 'senha',
    'promoção', 'promocao', 'ofertas', 'oferta', 'investimento', 'cdb', 'cripto', 'rendimento',
    'atualize seu app', 'novidade', 'pontos', 'milhas', 'seguro de vida', 'portabilidade',
    'guardar dinheiro', 'resgate seu', 'aproveite', 'parabéns', 'parabens', 'sorteio'
  ];

  static const List<String> transactionKeywords = [
    'compra', 'pagou', 'pago', 'pagamento', 'pagar', 'pix enviado', 'pix recebido', 'pix de',
    'transferência enviada', 'transferência recebida', 'transferencia enviada', 'transferencia recebida',
    'transferiu', 'enviou um pix', 'enviado', 'enviada', 'recebeu um pix', 'recebeu', 'recebido',
    'recebida', 'você pagou', 'voce pagou', 'você recebeu', 'voce recebeu',
    'débito', 'debito', 'crédito', 'credito', 'aprovada', 'aprovado', 'autorizada', 'autorizado',
    'confirmada', 'confirmado', 'transação', 'transacao', 'saque', 'boleto pago', 'recarga realizada',
    'compra no cartão', 'compra no cartao', 'carteira do google', 'google pay', 'gpay', 'carteira',
    'wallet', 'aproximação', 'aproximacao', 'contactless', 'gasto', 'gastou'
  ];

  static bool isPromotionalOrSpam(String text) {
    final lower = text.toLowerCase();
    for (final kw in promoKeywords) {
      if (lower.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  static bool isFinancialTransaction(String text) {
    if (isPromotionalOrSpam(text)) return false;

    final lower = text.toLowerCase();
    final hasTransactionKeyword = transactionKeywords.any((kw) => lower.contains(kw));
    final hasAmount = extractAmount(text) != null;
    final hasMerchantPattern = RegExp(r'(?:em|no|na|para|de)\s+[A-Za-z0-9]').hasMatch(lower);
    final isDigitalWallet = lower.contains('wallet') || lower.contains('carteira') || lower.contains('gpay') || lower.contains('google pay');

    return (hasTransactionKeyword || hasMerchantPattern || isDigitalWallet) && hasAmount;
  }

  static double? extractAmount(String text) {
    final explicitRegex = RegExp(
      r'(?:R\$\s*|BRL\s*)([0-9]{1,3}(?:\.[0-9]{3})*\,[0-9]{2}|[0-9]{1,3}(?:\,[0-9]{3})*\.[0-9]{2}|[0-9]+(?:[\.,][0-9]{2})?|\b[0-9]+\b)',
      caseSensitive: false,
    );
    final explicitMatch = explicitRegex.firstMatch(text);
    if (explicitMatch != null) {
      final raw = explicitMatch.group(1)!;
      if (raw.contains(',')) {
        final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
        final val = double.tryParse(normalized);
        if (val != null && val > 0) return val;
      } else {
        final val = double.tryParse(raw);
        if (val != null && val > 0) return val;
      }
    }

    final standardRegex = RegExp(r'\b([0-9]{1,3}(?:\.[0-9]{3})*\,[0-9]{2})\b');
    final match = standardRegex.firstMatch(text);
    if (match != null) {
      final strVal = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(strVal);
    }
    return null;
  }
}
