import 'package:flutter/material.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/person.dart';
import '../../../domain/entities/transaction.dart';
import '../categories/categories_management_screen.dart';
import '../people/people_management_screen.dart';
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
  late String _selectedPersonId;
  String? _selectedCardId;
  int _installments = 1;
  bool _isRecurring = false;
  RecurrenceFrequency _recurrence = RecurrenceFrequency.monthly;

  @override
  void initState() {
    super.initState();
    _type = TransactionType.expense;
    _descController = TextEditingController(text: widget.initialDescription ?? '');
    _amountController = TextEditingController(
      text: widget.initialAmount != null ? widget.initialAmount!.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _notesController = TextEditingController();

    _paymentMethod = widget.initialPaymentMethod == 'pix' ? PaymentMethod.pix : PaymentMethod.creditCard;
    _selectedDate = DateTime.now();

    final categories = widget.notifier.categories;
    _selectedCategoryId = categories.isNotEmpty ? categories.first.id : 'cat_other';

    final people = widget.notifier.state.people;
    _selectedPersonId = people.isNotEmpty ? people.first.id : 'ME';

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

  String _recurrenceLabel(RecurrenceFrequency freq) {
    switch (freq) {
      case RecurrenceFrequency.daily:
        return 'Diária';
      case RecurrenceFrequency.weekly:
        return 'Semanal';
      case RecurrenceFrequency.biweekly:
        return 'Quinzenal';
      case RecurrenceFrequency.monthly:
        return 'Mensal';
      case RecurrenceFrequency.yearly:
        return 'Anual';
      case RecurrenceFrequency.none:
      default:
        return 'Única';
    }
  }

  void _saveTransaction() {
    final desc = _descController.text.trim();
    final amount = CurrencyUtils.parse(_amountController.text);

    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe uma descrição.')));
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }

    if (_paymentMethod == PaymentMethod.creditCard && _selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um cartão de crédito.')));
      return;
    }

    final now = DateTime.now();
    final effectivePurchaseDate = (_selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day)
        ? now
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute, now.second);

    final transaction = FinancialTransaction(
      id: _uuid.v4(),
      description: desc,
      amount: amount,
      purchaseDate: effectivePurchaseDate,
      categoryId: _selectedCategoryId,
      type: _type,
      paymentMethod: _type == TransactionType.income ? PaymentMethod.pix : _paymentMethod,
      personId: _selectedPersonId,
      cardId: _paymentMethod == PaymentMethod.creditCard ? _selectedCardId : null,
      totalInstallments: _paymentMethod == PaymentMethod.creditCard ? _installments : 1,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      sourceNotificationId: widget.initialSourceNotificationId,
      isRecurring: _isRecurring,
      recurrence: _isRecurring ? _recurrence : RecurrenceFrequency.none,
      createdAt: now,
    );

    widget.notifier.addTransaction(transaction);
    Navigator.of(context).pop(true);
  }

  void _switchType(TransactionType newType) {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      final newCats = widget.notifier.categories.where((c) => newType == TransactionType.income ? c.isIncome : c.isExpense).toList();
      if (newCats.isNotEmpty && !newCats.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = newCats.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.notifier.categories;
    final availableCategories = categories.where((c) => _type == TransactionType.income ? c.isIncome : c.isExpense).toList();
    final people = widget.notifier.state.people;
    final cards = widget.notifier.state.cards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Transação', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tipo (Despesa / Receita)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _switchType(TransactionType.expense),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == TransactionType.expense ? AppColors.expense.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text(
                            'Despesa',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _type == TransactionType.expense ? AppColors.expense : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _switchType(TransactionType.income),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == TransactionType.income ? AppColors.income.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text(
                            'Receita',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _type == TransactionType.income ? AppColors.income : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Valor
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyTextInputFormatter()],
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                prefixText: 'R\$ ',
                prefixStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Descrição
            TextField(
              controller: _descController,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: Amazon, Mercado, Almoço...',
                suffixIcon: _descController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _descController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // 4. Data
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Data: ${DateTimeUtils.formatDate(_selectedDate)}', style: const TextStyle(color: AppColors.textPrimary)),
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Categoria (Filtrada por Tipo)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _type == TransactionType.income ? 'Categoria de Receita' : 'Categoria de Despesa',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CategoriesManagementScreen(notifier: widget.notifier)),
                    );
                    setState(() {});
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  child: const Text('+ Gerenciar', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: availableCategories.any((c) => c.id == _selectedCategoryId)
                  ? _selectedCategoryId
                  : (availableCategories.isNotEmpty ? availableCategories.first.id : null),
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: availableCategories.map((Category cat) {
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
                if (val != null) setState(() => _selectedCategoryId = val);
              },
            ),
            const SizedBox(height: 16),

            // Se for despesa, exibe forma de pagamento, parcelas e terceiro
            if (_type == TransactionType.expense) ...[
              // Forma de pagamento
              const Text('Forma de Pagamento', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPaymentChip(PaymentMethod.pix, 'Pix (Imediato)', Icons.pix),
                  const SizedBox(width: 8),
                  _buildPaymentChip(PaymentMethod.creditCard, 'Cartão de Crédito', Icons.credit_card),
                  const SizedBox(width: 8),
                  _buildPaymentChip(PaymentMethod.cash, 'Dinheiro', Icons.attach_money),
                ],
              ),
              const SizedBox(height: 16),

              // Seletor de Cartão & Parcelas
              if (_paymentMethod == PaymentMethod.creditCard) ...[
                if (cards.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedCardId ?? cards.first.id,
                    dropdownColor: AppColors.surface,
                    decoration: const InputDecoration(labelText: 'Cartão'),
                    items: cards.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(color: AppColors.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCardId = val),
                  ),
                  const SizedBox(height: 16),
                ],

                // Parcelamento
                DropdownButtonFormField<int>(
                  value: _installments,
                  dropdownColor: AppColors.surface,
                  decoration: const InputDecoration(labelText: 'Parcelas'),
                  items: List.generate(24, (i) => i + 1).map((n) {
                    final amountVal = CurrencyUtils.parse(_amountController.text) ?? 0.0;
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
                    if (val != null) setState(() => _installments = val);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Quem vai pagar? (Gastos para Terceiros)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quem vai pagar? (Responsável)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _showAddPersonDialog,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        child: const Text('+ Nova', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PeopleManagementScreen(notifier: widget.notifier),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        child: const Text('Gerenciar', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedPersonId,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Responsável'),
                items: people.map((p) {
                  return DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      p.isMe ? 'Eu (Gasto Pessoal)' : '${p.name} (Gerar Reembolso)',
                      style: TextStyle(
                        color: p.isMe ? AppColors.textPrimary : AppColors.reimbursement,
                        fontWeight: p.isMe ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPersonId = val);
                },
              ),
              const SizedBox(height: 16),
            ],

            // Recorrência (Diária, Semanal, Mensal, Anual, etc.)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _isRecurring ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.repeat, color: _isRecurring ? AppColors.primary : AppColors.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _type == TransactionType.income ? 'Receita Recorrente?' : 'Despesa Recorrente?',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              ),
                              Text(
                                _isRecurring ? 'Repete automaticamente (${_recurrenceLabel(_recurrence)})' : 'Lançamento único',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isRecurring,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _isRecurring = val),
                      ),
                    ],
                  ),
                  if (_isRecurring) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RecurrenceFrequency>(
                      value: _recurrence,
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(
                        labelText: 'Frequência da Recorrência',
                        prefixIcon: Icon(Icons.schedule, size: 18, color: AppColors.primary),
                      ),
                      items: const [
                        DropdownMenuItem(value: RecurrenceFrequency.daily, child: Text('Todo dia (Diária)', style: TextStyle(color: AppColors.textPrimary))),
                        DropdownMenuItem(value: RecurrenceFrequency.weekly, child: Text('Toda semana (Semanal)', style: TextStyle(color: AppColors.textPrimary))),
                        DropdownMenuItem(value: RecurrenceFrequency.biweekly, child: Text('A cada 15 dias (Quinzenal)', style: TextStyle(color: AppColors.textPrimary))),
                        DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Todo mês (Mensal)', style: TextStyle(color: AppColors.textPrimary))),
                        DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text('Todo ano (Anual)', style: TextStyle(color: AppColors.textPrimary))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _recurrence = val);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Observações
            TextField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observação (Opcional)',
              ),
            ),
            const SizedBox(height: 24),

            // Botão Salvar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveTransaction,
                child: const Text('Confirmar Lançamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChip(PaymentMethod method, String label, IconData icon) {
    final isSelected = _paymentMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPersonDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Cadastrar Pessoa', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome (ex: Mãe, Namorada)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  widget.notifier.addPerson(name);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }
}
