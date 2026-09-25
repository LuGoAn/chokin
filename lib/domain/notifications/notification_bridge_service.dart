import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../entities/inbox_notification.dart';
import 'notification_payload.dart';
import 'parsers/generic_bank_parser.dart';
import 'parsers/notification_parser.dart';
import 'parsers/nubank_parser.dart';
import 'parsers/samsung_pay_parser.dart';

class NotificationBridgeService {
  static const _methodChannel = MethodChannel('com.chokin.app/notifications_channel');
  static const _eventChannel = EventChannel('com.chokin.app/notifications_stream');
  static const _uuid = Uuid();

  final List<NotificationParser> _parsers = [
    NubankParser(),
    SamsungPayParser(),
    GenericBankParser(),
  ];

  StreamSubscription? _eventSubscription;
  final _onNotificationReceived = StreamController<InboxNotification>.broadcast();
  Stream<InboxNotification> get onNotificationReceived => _onNotificationReceived.stream;

  /// Inicia a escuta do EventChannel e processa notificações em tempo real
  void initialize() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is Map) {
          final payload = RawNotificationPayload.fromMap(Map<String, dynamic>.from(data));
          final inboxItem = processRawNotification(payload);
          if (inboxItem != null) {
            _onNotificationReceived.add(inboxItem);
          }
          // Confirma leitura para o Kotlin
          _methodChannel.invokeMethod('ackNotification', {
            'ids': [payload.id]
          });
        }
      },
      onError: (error) {
        // Silencioso
      },
    );
  }

  /// Força o Android a re-vincular o NotificationListenerService caso o SO tenha desconectado
  Future<void> rebindService() async {
    try {
      await _methodChannel.invokeMethod('rebindService');
    } catch (_) {}
  }

  /// Converte um payload bruto em um item da Inbox. Retorna null se for promocional ou não-financeira
  InboxNotification? processRawNotification(RawNotificationPayload payload) {
    final fullText = '${payload.rawTitle} ${payload.rawText}'.trim();

    // Rejeição direta de notificações promocionais ou spam
    if (NotificationParser.isPromotionalOrSpam(fullText)) {
      return null;
    }

    ParsedTransactionDraft? draft;
    for (final parser in _parsers) {
      if (parser.canHandle(payload)) {
        draft = parser.parse(payload);
        if (draft != null) break;
      }
    }

    // Se nenhum parser reconheceu como transação com valor válido, ignora
    if (draft == null || draft.amount == null || draft.amount! <= 0) {
      return null;
    }

    return InboxNotification(
      id: _uuid.v4(),
      rawId: payload.id,
      packageName: payload.packageName,
      appName: payload.appName.isNotEmpty ? payload.appName : draft.sourceApp,
      rawTitle: payload.rawTitle,
      rawText: payload.rawText,
      parsedAmount: draft.amount,
      parsedMerchant: draft.merchant,
      suggestedPaymentMethod: draft.paymentMethod,
      eventTimestamp: payload.timestamp,
      status: InboxStatus.pending,
      detectedSources: [draft.sourceApp],
    );
  }

  /// Recupera notificações pendentes salvas pelo serviço nativo do Kotlin
  Future<List<InboxNotification>> fetchPendingNotificationsFromNative() async {
    try {
      final List<dynamic>? rawList = await _methodChannel.invokeListMethod('getPendingNotifications');
      if (rawList == null || rawList.isEmpty) return [];

      final items = <InboxNotification>[];
      final rawIds = <String>[];

      for (final item in rawList) {
        final payload = RawNotificationPayload.fromMap(Map<String, dynamic>.from(item as Map));
        final processed = processRawNotification(payload);
        if (processed != null) {
          items.add(processed);
        }
        rawIds.add(payload.id);
      }

      // Envia confirmação (ACK) para o Kotlin marcar como sincronizadas
      if (rawIds.isNotEmpty) {
        await _methodChannel.invokeMethod('ackNotification', {'ids': rawIds});
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  /// Verifica se o usuário concedeu a permissão do NotificationListenerService
  Future<bool> checkPermission() async {
    try {
      final bool? granted = await _methodChannel.invokeMethod('checkPermission');
      return granted ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Abre a tela do sistema operacional para concessão de permissão de acesso a notificações
  Future<void> openPermissionSettings() async {
    try {
      await _methodChannel.invokeMethod('openPermissionSettings');
    } catch (e) {
      // Ignora erro
    }
  }

  /// Atualiza a lista de aplicativos monitorados no Kotlin
  Future<void> updateMonitoredApps(List<String> packages) async {
    try {
      await _methodChannel.invokeMethod('updateMonitoredApps', {'packages': packages});
    } catch (e) {
      // Ignora erro
    }
  }

  /// Abre uma URL externa no navegador padrão do Android
  Future<bool> openUrl(String url) async {
    try {
      final bool? res = await _methodChannel.invokeMethod('openUrl', {'url': url});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _onNotificationReceived.close();
  }
}
