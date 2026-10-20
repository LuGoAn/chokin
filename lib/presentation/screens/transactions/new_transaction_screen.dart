import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/money.dart';
import '../../../domain/engine/invoice_calculator.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/transaction.dart';
import '../../widgets/sumi_widgets.dart';
import '../categories/categories_management_screen.dart';
import '../invoices/invoices_screen.dart';
import '../../state/financial_state_notifier.dart';

class NewTransactionScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;
  final String? initialDescription;
  final double? initialAmount;
  final String? initialPaymentMethod;
  final String? initialSourceNotificationId;

  const NewTransactionScreen({
    super.key,
    required this.notifier,
    this.initialDescription,
    this.initialAmount,
    this.initialPaymentMethod,
    this.initialSourceNotificationId,
  });

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  static const _uuid = Uuid();

  late TransactionType _type;
  late TextEditingController _descController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late PaymentMethod _paymentMethod;
  late DateTime _selectedDate;
  late String _selectedCategoryId;
  String _selectedPersonId = 'ME';
  String? _selectedCardId;
  int _installments = 1;
  RecurrenceFrequency _recurrence = RecurrenceFrequency.none;

  static const _recurrenceOptions = [
    (RecurrenceFrequency.none, 'Não repete'),
    (RecurrenceFrequency.daily, 'Todo dia'),
    (RecurrenceFrequency.weekly, 'Toda semana'),
    (RecurrenceFrequency.biweekly, 'A cada 15 dias'),
    (RecurrenceFrequency.monthly, 'Todo mês'),
    (RecurrenceFrequency.yearly, 'Todo ano'),
  ];

  @override
  void initState() {
    super.initState();
    _type = TransactionType.expense;
    _descController = TextEditingController(text: widget.initialDescription ?? '');
    _amountController = TextEditingController(
      text: widget.initialAmount != null ? widget.initialAmount!.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _notesController = TextEditingController();

    _paymentMethod = PaymentMethod.values.where((m) => m.name == widget.initialPaymentMethod).firstOrNull ??
        PaymentMethod.creditCard;
    _selectedDate = DateTime.now();

    final expenseCategories = widget.notifier.categories.where((c) => c.isExpense).toList();
    _selectedCategoryId = expenseCategories.isNotEmpty ? expenseCategories.first.id : 'cat_other';

    final cards = widget.notifier.state.cards;
    _selectedCardId = cards.isNotEmpty ? cards.first.id : null;
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isExpense => _type == TransactionType.expense;
  bool get _isCard => _isExpense && _paymentMethod == PaymentMethod.creditCard;
  bool get _isForOther => _isExpense && _selectedPersonId != 'ME';

  void _saveTransaction() {
    final desc = _descController.text.trim();
    final amountCents = CurrencyUtils.parseCents(_amountController.text);

    if (amountCents == null || amountCents <= 0) {
      _warn('Informe um valor válido.');
      return;
    }
    if (desc.isEmpty) {
      _warn('Informe uma descrição.');
      return;
    }
    if (_isCard && _selectedCardId == null) {
      _warn('Cadastre ou selecione um cartão de crédito.');
      return;
    }
    if (_isForOther && !widget.notifier.state.people.any((p) => p.id == _selectedPersonId)) {
      _warn('Escolha quem vai pagar.');
      return;
    }

    final now = DateTime.now();
    final effectivePurchaseDate = DateUtils.isSameDay(_selectedDate, now)
        ? now
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute, now.second);

    final isRecurring = _recurrence != RecurrenceFrequency.none;
    final transaction = FinancialTransaction(
      id: _uuid.v4(),
      description: desc,
      amountCents: amountCents,
      purchaseDate: effectivePurchaseDate,
      categoryId: _selectedCategoryId,
      type: _type,
      paymentMethod: _isExpense ? _paymentMethod : PaymentMethod.pix,
      personId: _isExpense ? _selectedPersonId : 'ME',
      cardId: _isCard ? _selectedCardId : null,
      totalInstallments: _isCard ? _installments : 1,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      sourceNotificationId: widget.initialSourceNotificationId,
      isRecurring: isRecurring,
      recurrence: _recurrence,
      createdAt: now,
    );

    widget.notifier.addTransaction(transaction);
    Navigator.of(context).pop(true);
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _switchType(TransactionType newType) {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      final newCats = widget.notifier.categories
          .where((c) => newType == TransactionType.income ? c.isIncome : c.isExpense)
          .toList();
      if (newCats.isNotEmpty && !newCats.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = newCats.first.id;
      }
    });
  }

  String _dateLabel(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = DateUtils.dateOnly(date).difference(today).inDays;
    final dayMonth = '${date.day} ${Sumi.shortMonth(date.month)}';
    if (diff == 0) return 'Hoje, $dayMonth';
    if (diff == -1) return 'Ontem, $dayMonth';
    if (diff == 1) return 'Amanhã, $dayMonth';
    return DateTimeUtils.formatDate(date);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickRecurrence() async {
    final choice = await showModalBottomSheet<RecurrenceFrequency>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (freq, label) in _recurrenceOptions)
              ListTile(
                title: Text(label, style: Sumi.body),
                trailing: freq == _recurrence ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.of(ctx).pop(freq),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) setState(() => _recurrence = choice);
  }

  String? _installmentHint(CreditCard? card) {
    if (card == null) return null;
    final amountCents = CurrencyUtils.parseCents(_amountController.text) ?? 0;
    final period = InvoiceCalculator.getInvoicePeriodForPurchase(
      purchaseDate: _selectedDate,
      closingDay: card.closingDay,
    );
    final due = DateTimeUtils.calculateDueDate(period.year, period.month, card.dueDay);
    final dueText = '${due.day.toString().padLeft(2, '0')}/${due.month.toString().padLeft(2, '0')}';
    if (amountCents <= 0) return 'Entra na fatura que vence em $dueText';
    final first = Money.splitInstallments(amountCents, _installments).first;
    final prefix = _installments == 1 ? 'À vista' : '$_installments × ${CurrencyUtils.formatCents(first)} · 1ª parcela';
    return '$prefix na fatura que vence em $dueText';
  }

  Future<void> _addPerson() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova pessoa'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome (ex: Mãe, Ana)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(nameCtrl.text.trim()), child: const Text('Adicionar')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await widget.notifier.addPerson(name);
    if (!mounted) return;
    final others = widget.notifier.state.people.where((p) => !p.isMe).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setState(() {
      if (others.isNotEmpty) _selectedPersonId = others.last.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.notifier.categories.where((c) => _type == TransactionType.income ? c.isIncome : c.isExpense).toList();
    final people = widget.notifier.state.people.where((p) => !p.isMe).toList();
    final cards = widget.notifier.state.cards;
    final selectedCard = cards.where((c) => c.id == _selectedCardId).firstOrNull;
    final recurrenceLabel = _recurrenceOptions.firstWhere((o) => o.$1 == _recurrence).$2;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text('Novo lançamento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sumi.gutter, 8, Sumi.gutter, 24),
        children: [
          SegmentedChoice<TransactionType>(
            underline: true,
            options: const [(TransactionType.expense, 'Despesa'), (TransactionType.income, 'Receita')],
            value: _type,
            onChanged: _switchType,
          ),
          const SizedBox(height: 28),

          const Center(child: Text('Valor', style: Sumi.label)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('R\$', style: Sumi.figures(22, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              IntrinsicWidth(
                child: TextField(
                  controller: _amountController,
                  autofocus: widget.initialAmount == null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyTextInputFormatter()],
                  onChanged: (_) => setState(() {}),
                  textAlign: TextAlign.center,
                  style: Sumi.figures(52),
                  decoration: InputDecoration(
                    hintText: '0,00',
                    hintStyle: Sumi.figures(52, color: AppColors.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _descController,
            textCapitalization: TextCapitalization.sentences,
            style: Sumi.body.copyWith(fontSize: 15),
            decoration: underlineDecoration('Descrição', hint: 'Ex: Mercado, Uber, Almoço'),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(child: _TapField(label: 'Data', value: _dateLabel(_selectedDate), onTap: _pickDate)),
              const SizedBox(width: 16),
              Expanded(child: _TapField(label: 'Repetir', value: recurrenceLabel, onTap: _pickRecurrence)),
            ],
          ),
          const SizedBox(height: 24),

          const Text('Categoria', style: Sumi.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in categories)
                ChoiceChipSumi(
                  label: cat.name,
                  selected: cat.id == _selectedCategoryId,
                  onTap: () => setState(() => _selectedCategoryId = cat.id),
                ),
              ChoiceChipSumi(
                label: 'Gerenciar',
                selected: false,
                semanticLabel: 'Gerenciar categorias',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CategoriesManagementScreen(notifier: widget.notifier)),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),

          if (_isExpense) ...[
            const SizedBox(height: 24),
            const Text('Forma de pagamento', style: Sumi.caption),
            const SizedBox(height: 8),
            SegmentedChoice<PaymentMethod>(
              options: const [
                (PaymentMethod.pix, 'Pix'),
                (PaymentMethod.cash, 'Dinheiro/Débito'),
                (PaymentMethod.creditCard, 'Cartão'),
              ],
              value: _paymentMethod,
              onChanged: (m) => setState(() => _paymentMethod = m),
            ),
            if (_isCard) ...[
              const SizedBox(height: 20),
              if (cards.isEmpty)
                LedgerLine(
                  label: 'Nenhum cartão cadastrado',
                  value: '',
                  detail: 'Toque para cadastrar um cartão',
                  showBottomBorder: true,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => InvoicesScreen(notifier: widget.notifier)),
                    );
                    if (!mounted) return;
                    setState(() => _selectedCardId ??= widget.notifier.state.cards.firstOrNull?.id);
                  },
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cartão', style: Sumi.caption),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final card in cards)
                                ChoiceChipSumi(
                                  label: card.name,
                                  selected: card.id == _selectedCardId,
                                  onTap: () => setState(() => _selectedCardId = card.id),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _InstallmentStepper(
                      value: _installments,
                      onChanged: (n) => setState(() => _installments = n),
                    ),
                  ],
                ),
                if (_installmentHint(selectedCard) case final hint?) ...[
                  const SizedBox(height: 10),
                  Text(hint, style: Sumi.caption.copyWith(color: AppColors.textPrimary)),
                ],
              ],
            ],
            const SizedBox(height: 24),
            const Text('Quem vai pagar?', style: Sumi.caption),
            const SizedBox(height: 8),
            SegmentedChoice<bool>(
              options: const [(false, 'Eu'), (true, 'Outra pessoa')],
              value: _isForOther,
              onChanged: (other) => setState(() {
                _selectedPersonId = other ? (people.firstOrNull?.id ?? '') : 'ME';
              }),
            ),
            if (_isForOther) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in people)
                    ChoiceChipSumi(
                      label: p.name,
                      selected: p.id == _selectedPersonId,
                      onTap: () => setState(() => _selectedPersonId = p.id),
                    ),
                  ChoiceChipSumi(label: '+ Nova pessoa', selected: false, onTap: _addPerson),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Não entra no seu gasto pessoal: vira uma cobrança para a pessoa.',
                style: Sumi.caption,
              ),
            ],
          ],

          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            style: Sumi.body,
            decoration: underlineDecoration('Observação (opcional)'),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sumi.gutter, 12, Sumi.gutter, 12),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(onPressed: _saveTransaction, child: const Text('Confirmar lançamento')),
            ),
          ),
        ),
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TapField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderStrong))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(label, style: Sumi.caption),
              const SizedBox(height: 6),
              Text(value, style: Sumi.body.copyWith(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstallmentStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _InstallmentStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Parcelas', style: Sumi.caption),
        const SizedBox(height: 4),
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderStrong))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Menos parcelas',
                icon: const Icon(Icons.remove, size: 18),
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
              ),
              SizedBox(
                width: 36,
                child: Text('${value}x', textAlign: TextAlign.center, style: Sumi.figures(18)),
              ),
              IconButton(
                tooltip: 'Mais parcelas',
                icon: const Icon(Icons.add, size: 18),
                onPressed: value < 24 ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
