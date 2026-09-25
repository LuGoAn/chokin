class DashboardSummary {
  final double availableBalance;        // Saldo disponível em conta corrente / dinheiro
  final double reserveBalance;          // Caixinha / Reserva de emergência
  final double committedBalance;        // Saldo comprometido com faturas de cartão em aberto
  final double pendingReimbursements;   // Valor a receber de terceiros devido até o período
  final double totalPendingReimbursements; // Total geral acumulado a receber de terceiros (todas as cobranças)
  final double periodIncomes;           // Receitas do período selecionado
  final double periodPaidExpenses;      // Total de despesas pessoais do período (Pix, dinheiro e cartão de crédito pessoal)
  final double periodCreditPurchases;   // Compras pessoais no cartão no período
  final double periodPixExpenses;       // Gastos pessoais via Pix no período
  final int pendingInboxCount;          // Quantidade de notificações aguardando revisão

  const DashboardSummary({
    required this.availableBalance,
    required this.reserveBalance,
    required this.committedBalance,
    required this.pendingReimbursements,
    this.totalPendingReimbursements = 0.0,
    required this.periodIncomes,
    required this.periodPaidExpenses,
    required this.periodCreditPurchases,
    required this.periodPixExpenses,
    this.pendingInboxCount = 0,
  });

  /// Saldo livre real considerando compromissos futuros do cartão compensados por valores a receber de terceiros
  double get freeBalance {
    final personalCommitted = (committedBalance - pendingReimbursements).clamp(0.0, double.infinity);
    return (availableBalance + reserveBalance) - personalCommitted;
  }

  /// Patrimônio total real do usuário (Dinheiro em conta + Caixinha / Reserva).
  /// Valores a receber de terceiros NÃO são somados ao patrimônio porque são destinados a pagar as faturas do cartão.
  double get totalNetWorth => availableBalance + reserveBalance;

  /// Sobra ou déficit do período (Receitas - Todos os Gastos pessoais do mês)
  double get periodNetResult => periodIncomes - periodPaidExpenses;

  factory DashboardSummary.initial() {
    return const DashboardSummary(
      availableBalance: 0.0,
      reserveBalance: 0.0,
      committedBalance: 0.0,
      pendingReimbursements: 0.0,
      totalPendingReimbursements: 0.0,
      periodIncomes: 0.0,
      periodPaidExpenses: 0.0,
      periodCreditPurchases: 0.0,
      periodPixExpenses: 0.0,
      pendingInboxCount: 0,
    );
  }
}
