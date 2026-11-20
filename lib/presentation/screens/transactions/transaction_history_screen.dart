import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../../domain/entities/installment.dart';
import '../../../domain/entities/transaction.dart';
import '../../widgets/sumi_widgets.dart';
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
  final int amountCents;
  final int netAmountCents;
  final int? installmentNumber;
  final DateTime displayDate;

  const ExtratoEntry({
    required this.transaction,
    this.installment,
    required this.amountCents,
    required this.netAmountCents,
    this.installmentNumber,
    required this.displayDate,
  });

  bool get isThirdParty =>
      transaction.isForThirdParty || (installment?.personId != null && installment!.personId != 'ME');
  bool get isIncome => transaction.type == TransactionType.income;
}

enum _KindFilter { all, income, personal, thirdParty }

enum _PaymentFilter { all, pix, card, cash }

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  _KindFilter _kindFilter = _KindFilter.all;
  _PaymentFilter _paymentFilter = _PaymentFilter.all;
  String? _categoryFilter;
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

  void _selectMonth(int month, int year) {
    setState(() {
      _viewAllMonths = false;
      _selectedMonth = month;
      _selectedYear = year;
    });
    widget.notifier.changePeriod(month, year);
  }

  int get _activeExtraFilters =>
      (_paymentFilter != _PaymentFilter.all ? 1 : 0) + (_categoryFilter != null ? 1 : 0) + (_viewAllMonths ? 1 : 0);

  List<ExtratoEntry> _entriesForPeriod(FinancialState state) {
    final entries = <ExtratoEntry>[];
    final installmentsByTx = <String, Map<int, Installment>>{};
    for (final inst in state.installments) {
      installmentsByTx.putIfAbsent(inst.transactionId, () => {})[inst.installmentNumber] = inst;
    }

    for (final t in state.transactions) {
      final isSplit = t.isCreditCard && t.totalInstallments > 1;
      if (_viewAllMonths || !isSplit) {
        if (_viewAllMonths || (t.purchaseDate.month == _selectedMonth && t.purchaseDate.year == _selectedYear)) {
          entries.add(ExtratoEntry(
            transaction: t,
            amountCents: t.amountCents,
            netAmountCents: t.netAmountCents,
            displayDate: t.purchaseDate,
          ));
        }
        continue;
      }

      final diffMonths =
          (_selectedYear * 12 + _selectedMonth - 1) - (t.purchaseDate.year * 12 + t.purchaseDate.month - 1);
      if (diffMonths < 0 || diffMonths >= t.totalInstallments) continue;

      final number = diffMonths + 1;
      final gross = Money.installmentAt(t.amountCents, t.totalInstallments, number);
      final linked = installmentsByTx[t.id]?[number];
      final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      entries.add(ExtratoEntry(
        transaction: t,
        installment: linked,
        amountCents: gross,
        netAmountCents: linked?.amountCents ?? gross,
        installmentNumber: number,
        displayDate: DateTime(_selectedYear, _selectedMonth, t.purchaseDate.day.clamp(1, daysInMonth)),
      ));
    }
    return entries;
  }

  bool _matchesFilters(ExtratoEntry e) {
    final t = e.transaction;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      if (!t.description.toLowerCase().contains(q) && !(t.notes?.toLowerCase().contains(q) ?? false)) return false;
    }
    switch (_kindFilter) {
      case _KindFilter.all:
        break;
      case _KindFilter.income:
        if (!e.isIncome) return false;
      case _KindFilter.personal:
        if (e.isIncome || e.isThirdParty) return false;
      case _KindFilter.thirdParty:
        if (!e.isThirdParty) return false;
    }
    switch (_paymentFilter) {
      case _PaymentFilter.all:
        break;
      case _PaymentFilter.pix:
        if (!t.isPix) return false;
      case _PaymentFilter.card:
        if (!t.isCreditCard) return false;
      case _PaymentFilter.cash:
        if (t.paymentMethod != PaymentMethod.cash) return false;
    }
    if (_categoryFilter != null && t.categoryId != _categoryFilter) return false;
    return true;
  }

  String _dayHeader(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = DateUtils.dateOnly(date).difference(today).inDays;
    final weekday = _weekdays[date.weekday - 1];
    final dayMonth = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Hoje · $weekday ${date.day}';
    if (diff == -1) return 'Ontem · $weekday ${date.day}';
    if (diff == 1) return 'Amanhã · $weekday ${date.day} · previsto';

    final String label;
    if (_viewAllMonths || date.month != _selectedMonth) {
      label = '$weekday $dayMonth${date.year != today.year ? '/${date.year}' : ''}';
    } else {
      label = '${weekday[0].toUpperCase()}${weekday.substring(1)} ${date.day}';
    }
    return diff > 0 ? '$label · previsto' : label;
  }

  String _signed(int cents) => '${cents < 0 ? '−' : '+'} ${CurrencyUtils.formatNoSymbol(Money.toReais(cents.abs()))}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        final state = widget.notifier.state;
        final list = _entriesForPeriod(state).where(_matchesFilters).toList()
          ..sort((a, b) {
            final byDate = b.displayDate.compareTo(a.displayDate);
            return byDate != 0 ? byDate : b.transaction.effectiveCreatedAt.compareTo(a.transaction.effectiveCreatedAt);
          });

        var incomes = 0;
        var personal = 0;
        var thirdParty = 0;
        for (final e in list) {
          if (e.isIncome) {
            incomes += e.netAmountCents;
          } else if (e.isThirdParty) {
            thirdParty += e.netAmountCents;
          } else {
            personal += e.netAmountCents;
          }
        }

        final days = <DateTime, List<ExtratoEntry>>{};
        for (final e in list) {
          days.putIfAbsent(DateUtils.dateOnly(e.displayDate), () => []).add(e);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Extrato'),
            actions: [
              IconButton(
                tooltip: _viewAllMonths ? 'Ver por mês' : 'Ver todos os meses',
                icon: Icon(_viewAllMonths ? Icons.calendar_month_outlined : Icons.all_inclusive),
                onPressed: () => setState(() => _viewAllMonths = !_viewAllMonths),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 0),
                sliver: SliverList.list(
                  children: [
                    if (_viewAllMonths)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Todos os meses', style: Sumi.bodyStrong)),
                            TextButton(
                              onPressed: () => setState(() => _viewAllMonths = false),
                              child: const Text('Ver por mês'),
                            ),
                          ],
                        ),
                      )
                    else
                      MonthStrip(month: _selectedMonth, year: _selectedYear, onChanged: _selectMonth),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: Sumi.body,
                      decoration: underlineDecoration('Buscar', hint: 'Estabelecimento ou descrição').copyWith(
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        labelText: null,
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                        prefixIconConstraints: const BoxConstraints(minWidth: 32),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (kind, label) in const [
                            (_KindFilter.all, 'Tudo'),
                            (_KindFilter.income, 'Receitas'),
                            (_KindFilter.personal, 'Meus gastos'),
                            (_KindFilter.thirdParty, 'Terceiros'),
                          ]) ...[
                            ChoiceChipSumi(
                              label: label,
                              selected: _kindFilter == kind,
                              onTap: () => setState(() => _kindFilter = kind),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ChoiceChipSumi(
                            label: _activeExtraFilters > 0 ? 'Filtros ($_activeExtraFilters)' : 'Filtros',
                            selected: _activeExtraFilters > 0,
                            onTap: () => _showFiltersSheet(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSummary(incomes, personal, thirdParty),
                  ],
                ),
              ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Sumi.gutter),
                      child: Text(
                        _searchQuery.isNotEmpty || _activeExtraFilters > 0 || _kindFilter != _KindFilter.all
                            ? 'Nenhum lançamento com esses filtros.'
                            : (_viewAllMonths
                                ? 'Nenhum lançamento ainda.'
                                : 'Nenhum lançamento em ${DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth))}.'),
                        style: Sumi.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 32),
                  sliver: SliverList.list(
                    children: [
                      for (final day in days.entries) ...[
                        _buildDayHeader(day.key, day.value),
                        for (final e in day.value) _buildEntryRow(context, state, e),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(int incomes, int personal, int thirdParty) {
    Widget cell(String label, String value, {bool rightBorder = false}) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.fromLTRB(rightBorder ? 0 : 14, 12, 12, 12),
          decoration: BoxDecoration(
            border: rightBorder ? const Border(right: BorderSide(color: AppColors.border)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Sumi.caption),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: Sumi.figures(19)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              cell('Entrou', _signed(incomes), rightBorder: true),
              cell('Saiu (pessoal)', _signed(-personal)),
            ],
          ),
        ),
        if (thirdParty > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${CurrencyUtils.formatCents(thirdParty)} em compras para outras pessoas, fora do seu gasto',
              style: Sumi.caption,
            ),
          ),
      ],
    );
  }

  Widget _buildDayHeader(DateTime day, List<ExtratoEntry> entries) {
    final total = entries.fold<int>(0, (acc, e) {
      if (e.isIncome) return acc + e.netAmountCents;
      if (e.isThirdParty) return acc;
      return acc - e.netAmountCents;
    });
    final header = _dayHeader(day);
    final split = header.indexOf(' · ');

    return Container(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              split == -1
                  ? TextSpan(text: header, style: Sumi.bodyStrong.copyWith(fontSize: 13))
                  : TextSpan(
                      children: [
                        TextSpan(text: header.substring(0, split), style: Sumi.bodyStrong.copyWith(fontSize: 13)),
                        TextSpan(text: header.substring(split), style: Sumi.label),
                      ],
                    ),
            ),
          ),
          if (total != 0) Text(_signed(total), style: Sumi.figures(13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEntryRow(BuildContext context, FinancialState state, ExtratoEntry e) {
    final tx = e.transaction;
    final category = widget.notifier.categories.where((c) => c.id == tx.categoryId).firstOrNull;
    final personId = e.installment?.personId ?? tx.personId;
    final personName = state.people.where((p) => p.id == personId).firstOrNull?.name ?? 'terceiro';

    final String method;
    if (e.isIncome) {
      method = 'Receita';
    } else if (tx.isCreditCard) {
      method = state.cards.where((c) => c.id == tx.cardId).firstOrNull?.name ?? 'Cartão';
    } else {
      method = tx.isPix ? 'Pix' : 'Dinheiro/Débito';
    }

    final refunded = e.amountCents - e.netAmountCents;
    final detailParts = [
      if (category != null) category.name,
      method,
      if (e.installmentNumber != null) 'parcela ${e.installmentNumber} de ${tx.totalInstallments}',
      if (_viewAllMonths && tx.isInstallment) '${tx.totalInstallments}x',
      if (e.isThirdParty) 'fora do seu gasto',
    ];
    final sign = e.isIncome ? '+' : '−';

    return InkWell(
      onTap: () => _showTransactionActions(context, tx),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(tx.description, style: Sumi.body),
                      if (e.isThirdParty) _Tag('PARA ${personName.toUpperCase()}'),
                      if (tx.isRecurring)
                        const Icon(Icons.repeat, size: 14, color: AppColors.textSecondary, semanticLabel: 'Recorrente'),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      style: Sumi.caption,
                      children: [
                        TextSpan(text: detailParts.join(' · ')),
                        if (refunded > 0)
                          TextSpan(
                            text: ' · estornado ${CurrencyUtils.formatCents(refunded)}',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (refunded > 0)
                  Text(
                    '$sign ${CurrencyUtils.formatNoSymbol(Money.toReais(e.amountCents))}',
                    style: Sumi.figures(12, color: AppColors.textSecondary)
                        .copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.textSecondary),
                  ),
                Text(
                  '$sign ${CurrencyUtils.formatNoSymbol(Money.toReais(e.netAmountCents))}',
                  style: Sumi.figures(
                    16,
                    weight: e.isIncome ? FontWeight.w700 : FontWeight.w500,
                    color: e.isThirdParty ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFiltersSheet(BuildContext context) {
    final categories = widget.notifier.categories;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback change) {
            setState(change);
            setSheet(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  const Text('Forma de pagamento', style: Sumi.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (option, label) in const [
                        (_PaymentFilter.all, 'Todas'),
                        (_PaymentFilter.pix, 'Pix'),
                        (_PaymentFilter.card, 'Cartão'),
                        (_PaymentFilter.cash, 'Dinheiro/Débito'),
                      ])
                        ChoiceChipSumi(
                          label: label,
                          selected: _paymentFilter == option,
                          onTap: () => update(() => _paymentFilter = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Categoria', style: Sumi.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChipSumi(
                        label: 'Todas',
                        selected: _categoryFilter == null,
                        onTap: () => update(() => _categoryFilter = null),
                      ),
                      for (final cat in categories)
                        ChoiceChipSumi(
                          label: cat.name,
                          selected: _categoryFilter == cat.id,
                          onTap: () => update(() => _categoryFilter = cat.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ver todos os meses', style: Sumi.body),
                    subtitle: const Text('Mostra o histórico inteiro, sem separar por mês', style: Sumi.caption),
                    value: _viewAllMonths,
                    onChanged: (v) => update(() => _viewAllMonths = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => update(() {
                          _paymentFilter = _PaymentFilter.all;
                          _categoryFilter = null;
                          _viewAllMonths = false;
                        }),
                        child: const Text('Limpar'),
                      ),
                      const Spacer(),
                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Ver resultados')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
                      color: isIncome
                          ? AppColors.income
                          : (tx.isForThirdParty ? AppColors.reimbursement : AppColors.textPrimary),
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
                Text('Obs: ${tx.notes}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.replay_outlined, color: AppColors.primaryLight, size: 20),
                ),
                title: const Text('Estornar Compra',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: Text(
                  tx.isRefunded
                      ? 'Já estornado ${CurrencyUtils.format(tx.refundAmount)} • Estornar mais'
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
                title: const Text('Editar Lançamento',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: const Text('Altere valor, descrição, data, categoria ou forma de pagamento',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
                title: const Text('Excluir Lançamento',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense)),
                subtitle: const Text('Remove o lançamento e recalcula saldos e faturas atomicamente',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
    PaymentMethod selectedRefundMethod =
        tx.refundMethod ?? (tx.isCreditCard ? PaymentMethod.creditCard : PaymentMethod.pix);
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
                bottom: math.max(MediaQuery.of(ctx).viewInsets.bottom, MediaQuery.of(ctx).viewPadding.bottom) + 20,
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
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                          const Text('Valor Original da Compra:',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(
                            CurrencyUtils.format(tx.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo de Estorno',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
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
                    const Text('Valor a Estornar (R\$)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
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
                    const Text('Onde o estorno foi recebido?',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
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
                              title: const Text('Na Fatura do Cartão',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              subtitle: const Text('Abate o valor da fatura em aberto',
                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              activeColor: AppColors.primary,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedRefundMethod = val);
                              },
                            ),
                          RadioListTile<PaymentMethod>(
                            value: PaymentMethod.pix,
                            groupValue: selectedRefundMethod,
                            title: const Text('Via Pix / Conta Bancária',
                                style:
                                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            subtitle: const Text('Credita o valor no seu saldo disponível em conta',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            activeColor: AppColors.primary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedRefundMethod = val);
                            },
                          ),
                          RadioListTile<PaymentMethod>(
                            value: PaymentMethod.cash,
                            groupValue: selectedRefundMethod,
                            title: const Text('Em Dinheiro Vivo',
                                style:
                                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            subtitle: const Text('Devolução recebida em espécie',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                    const Text('Data do Estorno',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
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
                            Text(DateTimeUtils.formatDate(selectedDate),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryLight),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Observação (Opcional)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
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
                              SnackBar(
                                  content: Text(
                                      'O valor do estorno não pode ser maior que o da compra (${CurrencyUtils.format(tx.amount)})!')),
                            );
                            return;
                          }

                          await widget.notifier.refundTransaction(
                            transactionId: tx.id,
                            refundAmountCents: Money.fromReais(parsedAmount),
                            refundMethod: selectedRefundMethod,
                            refundDate: selectedDate,
                            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          );

                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Estorno de ${CurrencyUtils.format(parsedAmount)} registrado com sucesso!'),
                                backgroundColor: AppColors.income,
                              ),
                            );
                          }
                        },
                        child: const Text('Confirmar Estorno',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
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
            final availableCats =
                categories.where((c) => editType == TransactionType.income ? c.isIncome : c.isExpense).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: math.max(MediaQuery.of(ctx).viewInsets.bottom, MediaQuery.of(ctx).viewPadding.bottom) + 20,
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
                                  color: editType == TransactionType.expense
                                      ? AppColors.expense.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text('Despesa',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: editType == TransactionType.expense
                                              ? AppColors.expense
                                              : AppColors.textSecondary)),
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
                                  color: editType == TransactionType.income
                                      ? AppColors.income.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text('Receita',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: editType == TransactionType.income
                                              ? AppColors.income
                                              : AppColors.textSecondary)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

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
                            Text('Data: ${DateTimeUtils.formatDate(editDate)}',
                                style: const TextStyle(color: AppColors.textPrimary)),
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

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

                    if (editType == TransactionType.expense) ...[
                      DropdownButtonFormField<PaymentMethod>(
                        value: editPaymentMethod,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(labelText: 'Forma de Pagamento'),
                        items: const [
                          DropdownMenuItem(
                              value: PaymentMethod.pix,
                              child: Text('Pix (Imediato)', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(
                              value: PaymentMethod.creditCard,
                              child: Text('Cartão de Crédito', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(
                              value: PaymentMethod.cash,
                              child: Text('Dinheiro', style: TextStyle(color: AppColors.textPrimary))),
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
                            items: cards
                                .map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name, style: const TextStyle(color: AppColors.textPrimary))))
                                .toList(),
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
                            child: const Text('Gerenciar Pessoas',
                                style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: people.any((p) => p.id == editPersonId)
                            ? editPersonId
                            : (people.isNotEmpty ? people.first.id : 'ME'),
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

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Transação Recorrente?',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      value: editIsRecurring,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setModalState(() => editIsRecurring = val),
                    ),
                    if (editIsRecurring) ...[
                      DropdownButtonFormField<RecurrenceFrequency>(
                        value:
                            editRecurrence == RecurrenceFrequency.none ? RecurrenceFrequency.monthly : editRecurrence,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(labelText: 'Frequência'),
                        items: const [
                          DropdownMenuItem(
                              value: RecurrenceFrequency.daily,
                              child: Text('Diária', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(
                              value: RecurrenceFrequency.weekly,
                              child: Text('Semanal', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(
                              value: RecurrenceFrequency.biweekly,
                              child: Text('Quinzenal', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(
                              value: RecurrenceFrequency.monthly,
                              child: Text('Mensal', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(
                              value: RecurrenceFrequency.yearly,
                              child: Text('Anual', style: TextStyle(color: AppColors.textPrimary))),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => editRecurrence = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Observação (Opcional)'),
                    ),
                    const SizedBox(height: 20),

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
                            amountCents: Money.fromReais(amount),
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
                                title:
                                    const Text('Encerrar Recorrência?', style: TextStyle(color: AppColors.textPrimary)),
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
                                  SnackBar(
                                      content: Text(
                                          'Recorrência encerrada a partir de $monthName. Histórico passado preservado.')),
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

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.primary),
      ),
    );
  }
}
