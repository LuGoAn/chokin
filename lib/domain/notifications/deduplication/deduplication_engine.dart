import 'dart:math';
import '../notification_payload.dart';
import '../../entities/inbox_notification.dart';

class DeduplicationEngine {
  static double calculateSimilarityScore({
    required double? amountA,
    required String? merchantA,
    required DateTime timestampA,
    required String appA,
    required double? amountB,
    required String? merchantB,
    required DateTime timestampB,
    required String appB,
  }) {
    double score = 0.0;

    if (amountA != null && amountB != null) {
      if ((amountA - amountB).abs() < 0.01) {
        score += 30.0;
      }
    }

    if (merchantA != null && merchantB != null && merchantA.isNotEmpty && merchantB.isNotEmpty) {
      final cleanA = merchantA.toLowerCase().trim();
      final cleanB = merchantB.toLowerCase().trim();

      if (cleanA == cleanB) {
        score += 20.0;
      } else if (cleanA.contains(cleanB) || cleanB.contains(cleanA)) {
        score += 15.0;
      } else {
        final sim = _stringSimilarity(cleanA, cleanB);
        if (sim >= 0.7) {
          score += 10.0;
        }
      }
    }

    final diffMinutes = timestampA.difference(timestampB).inMinutes.abs();
    if (diffMinutes <= 5) {
      score += 30.0;
    } else if (diffMinutes <= 30) {
      score += 20.0;
    } else if (diffMinutes <= 120) {
      score += 10.0;
    }

    if (timestampA.year == timestampB.year &&
        timestampA.month == timestampB.month &&
        timestampA.day == timestampB.day) {
      score += 10.0;
    }

    if (appA.toLowerCase() != appB.toLowerCase()) {
      score += 10.0;
    }

    return min(100.0, score);
  }

  static List<InboxNotification> integrateNotification({
    required List<InboxNotification> existingInbox,
    required InboxNotification newNotification,
  }) {
    final result = List<InboxNotification>.from(existingInbox);

    int? matchedIndex;
    double highestScore = 0.0;

    for (var i = 0; i < result.length; i++) {
      final item = result[i];
      if (item.status != InboxStatus.pending) continue;

      final score = calculateSimilarityScore(
        amountA: item.parsedAmount,
        merchantA: item.parsedMerchant,
        timestampA: item.eventTimestamp,
        appA: item.appName,
        amountB: newNotification.parsedAmount,
        merchantB: newNotification.parsedMerchant,
        timestampB: newNotification.eventTimestamp,
        appB: newNotification.appName,
      );

      if (score >= 70.0 && score > highestScore) {
        highestScore = score;
        matchedIndex = i;
      }
    }

    if (matchedIndex != null) {
      final existing = result[matchedIndex];
      final combinedSources = Set<String>.from(existing.detectedSources)
        ..add(existing.appName)
        ..add(newNotification.appName);

      result[matchedIndex] = existing.copyWith(
        duplicateScore: highestScore,
        duplicateGroupId: existing.id,
        detectedSources: combinedSources.toList(),
      );
    } else {
      double possibleScore = 0.0;
      for (final item in result) {
        if (item.status != InboxStatus.pending) continue;
        final score = calculateSimilarityScore(
          amountA: item.parsedAmount,
          merchantA: item.parsedMerchant,
          timestampA: item.eventTimestamp,
          appA: item.appName,
          amountB: newNotification.parsedAmount,
          merchantB: newNotification.parsedMerchant,
          timestampB: newNotification.eventTimestamp,
          appB: newNotification.appName,
        );
        if (score > possibleScore) possibleScore = score;
      }

      final sources = [newNotification.appName];
      result.insert(
        0,
        newNotification.copyWith(
          duplicateScore: possibleScore,
          detectedSources: sources,
        ),
      );
    }

    return result;
  }

  static double _stringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLen = max(s1.length, s2.length);
    return (maxLen - distance) / maxLen;
  }

  static int _levenshteinDistance(String s1, String s2) {
    final v0 = List<int>.filled(s2.length + 1, 0);
    final v1 = List<int>.filled(s2.length + 1, 0);

    for (var i = 0; i <= s2.length; i++) {
      v0[i] = i;
    }

    for (var i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (var j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }
}
