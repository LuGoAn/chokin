import '../notification_payload.dart';

abstract class NotificationParser {
  bool canHandle(RawNotificationPayload payload);
  ParsedTransactionDraft? parse(RawNotificationPayload payload);

  /// Termos que identificam que a notificação é promocional, aviso ou spam não-financeiro
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

  /// Termos que confirmam que se trata de uma movimentação/transação financeira real
  static const List<String> transactionKeywords = [
    'compra', 'pagou', 'pago', 'pagamento', 'pix enviado', 'pix recebido', 'pix de',
    'transferência enviada', 'transferência recebida', 'transferencia enviada', 'transferencia recebida',
    'recebeu um pix', 'enviou um pix', 'você pagou', 'voce pagou', 'você recebeu', 'voce recebeu',
    'débito', 'debito', 'crédito', 'credito', 'aprovada', 'aprovado', 'transação', 'transacao',
    'saque', 'boleto pago', 'recarga realizada', 'compra no cartão', 'compra no cartao'
  ];

  /// Retorna true se o texto contém palavras típicas de promoção, marketing ou avisos
  static bool isPromotionalOrSpam(String text) {
    final lower = text.toLowerCase();
    for (final kw in promoKeywords) {
      if (lower.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// Retorna true apenas se a notificação for comprovadamente uma transação financeira real
  static bool isFinancialTransaction(String text) {
    if (isPromotionalOrSpam(text)) return false;

    final lower = text.toLowerCase();
    final hasTransactionKeyword = transactionKeywords.any((kw) => lower.contains(kw));
    final hasAmount = extractAmount(text) != null;

    return hasTransactionKeyword && hasAmount;
  }

  /// Extrai valor em reais de strings com formatos comuns (ex: R$ 89,90 ou 89,90 ou BRL 50,00)
  static double? extractAmount(String text) {
    final regex = RegExp(r'(?:R\$\s*|BRL\s*)?([0-9]{1,3}(?:\.[0-9]{3})*\,[0-9]{2})');
    final match = regex.firstMatch(text);
    if (match != null) {
      final strVal = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(strVal);
    }
    return null;
  }
}
