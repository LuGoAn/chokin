import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../../domain/entities/installment.dart';
import '../../../domain/entities/person.dart';
import '../../../domain/entities/reimbursement.dart';
import '../../../domain/entities/transaction.dart';
import '../../widgets/sumi_widgets.dart';
import '../people/people_management_screen.dart';
import '../../state/financial_state_notifier.dart';

class ReimbursementsScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const ReimbursementsScreen({super.key, required this.notifier});

  @override
  State<ReimbursementsScreen> createState() => _ReimbursementsScreenState();
}

class _ReimbursementsScreenState extends State<ReimbursementsScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _viewAllMonths = false;
  bool _showReceived = false;
  final Set<String> _toggled = {};

  FinancialStateNotifier get notifier => widget.notifier;

  @override
  void initState() {
    super.initState();
    _selectedMonth = notifier.selectedMonth;
    _selectedYear = notifier.selectedYear;
  }

  String get _monthName => DateTimeUtils.formatMonthYear(DateTime(_selectedYear, _selectedMonth)).split(' ').first;

  String _dayMonth(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  FinancialTransaction _txFor(FinancialState state, Reimbursement r) {
    return state.transactions.where((t) => t.id == r.transactionId).firstOrNull ??
        FinancialTransaction(
          id: r.transactionId,
          description: 'Compra para terceiro',
          amountCents: r.totalAmountCents,
          purchaseDate: r.createdAt,
          categoryId: 'cat_other',
          paymentMethod: PaymentMethod.pix,
        );
  }

  List<_ReceivedEntry> _receivedEntries(FinancialState state) {
    final entries = <_ReceivedEntry>[];
    for (final r in state.reimbursements) {
      final person = state.people.where((p) => p.id == r.personId).firstOrNull ??
          Person(id: r.personId, name: 'Terceiro', createdAt: r.createdAt);
      final tx = _txFor(state, r);
      if (r.payments.isNotEmpty) {
        for (var i = 0; i < r.payments.length; i++) {
          final p = r.payments[i];
          final ref = FinancialMovementEngine.getReimbursementPaymentReferencePeriod(
            transaction: tx,
            reimbursement: r,
            payment: p,
            paymentIndex: i,
          );
          entries.add(_ReceivedEntry(r, p, person, tx, p.paymentDate, ref.month, ref.year, p.amountCents));
        }
      } else if (r.isSettled) {
        final ref = FinancialMovementEngine.getReimbursementPaymentReferencePeriod(transaction: tx, reimbursement: r);
        entries.add(_ReceivedEntry(r, null, person, tx, r.createdAt, ref.month, ref.year, r.totalAmountCents));
      }
    }
    final filtered = _viewAllMonths
        ? entries
        : entries.where((e) => e.referenceMonth == _selectedMonth && e.referenceYear == _selectedYear).toList();
    return filtered..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final state = notifier.state;
        final summary = FinancialMovementEngine.calculateReimbursementsSummary(
          state: state,
          targetMonth: _selectedMonth,
          targetYear: _selectedYear,
        );
        final debtors = _viewAllMonths
            ? state.people
                .where((p) => !p.isMe && state.reimbursements.any((r) => r.personId == p.id && !r.isSettled))
                .toList()
            : summary.activeDebtorsInMonth;
        final received = _receivedEntries(state);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Cobranças'),
            actions: [
              IconButton(
                tooltip: _viewAllMonths ? 'Ver por mês' : 'Ver todos os meses',
                icon: Icon(_viewAllMonths ? Icons.calendar_month_outlined : Icons.all_inclusive),
                onPressed: () => setState(() => _viewAllMonths = !_viewAllMonths),
              ),
              IconButton(
                tooltip: 'Pessoas',
                icon: const Icon(Icons.people_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PeopleManagementScreen(notifier: notifier)),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 32),
            children: [
              if (_viewAllMonths)
                Row(
                  children: [
                    const Expanded(child: Text('Todos os meses', style: Sumi.bodyStrong)),
                    TextButton(
                      onPressed: () => setState(() => _viewAllMonths = false),
                      child: const Text('Ver por mês'),
                    ),
                  ],
                )
              else
                MonthStrip(
                  month: _selectedMonth,
                  year: _selectedYear,
                  onChanged: (m, y) => setState(() {
                    _selectedMonth = m;
                    _selectedYear = y;
                  }),
                ),
              const SizedBox(height: 12),
              SegmentedChoice<bool>(
                underline: true,
                options: [
                  (false, 'A receber (${debtors.length})'),
                  (true, 'Recebidos (${received.length})'),
                ],
                value: _showReceived,
                onChanged: (v) => setState(() => _showReceived = v),
              ),
              const SizedBox(height: 24),
              if (_showReceived)
                ..._buildReceived(context, received)
              else
                ..._buildPending(context, state, summary, debtors),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPending(
    BuildContext context,
    FinancialState state,
    ({
      int monthDueCents,
      int totalPendingCents,
      int activeDebtorsCount,
      List<Person> activeDebtorsInMonth,
      Map<String, int> personMonthDueCentsMap,
    }) summary,
    List<Person> debtors,
  ) {
    final heroCents = _viewAllMonths ? summary.totalPendingCents : summary.monthDueCents;
    final String heroCaption;
    if (_viewAllMonths) {
      heroCaption = '${debtors.length} pessoa${debtors.length == 1 ? '' : 's'} com compras para acertar';
    } else if (summary.totalPendingCents > summary.monthDueCents) {
      heroCaption = '${CurrencyUtils.formatCents(summary.totalPendingCents)} no total, contando os próximos meses';
    } else {
      heroCaption = 'é tudo o que falta receber';
    }

    return [
      Text(_viewAllMonths ? 'Total a receber' : 'A receber em $_monthName', style: Sumi.label),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(CurrencyUtils.formatCents(heroCents), style: Sumi.figures(44)),
      ),
      const SizedBox(height: 4),
      Text(heroCaption, style: Sumi.caption),
      const SizedBox(height: 28),
      if (debtors.isEmpty)
        LedgerLine(
          label: _viewAllMonths ? 'Ninguém te deve nada' : 'Nada para receber em $_monthName',
          value: '',
          detail: 'Compras feitas para outras pessoas aparecem aqui',
          showBottomBorder: true,
        )
      else
        for (final person in debtors)
          _buildPersonSection(context, state, person, summary.personMonthDueCentsMap,
              openByDefault: debtors.length == 1),
    ];
  }

  Widget _buildPersonSection(
    BuildContext context,
    FinancialState state,
    Person person,
    Map<String, int> dueMap, {
    required bool openByDefault,
  }) {
    final allPending = state.reimbursements.where((r) => r.personId == person.id && !r.isSettled).toList();
    final pendingCents = allPending.fold<int>(0, (acc, r) => acc + r.remainingAmountCents);
    final monthDue = dueMap[person.id] ?? 0;
    final shown = _viewAllMonths
        ? allPending
        : allPending
            .where((r) => FinancialMovementEngine.isReimbursementActiveInMonth(
                  transaction: _txFor(state, r),
                  targetMonth: _selectedMonth,
                  targetYear: _selectedYear,
                ))
            .toList();
    final expanded = _toggled.contains(person.id) ? !openByDefault : openByDefault;
    final headerValue = _viewAllMonths ? pendingCents : monthDue;

    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _toggled.contains(person.id) ? _toggled.remove(person.id) : _toggled.add(person.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: Sumi.bodyStrong.copyWith(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          '${shown.length} compra${shown.length == 1 ? '' : 's'}'
                          '${!_viewAllMonths && pendingCents > monthDue ? ' · ${CurrencyUtils.formatCents(pendingCents)} no total' : ''}',
                          style: Sumi.caption,
                        ),
                      ],
                    ),
                  ),
                  if (!_viewAllMonths && monthDue == 0)
                    const Text(
                      'MÊS QUITADO',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    )
                  else
                    Text(CurrencyUtils.formatCents(headerValue), style: Sumi.figures(19)),
                  const SizedBox(width: 4),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            _buildPersonActions(context, person, monthDue, pendingCents),
            const SizedBox(height: 12),
            for (final r in shown) _buildPurchase(context, state, r, person),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonActions(BuildContext context, Person person, int monthDue, int pendingCents) {
    if (!_viewAllMonths && monthDue > 0) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _confirmSettleMonth(context, person, monthDue),
              child: Text('Receber o mês', style: Sumi.bodyStrong.copyWith(color: AppColors.textOnPrimary)),
            ),
          ),
          if (pendingCents > monthDue) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _confirmSettleAll(context, person, pendingCents),
                child: const Text('Quitar tudo'),
              ),
            ),
          ],
        ],
      );
    }
    if (!_viewAllMonths) {
      return Row(
        children: [
          const Expanded(child: Text('As parcelas deste mês já foram recebidas.', style: Sumi.caption)),
          if (pendingCents > 0)
            TextButton(
              onPressed: () => _confirmSettleAll(context, person, pendingCents),
              child: const Text('Adiantar restante'),
            ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _confirmSettleAll(context, person, pendingCents),
        child: Text('Quitar tudo (${CurrencyUtils.formatCents(pendingCents)})'),
      ),
    );
  }

  Widget _buildPurchase(BuildContext context, FinancialState state, Reimbursement r, Person person) {
    final tx = _txFor(state, r);
    final installments = state.installments.where((i) => i.transactionId == tx.id).toList()
      ..sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));
    final details = [
      'comprado em ${_dayMonth(tx.purchaseDate)}',
      'total ${CurrencyUtils.formatCents(r.totalAmountCents)}',
      if (tx.isInstallment) '${tx.totalInstallments}x',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(Sumi.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.description, style: Sumi.body),
                    const SizedBox(height: 2),
                    Text(details.join(' · '), style: Sumi.caption),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyUtils.formatCents(r.remainingAmountCents), style: Sumi.figures(16)),
                  const Text('falta', style: Sumi.caption),
                ],
              ),
            ],
          ),
          if (tx.isInstallment && installments.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._buildInstallmentLines(tx, r, installments),
          ],
          if (r.payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final p in r.payments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('recebido em ${_dayMonth(p.paymentDate)}', style: Sumi.caption)),
                    Text('+ ${CurrencyUtils.formatCents(p.amountCents)}', style: Sumi.figures(12)),
                  ],
                ),
              ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.primary),
              onPressed: () => _showReceiveSheet(context, r, person.name, tx, installments.map((i) => i.amountCents)),
              child: Text(tx.isInstallment ? 'Receber parcela ou valor' : 'Marcar como recebido'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInstallmentLines(FinancialTransaction tx, Reimbursement r, List<Installment> installments) {
    final paid = r.paidAmountCents;
    var cumulative = 0;
    final lines = <Widget>[];
    for (final inst in installments) {
      cumulative += inst.amountCents;
      final isPaid = paid >= cumulative;
      final monthIndex = tx.purchaseDate.year * 12 + tx.purchaseDate.month - 1 + inst.installmentNumber - 1;
      final month = monthIndex % 12 + 1;
      final year = monthIndex ~/ 12;
      final isThisMonth = !_viewAllMonths && month == _selectedMonth && year == _selectedYear;
      final color = isPaid ? AppColors.textMuted : (isThisMonth ? AppColors.textPrimary : AppColors.textSecondary);
      final decoration = isPaid ? TextDecoration.lineThrough : null;

      lines.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isThisMonth && !isPaid ? AppColors.primary : Colors.transparent,
                border: Border.all(color: isThisMonth && !isPaid ? AppColors.primary : color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${inst.installmentNumber}/${inst.totalInstallments} · ${Sumi.shortMonth(month)} $year'
                '${isPaid ? ' · paga' : (isThisMonth ? ' · neste mês' : '')}',
                style: Sumi.caption.copyWith(
                  color: color,
                  decoration: decoration,
                  fontWeight: isThisMonth && !isPaid ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              CurrencyUtils.formatCents(inst.amountCents),
              style: Sumi.figures(12, color: color).copyWith(decoration: decoration),
            ),
          ],
        ),
      ));
    }
    return lines;
  }

  List<Widget> _buildReceived(BuildContext context, List<_ReceivedEntry> received) {
    final total = received.fold<int>(0, (acc, e) => acc + e.amountCents);
    return [
      Text(_viewAllMonths ? 'Total recebido' : 'Recebido referente a $_monthName', style: Sumi.label),
      const SizedBox(height: 4),
      Text(CurrencyUtils.formatCents(total), style: Sumi.figures(44)),
      const SizedBox(height: 4),
      Text('${received.length} recebimento${received.length == 1 ? '' : 's'}', style: Sumi.caption),
      const SizedBox(height: 24),
      if (received.isEmpty)
        LedgerLine(
          label: _viewAllMonths ? 'Nenhum recebimento ainda' : 'Nada recebido referente a $_monthName',
          value: '',
          detail: 'Quando alguém te pagar, registre em "A receber"',
          showBottomBorder: true,
        )
      else
        for (final e in received)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.person.name} · ${e.transaction.description}', style: Sumi.body),
                      const SizedBox(height: 2),
                      Text(
                        'referente a ${Sumi.shortMonth(e.referenceMonth)} ${e.referenceYear} · pago em ${_dayMonth(e.date)}'
                        '${e.payment?.notes?.isNotEmpty == true ? ' · ${e.payment!.notes}' : ''}',
                        style: Sumi.caption,
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: const Size(44, 36),
                        ),
                        onPressed: () => _confirmRevert(context, e),
                        child: const Text('Desfazer recebimento'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('+ ${CurrencyUtils.formatNoSymbol(e.amountCents / 100)}', style: Sumi.figures(16)),
              ],
            ),
          ),
    ];
  }

  Future<bool> _confirm(BuildContext context, String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(dCtx).pop(true), child: Text(action)),
        ],
      ),
    );
    return result == true;
  }

  void _toast(BuildContext context, String message) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmSettleMonth(BuildContext context, Person person, int amountCents) async {
    final ok = await _confirm(
      context,
      'Receber $_monthName de ${person.name}?',
      '${CurrencyUtils.formatCents(amountCents)} entram no seu saldo disponível.',
      'Receber',
    );
    if (!ok) return;
    await notifier.settleMonthReimbursementsForPerson(
      personId: person.id,
      month: _selectedMonth,
      year: _selectedYear,
      date: DateTime.now(),
    );
    if (context.mounted) _toast(context, 'Parcelas de $_monthName de ${person.name} recebidas.');
  }

  Future<void> _confirmSettleAll(BuildContext context, Person person, int amountCents) async {
    final ok = await _confirm(
      context,
      'Quitar tudo de ${person.name}?',
      'Todas as pendências (${CurrencyUtils.formatCents(amountCents)}) entram no seu saldo disponível.',
      'Quitar tudo',
    );
    if (!ok) return;
    await notifier.settleAllReimbursementsForPerson(personId: person.id, date: DateTime.now());
    if (context.mounted) _toast(context, 'Tudo de ${person.name} foi quitado.');
  }

  Future<void> _confirmRevert(BuildContext context, _ReceivedEntry e) async {
    final ok = await _confirm(
      context,
      'Desfazer recebimento?',
      '${CurrencyUtils.formatCents(e.amountCents)} de ${e.person.name} ("${e.transaction.description}") '
          'voltam para a lista de pendências e saem do seu saldo disponível.',
      'Desfazer',
    );
    if (!ok) return;
    await notifier.revertReimbursementPayment(reimbursementId: e.reimbursement.id, paymentId: e.payment?.id);
    if (context.mounted) _toast(context, 'Recebimento desfeito.');
  }

  void _showReceiveSheet(
    BuildContext context,
    Reimbursement r,
    String personName,
    FinancialTransaction tx,
    Iterable<int> installmentCents,
  ) {
    var suggestion = r.remainingAmountCents;
    if (tx.isInstallment) {
      var cumulative = 0;
      for (final cents in installmentCents) {
        cumulative += cents;
        if (r.paidAmountCents < cumulative) {
          suggestion = (cumulative - r.paidAmountCents).clamp(0, r.remainingAmountCents);
          break;
        }
      }
    }
    final amountCtrl = TextEditingController(text: CurrencyUtils.formatNoSymbol(suggestion / 100));
    var date = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receber de $personName', style: Sumi.bodyStrong.copyWith(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('${tx.description} · falta ${CurrencyUtils.formatCents(r.remainingAmountCents)}',
                      style: Sumi.caption),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyTextInputFormatter()],
                    style: Sumi.figures(28),
                    decoration: underlineDecoration('Valor recebido (R\$)'),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setSheet(() => date = picked);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.only(bottom: 8),
                      decoration:
                          const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderStrong))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Data do recebimento', style: Sumi.caption),
                                const SizedBox(height: 6),
                                Text(DateTimeUtils.formatDate(date), style: Sumi.body),
                              ],
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final cents = CurrencyUtils.parseCents(amountCtrl.text);
                        if (cents == null || cents <= 0) return;
                        notifier.receiveReimbursement(reimbursementId: r.id, amountCents: cents, date: date);
                        Navigator.of(ctx).pop();
                        _toast(context, 'Recebimento registrado no seu saldo.');
                      },
                      child: const Text('Confirmar recebimento'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceivedEntry {
  final Reimbursement reimbursement;
  final ReimbursementPayment? payment;
  final Person person;
  final FinancialTransaction transaction;
  final DateTime date;
  final int referenceMonth;
  final int referenceYear;
  final int amountCents;

  const _ReceivedEntry(
    this.reimbursement,
    this.payment,
    this.person,
    this.transaction,
    this.date,
    this.referenceMonth,
    this.referenceYear,
    this.amountCents,
  );
}
