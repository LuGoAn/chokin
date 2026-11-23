import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/dashboard_summary.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../widgets/sumi_widgets.dart';
import '../inbox/inbox_screen.dart';
import '../invoices/invoices_screen.dart';
import '../reimbursements/reimbursements_screen.dart';
import '../settings/balance_dialog.dart';
import '../transactions/transaction_history_screen.dart';
import '../../../services/update_service.dart';
import '../../state/financial_state_notifier.dart';

class DashboardScreen extends StatelessWidget {
  final FinancialStateNotifier notifier;

  const DashboardScreen({super.key, required this.notifier});

  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return notifier.selectedYear == now.year && notifier.selectedMonth == now.month;
  }

  bool get _isPastMonth {
    final now = DateTime.now();
    return notifier.selectedYear < now.year ||
        (notifier.selectedYear == now.year && notifier.selectedMonth < now.month);
  }

  String get _selectedMonthName =>
      DateTimeUtils.formatMonthYear(DateTime(notifier.selectedYear, notifier.selectedMonth))
          .split(' ')
          .first
          .toLowerCase();

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final summary = notifier.dashboardSummary;
    final state = notifier.state;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => notifier.initialize(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Sumi.gutter, 12, Sumi.gutter, 32),
            children: [
              MonthStrip(
                month: notifier.selectedMonth,
                year: notifier.selectedYear,
                onChanged: (m, y) => notifier.changePeriod(m, y),
              ),
              if (notifier.availableUpdate?.hasUpdate == true) ...[
                const SizedBox(height: 16),
                _buildUpdateBanner(context, notifier.availableUpdate!, notifier),
              ],
              if (notifier.showBalanceHint) ...[
                const SizedBox(height: 16),
                _buildBalanceHint(context),
              ],
              if (notifier.inbox.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildInboxNotice(context, notifier.inbox.length),
              ],
              const SizedBox(height: 32),
              _buildBalanceHero(summary),
              const SizedBox(height: 24),
              _buildLedgerLines(context, summary),
              const SizedBox(height: 32),
              _buildCardsSection(context, state),
              const SizedBox(height: 32),
              _buildUpcomingSection(context, state),
              const SizedBox(height: 32),
              _buildRecentSection(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceHero(DashboardSummary summary) {
    final String label;
    final String caption;
    if (_isPastMonth) {
      label = 'Saldo no fim de $_selectedMonthName';
      caption = 'reais em conta naquele dia';
    } else if (_isCurrentMonth) {
      label = 'Saldo disponível';
      caption = 'reais, livres para o dia a dia';
    } else {
      label = 'Saldo previsto para $_selectedMonthName';
      caption = 'se as receitas e contas planejadas acontecerem';
    }

    final formatted = CurrencyUtils.formatNoSymbol(summary.availableBalance);
    final comma = formatted.lastIndexOf(',');
    final whole = comma == -1 ? formatted : formatted.substring(0, comma);
    final cents = comma == -1 ? '' : formatted.substring(comma);

    return Semantics(
      label: '$label: ${CurrencyUtils.formatCents(summary.availableCents)}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 18),
            child: Column(
              children: [
                for (final c in '残高'.split(''))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(c, style: Sumi.figures(13, color: AppColors.primary)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Sumi.label),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: whole, style: Sumi.figures(54)),
                        TextSpan(text: cents, style: Sumi.figures(30, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(caption, style: Sumi.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerLines(BuildContext context, DashboardSummary summary) {
    final debtors = notifier.state.people
        .where((p) => !p.isMe && notifier.state.reimbursements.any((r) => r.personId == p.id && !r.isSettled))
        .length;

    String? receivableDetail;
    if (summary.totalPendingReimbursementsCents > summary.pendingReimbursementsCents) {
      receivableDetail = '${CurrencyUtils.formatCents(summary.totalPendingReimbursementsCents)} no total';
    } else if (debtors > 0) {
      receivableDetail = 'de $debtors pessoa${debtors > 1 ? 's' : ''}';
    }

    return Column(
      children: [
        LedgerLine(
          label: 'Gasto pessoal em $_selectedMonthName',
          value: CurrencyUtils.formatCents(summary.periodPaidExpensesCents),
          detail: summary.periodIncomesCents > 0
              ? 'entrou ${CurrencyUtils.formatCents(summary.periodIncomesCents)} no mês'
              : null,
          onTap: () => _open(context, TransactionHistoryScreen(notifier: notifier)),
        ),
        LedgerLine(
          label: 'A receber no mês',
          value: CurrencyUtils.formatCents(summary.pendingReimbursementsCents),
          detail: receivableDetail,
          onTap: () => _open(context, ReimbursementsScreen(notifier: notifier)),
        ),
        LedgerLine(
          label: 'Livre depois das faturas',
          value: CurrencyUtils.formatCents(summary.freeBalanceCents),
          detail: 'já descontadas as faturas abertas',
          showBottomBorder: true,
        ),
      ],
    );
  }

  Widget _buildBalanceHint(BuildContext context) {
    return InkWell(
      onTap: () => showBalanceDialog(context, notifier),
      borderRadius: BorderRadius.circular(Sumi.radius),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: BorderRadius.circular(Sumi.radius),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Já tem dinheiro guardado? Toque aqui e informe seu saldo atual.', style: Sumi.body),
            ),
            IconButton(
              tooltip: 'Dispensar',
              icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
              onPressed: notifier.dismissBalanceHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxNotice(BuildContext context, int pending) {
    return InkWell(
      onTap: () => _open(context, InboxScreen(notifier: notifier)),
      borderRadius: BorderRadius.circular(Sumi.radius),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: BorderRadius.circular(Sumi.radius),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$pending compra${pending > 1 ? 's' : ''} lida${pending > 1 ? 's' : ''} das notificações para revisar',
                style: Sumi.body,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Invoice? _invoiceForCard(FinancialState state, CreditCard card) {
    final cardInvoices = state.invoices.where((i) => i.cardId == card.id).toList();
    final openInvoices = cardInvoices.where((i) => !i.isPaid).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final periodInvoice = cardInvoices
        .where((inv) => inv.month == notifier.selectedMonth && inv.year == notifier.selectedYear)
        .firstOrNull;

    if (!_isCurrentMonth) return periodInvoice;
    if (periodInvoice != null && !periodInvoice.isPaid) return periodInvoice;
    return openInvoices.firstOrNull ?? periodInvoice;
  }

  Widget _buildCardsSection(BuildContext context, FinancialState state) {
    final cards = state.cards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Cartões',
          trailing: TextButton(
            onPressed: () => _open(context, InvoicesScreen(notifier: notifier)),
            child: const Text('Ver faturas'),
          ),
        ),
        const SizedBox(height: 8),
        if (cards.isEmpty)
          LedgerLine(
            label: 'Nenhum cartão cadastrado',
            value: '',
            detail: 'Cadastre seus cartões para acompanhar faturas e parcelas',
            onTap: () => _open(context, InvoicesScreen(notifier: notifier)),
            showBottomBorder: true,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final width = cards.length == 1 ? constraints.maxWidth : (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final card in cards) SizedBox(width: width, child: _buildCardTile(context, state, card)),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildCardTile(BuildContext context, FinancialState state, CreditCard card) {
    final invoice = _invoiceForCard(state, card);
    final now = DateTime.now();
    final isPaid = invoice?.isPaid ?? false;
    final amountCents = invoice?.totalAmountCents ?? 0;

    final String status;
    if (invoice == null) {
      status = _isPastMonth ? 'SEM FATURA' : 'SEM COMPRAS';
    } else if (isPaid) {
      status = '';
    } else {
      status = invoiceStatusLabel(
        isPaid: isPaid,
        amountCents: amountCents,
        closingDate: invoice.closingDate,
        dueDate: invoice.effectiveDueDate,
        month: invoice.month,
        year: invoice.year,
        now: now,
      );
    }

    final String dueText;
    if (invoice == null) {
      dueText = 'vence dia ${card.dueDay}';
    } else if (isPaid && invoice.paidAt != null) {
      dueText = 'paga em ${_dayMonth(invoice.paidAt!)}';
    } else {
      dueText = 'vence ${_dayMonth(invoice.effectiveDueDate)}';
    }

    final limitCents = card.creditLimitCents ?? 0;
    final usedCents = FinancialMovementEngine.calculateCardUsedLimitCents(state: state, cardId: card.id);
    final usage = limitCents > 0 ? (usedCents / limitCents).clamp(0.0, 1.0) : null;
    final canPay = invoice != null && !isPaid && amountCents > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context, InvoicesScreen(notifier: notifier)),
        borderRadius: BorderRadius.circular(Sumi.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderStrong),
            borderRadius: BorderRadius.circular(Sumi.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(card.name, style: Sumi.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (status.isNotEmpty)
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: status == 'VENCIDA' ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyUtils.formatCents(amountCents),
                        style: Sumi.figures(21, color: isPaid ? AppColors.textSecondary : AppColors.textPrimary),
                      ),
                    ),
                  ),
                  if (isPaid) const HankoStamp(size: 44),
                ],
              ),
              const SizedBox(height: 4),
              Text(dueText, style: Sumi.caption),
              if (usage != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: usage, minHeight: 3),
                ),
                const SizedBox(height: 4),
                Text('${(usage * 100).round()}% do limite', style: Sumi.caption),
              ],
              if (canPay) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 36),
                    ),
                    onPressed: () => _showPayInvoiceModal(context, invoice),
                    child: const Text('Pagar fatura'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _dayMonth(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _relativeDay(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(date);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'hoje';
    if (diff == 1) return 'amanhã';
    final weekday = _weekdays[date.weekday - 1];
    return date.month == today.month
        ? '$weekday ${date.day.toString().padLeft(2, '0')}'
        : '$weekday ${_dayMonth(date)}';
  }

  String _transactionDetail(FinancialState state, FinancialTransaction tx) {
    final String method;
    if (tx.type == TransactionType.income) {
      method = 'Receita';
    } else if (tx.isCreditCard) {
      final card = state.cards.where((c) => c.id == tx.cardId).firstOrNull;
      method = card?.name ?? 'Cartão';
    } else {
      method = tx.isPix ? 'Pix' : 'Dinheiro/Débito';
    }
    final parts = [
      method,
      if (tx.isInstallment) '${tx.totalInstallments}x',
      if (tx.isRecurring) tx.recurrenceLabel.toLowerCase(),
      if (tx.isForThirdParty) 'para ${state.people.where((p) => p.id == tx.personId).firstOrNull?.name ?? 'terceiro'}',
    ];
    return parts.join(' · ');
  }

  Widget _buildUpcomingSection(BuildContext context, FinancialState state) {
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 35));
    final rows = <({DateTime date, Widget row})>[];

    for (final tx in state.transactions) {
      if (tx.isCancelled || !tx.purchaseDate.isAfter(now) || tx.purchaseDate.isAfter(horizon)) continue;
      rows.add((
        date: tx.purchaseDate,
        row: _TimelineRow(
          dateLabel: _relativeDay(tx.purchaseDate),
          title: tx.description,
          detail: _transactionDetail(state, tx),
          amount: '${tx.type == TransactionType.income ? '+' : '−'} ${CurrencyUtils.formatNoSymbol(tx.amount)}',
          highlight: tx.type == TransactionType.income,
          onTap: () => _showTransactionActionsModal(context, tx),
        ),
      ));
    }

    final today = DateUtils.dateOnly(now);
    for (final inv in state.invoices) {
      if (inv.isPaid || inv.totalAmountCents <= 0) continue;
      if (inv.effectiveDueDate.isBefore(today) || inv.effectiveDueDate.isAfter(horizon)) continue;
      final card = state.cards.where((c) => c.id == inv.cardId).firstOrNull;
      rows.add((
        date: inv.effectiveDueDate,
        row: _TimelineRow(
          dateLabel: _relativeDay(inv.effectiveDueDate),
          title: 'Fatura ${card?.name ?? 'do cartão'}',
          detail: 'vencimento',
          amount: '− ${CurrencyUtils.formatNoSymbol(inv.totalAmount)}',
          onTap: () => _showPayInvoiceModal(context, inv),
        ),
      ));
    }

    rows.sort((a, b) => a.date.compareTo(b.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Próximos dias'),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nada previsto para as próximas semanas.', style: Sumi.caption),
          )
        else
          ...rows.take(6).map((r) => r.row),
      ],
    );
  }

  Widget _buildRecentSection(BuildContext context, FinancialState state) {
    final endOfMonth = DateTime(notifier.selectedYear, notifier.selectedMonth + 1, 0, 23, 59, 59);
    final now = DateTime.now();
    final limit = endOfMonth.isBefore(now) ? endOfMonth : now;
    final recent = state.transactions.where((t) => !t.purchaseDate.isAfter(limit)).toList()
      ..sort((a, b) {
        final dateCmp = b.purchaseDate.compareTo(a.purchaseDate);
        return dateCmp != 0 ? dateCmp : b.effectiveCreatedAt.compareTo(a.effectiveCreatedAt);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Lançamentos recentes',
          trailing: TextButton(
            onPressed: () => _open(context, TransactionHistoryScreen(notifier: notifier)),
            child: const Text('Extrato'),
          ),
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhum lançamento ainda. Toque em + para começar.', style: Sumi.caption),
          )
        else
          ...recent.take(5).map((tx) => _TimelineRow(
                dateLabel: _dayMonth(tx.purchaseDate),
                title: tx.description,
                detail: _transactionDetail(state, tx),
                amount: '${tx.type == TransactionType.income ? '+' : '−'} ${CurrencyUtils.formatNoSymbol(tx.amount)}',
                highlight: tx.type == TransactionType.income,
                muted: tx.isForThirdParty,
                onTap: () => _showTransactionActionsModal(context, tx),
              )),
      ],
    );
  }

  void _showPayInvoiceModal(BuildContext context, invoice) {
    var selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pagar Fatura',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Valor: ${CurrencyUtils.format(invoice.totalAmount)}',
                    style: const TextStyle(fontSize: 16, color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Data real do pagamento:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                          Text(DateTimeUtils.formatDate(selectedDate),
                              style: const TextStyle(color: AppColors.textPrimary)),
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
                        notifier.payInvoice(invoice.id, selectedDate);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fatura paga com sucesso!')),
                        );
                      },
                      child: const Text('Confirmar Pagamento'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTransactionActionsModal(BuildContext context, FinancialTransaction tx) {
    final isRecurring = tx.isRecurring || tx.recurringGroupId != null;
    final isIncome = tx.type == TransactionType.income;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tx.description,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${isIncome ? '+' : '-'}${CurrencyUtils.format(tx.amount)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? AppColors.income : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${DateTimeUtils.formatDate(tx.purchaseDate)} • ${tx.paymentMethodLabel}${isRecurring ? ' • Recorrente (${tx.recurrenceLabel})' : ''}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x223B82F6),
                  child: Icon(Icons.receipt_long, color: AppColors.primaryLight),
                ),
                title: const Text('Ver Extrato Completo',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: const Text('Abre o extrato detalhado para ver ou filtrar lançamentos.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TransactionHistoryScreen(notifier: notifier)),
                  );
                },
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isRecurring ? const Color(0x22F59E0B) : const Color(0x22EF4444),
                  child: Icon(isRecurring ? Icons.event_busy : Icons.delete_outline,
                      color: isRecurring ? const Color(0xFFF59E0B) : AppColors.expense),
                ),
                title: Text(
                  isRecurring ? 'Gerenciar / Encerrar Recorrência' : 'Excluir Lançamento',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense),
                ),
                subtitle: Text(
                  isRecurring
                      ? 'Opções para cancelar daqui para frente, excluir este mês ou excluir tudo.'
                      : 'Exclui esta transação e recalcula o saldo.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleDeleteTransaction(context, tx);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _handleDeleteTransaction(BuildContext context, FinancialTransaction tx) async {
    final isRecurring = tx.isRecurring || tx.recurringGroupId != null;

    if (isRecurring) {
      final monthName = DateTimeUtils.formatMonthYear(DateTime(notifier.selectedYear, notifier.selectedMonth));
      final choice = await showModalBottomSheet<RecurringDeleteOption>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (dCtx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lançamento Recorrente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Esta transação faz parte de um lançamento recorrente ("${tx.description}"). Como deseja excluí-la?',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22F59E0B),
                  child: Icon(Icons.event_busy, color: Color(0xFFF59E0B)),
                ),
                title: const Text('Excluir apenas deste mês',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Remove o lançamento em $monthName. Nos meses seguintes ele continuará normalmente.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () => Navigator.of(dCtx).pop(RecurringDeleteOption.onlyThisMonth),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22EF4444),
                  child: Icon(Icons.cancel_outlined, color: AppColors.expense),
                ),
                title: const Text('Cancelar daqui para frente',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                    'Encerra a recorrência a partir de $monthName. O histórico dos meses passados continua 100% preservado.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () => Navigator.of(dCtx).pop(RecurringDeleteOption.fromNowOn),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22DC2626),
                  child: Icon(Icons.delete_forever, color: Colors.red),
                ),
                title: const Text('Excluir todas as ocorrências',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Apaga todas as transações passadas e futuras desta série recorrente.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () => Navigator.of(dCtx).pop(RecurringDeleteOption.allOccurrences),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );

      if (choice != null) {
        await notifier.deleteRecurringTransaction(
          transactionId: tx.id,
          option: choice,
          currentMonth: notifier.selectedMonth,
          currentYear: notifier.selectedYear,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lançamento recorrente atualizado com sucesso.')),
          );
        }
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir Lançamento?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Deseja excluir "${tx.description}" (${CurrencyUtils.format(tx.amount)})?\nO saldo e os impactos financeiros serão recalculados.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await notifier.deleteTransaction(tx.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lançamento excluído e saldo recalculado.')),
        );
      }
    }
  }

  Widget _buildUpdateBanner(BuildContext context, AppUpdateInfo update, FinancialStateNotifier notifier) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(Sumi.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_outlined, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _showUpdateDialog(context, update, notifier),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nova versão v${update.latestVersion}', style: Sumi.bodyStrong),
                    const Text('Toque para ver as novidades', style: Sumi.caption),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: () {
              if (update.apkDownloadUrl != null) {
                notifier.openUrl(update.apkDownloadUrl!);
              }
            },
            child: const Text('Baixar'),
          ),
          IconButton(
            tooltip: 'Dispensar',
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: () => notifier.dismissUpdateNotification(),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, AppUpdateInfo update, FinancialStateNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Chokin v${update.latestVersion}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uma nova versão do aplicativo está pronta para download.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (update.releaseNotes != null && update.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Novidades:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    update.releaseNotes!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Lembrar Mais Tarde'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Baixar chokin.apk'),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (update.apkDownloadUrl != null) {
                notifier.openUrl(update.apkDownloadUrl!);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String dateLabel;
  final String title;
  final String detail;
  final String amount;
  final bool highlight;
  final bool muted;
  final VoidCallback? onTap;

  const _TimelineRow({
    required this.dateLabel,
    required this.title,
    required this.detail,
    required this.amount,
    this.highlight = false,
    this.muted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(dateLabel, style: Sumi.caption, textAlign: TextAlign.right),
            ),
            const SizedBox(width: 12),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highlight ? AppColors.primary : Colors.transparent,
                border: Border.all(color: highlight ? AppColors.primary : AppColors.textPrimary, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Sumi.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(detail, style: Sumi.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: Sumi.figures(
                16,
                weight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: muted ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
