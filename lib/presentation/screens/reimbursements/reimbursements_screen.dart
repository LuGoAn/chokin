import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../../domain/entities/installment.dart';
import '../../../domain/entities/person.dart';
import '../../../domain/entities/reimbursement.dart';
import '../../../domain/entities/transaction.dart';
import '../people/people_management_screen.dart';
import '../../state/financial_state_notifier.dart';

class ReimbursementsScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const ReimbursementsScreen({super.key, required this.notifier});

  @override
  State<ReimbursementsScreen> createState() => _ReimbursementsScreenState();
}

class _ReimbursementsScreenState extends State<ReimbursementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _viewAllMonths = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedMonth = widget.notifier.selectedMonth;
    _selectedYear = widget.notifier.selectedYear;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _viewAllMonths = false;
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      _viewAllMonths = false;
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        final state = widget.notifier.state;
        final reimbursements = state.reimbursements;
        final people = state.people;
        final now = DateTime.now();

        final reimbSummary = FinancialMovementEngine.calculateReimbursementsSummary(
          state: state,
          targetMonth: _selectedMonth,
          targetYear: _selectedYear,
        );
        final pendingTotal = reimbSummary.totalPending;
        final totalDueInSelectedMonth = reimbSummary.monthDue;
        final personMonthDueMap = reimbSummary.personMonthDueMap;

        // Agrupa devedores (se visão geral de todos os meses, qualquer pessoa com pendência; senão, devedores ativos no mês)
        final debtors = _viewAllMonths
            ? people.where((p) => !p.isMe && reimbursements.any((r) => r.personId == p.id && !r.isSettled)).toList()
            : reimbSummary.activeDebtorsInMonth;

        final List<_SettledEntry> allSettledEntries = [];
        for (final r in reimbursements) {
          final person = people.firstWhere(
            (p) => p.id == r.personId,
            orElse: () => Person(id: r.personId, name: 'Terceiro', createdAt: r.createdAt),
          );
          final tx = state.transactions.firstWhere(
            (t) => t.id == r.transactionId,
            orElse: () => FinancialTransaction(
              id: r.transactionId,
              description: 'Compra para terceiro',
              amount: r.totalAmount,
              purchaseDate: r.createdAt,
              categoryId: 'cat_other',
              paymentMethod: PaymentMethod.pix,
            ),
          );

          if (r.payments.isNotEmpty) {
            for (var pIdx = 0; pIdx < r.payments.length; pIdx++) {
              final p = r.payments[pIdx];
              final ref = FinancialMovementEngine.getReimbursementPaymentReferencePeriod(
                transaction: tx,
                reimbursement: r,
                payment: p,
                paymentIndex: pIdx,
              );
              allSettledEntries.add(_SettledEntry(
                reimbursement: r,
                payment: p,
                person: person,
                transaction: tx,
                date: p.paymentDate,
                referenceMonth: ref.month,
                referenceYear: ref.year,
                amount: p.amount,
              ));
            }
          } else if (r.isSettled) {
            final ref = FinancialMovementEngine.getReimbursementPaymentReferencePeriod(
              transaction: tx,
              reimbursement: r,
            );
            allSettledEntries.add(_SettledEntry(
              reimbursement: r,
              payment: null,
              person: person,
              transaction: tx,
              date: r.createdAt,
              referenceMonth: ref.month,
              referenceYear: ref.year,
              amount: r.totalAmount,
            ));
          }
        }

        final filteredSettledEntries = _viewAllMonths
            ? allSettledEntries
            : allSettledEntries
                .where((e) => e.referenceMonth == _selectedMonth && e.referenceYear == _selectedYear)
                .toList();

        filteredSettledEntries.sort((a, b) => b.date.compareTo(a.date));

        final totalSettledInView = filteredSettledEntries.fold<double>(0.0, (acc, e) => acc + e.amount);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Cobranças & Reembolsos', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                tooltip: 'Gerenciar Pessoas',
                icon: const Icon(Icons.people_outline, color: AppColors.primary),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PeopleManagementScreen(notifier: widget.notifier)),
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Pendentes (${debtors.length})'),
                Tab(text: 'Quitados (${filteredSettledEntries.length})'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Navegador de Período / Meses (Visível para Pendentes e Quitados)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                      onPressed: _previousMonth,
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _viewAllMonths = !_viewAllMonths);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              _viewAllMonths
                                  ? 'Todos os Meses (Visão Geral)'
                                  : DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth)),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 6),
                            Icon(_viewAllMonths ? Icons.visibility : Icons.calendar_month, color: AppColors.primaryLight, size: 16),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Aba Pendentes (Agrupados por Pessoa)
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero Card Total a Receber
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _viewAllMonths
                                    ? 'Total Geral a Receber'
                                    : 'A Receber em ${DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth))}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.handshake_outlined, color: AppColors.primaryLight, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyUtils.format(_viewAllMonths ? pendingTotal : totalDueInSelectedMonth),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _viewAllMonths
                                ? '${debtors.length} pessoa${debtors.length > 1 ? "s possuem" : " possui"} compras aguardando acerto'
                                : 'Total acumulado (todas as faturas): ${CurrencyUtils.format(pendingTotal)}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Pessoas com Cobranças Ativas',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    if (debtors.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline, color: AppColors.income, size: 40),
                              SizedBox(height: 10),
                              Text('Nenhuma dívida pendente de terceiros!', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Todas as compras feitas para terceiros foram quitadas.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...debtors.map((person) {
                        final allPersonReimbs = reimbursements.where((r) => r.personId == person.id && !r.isSettled).toList();
                        final personPendingTotal = allPersonReimbs.fold<double>(0.0, (acc, r) => acc + r.remainingAmount);

                        final personReimbs = _viewAllMonths
                            ? allPersonReimbs
                            : allPersonReimbs.where((r) {
                                final tx = state.transactions.firstWhere(
                                  (t) => t.id == r.transactionId,
                                  orElse: () => FinancialTransaction(
                                    id: r.transactionId,
                                    description: '',
                                    amount: r.totalAmount,
                                    purchaseDate: r.createdAt,
                                    categoryId: 'cat_other',
                                    paymentMethod: PaymentMethod.pix,
                                  ),
                                );
                                return FinancialMovementEngine.isReimbursementActiveInMonth(
                                  transaction: tx,
                                  targetMonth: _selectedMonth,
                                  targetYear: _selectedYear,
                                );
                              }).toList();

                        final currentMonthDue = personMonthDueMap[person.id] ?? 0.0;
                        final hasMonthDue = currentMonthDue > 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: hasMonthDue
                                  ? AppColors.reimbursement.withValues(alpha: 0.5)
                                  : AppColors.border,
                              width: hasMonthDue ? 1.5 : 1.0,
                            ),
                          ),
                          child: ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            tilePadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.reimbursement.withValues(alpha: 0.15),
                              child: const Icon(Icons.person_outline, color: AppColors.reimbursement, size: 24),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    person.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyUtils.format(!_viewAllMonths ? currentMonthDue : personPendingTotal),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: !_viewAllMonths
                                            ? (hasMonthDue ? AppColors.reimbursement : AppColors.income)
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (!_viewAllMonths)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: (hasMonthDue ? AppColors.reimbursement : AppColors.income).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          hasMonthDue ? 'Neste Mês' : 'Quitado no Mês',
                                          style: TextStyle(
                                            color: hasMonthDue ? AppColors.reimbursement : AppColors.income,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                !_viewAllMonths
                                    ? '${personReimbs.length} compra${personReimbs.length > 1 ? "s" : ""} neste mês • Total acumulado: ${CurrencyUtils.format(personPendingTotal)}'
                                    : '${personReimbs.length} compra${personReimbs.length > 1 ? "s" : ""} pendente${personReimbs.length > 1 ? "s" : ""}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(color: AppColors.border),
                                    const SizedBox(height: 8),

                                    // Botões de Ação Rápida: Quitar Mês e/ou Quitar Tudo
                                    if (!_viewAllMonths && !hasMonthDue)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.income.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: AppColors.income, size: 18),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'Este mês já foi quitado!',
                                                style: TextStyle(color: AppColors.income, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                            if (personPendingTotal > 0.001)
                                              TextButton(
                                                onPressed: () => _confirmSettleAll(context, person, personPendingTotal),
                                                child: const Text('Adiantar Restante', style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                      )
                                    else if (hasMonthDue && currentMonthDue < personPendingTotal)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                                              label: Text(
                                                'Quitar Mês (${CurrencyUtils.format(currentMonthDue)})',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                              onPressed: () => _confirmSettleCurrentMonth(context, person, currentMonthDue, _selectedMonth, _selectedYear),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: AppColors.primaryLight),
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              icon: const Icon(Icons.done_all, size: 16, color: AppColors.primaryLight),
                                              label: Text(
                                                'Quitar Tudo (${CurrencyUtils.format(personPendingTotal)})',
                                                style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                              onPressed: () => _confirmSettleAll(context, person, personPendingTotal),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryDark,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.done_all, size: 18, color: Colors.white),
                                          label: Text(
                                            'Quitar Tudo (${CurrencyUtils.format(personPendingTotal)})',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          onPressed: () => _confirmSettleAll(context, person, personPendingTotal),
                                        ),
                                      ),
                                    const SizedBox(height: 16),

                                    const Text('Detalhamento das Compras:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                    const SizedBox(height: 8),

                                    // Lista de compras individuais da pessoa
                                    ...personReimbs.map((r) {
                                      final tx = state.transactions.firstWhere(
                                        (t) => t.id == r.transactionId,
                                        orElse: () => FinancialTransaction(
                                          id: '',
                                          description: 'Compra para terceiro',
                                          amount: r.totalAmount,
                                          purchaseDate: r.createdAt,
                                          categoryId: 'cat_other',
                                          paymentMethod: PaymentMethod.pix,
                                        ),
                                      );

                                      final isInstallment = tx.isInstallment;
                                      final itemInstallments = state.installments.where((inst) => inst.transactionId == tx.id).toList();

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    tx.description,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                                  ),
                                                ),
                                                Text(
                                                  CurrencyUtils.format(r.remainingAmount),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.reimbursement),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Comprado em ${DateTimeUtils.formatDate(tx.purchaseDate)} • Total: ${CurrencyUtils.format(r.totalAmount)}${isInstallment ? " (${tx.totalInstallments}x de ${CurrencyUtils.format(r.totalAmount / tx.totalInstallments)})" : ""}',
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                            ),

                                            // Se for parcelada, mostra as parcelas
                                            if (isInstallment && itemInstallments.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              ...() {
                                                final unpaidItemInsts = itemInstallments.where((inst) {
                                                  final inv = state.invoices.firstWhere((i) => i.id == inst.invoiceId, orElse: () => state.invoices.first);
                                                  return !inv.isPaid;
                                                }).toList();
                                                final currentActiveInst = unpaidItemInsts.isNotEmpty ? unpaidItemInsts.first : null;

                                                final totalReimbPaid = (r.totalAmount - r.remainingAmount).clamp(0.0, r.totalAmount);

                                                return itemInstallments.map((inst) {
                                                  final prevInsts = itemInstallments.where((other) => other.installmentNumber < inst.installmentNumber);
                                                  final prevSum = prevInsts.fold<double>(0.0, (acc, other) => acc + other.amount);
                                                  final thisEnd = prevSum + inst.amount;
                                                  final isPaidByDebtor = totalReimbPaid >= (thisEnd - 0.001);

                                                  final totalMonths = (tx.purchaseDate.year * 12) + (tx.purchaseDate.month - 1) + (inst.installmentNumber - 1);
                                                  final instYear = totalMonths ~/ 12;
                                                  final instMonth = (totalMonths % 12) + 1;
                                                  final monthLabel = DateTimeUtils.formatShortMonth(DateTime(instYear, instMonth, 1));
                                                  final isSelectedMonthInst = instMonth == _selectedMonth && instYear == _selectedYear;

                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              isPaidByDebtor
                                                                  ? Icons.check_circle
                                                                  : (isSelectedMonthInst ? Icons.calendar_today : Icons.schedule),
                                                              size: 13,
                                                              color: isPaidByDebtor
                                                                  ? AppColors.income
                                                                  : (isSelectedMonthInst ? AppColors.reimbursement : AppColors.textMuted),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              'Parcela ${inst.installmentNumber}/${inst.totalInstallments} • $monthLabel${isPaidByDebtor ? " (Paga)" : (isSelectedMonthInst ? " (Pendente no Mês)" : "")}',
                                                              style: TextStyle(
                                                                color: isPaidByDebtor
                                                                    ? AppColors.income
                                                                    : (isSelectedMonthInst ? AppColors.reimbursement : AppColors.textSecondary),
                                                                fontSize: 11,
                                                                fontWeight: (isPaidByDebtor || isSelectedMonthInst) ? FontWeight.bold : FontWeight.normal,
                                                                decoration: isPaidByDebtor ? TextDecoration.lineThrough : null,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Text(
                                                          CurrencyUtils.format(inst.amount),
                                                          style: TextStyle(
                                                            color: isPaidByDebtor
                                                                ? AppColors.income
                                                                : (isSelectedMonthInst ? AppColors.reimbursement : AppColors.textPrimary),
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            decoration: isPaidByDebtor ? TextDecoration.lineThrough : null,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                });
                                              }(),
                                            ],

                                            // Histórico de pagamentos parciais já feitos nesta compra
                                            if (r.payments.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              const Divider(color: AppColors.border),
                                              ...r.payments.map((p) => Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text('Pago em ${DateTimeUtils.formatDate(p.paymentDate)}', style: const TextStyle(color: AppColors.income, fontSize: 11)),
                                                        Text('+${CurrencyUtils.format(p.amount)}', style: const TextStyle(color: AppColors.income, fontSize: 11, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  )),
                                            ],

                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: AppColors.income,
                                                      side: const BorderSide(color: AppColors.income),
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                    ),
                                                    onPressed: () => _showReceivePaymentModal(context, r, person.name, defaultAmount: isInstallment && itemInstallments.isNotEmpty ? (r.totalAmount / tx.totalInstallments) : r.remainingAmount),
                                                    child: Text(
                                                      isInstallment ? 'Receber Parcela / Valor' : 'Marcar como Pago',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              // 2. Aba Quitados (Histórico Filtrado por Mês com Opção de Desfazer)
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Card Total Recebido / Quitado
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF022C22)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.income.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.income.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _viewAllMonths
                                    ? 'Total Geral Quitado'
                                    : 'Quitados de ${DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth))}',
                                style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.income.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check_circle_outline, color: AppColors.income, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyUtils.format(totalSettledInView),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _viewAllMonths
                                ? '${filteredSettledEntries.length} acerto${filteredSettledEntries.length != 1 ? "s" : ""} registrado${filteredSettledEntries.length != 1 ? "s" : ""} no total'
                                : '${filteredSettledEntries.length} acerto${filteredSettledEntries.length != 1 ? "s" : ""} referente${filteredSettledEntries.length != 1 ? "s" : ""} a este mês',
                            style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      _viewAllMonths
                          ? 'Todos os Acertos Realizados'
                          : 'Cobranças Quitadas de ${DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth))}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    if (filteredSettledEntries.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.event_busy, color: AppColors.textMuted, size: 40),
                              const SizedBox(height: 10),
                              Text(
                                _viewAllMonths
                                    ? 'Nenhum acerto registrado ainda.'
                                    : 'Nenhuma cobrança de ${DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth))} foi quitada ainda.',
                                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Quando você der baixa em parcelas ou compras deste mês, elas aparecerão aqui.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filteredSettledEntries.map((entry) {
                        final isFullSettled = entry.reimbursement.isSettled;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.income.withValues(alpha: 0.15),
                                          child: const Icon(Icons.check, color: AppColors.income, size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.person.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.income.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isFullSettled ? '100% QUITADO' : 'PARCELA QUITADA',
                                      style: const TextStyle(color: AppColors.income, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.transaction.description,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    CurrencyUtils.format(entry.amount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.income),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Quitado de ${DateTimeUtils.formatMonthYear(DateTime(entry.referenceYear, entry.referenceMonth))} • Pago em ${DateTimeUtils.formatDate(entry.date)}${(entry.payment?.notes?.isNotEmpty == true) ? " • ${entry.payment!.notes}" : ""}',
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                    ),
                                  ),
                                  if (entry.transaction.isInstallment)
                                    Text(
                                      'Total compra: ${CurrencyUtils.format(entry.reimbursement.totalAmount)}',
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: AppColors.border),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.expense,
                                    side: BorderSide(color: AppColors.expense.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.undo, size: 15, color: AppColors.expense),
                                  label: const Text('Desfazer Quitação', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => _confirmRevertPayment(context, entry),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
      },
    );
  }

  void _confirmSettleCurrentMonth(BuildContext context, Person person, double monthAmount, int month, int year) async {
    final monthName = DateTimeUtils.formatMonthYear(DateTime(year, month));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Quitar $monthName de ${person.name}?', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Deseja dar baixa nas parcelas de $monthName de ${person.name} (${CurrencyUtils.format(monthAmount)})?\nO valor será creditado no seu saldo disponível.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Confirmar Quitação do Mês'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.notifier.settleMonthReimbursementsForPerson(
        personId: person.id,
        month: month,
        year: year,
        date: DateTime.now(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parcelas de $monthName de ${person.name} foram quitadas com sucesso!')),
        );
      }
    }
  }

  void _confirmSettleAll(BuildContext context, Person person, double total) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Quitar tudo de ${person.name}?', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Deseja dar baixa total em todas as pendências de ${person.name} (${CurrencyUtils.format(total)})?\nO valor será creditado no seu saldo disponível.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Confirmar Quitação Total'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.notifier.settleAllReimbursementsForPerson(
        personId: person.id,
        date: DateTime.now(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Todas as pendências de ${person.name} foram quitadas!')),
        );
      }
    }
  }

  void _showReceivePaymentModal(BuildContext context, Reimbursement r, String personName, {double? defaultAmount}) {
    final amountToSuggest = defaultAmount ?? r.remainingAmount;
    final amountCtrl = TextEditingController(text: amountToSuggest.toStringAsFixed(2).replaceAll('.', ','));
    var selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receber de $personName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text('Saldo devedor total desta compra: ${CurrencyUtils.format(r.remainingAmount)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyTextInputFormatter()],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Valor Recebido (R\$)',
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Data do recebimento:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateTimeUtils.formatDate(selectedDate), style: const TextStyle(color: AppColors.textPrimary)),
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final amt = CurrencyUtils.parse(amountCtrl.text);
                        if (amt == null || amt <= 0) return;
                        widget.notifier.receiveReimbursement(
                          reimbursementId: r.id,
                          amount: amt,
                          date: selectedDate,
                        );
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reembolso recebido e adicionado ao saldo!')),
                        );
                      },
                      child: const Text('Confirmar Recebimento'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRevertPayment(BuildContext context, _SettledEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Desfazer Quitação?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Deseja cancelar a quitação de ${CurrencyUtils.format(entry.amount)} referente a "${entry.transaction.description}" de ${entry.person.name}?\n\n'
          '• O valor voltará para a lista de pendências.\n'
          '• ${CurrencyUtils.format(entry.amount)} será descontado do seu saldo disponível.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Confirmar Cancelamento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.notifier.revertReimbursementPayment(
        reimbursementId: entry.reimbursement.id,
        paymentId: entry.payment?.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quitação de ${CurrencyUtils.format(entry.amount)} cancelada com sucesso!'),
          ),
        );
      }
    }
  }
}

class _SettledEntry {
  final Reimbursement reimbursement;
  final ReimbursementPayment? payment;
  final Person person;
  final FinancialTransaction transaction;
  final DateTime date;
  final int referenceMonth;
  final int referenceYear;
  final double amount;

  const _SettledEntry({
    required this.reimbursement,
    this.payment,
    required this.person,
    required this.transaction,
    required this.date,
    required this.referenceMonth,
    required this.referenceYear,
    required this.amount,
  });
}
