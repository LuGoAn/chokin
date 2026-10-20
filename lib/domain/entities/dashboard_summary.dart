import 'dart:math' as math;

import '../../core/utils/money.dart';

class DashboardSummary {
  final int availableCents;
  final int reserveCents;
  final int committedCents;
  final int pendingReimbursementsCents;
  final int totalPendingReimbursementsCents;
  final int periodIncomesCents;
  final int periodPaidExpensesCents;
  final int periodCreditPurchasesCents;
  final int periodPixExpensesCents;
  final int pendingInboxCount;

  const DashboardSummary({
    required this.availableCents,
    required this.reserveCents,
    required this.committedCents,
    required this.pendingReimbursementsCents,
    this.totalPendingReimbursementsCents = 0,
    required this.periodIncomesCents,
    required this.periodPaidExpensesCents,
    required this.periodCreditPurchasesCents,
    required this.periodPixExpensesCents,
    this.pendingInboxCount = 0,
  });

  int get freeBalanceCents {
    final personalCommitted = math.max<int>(0, committedCents - pendingReimbursementsCents);
    return (availableCents + reserveCents) - personalCommitted;
  }

  int get totalNetWorthCents => availableCents + reserveCents;

  int get periodNetResultCents => periodIncomesCents - periodPaidExpensesCents;

  double get availableBalance => Money.toReais(availableCents);
  double get reserveBalance => Money.toReais(reserveCents);
  double get committedBalance => Money.toReais(committedCents);
  double get pendingReimbursements => Money.toReais(pendingReimbursementsCents);
  double get totalPendingReimbursements => Money.toReais(totalPendingReimbursementsCents);
  double get periodIncomes => Money.toReais(periodIncomesCents);
  double get periodPaidExpenses => Money.toReais(periodPaidExpensesCents);
  double get periodCreditPurchases => Money.toReais(periodCreditPurchasesCents);
  double get periodPixExpenses => Money.toReais(periodPixExpensesCents);
  double get freeBalance => Money.toReais(freeBalanceCents);
  double get totalNetWorth => Money.toReais(totalNetWorthCents);
  double get periodNetResult => Money.toReais(periodNetResultCents);

  factory DashboardSummary.initial() {
    return const DashboardSummary(
      availableCents: 0,
      reserveCents: 0,
      committedCents: 0,
      pendingReimbursementsCents: 0,
      totalPendingReimbursementsCents: 0,
      periodIncomesCents: 0,
      periodPaidExpensesCents: 0,
      periodCreditPurchasesCents: 0,
      periodPixExpensesCents: 0,
      pendingInboxCount: 0,
    );
  }
}
