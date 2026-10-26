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
    'guardar dinheiro', 'resgate seu', 'aproveite', 'parabéns', 'parabens', 'sorteio',
    'venda de qualquer lugar', 'maquininha', 'receba em', 'de graça', 'de graca', 'grátis', 'gratis',
    'taxa', 'taxas', 'a partir de', 'por apenas', 'apenas r\$', 'só r\$', 'pré-aprovado', 'pré-aprovada',
    'pre-aprovado', 'pre-aprovada', 'próxima compra', 'proxima compra', 'simule', 'simular', 'contrate',
    'contratar', 'libere', 'conheça', 'conheca', 'experimente', 'saiba mais', 'baixe', 'ative', 'ativar',
    'abra sua conta', 'peça', 'peca', 'tap', 'campanha', 'vantagens', 'benefício', 'beneficio', 'anuidade'
  ];

  static const List<String> transactionKeywords = [
    'compra', 'pagou', 'pagamento', 'pix enviado', 'pix recebido', 'pix de',
    'transferência enviada', 'transferência recebida', 'transferencia enviada', 'transferencia recebida',
    'transferiu', 'enviou um pix', 'enviou', 'recebeu um pix', 'recebeu', 'você pagou', 'voce pagou',
    'você recebeu', 'voce recebeu', 'aprovada', 'aprovado', 'autorizada', 'autorizado', 'confirmada',
    'confirmado', 'transação', 'transacao', 'saque', 'boleto pago', 'recarga realizada',
    'aproximação', 'aproximacao', 'contactless', 'gasto', 'gastou', 'débito automático',
    'debito automatico'
  ];

  static RegExp _wordsRegex(String keyword) =>
      RegExp(r'(?<![\p{L}])' + RegExp.escape(keyword) + r'(?![\p{L}])', caseSensitive: false, unicode: true);

  static final List<(String, RegExp)> _promoMatchers = [for (final kw in promoKeywords) (kw, _wordsRegex(kw))];
  static final List<RegExp> _transactionMatchers = [for (final kw in transactionKeywords) _wordsRegex(kw)];

  static String? matchedPromoKeyword(String text) {
    for (final (keyword, regex) in _promoMatchers) {
      if (regex.hasMatch(text)) return keyword;
    }
    return null;
  }

  static bool isPromotionalOrSpam(String text) => matchedPromoKeyword(text) != null;

  static bool hasTransactionKeyword(String text) => _transactionMatchers.any((regex) => regex.hasMatch(text));

  static bool isFinancialTransaction(String text) {
    if (isPromotionalOrSpam(text)) return false;
    return hasTransactionKeyword(text) && extractAmount(text) != null;
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
