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
  });
}

