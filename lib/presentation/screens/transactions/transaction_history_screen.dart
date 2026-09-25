import 'package:flutter/material.dart' hide Category;
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/installment.dart';
import '../../../domain/entities/person.dart';
import '../../../domain/entities/transaction.dart';
import '../categories/categories_management_screen.dart';
import '../people/people_management_screen.dart';
import '../../state/financial_state_notifier.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const TransactionHistoryScreen({super.key, required this.notifier});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class ExtratoEntry {
  final FinancialTransaction transaction;
  final Installment? installment;
  final double displayAmount;
  final String? installmentLabel;
  final DateTime displayDate;

  const ExtratoEntry({
    required this.transaction,
    this.installment,
    required this.displayAmount,
    this.installmentLabel,
    required this.displayDate,
  });
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _ownershipFilter = 'ALL'; // 'ALL', 'PERSONAL', 'THIRD_PARTY', 'INCOME'
  String _paymentFilter = 'ALL'; // 'ALL', 'PIX', 'CREDIT', 'CASH'
  String _searchQuery = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _viewAllMonths = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.notifier.selectedMonth;
    _selectedYear = widget.notifier.selectedYear;
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
    widget.notifier.changePeriod(_selectedMonth, _selectedYear);
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
    widget.notifier.changePeriod(_selectedMonth, _selectedYear);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        final state = widget.notifier.state;
        
        // Constrói lista de lançamentos para o extrato (incluindo parcelas do mês)
        final allEntries = <ExtratoEntry>[];

        if (_viewAllMonths) {
          for (final t in state.transactions) {
            allEntries.add(ExtratoEntry(
              transaction: t,
              displayAmount: t.amount,
              installmentLabel: t.isInstallment ? '(${t.totalInstallments}x)' : null,
              displayDate: t.purchaseDate,
            ));
          }
        } else {
          // Mês específico selecionado:
          for (final t in state.transactions) {
            if (!t.isCreditCard || t.totalInstallments <= 1) {
              if (t.purchaseDate.month == _selectedMonth && t.purchaseDate.year == _selectedYear) {
                allEntries.add(ExtratoEntry(
                  transaction: t,
                  displayAmount: t.amount,
                  installmentLabel: null,
                  displayDate: t.purchaseDate,
                ));
              }
            } else {
              // Compra parcelada no cartão:
              // Parcela 1 pertence ao mês da compra, Parcela 2 ao mês seguinte, etc.
              final totalMonthsPurchase = (t.purchaseDate.year * 12) + (t.purchaseDate.month - 1);
              final totalMonthsSelected = (_selectedYear * 12) + (_selectedMonth - 1);
              final diffMonths = totalMonthsSelected - totalMonthsPurchase;

              if (diffMonths >= 0 && diffMonths < t.totalInstallments) {
                final instNum = diffMonths + 1;
                final baseAmt = double.parse((t.amount / t.totalInstallments).toStringAsFixed(2));
                final lastAmt = double.parse((t.amount - (baseAmt * (t.totalInstallments - 1))).toStringAsFixed(2));
                final instAmt = (instNum == t.totalInstallments) ? lastAmt : baseAmt;

                final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
                final day = t.purchaseDate.day > daysInMonth ? daysInMonth : t.purchaseDate.day;
                final instDate = DateTime(_selectedYear, _selectedMonth, day);

                final linkedInst = state.installments.where((i) =>
                    i.transactionId == t.id && i.installmentNumber == instNum).firstOrNull;

                allEntries.add(ExtratoEntry(
                  transaction: t,
                  installment: linkedInst,
                  displayAmount: instAmt,
                  installmentLabel: '($instNum/${t.totalInstallments})',
                  displayDate: instDate,
                ));
              }
            }
          }
        }

        // Aplica os filtros
        var list = allEntries.where((e) {
          final t = e.transaction;
          if (_searchQuery.isNotEmpty) {
            if (!t.description.toLowerCase().contains(_searchQuery.toLowerCase())) {
              return false;
            }
          }

          // 1. Filtro de Titularidade / Tipo
          final isThirdParty = t.isForThirdParty ||
              (e.installment != null && e.installment!.personId != null && e.installment!.personId != 'ME');
          if (_ownershipFilter == 'PERSONAL') {
            if (t.type != TransactionType.expense || isThirdParty) return false;
          } else if (_ownershipFilter == 'THIRD_PARTY') {
            if (!isThirdParty) return false;
          } else if (_ownershipFilter == 'INCOME') {
            if (t.type != TransactionType.income) return false;
          }

          // 2. Filtro de Forma de Pagamento
          if (_paymentFilter == 'PIX') {
            if (!t.isPix) return false;
          } else if (_paymentFilter == 'CREDIT') {
            if (!t.isCreditCard) return false;
          } else if (_paymentFilter == 'CASH') {
            if (t.paymentMethod != PaymentMethod.cash) return false;
          }

          return true;
        }).toList();

        list.sort((a, b) => b.displayDate.compareTo(a.displayDate));

        // Resumo do período selecionado
        final monthIncomes = list
            .where((e) => e.transaction.type == TransactionType.income)
            .fold<double>(0.0, (acc, e) => acc + e.displayAmount);

        final monthPersonalExpenses = list
            .where((e) {
              final isThirdParty = e.transaction.isForThirdParty ||
                  (e.installment != null && e.installment!.personId != null && e.installment!.personId != 'ME');
              return e.transaction.type == TransactionType.expense && !isThirdParty;
            })
            .fold<double>(0.0, (acc, e) => acc + e.displayAmount);

        final monthThirdPartyExpenses = list
            .where((e) {
              final isThirdParty = e.transaction.isForThirdParty ||
                  (e.installment != null && e.installment!.personId != null && e.installment!.personId != 'ME');
              return isThirdParty;
            })
            .fold<double>(0.0, (acc, e) => acc + e.displayAmount);

        final monthBalance = monthIncomes - monthPersonalExpenses;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Extrato Financeiro', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                tooltip: _viewAllMonths ? 'Ver por Mês' : 'Ver Todos os Meses',
                icon: Icon(
                  _viewAllMonths ? Icons.calendar_month : Icons.calendar_view_day,
                  color: _viewAllMonths ? AppColors.primaryLight : AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() => _viewAllMonths = !_viewAllMonths);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Navegador de Meses
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                      onPressed: _previousMonth,
                    ),
                    InkWell(
                      onTap: () => _showMonthPicker(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              _viewAllMonths ? 'Todos os Meses (Histórico Geral)' : DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth)),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: AppColors.primaryLight, size: 18),
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

              // 2. Mini Resumo do Mês
              Container(
                color: AppColors.surface.withValues(alpha: 0.7),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Entradas', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            '+${CurrencyUtils.format(monthIncomes)}',
                            style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gastos Pessoais', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            '-${CurrencyUtils.format(monthPersonalExpenses)}',
                            style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (monthThirdPartyExpenses > 0)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Terceiros', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            Text(
                              CurrencyUtils.format(monthThirdPartyExpenses),
                              style: const TextStyle(color: AppColors.reimbursement, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Balanço', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            '${monthBalance >= 0 ? '+' : ''}${CurrencyUtils.format(monthBalance)}',
                            style: TextStyle(
                              color: monthBalance >= 0 ? AppColors.income : AppColors.expense,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Barra de busca
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Buscar lançamento por descrição...',
                    prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  ),
                ),
              ),

              // 4. Chips de Filtro (Combináveis)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Row(
                        children: [
                          _buildOwnershipFilterChip('ALL', 'Todos Lançamentos'),
                          const SizedBox(width: 8),
                          _buildOwnershipFilterChip('PERSONAL', 'Meus Gastos'),
                          const SizedBox(width: 8),
                          _buildOwnershipFilterChip('THIRD_PARTY', 'Gastos de Terceiros'),
                          const SizedBox(width: 8),
                          _buildOwnershipFilterChip('INCOME', 'Receitas'),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Row(
                        children: [
                          _buildPaymentFilterChip('ALL', 'Todas as Formas'),
                          const SizedBox(width: 8),
                          _buildPaymentFilterChip('PIX', 'Pix'),
                          const SizedBox(width: 8),
                          _buildPaymentFilterChip('CREDIT', 'Cartão de Crédito'),
                          const SizedBox(width: 8),
                          _buildPaymentFilterChip('CASH', 'Dinheiro'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 5. Lista de Transações
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _viewAllMonths
                                  ? 'Nenhum lançamento encontrado.'
                                  : 'Nenhum lançamento em ${DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth))}.',
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (ctx, index) {
                          final entry = list[index];
                          final tx = entry.transaction;
                          final isIncome = tx.type == TransactionType.income;
                          final isThirdParty = tx.isForThirdParty ||
                              (entry.installment != null && entry.installment!.personId != null && entry.installment!.personId != 'ME');
                          final personId = entry.installment?.personId ?? tx.personId;
                          final person = state.people.firstWhere(
                            (p) => p.id == personId,
                            orElse: () => state.people.isNotEmpty ? state.people.first : Person(id: 'ME', name: 'Eu', createdAt: DateTime.now()),
                          );
                          final category = widget.notifier.categories.firstWhere(
                            (c) => c.id == tx.categoryId,
                            orElse: () => const Category(id: 'cat_other', name: 'Outros', icon: 'category', colorHex: '0xFF94A3B8'),
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _showTransactionActions(context, tx),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: (isIncome ? AppColors.income : (isThirdParty ? AppColors.reimbursement : AppColors.expense)).withValues(alpha: 0.15),
                                        child: Icon(
                                          isIncome
                                              ? Icons.arrow_upward
                                              : (isThirdParty
                                                  ? Icons.person_outline
                                                  : (tx.isCreditCard ? Icons.credit_card : Icons.pix)),
                                          color: isIncome
                                              ? AppColors.income
                                              : (isThirdParty
                                                  ? AppColors.reimbursement
                                                  : (tx.isCreditCard ? AppColors.committed : AppColors.expense)),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx.description,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  DateTimeUtils.formatDate(entry.displayDate),
                                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                                ),
                                                const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceLight,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    category.name,
                                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                                Text(
                                                  tx.paymentMethodLabel,
                                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                                if (entry.installmentLabel != null)
                                                  Text(
                                                    entry.installmentLabel!,
                                                    style: const TextStyle(color: AppColors.committed, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                if (tx.isRecurring)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.repeat, size: 10, color: AppColors.primaryLight),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          tx.recurrenceLabel,
                                                          style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (tx.isForThirdParty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.reimbursement.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Para: ${person.name}',
                                                      style: const TextStyle(color: AppColors.reimbursement, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                if (tx.isRefunded)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: (tx.isFullyRefunded ? AppColors.income : AppColors.primary).withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      tx.isFullyRefunded
                                                          ? 'ESTORNADO (${tx.refundMethod == PaymentMethod.pix ? "PIX" : tx.paymentMethodLabel})'
                                                          : 'ESTORNO PARCIAL (-${CurrencyUtils.format(tx.refundAmount)})',
                                                      style: TextStyle(
                                                        color: tx.isFullyRefunded ? AppColors.income : AppColors.primaryLight,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (tx.isFullyRefunded) ...[
                                            Text(
                                              '${isIncome ? '+' : '-'}${CurrencyUtils.format(entry.displayAmount)}',
                                              style: const TextStyle(
                                                decoration: TextDecoration.lineThrough,
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Text(
                                              'R\$ 0,00',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ] else if (tx.isPartiallyRefunded) ...[
                                            Text(
                                              '${isIncome ? '+' : '-'}${CurrencyUtils.format(entry.displayAmount)}',
                                              style: const TextStyle(
                                                decoration: TextDecoration.lineThrough,
                                                color: AppColors.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              '${isIncome ? '+' : '-'}${CurrencyUtils.format(entry.displayAmount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isIncome ? AppColors.income : (isThirdParty ? AppColors.reimbursement : AppColors.textPrimary),
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              '${isIncome ? '+' : '-'}${CurrencyUtils.format(entry.displayAmount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isIncome
                                                    ? AppColors.income
                                                    : (isThirdParty ? AppColors.reimbursement : AppColors.textPrimary),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () => _showRefundDialog(context, tx),
                                                borderRadius: BorderRadius.circular(6),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.replay_outlined, size: 18, color: AppColors.primaryLight),
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              InkWell(
                                                onTap: () => _showEditTransactionModal(context, tx),
                                                borderRadius: BorderRadius.circular(6),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              InkWell(
                                                onTap: () => _confirmDeleteTransaction(context, tx),
                                                borderRadius: BorderRadius.circular(6),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.delete_outline, size: 18, color: AppColors.expense),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final currentYear = DateTime.now().year;
        final months = [
          'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
          'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
        ];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecionar Período', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: AppColors.primaryLight),
                title: const Text('Ver Todos os Meses', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                selected: _viewAllMonths,
                onTap: () {
                  setState(() => _viewAllMonths = true);
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(color: AppColors.border),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, idx) {
                    final monthNum = idx + 1;
                    final isSelected = !_viewAllMonths && _selectedMonth == monthNum && _selectedYear == currentYear;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedMonth = monthNum;
                          _selectedYear = currentYear;
                          _viewAllMonths = false;
                        });
                        widget.notifier.changePeriod(_selectedMonth, _selectedYear);
                        Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            months[idx],
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOwnershipFilterChip(String key, String label) {
    final isSelected = _ownershipFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _ownershipFilter = key);
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildPaymentFilterChip(String key, String label) {
    final isSelected = _paymentFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _paymentFilter = key);
      },
      selectedColor: AppColors.primaryLight,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  void _showTransactionActions(BuildContext context, FinancialTransaction tx) {
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
                    ),
                  ),
                  Text(
                    '${isIncome ? '+' : '-'}${CurrencyUtils.format(tx.amount)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? AppColors.income : (tx.isForThirdParty ? AppColors.reimbursement : AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Data: ${DateTimeUtils.formatDate(tx.purchaseDate)} • Pagamento: ${tx.paymentMethodLabel}${tx.isInstallment ? " (${tx.totalInstallments}x)" : ""}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Obs: ${tx.notes}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.replay_outlined, color: AppColors.primaryLight, size: 20),
                ),
                title: const Text('Estornar Compra', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: Text(
                  tx.isRefunded
                      ? 'Já estornado ${CurrencyUtils.format(tx.refundAmount)} • Ajustar estorno'
                      : 'Estorno total ou parcial na mesma forma ou em outra',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showRefundDialog(context, tx);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.background,
                  child: Icon(Icons.edit, color: AppColors.primaryLight, size: 20),
                ),
                title: const Text('Editar Lançamento', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: const Text('Altere valor, descrição, data, categoria ou forma de pagamento', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showEditTransactionModal(context, tx);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.expense.withValues(alpha: 0.15),
                  child: const Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
                ),
                title: const Text('Excluir Lançamento', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense)),
                subtitle: const Text('Remove o lançamento e recalcula saldos e faturas atomicamente', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeleteTransaction(context, tx);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showRefundDialog(BuildContext context, FinancialTransaction tx) {
    bool isFullRefund = tx.refundAmount == 0 || tx.refundAmount >= tx.amount;
    final initialRefund = isFullRefund ? tx.amount : tx.refundAmount;
    final amountCtrl = TextEditingController(text: CurrencyUtils.formatNoSymbol(initialRefund));
    PaymentMethod selectedRefundMethod = tx.refundMethod ?? (tx.isCreditCard ? PaymentMethod.creditCard : PaymentMethod.pix);
    DateTime selectedDate = tx.refundedAt ?? DateTime.now();
    final notesCtrl = TextEditingController(text: tx.refundNotes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.replay_outlined, color: AppColors.primaryLight, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estornar Compra',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  tx.description,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor Original da Compra:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(
                            CurrencyUtils.format(tx.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo de Estorno', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Estorno Total')),
                            selected: isFullRefund,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.background,
                            labelStyle: TextStyle(
                              color: isFullRefund ? Colors.white : AppColors.textSecondary,
                              fontWeight: isFullRefund ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  isFullRefund = true;
                                  amountCtrl.text = CurrencyUtils.formatNoSymbol(tx.amount);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Estorno Parcial')),
                            selected: !isFullRefund,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.background,
                            labelStyle: TextStyle(
                              color: !isFullRefund ? Colors.white : AppColors.textSecondary,
                              fontWeight: !isFullRefund ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  isFullRefund = false;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Valor a Estornar (R\$)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      enabled: !isFullRefund,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyTextInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money, color: AppColors.primaryLight),
                        hintText: '0,00',
                        filled: isFullRefund,
                        fillColor: isFullRefund ? AppColors.background : AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Onde o estorno foi recebido?', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          if (tx.isCreditCard)
                            RadioListTile<PaymentMethod>(
                              value: PaymentMethod.creditCard,
                              groupValue: selectedRefundMethod,
                              title: const Text('Na Fatura do Cartão', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              subtitle: const Text('Abate o valor da fatura em aberto', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              activeColor: AppColors.primary,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedRefundMethod = val);
                              },
                            ),
                          RadioListTile<PaymentMethod>(
                            value: PaymentMethod.pix,
                            groupValue: selectedRefundMethod,
                            title: const Text('Via Pix / Conta Bancária', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            subtitle: const Text('Credita o valor no seu saldo disponível em conta', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            activeColor: AppColors.primary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedRefundMethod = val);
                            },
                          ),
                          RadioListTile<PaymentMethod>(
                            value: PaymentMethod.cash,
                            groupValue: selectedRefundMethod,
                            title: const Text('Em Dinheiro Vivo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            subtitle: const Text('Devolução recebida em espécie', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            activeColor: AppColors.primary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedRefundMethod = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Data do Estorno', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateTimeUtils.formatDate(selectedDate), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryLight),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Observação (Opcional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Produto cancelado na loja, devolução...',
                        prefixIcon: Icon(Icons.notes, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final parsedAmount = isFullRefund ? tx.amount : (CurrencyUtils.parse(amountCtrl.text) ?? 0.0);
                          if (parsedAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Informe um valor de estorno válido!')),
                            );
                            return;
                          }
                          if (parsedAmount > tx.amount) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('O valor do estorno não pode ser maior que o da compra (${CurrencyUtils.format(tx.amount)})!')),
                            );
                            return;
                          }

                          await widget.notifier.refundTransaction(
                            transactionId: tx.id,
                            refundAmount: parsedAmount,
                            refundMethod: selectedRefundMethod,
                            refundDate: selectedDate,
                            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          );

                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Estorno de ${CurrencyUtils.format(parsedAmount)} registrado com sucesso!'),
                                backgroundColor: AppColors.income,
                              ),
                            );
                          }
                        },
                        child: const Text('Confirmar Estorno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTransactionModal(BuildContext context, FinancialTransaction tx) {
    final descCtrl = TextEditingController(text: tx.description);
    final amountCtrl = TextEditingController(text: tx.amount.toStringAsFixed(2).replaceAll('.', ','));
    final notesCtrl = TextEditingController(text: tx.notes ?? '');

    TransactionType editType = tx.type;
    PaymentMethod editPaymentMethod = tx.paymentMethod;
    DateTime editDate = tx.purchaseDate;
    String editCategoryId = tx.categoryId;
    String editPersonId = tx.personId;
    String? editCardId = tx.cardId;
    int editInstallments = tx.totalInstallments;
    bool editIsRecurring = tx.isRecurring;
    RecurrenceFrequency editRecurrence = tx.recurrence;

    final categories = widget.notifier.categories;
    final people = widget.notifier.state.people;
    final cards = widget.notifier.state.cards;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableCats = categories.where((c) => editType == TransactionType.income ? c.isIncome : c.isExpense).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Editar Lançamento',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tipo (Despesa / Receita)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  editType = TransactionType.expense;
                                  final newCats = categories.where((c) => c.isExpense).toList();
                                  if (newCats.isNotEmpty && !newCats.any((c) => c.id == editCategoryId)) {
                                    editCategoryId = newCats.first.id;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: editType == TransactionType.expense ? AppColors.expense.withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text('Despesa', style: TextStyle(fontWeight: FontWeight.bold, color: editType == TransactionType.expense ? AppColors.expense : AppColors.textSecondary)),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  editType = TransactionType.income;
                                  final newCats = categories.where((c) => c.isIncome).toList();
                                  if (newCats.isNotEmpty && !newCats.any((c) => c.id == editCategoryId)) {
                                    editCategoryId = newCats.first.id;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: editType == TransactionType.income ? AppColors.income.withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text('Receita', style: TextStyle(fontWeight: FontWeight.bold, color: editType == TransactionType.income ? AppColors.income : AppColors.textSecondary)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Valor & Descrição
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyTextInputFormatter()],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Valor (R\$)', prefixText: 'R\$ '),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                    ),
                    const SizedBox(height: 12),

                    // Data
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: editDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => editDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Data: ${DateTimeUtils.formatDate(editDate)}', style: const TextStyle(color: AppColors.textPrimary)),
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Categoria
                    DropdownButtonFormField<String>(
                      value: availableCats.any((c) => c.id == editCategoryId)
                          ? editCategoryId
                          : (availableCats.isNotEmpty ? availableCats.first.id : null),
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: availableCats.map((cat) {
                        Color catColor;
                        try {
                          catColor = Color(int.parse(cat.colorHex));
                        } catch (_) {
                          catColor = AppColors.primary;
                        }
                        return DropdownMenuItem<String>(
                          value: cat.id,
                          child: Row(
                            children: [
                              Icon(CategoriesManagementScreen.getIconData(cat.icon), size: 16, color: catColor),
                              const SizedBox(width: 8),
                              Text(cat.name, style: const TextStyle(color: AppColors.textPrimary)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => editCategoryId = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Forma de Pagamento (Se despesa)
                    if (editType == TransactionType.expense) ...[
                      DropdownButtonFormField<PaymentMethod>(
                        value: editPaymentMethod,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(labelText: 'Forma de Pagamento'),
                        items: const [
                          DropdownMenuItem(value: PaymentMethod.pix, child: Text('Pix (Imediato)', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(value: PaymentMethod.creditCard, child: Text('Cartão de Crédito', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(value: PaymentMethod.cash, child: Text('Dinheiro', style: TextStyle(color: AppColors.textPrimary))),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => editPaymentMethod = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      if (editPaymentMethod == PaymentMethod.creditCard) ...[
                        if (cards.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            value: editCardId ?? cards.first.id,
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(labelText: 'Cartão'),
                            items: cards.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(color: AppColors.textPrimary)))).toList(),
                            onChanged: (val) => setModalState(() => editCardId = val),
                          ),
                          const SizedBox(height: 12),
                        ],
                        DropdownButtonFormField<int>(
                          value: editInstallments,
                          dropdownColor: AppColors.surface,
                          decoration: const InputDecoration(labelText: 'Parcelas'),
                          items: List.generate(24, (i) => i + 1).map((n) {
                            final amountVal = CurrencyUtils.parse(amountCtrl.text) ?? 0.0;
                            final parcelVal = n > 0 && amountVal > 0 ? (amountVal / n).toStringAsFixed(2) : '0,00';
                            return DropdownMenuItem(
                              value: n,
                              child: Text(
                                n == 1 ? '1x (À vista na fatura)' : '${n}x de R\$ $parcelVal',
                                style: const TextStyle(color: AppColors.textPrimary),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => editInstallments = val);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Responsável
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Responsável', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => PeopleManagementScreen(notifier: widget.notifier)),
                              );
                            },
                            child: const Text('Gerenciar Pessoas', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: people.any((p) => p.id == editPersonId) ? editPersonId : (people.isNotEmpty ? people.first.id : 'ME'),
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(labelText: 'Responsável'),
                        items: people.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.isMe ? 'Eu (Gasto Pessoal)' : '${p.name} (Reembolso)',
                              style: TextStyle(color: p.isMe ? AppColors.textPrimary : AppColors.reimbursement),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => editPersonId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Recorrência
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Transação Recorrente?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      value: editIsRecurring,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setModalState(() => editIsRecurring = val),
                    ),
                    if (editIsRecurring) ...[
                      DropdownButtonFormField<RecurrenceFrequency>(
                        value: editRecurrence == RecurrenceFrequency.none ? RecurrenceFrequency.monthly : editRecurrence,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(labelText: 'Frequência'),
                        items: const [
                          DropdownMenuItem(value: RecurrenceFrequency.daily, child: Text('Diária', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(value: RecurrenceFrequency.weekly, child: Text('Semanal', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(value: RecurrenceFrequency.biweekly, child: Text('Quinzenal', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Mensal', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text('Anual', style: TextStyle(color: AppColors.textPrimary))),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => editRecurrence = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Observações
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Observação (Opcional)'),
                    ),
                    const SizedBox(height: 20),

                    // Botão Salvar Alterações
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final desc = descCtrl.text.trim();
                          final amount = CurrencyUtils.parse(amountCtrl.text);

                          if (desc.isEmpty || amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Informe uma descrição e valor válidos.')),
                            );
                            return;
                          }

                          final updatedTx = tx.copyWith(
                            description: desc,
                            amount: amount,
                            purchaseDate: editDate,
                            categoryId: editCategoryId,
                            type: editType,
                            paymentMethod: editType == TransactionType.income ? PaymentMethod.pix : editPaymentMethod,
                            personId: editPersonId,
                            cardId: editPaymentMethod == PaymentMethod.creditCard ? editCardId : null,
                            totalInstallments: editInstallments,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            isRecurring: editIsRecurring,
                            recurrence: editIsRecurring ? editRecurrence : RecurrenceFrequency.none,
                          );

                          await widget.notifier.updateTransaction(
                            oldTransactionId: tx.id,
                            newTransaction: updatedTx,
                          );

                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lançamento atualizado com sucesso!')),
                            );
                          }
                        },
                        child: const Text('Salvar Alterações'),
                      ),
                    ),
                    if (tx.isRecurring || tx.recurringGroupId != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_busy, color: AppColors.expense, size: 18),
                          label: const Text(
                            'Encerrar Recorrência',
                            style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.expense, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final monthName = DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth));
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: const Text('Encerrar Recorrência?', style: TextStyle(color: AppColors.textPrimary)),
                                content: Text(
                                  'Deseja encerrar este lançamento recorrente ("${tx.description}") a partir de $monthName?\n\n'
                                  '• O histórico dos meses passados continuará 100% preservado.\n'
                                  '• Não serão geradas novas cobranças deste lançamento a partir deste mês.',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dCtx).pop(false),
                                    child: const Text('Voltar'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
                                    onPressed: () => Navigator.of(dCtx).pop(true),
                                    child: const Text('Encerrar Recorrência'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await widget.notifier.deleteRecurringTransaction(
                                transactionId: tx.id,
                                option: RecurringDeleteOption.fromNowOn,
                                currentMonth: _selectedMonth,
                                currentYear: _selectedYear,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Recorrência encerrada a partir de $monthName. Histórico passado preservado.')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTransaction(BuildContext context, FinancialTransaction tx) async {
    final isRecurring = tx.isRecurring || tx.recurringGroupId != null;

    if (isRecurring) {
      final monthName = DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth));
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
        await widget.notifier.deleteRecurringTransaction(
          transactionId: tx.id,
          option: choice,
          currentMonth: _selectedMonth,
          currentYear: _selectedYear,
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
      await widget.notifier.deleteTransaction(tx.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lançamento excluído e saldo recalculado.')),
        );
      }
    }
  }
}
