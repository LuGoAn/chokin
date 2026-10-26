import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/domain/notifications/notification_payload.dart';
import 'package:chokin/domain/notifications/notification_bridge_service.dart';
import 'package:chokin/domain/notifications/parsers/notification_parser.dart';
import 'package:chokin/domain/notifications/parsers/nubank_parser.dart';
import 'package:chokin/domain/notifications/parsers/generic_bank_parser.dart';

void main() {
  group('Notification Anti-Promo & Financial Transaction Filtering Tests', () {
    final bridge = NotificationBridgeService();
    final nubankParser = NubankParser();
    final genericParser = GenericBankParser();

    test('Real Nubank Credit Card Purchase is successfully parsed', () {
      final payload = RawNotificationPayload(
        id: 'n_1',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Compra aprovada',
        rawText: 'Compra de R\$ 89,90 em AMAZON no seu cartão de crédito',
        timestamp: DateTime.now(),
      );

      final draft = nubankParser.parse(payload);
      expect(draft, isNotNull);
      expect(draft!.amount, equals(89.90));
      expect(draft.merchant, equals('AMAZON'));
      expect(draft.paymentMethod, equals('creditCard'));

      final inboxItem = bridge.processRawNotification(payload);
      expect(inboxItem, isNotNull);
      expect(inboxItem!.parsedAmount, equals(89.90));
      expect(inboxItem.parsedMerchant, equals('AMAZON'));
    });

    test('Nubank: Compra no crédito aprovada PlayStation Store extrai PlayStation Store corretamente', () {
      final payload = RawNotificationPayload(
        id: 'n_ps',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Compra no crédito aprovada PlayStation Store',
        rawText: 'R\$ 250,00 no seu cartão final 1234',
        timestamp: DateTime.now(),
      );

      final draft = nubankParser.parse(payload);
      expect(draft, isNotNull);
      expect(draft!.amount, equals(250.00));
      expect(draft.merchant, equals('PlayStation Store'));
    });

    test('Nubank: Formato com dois-pontos Estabelecimento: compra aprovada', () {
      final payload = RawNotificationPayload(
        id: 'n_colon',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Compra no crédito aprovada',
        rawText: 'Steam Games: compra de R\$ 79,90 aprovada no cartão',
        timestamp: DateTime.now(),
      );

      final draft = nubankParser.parse(payload);
      expect(draft, isNotNull);
      expect(draft!.amount, equals(79.90));
      expect(draft.merchant, equals('Steam Games'));
    });

    test('Real Nubank Pix is successfully parsed', () {
      final payload = RawNotificationPayload(
        id: 'n_2',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Pix enviado',
        rawText: 'Você transferiu um Pix de R\$ 150,00 para João Silva',
        timestamp: DateTime.now(),
      );

      final draft = nubankParser.parse(payload);
      expect(draft, isNotNull);
      expect(draft!.amount, equals(150.00));
      expect(draft.paymentMethod, equals('pix'));

      final inboxItem = bridge.processRawNotification(payload);
      expect(inboxItem, isNotNull);
      expect(inboxItem!.parsedAmount, equals(150.00));
    });

    test('Promotional Nubank notification (loan offer) is REJECTED', () {
      final payload = RawNotificationPayload(
        id: 'n_promo_1',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Empréstimo pré-aprovado',
        rawText: 'Você tem R\$ 10.000,00 de empréstimo disponível para simular agora!',
        timestamp: DateTime.now(),
      );

      expect(NotificationParser.isPromotionalOrSpam('${payload.rawTitle} ${payload.rawText}'), isTrue);

      final draft = nubankParser.parse(payload);
      expect(draft, isNull);

      final inboxItem = bridge.processRawNotification(payload);
      expect(inboxItem, isNull);
    });

    test('Limit increase notification is REJECTED', () {
      final payload = RawNotificationPayload(
        id: 'n_promo_2',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Limite Aumentou',
        rawText: 'Seu novo limite do cartão Nubank é de R\$ 3.500,00',
        timestamp: DateTime.now(),
      );

      final draft = nubankParser.parse(payload);
      expect(draft, isNull);

      final inboxItem = bridge.processRawNotification(payload);
      expect(inboxItem, isNull);
    });

    test('Cashback / Cupom promotion is REJECTED', () {
      final payload = RawNotificationPayload(
        id: 'n_promo_3',
        packageName: 'com.mercadopago.wallet',
        appName: 'Mercado Pago',
        rawTitle: 'Cupom de desconto',
        rawText: 'Ganhe R\$ 20,00 de cashback na sua próxima compra no shopping!',
        timestamp: DateTime.now(),
      );

      final draft = genericParser.parse(payload);
      expect(draft, isNull);

      final inboxItem = bridge.processRawNotification(payload);
      expect(inboxItem, isNull);
    });

    test('Real Generic Bank Purchase (Mercado Pago / Inter) is accepted', () {
      final payload = RawNotificationPayload(
        id: 'n_mp_1',
        packageName: 'com.mercadopago.wallet',
        appName: 'Mercado Pago',
        rawTitle: 'Pagamento aprovado',
        rawText: 'Você pagou R\$ 45,50 em PADARIA CENTRAL com cartão de débito',
        timestamp: DateTime.now(),
      );

      final draft = genericParser.parse(payload);
      expect(draft, isNotNull);
      expect(draft!.amount, equals(45.50));
      expect(draft.paymentMethod, equals('cash'));

      final inboxItem = bridge.processRawNotification(payload);
      expect(inboxItem, isNotNull);
      expect(inboxItem!.parsedAmount, equals(45.50));
    });

    test('Nubank: Compra no crédito aprovada CANTINA DONA AMELIA extrai estabelecimento real e não crédito', () {
      final payload = RawNotificationPayload(
        id: 'n_cantina',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Compra no crédito aprovada',
        rawText: 'Compra de R\$ 9,80 APROVADA em CANTINA DONA AMELIA para o cartão com final 9844.',
        timestamp: DateTime.now(),
      );

      final draft = nubankParser.parse(payload);
      expect(draft, isNotNull);
      expect(draft!.amount, equals(9.80));
      expect(draft.merchant, equals('CANTINA DONA AMELIA'));
      expect(draft.paymentMethod, equals('creditCard'));
    });

    test('Propaganda do Mercado Pago com valor em reais é descartada', () {
      final payload = RawNotificationPayload(
        id: 'n_mp_promo',
        packageName: 'com.mercadopago.wallet',
        appName: 'Mercado Pago',
        rawTitle: 'Venda de qualquer lugar',
        rawText: 'Com Tap seu celular vira maquininha de graça, sem pegadinha ou letras miúdas. '
            'Receba em segundos com taxa a partir de R\$ 0,89',
        timestamp: DateTime.now(),
      );

      expect(bridge.processRawNotification(payload), isNull);
      expect(bridge.describeOutcome(payload), startsWith('descartada'));
    });

    test('Aviso sem palavra de transação não vira lançamento', () {
      final payload = RawNotificationPayload(
        id: 'n_no_kw',
        packageName: 'com.mercadopago.wallet',
        appName: 'Mercado Pago',
        rawTitle: 'Seu saldo no Mercado Pago',
        rawText: 'Hoje você tem R\$ 12,00 disponíveis',
        timestamp: DateTime.now(),
      );

      expect(bridge.processRawNotification(payload), isNull);
    });

    test('Estabelecimento com nome parecido com palavra de promoção não bloqueia a compra', () {
      final payload = RawNotificationPayload(
        id: 'n_tapioca',
        packageName: 'com.nu.production',
        appName: 'Nubank',
        rawTitle: 'Compra no crédito aprovada',
        rawText: 'Compra de R\$ 18,00 APROVADA em TAPIOCA DA VILA para o cartão com final 1234.',
        timestamp: DateTime.now(),
      );

      final item = bridge.processRawNotification(payload);
      expect(item, isNotNull);
      expect(item!.parsedAmount, equals(18.00));
    });

    test('Carteira do Google não é mais lida', () {
      final payload = RawNotificationPayload(
        id: 'n_wallet_off',
        packageName: 'com.google.android.apps.walletnfcrel',
        appName: 'Carteira do Google',
        rawTitle: 'Carteira do Google',
        rawText: 'R\$ 38,50 em Padaria Bella',
        timestamp: DateTime.now(),
      );

      expect(bridge.processRawNotification(payload), isNull);
    });

    test('NotificationParser.extractAmount supports comma, dot, and plain integer amounts', () {
      expect(NotificationParser.extractAmount('R\$ 125,50 em Loja'), equals(125.50));
      expect(NotificationParser.extractAmount('R\$ 38.50 em Padaria'), equals(38.50));
      expect(NotificationParser.extractAmount('BRL 99,00 aprovado'), equals(99.00));
      expect(NotificationParser.extractAmount('R\$ 1.250,00 no Pix'), equals(1250.00));
      expect(NotificationParser.extractAmount('Você pagou R\$ 50 no débito'), equals(50.00));
    });

    test('simulateTestNotification creates a valid pending Inbox item for Nubank', () async {
      final item = await bridge.simulateTestNotification();
      expect(item, isNotNull);
      expect(item!.parsedAmount, equals(25.50));
      expect(item.parsedMerchant, equals('Supermercado Teste'));
      expect(item.appName, equals('Nubank'));
    });
  });
}

