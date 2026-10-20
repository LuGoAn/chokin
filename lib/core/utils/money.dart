abstract final class Money {
  static int fromReais(num reais) => (reais * 100).round();

  static double toReais(int cents) => cents / 100;

  static List<int> splitInstallments(int totalCents, int count) {
    if (count <= 1) return [totalCents];
    final base = (totalCents / count).round();
    final last = totalCents - base * (count - 1);
    return [for (var i = 1; i < count; i++) base, last];
  }

  static int installmentAt(int totalCents, int count, int number) {
    final parts = splitInstallments(totalCents, count);
    return parts[(number - 1).clamp(0, parts.length - 1)];
  }
}
