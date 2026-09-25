import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/dashboard_summary.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/person.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../invoices/invoices_screen.dart';
import '../people/people_management_screen.dart';
import '../reimbursements/reimbursements_screen.dart';
import '../transactions/new_transaction_screen.dart';
import '../transactions/transaction_history_screen.dart';
import '../../../services/update_service.dart';
import '../../state/financial_state_notifier.dart';

class DashboardScreen extends StatelessWidget {
  final FinancialStateNotifier notifier;

  const DashboardScreen({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final summary = notifier.dashboardSummary;
    final state = notifier.state;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Chokin',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          // Seletor de Período Contínuo
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    var m = notifier.selectedMonth - 1;
                    var y = notifier.selectedYear;
                    if (m < 1) {
                      m = 12;
                      y--;
                    }
                    notifier.changePeriod(m, y);
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  DateTimeUtils.formatShortMonth(DateTime(notifier.selectedYear, notifier.selectedMonth)),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    var m = notifier.selectedMonth + 1;
                    var y = notifier.selectedYear;
                    if (m > 12) {
                      m = 1;
                      y++;
                    }
                    notifier.changePeriod(m, y);
                  },
                ),
              ],
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.initialize(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner de Atualização Disponível
              if (notifier.availableUpdate?.hasUpdate == true) ...[
                _buildUpdateBanner(context, notifier.availableUpdate!, notifier),
                const SizedBox(height: 16),
              ],

              // 1. Card Principal de Patrimônio & Saldo Livre
              _buildNetWorthHeroCard(summary),
              const SizedBox(height: 16),

              // 2. Grid de Cards Financeiros (A Receber, Faturas a Pagar)
              _buildFinancialPillarsGrid(summary, context, notifier),
              const SizedBox(height: 20),

              // 3. Resumo Operacional do Mês (Receitas x Despesas Pagas)
              _buildMonthlyFlowCard(context, summary, notifier),
              const SizedBox(height: 20),

              // 4. Seção de Cartões de Crédito & Faturas
              _buildCreditCardsSection(context, state),
              const SizedBox(height: 20),

              // 5. Últimas Transações
              _buildRecentTransactionsSection(context, state),
              const SizedBox(height: 80), // Espaço para FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Transação', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => NewTransactionScreen(notifier: notifier),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetWorthHeroCard(DashboardSummary summary) {
    final now = DateTime.now();
    final isPast = notifier.selectedYear < now.year || (notifier.selectedYear == now.year && notifier.selectedMonth < now.month);
    final isFuture = notifier.selectedYear > now.year || (notifier.selectedYear == now.year && notifier.selectedMonth > now.month);
    final monthName = DateTimeUtils.formatMonthYear(DateTime(notifier.selectedYear, notifier.selectedMonth));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                isPast
                    ? 'Saldo (Fim de $monthName)'
                    : (isFuture ? 'Saldo Projetado ($monthName)' : 'Saldo'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Icon(Icons.shield_outlined, color: AppColors.primaryLight, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyUtils.format(summary.freeBalance),
            style: TextStyle(
              color: summary.freeBalance >= 0 ? AppColors.textPrimary : AppColors.expense,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialPillarsGrid(DashboardSummary summary, BuildContext context, FinancialStateNotifier notifier) {
    // Exibe o valor devido no mês selecionado exatamente como na tela de Cobranças & Reembolsos
    final monthDue = summary.pendingReimbursements;
    final totalPending = summary.totalPendingReimbursements;

    String? aReceberSubtitle;
    if (totalPending > monthDue) {
      aReceberSubtitle = 'Total acumulado: ${CurrencyUtils.format(totalPending)}';
    } else if (monthDue == 0 && totalPending > 0) {
      aReceberSubtitle = 'Total acumulado: ${CurrencyUtils.format(totalPending)}';
    } else {
      final activeDebtorsCount = notifier.state.people
          .where((p) => !p.isMe && notifier.state.reimbursements.any((r) => r.personId == p.id && !r.isSettled))
          .length;
      if (activeDebtorsCount > 0) {
        aReceberSubtitle = '$activeDebtorsCount pessoa${activeDebtorsCount > 1 ? "s possuem" : " possui"} acertos';
      }
    }

    return _buildPillarCard(
      title: 'A Receber no Mês',
      value: CurrencyUtils.format(monthDue),
      subtitle: aReceberSubtitle,
      icon: Icons.handshake_outlined,
      color: AppColors.reimbursement,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReimbursementsScreen(notifier: notifier),
          ),
        );
      },
    );
  }

  Widget _buildPillarCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyFlowCard(BuildContext context, DashboardSummary summary, FinancialStateNotifier notifier) {
    final netResult = summary.periodNetResult;
    final isSurplus = netResult >= 0;
    final now = DateTime.now();
    final isCurrentMonth = notifier.selectedYear == now.year && notifier.selectedMonth == now.month;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gastos & Entradas deste Mês',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFlowStat('Total Recebido', CurrencyUtils.format(summary.periodIncomes), AppColors.income, Icons.arrow_upward),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFlowStat('Total Gasto no Mês', CurrencyUtils.format(summary.periodPaidExpenses), AppColors.expense, Icons.arrow_downward),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (isSurplus ? AppColors.income : AppColors.expense).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSurplus ? 'Sobra deste mês' : 'Gasto a mais neste mês',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSurplus ? AppColors.income : AppColors.expense,
                  ),
                ),
                Text(
                  '${isSurplus ? '+' : ''}${CurrencyUtils.format(netResult)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSurplus ? AppColors.income : AppColors.expense,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFlowStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseCardColor(String colorHex) {
    try {
      return Color(int.parse(colorHex));
    } catch (_) {
      return const Color(0xFF820AD1);
    }
  }

  Widget _buildCreditCardsSection(BuildContext context, FinancialState state) {
    final cards = state.cards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Meus Cartões & Faturas (${cards.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => InvoicesScreen(notifier: notifier)),
                );
              },
              icon: const Icon(Icons.credit_card, size: 14, color: AppColors.primary),
              label: const Text('Ver Todos / + Cartão', style: TextStyle(fontSize: 12, color: AppColors.primary)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (cards.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.add_card, color: AppColors.primaryLight),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nenhum cartão cadastrado', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('Cadastre seus cartões para gerenciar faturas e parcelamentos.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => InvoicesScreen(notifier: notifier)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Adicionar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 195,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              itemBuilder: (ctx, index) {
                final card = cards[index];
                final cardColor = _parseCardColor(card.colorHex);

                // Faturas deste cartão ordenadas por vencimento
                final cardInvoices = state.invoices.where((i) => i.cardId == card.id).toList();
                final openInvoices = cardInvoices.where((i) => !i.isPaid).toList();
                openInvoices.sort((a, b) => a.dueDate.compareTo(b.dueDate));

                // Fatura do período visualizado
                final periodInvoice = cardInvoices.where((inv) =>
                    inv.month == notifier.selectedMonth &&
                    inv.year == notifier.selectedYear).firstOrNull;

                final now = DateTime.now();
                final isPastMonth = notifier.selectedYear < now.year ||
                    (notifier.selectedYear == now.year && notifier.selectedMonth < now.month);
                final isFutureMonth = notifier.selectedYear > now.year ||
                    (notifier.selectedYear == now.year && notifier.selectedMonth > now.month);

                // Determinação precisa da fatura a exibir:
                // - No passado e futuro: exibe estritamente a fatura do período selecionado.
                // - No presente: se a fatura do mês atual já estiver paga e houver nova fatura em aberto, exibe a em aberto.
                final Invoice? invoice;
                if (isPastMonth || isFutureMonth) {
                  invoice = periodInvoice;
                } else {
                  if (periodInvoice != null && !periodInvoice.isPaid) {
                    invoice = periodInvoice;
                  } else if (openInvoices.isNotEmpty) {
                    invoice = openInvoices.first;
                  } else {
                    invoice = periodInvoice;
                  }
                }

                final isInvoicePaid = invoice?.isPaid ?? false;
                final invoiceAmount = invoice?.totalAmount ?? 0.0;

                // Título e indicador do mês da fatura exibida
                final selectedShortMonth = DateTimeUtils.formatShortMonth(DateTime(notifier.selectedYear, notifier.selectedMonth));
                final String invoiceTitle;
                if (invoice != null) {
                  final invShortMonth = DateTimeUtils.formatShortMonth(DateTime(invoice.year, invoice.month));
                  if (isInvoicePaid) {
                    invoiceTitle = 'Fatura Paga ($invShortMonth)';
                  } else if (isPastMonth || invoice.effectiveDueDate.isBefore(now)) {
                    invoiceTitle = 'Fatura Fechada ($invShortMonth)';
                  } else if (isFutureMonth || invoice.year > now.year || (invoice.year == now.year && invoice.month > now.month)) {
                    invoiceTitle = 'Fatura Futura ($invShortMonth)';
                  } else {
                    invoiceTitle = 'Fatura Atual ($invShortMonth)';
                  }
                } else {
                  if (isPastMonth) {
                    invoiceTitle = 'Sem Fatura ($selectedShortMonth)';
                  } else if (isFutureMonth) {
                    invoiceTitle = 'Fatura Futura ($selectedShortMonth)';
                  } else {
                    invoiceTitle = 'Fatura Atual ($selectedShortMonth)';
                  }
                }

                // Calcula o limite utilizado com precisão bancária (excluindo projeções de recorrências futuras)
                final totalUsed = FinancialMovementEngine.calculateCardUsedLimit(
                  state: state,
                  cardId: card.id,
                );

                final hasLimit = card.creditLimit != null && card.creditLimit! > 0;
                final limitProgress = hasLimit ? (totalUsed / card.creditLimit!).clamp(0.0, 1.0) : 0.0;

                return Container(
                  width: 300,
                  margin: EdgeInsets.only(right: index == cards.length - 1 ? 0 : 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cardColor.withValues(alpha: 0.9),
                        HSLColor.fromColor(cardColor).withLightness((HSLColor.fromColor(cardColor).lightness * 0.6).clamp(0.0, 1.0)).toColor(),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Topo: Nome e Bandeira
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.credit_card, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    card.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              card.flag ?? 'Cartão',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      // Meio: Fatura Atual e Limite
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    invoiceTitle,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  if (isInvoicePaid) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('✓ PAGA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              if (hasLimit)
                                Text(
                                  'Uso: ${CurrencyUtils.format(totalUsed)} / ${CurrencyUtils.format(card.creditLimit!)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyUtils.format(invoiceAmount),
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                          if (hasLimit) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: limitProgress,
                                minHeight: 4,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Rodapé: Vencimento e Botão
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            invoice != null
                                ? (isInvoicePaid && invoice.paidAt != null
                                    ? 'Paga em ${DateTimeUtils.formatDate(invoice.paidAt!)}'
                                    : 'Vence ${DateTimeUtils.formatDate(invoice.effectiveDueDate)}')
                                : (isPastMonth ? 'Sem lançamentos' : 'Vence dia ${card.dueDay}'),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          if (invoice != null && !isInvoicePaid && invoiceAmount > 0)
                            ElevatedButton(
                              onPressed: () => _showPayInvoiceModal(context, invoice),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Pagar Agora', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          else
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => InvoicesScreen(notifier: notifier)),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Ver Fatura', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
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

  Widget _buildRecentTransactionsSection(BuildContext context, FinancialState state) {
    final endOfMonth = DateTime(notifier.selectedYear, notifier.selectedMonth + 1, 0, 23, 59, 59);
    final sorted = state.transactions
        .where((t) => !t.purchaseDate.isAfter(endOfMonth))
        .toList()
      ..sort((a, b) {
        final dateCmp = b.purchaseDate.compareTo(a.purchaseDate);
        if (dateCmp != 0) return dateCmp;
        return b.effectiveCreatedAt.compareTo(a.effectiveCreatedAt);
      });
    final recent = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lançamentos Recentes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'Nenhuma movimentação registrada ainda.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...recent.map((tx) {
            final isIncome = tx.type == TransactionType.income;
            final isThirdParty = tx.isForThirdParty;
            final person = isThirdParty
                ? state.people.firstWhere(
                    (p) => p.id == tx.personId,
                    orElse: () => Person(id: '', name: 'Terceiro', createdAt: DateTime.now()),
                  )
                : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isThirdParty
                      ? AppColors.reimbursement.withValues(alpha: 0.35)
                      : AppColors.border,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showTransactionActionsModal(context, tx),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isThirdParty
                              ? AppColors.reimbursement.withOpacity(0.15)
                              : (isIncome ? AppColors.income : AppColors.expense).withOpacity(0.15),
                          child: Icon(
                            isThirdParty
                                ? Icons.handshake_outlined
                                : (isIncome ? Icons.arrow_upward : (tx.isCreditCard ? Icons.credit_card : Icons.pix)),
                            color: isThirdParty
                                ? AppColors.reimbursement
                                : (isIncome ? AppColors.income : (tx.isCreditCard ? AppColors.committed : AppColors.expense)),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tx.description,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isThirdParty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.reimbursement.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.reimbursement.withValues(alpha: 0.4), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person, size: 10, color: AppColors.reimbursement),
                                          const SizedBox(width: 3),
                                          Text(
                                            person?.name ?? 'Terceiro',
                                            style: const TextStyle(color: AppColors.reimbursement, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateTimeUtils.formatDate(tx.purchaseDate)} • ${tx.paymentMethodLabel}${tx.isInstallment ? ' (${tx.totalInstallments}x)' : ''}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${isIncome ? '+' : '-'}${CurrencyUtils.format(tx.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isThirdParty
                                ? AppColors.reimbursement
                                : (isIncome ? AppColors.income : AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
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
                title: const Text('Ver Extrato Completo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: const Text('Abre o extrato detalhado para ver ou filtrar lançamentos.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                  child: Icon(isRecurring ? Icons.event_busy : Icons.delete_outline, color: isRecurring ? const Color(0xFFF59E0B) : AppColors.expense),
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
                title: const Text('Excluir apenas deste mês', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Remove o lançamento em $monthName. Nos meses seguintes ele continuará normalmente.', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () => Navigator.of(dCtx).pop(RecurringDeleteOption.onlyThisMonth),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22EF4444),
                  child: Icon(Icons.cancel_outlined, color: AppColors.expense),
                ),
                title: const Text('Cancelar daqui para frente', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Encerra a recorrência a partir de $monthName. O histórico dos meses passados continua 100% preservado.', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () => Navigator.of(dCtx).pop(RecurringDeleteOption.fromNowOn),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22DC2626),
                  child: Icon(Icons.delete_forever, color: Colors.red),
                ),
                title: const Text('Excluir todas as ocorrências', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Apaga todas as transações passadas e futuras desta série recorrente.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_rounded, color: AppColors.primaryLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _showUpdateDialog(context, update, notifier),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Nova Versão ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      Text(
                        'v${update.latestVersion}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Toque para ver novidades e baixar',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (update.apkDownloadUrl != null) {
                notifier.openUrl(update.apkDownloadUrl!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Baixar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
            Text('Chokin v${update.latestVersion}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
              const Text('Novidades:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
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
