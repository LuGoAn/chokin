import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../entities/inbox_notification.dart';
import 'notification_payload.dart';
import 'parsers/generic_bank_parser.dart';
import 'parsers/google_wallet_parser.dart';
import 'parsers/notification_parser.dart';
import 'parsers/nubank_parser.dart';
import 'parsers/samsung_pay_parser.dart';

class NotificationBridgeService {
  static const _methodChannel = MethodChannel('com.chokin.app/notifications_channel');
  static const _eventChannel = EventChannel('com.chokin.app/notifications_stream');
  static const _uuid = Uuid();

  final List<NotificationParser> _parsers = [
    NubankParser(),
    GoogleWalletParser(),
    SamsungPayParser(),
    GenericBankParser(),
  ];

  StreamSubscription? _eventSubscription;
  final _onNotificationReceived = StreamController<InboxNotification>.broadcast();
  Stream<InboxNotification> get onNotificationReceived => _onNotificationReceived.stream;

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
          _methodChannel.invokeMethod('ackNotification', {
            'ids': [payload.id]
          });
        }
      },
      onError: (error) {
      },
    );
  }

  Future<void> rebindService() async {
    try {
      await _methodChannel.invokeMethod('rebindService');
    } catch (_) {}
  }

  InboxNotification? processRawNotification(RawNotificationPayload payload) {
    final fullText = '${payload.rawTitle} ${payload.rawText}'.trim();

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

  String describeOutcome(RawNotificationPayload payload) {
    final fullText = '${payload.rawTitle} ${payload.rawText}'.trim();
    final lower = fullText.toLowerCase();
    for (final kw in NotificationParser.promoKeywords) {
      if (lower.contains(kw)) return 'descartada: contém "$kw", tratada como promoção';
    }
    final item = processRawNotification(payload);
    if (item == null) return 'descartada: nenhum leitor encontrou um valor em reais';
    final merchant = item.parsedMerchant ?? 'sem estabelecimento';
    return 'vira lançamento: R\$ ${item.parsedAmount?.toStringAsFixed(2)} · $merchant';
  }

  Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      final raw = await _methodChannel.invokeMapMethod<String, dynamic>('getDiagnostics');
      return raw ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<bool> isKeepAliveEnabled() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isKeepAliveEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setKeepAlive(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setKeepAlive', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> clearDiagnostics() async {
    try {
      await _methodChannel.invokeMethod('clearDiagnostics');
    } catch (_) {}
  }

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

      if (rawIds.isNotEmpty) {
        await _methodChannel.invokeMethod('ackNotification', {'ids': rawIds});
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<bool> checkPermission() async {
    try {
      final bool? granted = await _methodChannel.invokeMethod('checkPermission');
      return granted ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isServiceConnected() async {
    try {
      final bool? connected = await _methodChannel.invokeMethod('isServiceConnected');
      return connected ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<InboxNotification?> simulateTestNotification({
    String appName = 'Carteira do Google',
    String packageName = 'com.google.android.apps.walletnfcrel',
    String rawTitle = 'Carteira do Google',
    String rawText = 'R\$ 25,50 em Supermercado Teste',
  }) async {
    final payload = RawNotificationPayload(
      id: _uuid.v4(),
      packageName: packageName,
      appName: appName,
      rawTitle: rawTitle,
      rawText: rawText,
      timestamp: DateTime.now(),
    );
    final inboxItem = processRawNotification(payload);
    if (inboxItem != null) {
      _onNotificationReceived.add(inboxItem);
    }
    return inboxItem;
  }

  Future<void> openPermissionSettings() async {
    try {
      await _methodChannel.invokeMethod('openPermissionSettings');
    } catch (e) {
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _methodChannel.invokeMethod('openAppSettings');
    } catch (e) {
    }
  }

  Future<void> updateMonitoredApps(List<String> packages) async {
    try {
      await _methodChannel.invokeMethod('updateMonitoredApps', {'packages': packages});
    } catch (e) {
    }
  }

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
