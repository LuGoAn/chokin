import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/money.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/invoice.dart';
import '../../widgets/sumi_widgets.dart';
import '../../state/financial_state_notifier.dart';

class InvoicesScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const InvoicesScreen({super.key, required this.notifier});

  static const List<({String name, String hex})> cardColors = [
    (name: 'Roxo', hex: '0xFF820AD1'),
    (name: 'Laranja', hex: '0xFFFF7A00'),
    (name: 'Grafite', hex: '0xFF4B5563'),
    (name: 'Azul', hex: '0xFF2563EB'),
    (name: 'Vermelho', hex: '0xFFEF4444'),
    (name: 'Verde', hex: '0xFF10B981'),
    (name: 'Dourado', hex: '0xFFF59E0B'),
    (name: 'Ciano', hex: '0xFF06B6D4'),
    (name: 'Rosa', hex: '0xFFEC4899'),
    (name: 'Índigo', hex: '0xFF4338CA'),
  ];

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String? _selectedCardId;
  String? _selectedInvoiceId;

  FinancialStateNotifier get notifier => widget.notifier;

  static Color _cardColor(String? hex) {
    try {
      return Color(int.parse(hex ?? ''));
    } catch (_) {
      return const Color(0xFF820AD1);
    }
  }

  String _dayMonth(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _monthName(Invoice inv) => '${Sumi.shortMonth(inv.month)} ${inv.year}';

  Invoice? _currentInvoice(List<Invoice> cardInvoices) {
    final open = cardInvoices.where((i) => !i.isPaid && i.totalAmountCents > 0).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (open.isNotEmpty) return open.first;
    final sorted = List.of(cardInvoices)..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final now = DateTime.now();
    return sorted.where((i) => !i.dueDate.isAfter(now.add(const Duration(days: 40)))).firstOrNull ?? sorted.firstOrNull;
  }

  String _statusOf(Invoice inv) => invoiceStatusLabel(
        isPaid: inv.isPaid,
        amountCents: inv.totalAmountCents,
        closingDate: inv.closingDate,
        dueDate: inv.effectiveDueDate,
        month: inv.month,
        year: inv.year,
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final state = notifier.state;
        final cards = state.cards;
        final card = cards.where((c) => c.id == _selectedCardId).firstOrNull ?? cards.firstOrNull;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Faturas e cartões'),
            actions: [
              IconButton(
                tooltip: 'Novo cartão',
                icon: const Icon(Icons.add),
                onPressed: () => _showCardBottomSheet(context),
              ),
            ],
          ),
          body: card == null
              ? _buildEmpty(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Sumi.gutter, 4, Sumi.gutter, 32),
                  children: [
                    if (cards.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in cards) ...[
                              ChoiceChipSumi(
                                label: c.name,
                                selected: c.id == card.id,
                                onTap: () => setState(() {
                                  _selectedCardId = c.id;
                                  _selectedInvoiceId = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ..._buildCardContent(context, state, card),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sumi.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nenhum cartão cadastrado', style: Sumi.bodyStrong),
            const SizedBox(height: 6),
            const Text(
              'Cadastre seus cartões para acompanhar faturas, parcelas e o limite.',
              style: Sumi.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => _showCardBottomSheet(context), child: const Text('Cadastrar cartão')),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCardContent(BuildContext context, FinancialState state, CreditCard card) {
    final cardInvoices = state.invoices.where((i) => i.cardId == card.id).toList();
    final current = _currentInvoice(cardInvoices);
    final selected = cardInvoices.where((i) => i.id == _selectedInvoiceId).firstOrNull ?? current;
    final others = cardInvoices.where((i) => i.id != selected?.id && (i.isPaid || i.totalAmountCents > 0)).toList()
      ..sort((a, b) => (b.year * 12 + b.month).compareTo(a.year * 12 + a.month));

    final usedCents = FinancialMovementEngine.calculateCardUsedLimitCents(state: state, cardId: card.id);
    final limitCents = card.creditLimitCents ?? 0;

    return [
      Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _cardColor(card.colorHex), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(card.name, style: Sumi.bodyStrong.copyWith(fontSize: 20))),
          IconButton(
            tooltip: 'Editar cartão',
            icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
            onPressed: () => _showCardBottomSheet(context, existingCard: card),
          ),
        ],
      ),
      Text(
        '${card.flag ?? 'Crédito'} · fecha dia ${card.closingDay} · vence dia ${card.dueDay}',
        style: Sumi.caption,
      ),
      if (limitCents > 0) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Text('Limite usado', style: Sumi.label)),
            Text(
              '${CurrencyUtils.formatCents(usedCents)} de ${CurrencyUtils.formatCents(limitCents)}',
              style: Sumi.figures(14),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: (usedCents / limitCents).clamp(0.0, 1.0), minHeight: 3),
        ),
        const SizedBox(height: 4),
        Text('disponível: ${CurrencyUtils.formatCents(math.max(0, limitCents - usedCents))}', style: Sumi.caption),
      ],
      const SizedBox(height: 28),
      if (selected == null)
        const LedgerLine(
          label: 'Nenhuma fatura ainda',
          value: '',
          detail: 'As compras no cartão aparecem aqui, na fatura do mês',
          showBottomBorder: true,
        )
      else
        ..._buildInvoiceDetail(context, state, selected, isCurrent: selected.id == current?.id),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 32),
        const SectionTitle('Outras faturas'),
        const SizedBox(height: 4),
        for (final inv in others) _buildInvoiceRow(inv),
      ],
    ];
  }

  List<Widget> _buildInvoiceDetail(BuildContext context, FinancialState state, Invoice inv, {required bool isCurrent}) {
    final status = _statusOf(inv);
    final installments = state.installments.where((i) => i.invoiceId == inv.id).toList();
    final txById = {for (final t in state.transactions) t.id: t};
    installments.sort((a, b) {
      final da = txById[a.transactionId]?.purchaseDate ?? DateTime(2000);
      final db = txById[b.transactionId]?.purchaseDate ?? DateTime(2000);
      final byDate = db.compareTo(da);
      return byDate != 0 ? byDate : a.installmentNumber.compareTo(b.installmentNumber);
    });

    return [
      SectionTitle(
        'Fatura de ${_monthName(inv)}',
        trailing: isCurrent || _selectedInvoiceId == null
            ? null
            : TextButton(
                onPressed: () => setState(() => _selectedInvoiceId = null),
                child: const Text('Voltar para a atual'),
              ),
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyUtils.formatCents(inv.totalAmountCents),
                    style: Sumi.figures(40, color: inv.isPaid ? AppColors.textSecondary : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  inv.isPaid && inv.paidAt != null
                      ? 'paga em ${_dayMonth(inv.paidAt!)}'
                          '${inv.paidAmountCents != null && inv.paidAmountCents != inv.totalAmountCents ? ' · ${CurrencyUtils.formatCents(inv.paidAmountCents!)} pagos' : ''}'
                      : 'fecha ${_dayMonth(inv.closingDate)} · vence ${_dayMonth(inv.effectiveDueDate)}',
                  style: Sumi.caption,
                ),
              ],
            ),
          ),
          if (inv.isPaid)
            const HankoStamp(size: 60)
          else
            Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: status == 'VENCIDA' ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
        ],
      ),
      if (!inv.isPaid && inv.totalAmountCents > 0) ...[
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: () => _showPaymentSheet(context, inv), child: const Text('Pagar fatura')),
        ),
      ],
      const SizedBox(height: 24),
      const SectionTitle('Compras nesta fatura'),
      const SizedBox(height: 4),
      if (installments.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Nenhuma compra nesta fatura.', style: Sumi.caption),
        )
      else
        for (final inst in installments)
          Builder(builder: (context) {
            final tx = txById[inst.transactionId];
            final gross = tx == null
                ? inst.amountCents
                : Money.installmentAt(tx.amountCents, tx.totalInstallments, inst.installmentNumber);
            final person = inst.personId == null ? null : state.people.where((p) => p.id == inst.personId).firstOrNull;
            final details = [
              if (inst.totalInstallments > 1) 'parcela ${inst.installmentNumber}/${inst.totalInstallments}',
              if (tx != null) _dayMonth(tx.purchaseDate),
              if (person != null) 'para ${person.name}',
              if (gross > inst.amountCents) 'estornado ${CurrencyUtils.formatCents(gross - inst.amountCents)}',
            ];
            return Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx?.description ?? 'Compra', style: Sumi.body),
                        const SizedBox(height: 2),
                        Text(details.join(' · '), style: Sumi.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (gross > inst.amountCents)
                        Text(
                          CurrencyUtils.formatNoSymbol(Money.toReais(gross)),
                          style: Sumi.figures(12, color: AppColors.textSecondary).copyWith(
                              decoration: TextDecoration.lineThrough, decorationColor: AppColors.textSecondary),
                        ),
                      Text(
                        CurrencyUtils.formatNoSymbol(inst.amount),
                        style:
                            Sumi.figures(16, color: person != null ? AppColors.textSecondary : AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
    ];
  }

  Widget _buildInvoiceRow(Invoice inv) {
    final status = _statusOf(inv);
    return InkWell(
      onTap: () => setState(() => _selectedInvoiceId = inv.id),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            SizedBox(width: 84, child: Text(_monthName(inv), style: Sumi.body)),
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: status == 'VENCIDA' ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              CurrencyUtils.formatCents(inv.totalAmountCents),
              style: Sumi.figures(16, color: inv.isPaid ? AppColors.textSecondary : AppColors.textPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, Invoice inv) {
    var payDate = DateTime.now();
    var partial = false;
    final amountCtrl = TextEditingController(text: CurrencyUtils.formatNoSymbol(inv.totalAmount));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final amount = partial ? (CurrencyUtils.parseCents(amountCtrl.text) ?? 0) : inv.totalAmountCents;
          final available = math.max(0, notifier.state.availableCents);
          final fromReserve = amount - available;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pagar fatura de ${_monthName(inv)}', style: Sumi.bodyStrong.copyWith(fontSize: 18)),
                    const SizedBox(height: 16),
                    SegmentedChoice<bool>(
                      options: const [(false, 'Valor total'), (true, 'Outro valor')],
                      value: partial,
                      onChanged: (v) => setSheet(() => partial = v),
                    ),
                    const SizedBox(height: 16),
                    if (partial)
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyTextInputFormatter()],
                        onChanged: (_) => setSheet(() {}),
                        style: Sumi.figures(28),
                        decoration: underlineDecoration('Valor pago (R\$)'),
                      )
                    else
                      Text(CurrencyUtils.formatCents(inv.totalAmountCents), style: Sumi.figures(28)),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: payDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setSheet(() => payDate = picked);
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
                                  const Text('Data do pagamento', style: Sumi.caption),
                                  const SizedBox(height: 6),
                                  Text(DateTimeUtils.formatDate(payDate), style: Sumi.body),
                                ],
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    if (amount > 0 && fromReserve > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'O saldo disponível não cobre tudo: ${CurrencyUtils.formatCents(fromReserve)} sairão da Caixinha.',
                        style: Sumi.caption.copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: amount <= 0
                            ? null
                            : () {
                                notifier.payInvoice(inv.id, payDate, customAmountCents: partial ? amount : null);
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pagamento da fatura registrado.')),
                                );
                              },
                        child: const Text('Confirmar pagamento'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCardBottomSheet(BuildContext context, {CreditCard? existingCard}) {
    final isEditing = existingCard != null;
    final nameController = TextEditingController(text: existingCard?.name ?? '');
    final limitController = TextEditingController(
      text: existingCard?.creditLimitCents != null ? CurrencyUtils.formatNoSymbol(existingCard!.creditLimit!) : '',
    );
    var closingDay = existingCard?.closingDay ?? 1;
    var dueDay = existingCard?.dueDay ?? 8;
    var flag = existingCard?.flag ?? 'Mastercard';
    var selectedColorHex = existingCard?.colorHex ?? InvoicesScreen.cardColors.first.hex;
    const flags = ['Mastercard', 'Visa', 'Elo', 'American Express', 'Hipercard', 'Outro'];

    DropdownButtonFormField<int> dayField(String label, int value, ValueChanged<int> onChanged) {
      return DropdownButtonFormField<int>(
        value: value,
        dropdownColor: AppColors.surface,
        decoration: underlineDecoration(label),
        items: [
          for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Dia $d', style: Sumi.body)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEditing ? 'Editar cartão' : 'Novo cartão', style: Sumi.bodyStrong.copyWith(fontSize: 18)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      style: Sumi.body,
                      decoration: underlineDecoration('Nome do cartão', hint: 'Ex: Nubank, Inter, C6'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: flag,
                      dropdownColor: AppColors.surface,
                      decoration: underlineDecoration('Bandeira'),
                      items: [for (final f in flags) DropdownMenuItem(value: f, child: Text(f, style: Sumi.body))],
                      onChanged: (v) {
                        if (v != null) setSheet(() => flag = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: dayField('Fecha no dia', closingDay, (v) => setSheet(() => closingDay = v))),
                        const SizedBox(width: 16),
                        Expanded(child: dayField('Vence no dia', dueDay, (v) => setSheet(() => dueDay = v))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Compras até a véspera do fechamento entram na fatura do mês; a partir dele, na do mês seguinte.',
                      style: Sumi.caption,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyTextInputFormatter()],
                      style: Sumi.figures(18),
                      decoration: underlineDecoration('Limite (R\$)', hint: 'Ex: 5.000,00'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Cor', style: Sumi.caption),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in InvoicesScreen.cardColors)
                          Semantics(
                            button: true,
                            selected: c.hex == selectedColorHex,
                            label: c.name,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => setSheet(() => selectedColorHex = c.hex),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.hex == selectedColorHex ? AppColors.textPrimary : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(color: _cardColor(c.hex), shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Informe o nome do cartão.')),
                            );
                            return;
                          }
                          final updatedCard = CreditCard(
                            id: existingCard?.id ?? 'card_${const Uuid().v4()}',
                            name: name,
                            closingDay: closingDay,
                            dueDay: dueDay,
                            creditLimitCents: CurrencyUtils.parseCents(limitController.text),
                            flag: flag,
                            colorHex: selectedColorHex,
                          );
                          if (isEditing) {
                            await notifier.updateCreditCard(updatedCard);
                          } else {
                            await notifier.addCreditCard(updatedCard);
                            if (mounted) setState(() => _selectedCardId = updatedCard.id);
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Cartão atualizado.' : 'Cartão cadastrado.')),
                            );
                          }
                        },
                        child: Text(isEditing ? 'Salvar alterações' : 'Cadastrar cartão'),
                      ),
                    ),
                    if (isEditing && notifier.state.cards.length > 1) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Excluir cartão?'),
                                content: Text('O cartão "${existingCard.name}" será excluído.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(dCtx).pop(true),
                                    child: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await notifier.deleteCreditCard(existingCard.id);
                              if (mounted) setState(() => _selectedCardId = null);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            }
                          },
                          child: const Text('Excluir cartão'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
