enum InboxStatus {
  pending,
  confirmed,
  ignored,
  duplicate,
}

class InboxNotification {
  final String id;
  final String rawId;
  final String packageName;
  final String appName;
  final String rawTitle;
  final String rawText;
  final double? parsedAmount;
  final String? parsedMerchant;
  final String? suggestedPaymentMethod;
  final DateTime eventTimestamp;
  final InboxStatus status;
  final String? duplicateGroupId;
  final double duplicateScore;
  final List<String> detectedSources;

  const InboxNotification({
    required this.id,
    required this.rawId,
    required this.packageName,
    required this.appName,
    required this.rawTitle,
    required this.rawText,
    this.parsedAmount,
    this.parsedMerchant,
    this.suggestedPaymentMethod,
    required this.eventTimestamp,
    this.status = InboxStatus.pending,
    this.duplicateGroupId,
    this.duplicateScore = 0.0,
    this.detectedSources = const [],
  });

  bool get isDuplicate => duplicateScore >= 70.0 || (detectedSources.length > 1);
  bool get isPossibleDuplicate => duplicateScore >= 40.0 && duplicateScore < 70.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawId': rawId,
      'packageName': packageName,
      'appName': appName,
      'rawTitle': rawTitle,
      'rawText': rawText,
      'parsedAmount': parsedAmount,
      'parsedMerchant': parsedMerchant,
      'suggestedPaymentMethod': suggestedPaymentMethod,
      'eventTimestamp': eventTimestamp.toIso8601String(),
      'status': status.name,
      'duplicateGroupId': duplicateGroupId,
      'duplicateScore': duplicateScore,
      'detectedSources': detectedSources.join(','),
    };
  }

  factory InboxNotification.fromMap(Map<String, dynamic> map) {
    final sourcesStr = map['detectedSources'] as String? ?? '';
    final sourcesList = sourcesStr.isNotEmpty ? sourcesStr.split(',') : <String>[];
    return InboxNotification(
      id: map['id'] as String,
      rawId: map['rawId'] as String,
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      rawTitle: map['rawTitle'] as String,
      rawText: map['rawText'] as String,
      parsedAmount: (map['parsedAmount'] as num?)?.toDouble(),
      parsedMerchant: map['parsedMerchant'] as String?,
      suggestedPaymentMethod: map['suggestedPaymentMethod'] as String?,
      eventTimestamp: DateTime.parse(map['eventTimestamp'] as String),
      status: InboxStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InboxStatus.pending,
      ),
      duplicateGroupId: map['duplicateGroupId'] as String?,
      duplicateScore: (map['duplicateScore'] as num?)?.toDouble() ?? 0.0,
      detectedSources: sourcesList,
    );
  }

  InboxNotification copyWith({
    String? id,
    String? rawId,
    String? packageName,
    String? appName,
    String? rawTitle,
    String? rawText,
    double? parsedAmount,
    String? parsedMerchant,
    String? suggestedPaymentMethod,
    DateTime? eventTimestamp,
    InboxStatus? status,
    String? duplicateGroupId,
    double? duplicateScore,
    List<String>? detectedSources,
  }) {
    return InboxNotification(
      id: id ?? this.id,
      rawId: rawId ?? this.rawId,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      rawTitle: rawTitle ?? this.rawTitle,
      rawText: rawText ?? this.rawText,
      parsedAmount: parsedAmount ?? this.parsedAmount,
      parsedMerchant: parsedMerchant ?? this.parsedMerchant,
      suggestedPaymentMethod: suggestedPaymentMethod ?? this.suggestedPaymentMethod,
      eventTimestamp: eventTimestamp ?? this.eventTimestamp,
      status: status ?? this.status,
      duplicateGroupId: duplicateGroupId ?? this.duplicateGroupId,
      duplicateScore: duplicateScore ?? this.duplicateScore,
      detectedSources: detectedSources ?? this.detectedSources,
    );
  }
}
