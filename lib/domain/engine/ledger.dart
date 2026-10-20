import '../entities/financial_movement.dart';

typedef LedgerBalances = ({int available, int reserve});

abstract final class Ledger {
  static LedgerBalances effectOf(FinancialMovement m) {
    final a = m.amountCents;
    return switch (m.type) {
      MovementType.income => (available: a, reserve: 0),
      MovementType.reimbursementReceived => (available: a, reserve: 0),
      MovementType.refund => (available: a, reserve: 0),
      MovementType.expensePaid => (available: -a, reserve: 0),
      MovementType.invoicePayment => (available: -a, reserve: 0),
      MovementType.transferToReserve => (available: -a, reserve: a),
      MovementType.reserveCompensation => (available: a, reserve: -a),
      MovementType.manualAdjustment => (available: a, reserve: 0),
      MovementType.reserveAdjustment => (available: 0, reserve: a),
      MovementType.cardRefund => (available: 0, reserve: 0),
    };
  }

  static LedgerBalances balances(Iterable<FinancialMovement> movements, {DateTime? upTo}) {
    var available = 0;
    var reserve = 0;
    for (final m in movements) {
      if (upTo != null && m.movementDate.isAfter(upTo)) continue;
      final e = effectOf(m);
      available += e.available;
      reserve += e.reserve;
    }
    return (available: available, reserve: reserve);
  }

  static List<FinancialMovement> openingAdjustments({
    required Iterable<FinancialMovement> movements,
    required int targetAvailableCents,
    required int targetReserveCents,
    required DateTime date,
  }) {
    final current = balances(movements);
    final diffAvailable = targetAvailableCents - current.available;
    final diffReserve = targetReserveCents - current.reserve;
    return [
      if (diffAvailable != 0)
        FinancialMovement(
          id: 'opening_available',
          type: MovementType.manualAdjustment,
          amountCents: diffAvailable,
          movementDate: date,
          description: 'Saldo inicial',
        ),
      if (diffReserve != 0)
        FinancialMovement(
          id: 'opening_reserve',
          type: MovementType.reserveAdjustment,
          amountCents: diffReserve,
          movementDate: date,
          description: 'Saldo inicial da caixinha',
        ),
    ];
  }
}
