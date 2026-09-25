class RawNotificationPayload {
  final String id;
  final String packageName;
  final String appName;
  final String rawTitle;
  final String rawText;
  final DateTime timestamp;

  const RawNotificationPayload({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.rawTitle,
    required this.rawText,
    required this.timestamp,
  });

  factory RawNotificationPayload.fromMap(Map<String, dynamic> map) {
    return RawNotificationPayload(
      id: map['id'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      rawTitle: map['rawTitle'] as String? ?? map['title'] as String? ?? '',
      rawText: map['rawText'] as String? ?? map['text'] as String? ?? '',
      timestamp: map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'rawTitle': rawTitle,
      'rawText': rawText,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class ParsedTransactionDraft {
  final double? amount;
  final String? merchant;
  final String? paymentMethod; // 'PIX', 'CREDIT_CARD', etc.
  final DateTime date;
  final String sourceApp;
  final bool isPurchase; // true if it's a purchase/expense, false if informational

  const ParsedTransactionDraft({
    this.amount,
    this.merchant,
    this.paymentMethod,
    required this.date,
    required this.sourceApp,
    this.isPurchase = true,
  });
}
