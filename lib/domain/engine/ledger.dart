import '../entities/financial_movement.dart';

abstract final class Ledger {
  // os tipos de reserva vêm da época da caixinha: o dinheiro dela já está no saldo,
  // então só o ajuste de reserva conta
  static int effectOf(FinancialMovement m) {
    final a = m.amountCents;
    return switch (m.type) {
      MovementType.income => a,
      MovementType.reimbursementReceived => a,
      MovementType.refund => a,
      MovementType.expensePaid => -a,
      MovementType.invoicePayment => -a,
      MovementType.transferToReserve => 0,
      MovementType.reserveCompensation => 0,
      MovementType.manualAdjustment => a,
      MovementType.reserveAdjustment => a,
      MovementType.cardRefund => 0,
    };
  }

  static int balance(Iterable<FinancialMovement> movements, {DateTime? upTo}) {
    var total = 0;
    for (final m in movements) {
      if (upTo != null && m.movementDate.isAfter(upTo)) continue;
      total += effectOf(m);
    }
    return total;
  }

  static List<FinancialMovement> openingAdjustments({
    required Iterable<FinancialMovement> movements,
    required int targetAvailableCents,
    required DateTime date,
  }) {
    final diff = targetAvailableCents - balance(movements);
    return [
      if (diff != 0)
        FinancialMovement(
          id: 'opening_available',
          type: MovementType.manualAdjustment,
          amountCents: diff,
          movementDate: date,
          description: 'Saldo inicial',
        ),
    ];
  }
}
