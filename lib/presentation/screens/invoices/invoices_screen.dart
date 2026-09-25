import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/person.dart';
import '../../../domain/entities/transaction.dart';
import '../../state/financial_state_notifier.dart';

class InvoicesScreen extends StatelessWidget {
  final FinancialStateNotifier notifier;

  const InvoicesScreen({super.key, required this.notifier});

  static const List<Map<String, dynamic>> cardColors = [
    {'name': 'Roxo Nubank', 'hex': '0xFF820AD1', 'color': Color(0xFF820AD1)},
    {'name': 'Laranja Inter', 'hex': '0xFFFF7A00', 'color': Color(0xFFFF7A00)},
    {'name': 'Black / Carbon', 'hex': '0xFF1E293B', 'color': Color(0xFF1E293B)},
    {'name': 'Azul Royal', 'hex': '0xFF2563EB', 'color': Color(0xFF2563EB)},
    {'name': 'Vermelho Santander', 'hex': '0xFFEF4444', 'color': Color(0xFFEF4444)},
    {'name': 'Verde Esmeralda', 'hex': '0xFF10B981', 'color': Color(0xFF10B981)},
    {'name': 'Amarelo Ouro', 'hex': '0xFFF59E0B', 'color': Color(0xFFF59E0B)},
    {'name': 'Ciano Neon', 'hex': '0xFF06B6D4', 'color': Color(0xFF06B6D4)},
    {'name': 'Rosa Magenta', 'hex': '0xFFEC4899', 'color': Color(0xFFEC4899)},
    {'name': 'Índigo Deep', 'hex': '0xFF4338CA', 'color': Color(0xFF4338CA)},
  ];

  Color _parseCardColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF820AD1);
    try {
      return Color(int.parse(hex));
    } catch (_) {
      return const Color(0xFF820AD1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = notifier.state;
    final cards = state.cards;
    final invoices = List<Invoice>.from(state.invoices);
    invoices.sort((a, b) => b.closingDate.compareTo(a.closingDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões & Faturas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Adicionar Cartão',
            icon: const Icon(Icons.add_card, color: AppColors.primary),
            onPressed: () => _showCardBottomSheet(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Meus Cartões (${cards.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                TextButton.icon(
                  onPressed: () => _showCardBottomSheet(context),
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: const Text('Novo Cartão', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (cards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.credit_card_off, size: 40, color: AppColors.textMuted),
                      SizedBox(height: 10),
                      Text('Nenhum cartão cadastrado.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Toque em "Novo Cartão" para adicionar.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              ...cards.map((c) {
                final baseColor = _parseCardColor(c.colorHex);
                final darkColor = HSLColor.fromColor(baseColor)
                    .withLightness((HSLColor.fromColor(baseColor).lightness * 0.6).clamp(0.0, 1.0))
                    .toColor();

                // Faturas deste cartão específico
                final cardInvoices = invoices.where((i) => i.cardId == c.id).toList();
                final totalUsed = FinancialMovementEngine.calculateCardUsedLimit(
                  state: state,
                  cardId: c.id,
                );
                final hasLimit = c.creditLimit != null && c.creditLimit! > 0;
                final limitProgress = hasLimit ? (totalUsed / c.creditLimit!).clamp(0.0, 1.0) : 0.0;

                // Fatura em aberto mais próxima
                final openInvoices = cardInvoices.where((i) => !i.isPaid).toList();
                openInvoices.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                final currentOpenInvoice = openInvoices.isNotEmpty ? openInvoices.first : null;

                // Outras faturas (histórico pago e faturas futuras com saldo)
                final otherInvoices = cardInvoices.where((i) => i.id != currentOpenInvoice?.id && (i.isPaid || i.totalAmount > 0)).toList();
                otherInvoices.sort((a, b) => b.dueDate.compareTo(a.dueDate));

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: baseColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Cabeçalho do Cartão com Gradiente e Limite
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [baseColor, darkColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.credit_card, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      c.name,
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        c.flag ?? 'Crédito',
                                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                                      tooltip: 'Editar Cartão',
                                      onPressed: () => _showCardBottomSheet(context, existingCard: c),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Fechamento', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    Text('Dia ${c.closingDay}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Vencimento', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    Text('Dia ${c.dueDay} (útil)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                if (hasLimit)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Uso do Limite', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                      Text(
                                        '${CurrencyUtils.format(totalUsed)} / ${CurrencyUtils.format(c.creditLimit!)}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (hasLimit) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: limitProgress,
                                  minHeight: 5,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 2. Fatura Aberta do Mês Atual em Destaque
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.receipt_long, size: 16, color: AppColors.primaryLight),
                                SizedBox(width: 6),
                                Text(
                                  'Fatura Atual em Aberto',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (currentOpenInvoice != null)
                              _buildInvoiceCard(context, state, currentOpenInvoice, isHighlighted: true)
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: AppColors.income, size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Nenhuma fatura em aberto no momento para este cartão.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // 3. Acordeão Expansível para Outros Meses (Histórico / Futuras)
                            if (otherInvoices.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: ExpansionTile(
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                  leading: const Icon(Icons.history_toggle_off, color: AppColors.textSecondary, size: 20),
                                  title: Text(
                                    'Ver Outros Meses (${otherInvoices.length} faturas)',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  subtitle: const Text(
                                    'Histórico de faturas pagas e parcelas futuras',
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                      child: Column(
                                        children: otherInvoices.map((inv) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: _buildInvoiceCard(context, state, inv, isHighlighted: false),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
    );
  }

  Widget _buildInvoiceCard(BuildContext context, FinancialState state, Invoice inv, {required bool isHighlighted}) {
    final isPaid = inv.isPaid;
    final installments = state.installments.where((i) => i.invoiceId == inv.id).toList();
    installments.sort((a, b) {
      final txA = state.transactions.firstWhere(
        (t) => t.id == a.transactionId,
        orElse: () => FinancialTransaction(id: '', description: '', amount: 0, purchaseDate: DateTime(2000), categoryId: '', paymentMethod: PaymentMethod.creditCard),
      );
      final txB = state.transactions.firstWhere(
        (t) => t.id == b.transactionId,
        orElse: () => FinancialTransaction(id: '', description: '', amount: 0, purchaseDate: DateTime(2000), categoryId: '', paymentMethod: PaymentMethod.creditCard),
      );

      // 1. Data da compra: mais recente no topo (ordem decrescente)
      final dateCmp = txB.purchaseDate.compareTo(txA.purchaseDate);
      if (dateCmp != 0) return dateCmp;

      // 2. Data/hora de inclusão: mais recente no topo
      final createdCmp = txB.effectiveCreatedAt.compareTo(txA.effectiveCreatedAt);
      if (createdCmp != 0) return createdCmp;

      // 3. Ordem na lista de transações: inserido por último fica mais no topo
      final idxA = state.transactions.indexOf(txA);
      final idxB = state.transactions.indexOf(txB);
      final idxCmp = idxB.compareTo(idxA);
      if (idxCmp != 0) return idxCmp;

      return a.installmentNumber.compareTo(b.installmentNumber);
    });

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.surface : AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? (isPaid ? AppColors.income : AppColors.committed).withValues(alpha: 0.5)
              : AppColors.border,
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateTimeUtils.formatMonthYear(inv.dueDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                Text(
                  'Vence dia ${DateTimeUtils.formatDate(inv.effectiveDueDate)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyUtils.format(inv.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isPaid ? AppColors.income : AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isPaid ? AppColors.income.withValues(alpha: 0.15) : AppColors.committed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPaid ? 'PAGA' : 'EM ABERTO',
                    style: TextStyle(
                      color: isPaid ? AppColors.income : AppColors.committed,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: AppColors.border),
                const SizedBox(height: 4),
                const Text('Lançamentos da Fatura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                if (installments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Nenhum lançamento nesta fatura.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  )
                else
                  ...installments.map((inst) {
                    final tx = state.transactions.firstWhere(
                      (t) => t.id == inst.transactionId,
                      orElse: () => FinancialTransaction(
                        id: '',
                        description: 'Compra',
                        amount: 0,
                        purchaseDate: DateTime.now(),
                        categoryId: 'cat_other',
                        paymentMethod: PaymentMethod.creditCard,
                      ),
                    );
                    final person = inst.personId != null
                        ? state.people.firstWhere(
                            (p) => p.id == inst.personId,
                            orElse: () => state.people.isNotEmpty
                                ? state.people.first
                                : Person(id: 'ME', name: 'Eu', createdAt: DateTime.now()),
                          )
                        : null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tx.description, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Parcela ${inst.installmentNumber}/${inst.totalInstallments} • ${DateTimeUtils.formatDate(tx.purchaseDate)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                    if (person != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.reimbursement.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(person.name, style: const TextStyle(color: AppColors.reimbursement, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    if (tx.isRefunded)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: (tx.isFullyRefunded ? AppColors.income : AppColors.primary).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tx.isFullyRefunded
                                              ? 'ESTORNADO (${tx.refundMethod == PaymentMethod.pix ? "PIX" : "FATURA"})'
                                              : 'ESTORNO PARCIAL (-${CurrencyUtils.format(tx.refundAmount)})',
                                          style: TextStyle(
                                            color: tx.isFullyRefunded ? AppColors.income : AppColors.primaryLight,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (tx.isFullyRefunded) ...[
                                Text(
                                  CurrencyUtils.format(tx.amount / (tx.totalInstallments > 0 ? tx.totalInstallments : 1)),
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                                const Text(
                                  'R\$ 0,00',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMuted),
                                ),
                              ] else ...[
                                Text(
                                  CurrencyUtils.format(inst.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                if (!isPaid)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPaymentDialog(context, inv),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Registrar Pagamento da Fatura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.income,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.income.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Fatura paga em ${inv.paidAt != null ? DateTimeUtils.formatDate(inv.paidAt!) : "Data registrada"}',
                        style: const TextStyle(color: AppColors.income, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCardBottomSheet(BuildContext context, {CreditCard? existingCard}) {
    final isEditing = existingCard != null;
    final nameController = TextEditingController(text: existingCard?.name ?? '');
    final limitController = TextEditingController(text: existingCard?.creditLimit != null ? existingCard!.creditLimit!.toStringAsFixed(2) : '');
    int closingDay = existingCard?.closingDay ?? 1;
    int dueDay = existingCard?.dueDay ?? 8;
    String flag = existingCard?.flag ?? 'Mastercard';
    String selectedColorHex = existingCard?.colorHex ?? '0xFF820AD1';

    final flags = ['Mastercard', 'Visa', 'Elo', 'American Express', 'Hipercard', 'Outro'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentColor = _parseCardColor(selectedColorHex);

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
                        Text(
                          isEditing ? 'Editar Cartão' : 'Novo Cartão de Crédito',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Preview Visual do Cartão
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            currentColor,
                            HSLColor.fromColor(currentColor).withLightness((HSLColor.fromColor(currentColor).lightness * 0.6).clamp(0.0, 1.0)).toColor(),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: currentColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                nameController.text.isEmpty ? 'Nome do Cartão' : nameController.text,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(flag, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Fecha dia $closingDay', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('Vence dia $dueDay (útil)', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Nome do Cartão
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nome do Cartão',
                        hintText: 'Ex: Inter Black, C6 Carbon, Nubank...',
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                    const SizedBox(height: 14),

                    // Bandeira
                    DropdownButtonFormField<String>(
                      value: flag,
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(labelText: 'Bandeira'),
                      items: flags.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(color: AppColors.textPrimary)))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => flag = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Dias de Fechamento e Vencimento
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: closingDay,
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(labelText: 'Dia Fechamento'),
                            items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('Dia $d', style: const TextStyle(color: AppColors.textPrimary)))).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => closingDay = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: dueDay,
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(labelText: 'Dia Vencimento'),
                            items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('Dia $d', style: const TextStyle(color: AppColors.textPrimary)))).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => dueDay = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Limite de Crédito
                    TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyTextInputFormatter()],
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Limite de Crédito (R\$)',
                        prefixText: 'R\$ ',
                        hintText: 'Ex: 5.000,00',
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Paleta de Cores
                    const Text('Cor do Cartão', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: cardColors.map((colorItem) {
                        final hex = colorItem['hex'] as String;
                        final color = colorItem['color'] as Color;
                        final isSelected = selectedColorHex == hex;

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedColorHex = hex),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Botão Salvar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor, informe o nome do cartão.')),
                            );
                            return;
                          }

                          final limit = CurrencyUtils.parse(limitController.text);
                          final cardId = existingCard?.id ?? 'card_${const Uuid().v4()}';

                          final updatedCard = CreditCard(
                            id: cardId,
                            name: name,
                            closingDay: closingDay,
                            dueDay: dueDay,
                            creditLimit: limit,
                            flag: flag,
                            colorHex: selectedColorHex,
                          );

                          if (isEditing) {
                            await notifier.updateCreditCard(updatedCard);
                          } else {
                            await notifier.addCreditCard(updatedCard);
                          }

                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Cartão atualizado com sucesso!' : 'Cartão cadastrado com sucesso!')),
                            );
                          }
                        },
                        child: Text(isEditing ? 'Salvar Alterações' : 'Cadastrar Cartão'),
                      ),
                    ),

                    if (isEditing && notifier.state.cards.length > 1) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Excluir Cartão'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: const Text('Excluir Cartão', style: TextStyle(color: AppColors.textPrimary)),
                                content: Text('Tem certeza que deseja excluir o cartão "${existingCard.name}"?', style: const TextStyle(color: AppColors.textSecondary)),
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
                              await notifier.deleteCreditCard(existingCard.id);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Cartão excluído com sucesso!')),
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

  void _showPaymentDialog(BuildContext context, Invoice inv) {
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Quitar Fatura', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Valor: ${CurrencyUtils.format(inv.totalAmount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.income)),
                  const SizedBox(height: 12),
                  const Text('Selecione a data real do pagamento:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                        setStateDialog(() => selectedDate = picked);
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
                        notifier.payInvoice(inv.id, selectedDate);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pagamento de fatura registrado!')),
                        );
                      },
                      child: const Text('Confirmar Pagamento'),
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
}
