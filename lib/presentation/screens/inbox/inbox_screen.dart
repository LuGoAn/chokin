import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/inbox_notification.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/parsers/nubank_csv_parser.dart';
import '../../widgets/sumi_widgets.dart';
import '../transactions/new_transaction_screen.dart';
import '../../state/financial_state_notifier.dart';

class InboxScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const InboxScreen({super.key, required this.notifier});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  static const _uuid = Uuid();

  final Map<String, String> _categoryChoice = {};

  FinancialStateNotifier get notifier => widget.notifier;

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  PaymentMethod _methodFor(InboxNotification item) {
    return PaymentMethod.values.where((m) => m.name == item.suggestedPaymentMethod).firstOrNull ??
        PaymentMethod.creditCard;
  }

  CreditCard? _cardFor(InboxNotification item) {
    final cards = notifier.state.cards;
    final appWord = item.appName.toLowerCase().split(' ').first;
    return cards.where((c) => appWord.isNotEmpty && c.name.toLowerCase().contains(appWord)).firstOrNull ??
        cards.firstOrNull;
  }

  String _defaultCategory() {
    final expense = notifier.categories.where((c) => c.isExpense).toList();
    return expense.isNotEmpty ? expense.first.id : 'cat_other';
  }

  String _timeLabel(DateTime t) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = DateUtils.dateOnly(t).difference(today).inDays;
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'hoje, $hm';
    if (diff == -1) return 'ontem, $hm';
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}, $hm';
  }

  Future<void> _sync() async {
    final count = await notifier.syncPendingNotifications();
    _toast(count > 0
        ? '$count nova${count > 1 ? 's' : ''} compra${count > 1 ? 's' : ''} lida${count > 1 ? 's' : ''}.'
        : 'Nenhuma notificação nova.');
  }

  Future<void> _confirm(InboxNotification item) async {
    final method = _methodFor(item);
    final card = method == PaymentMethod.creditCard ? _cardFor(item) : null;
    if (method == PaymentMethod.creditCard && card == null) {
      await _edit(item);
      return;
    }
    final transaction = FinancialTransaction(
      id: _uuid.v4(),
      description: item.parsedMerchant ?? item.rawTitle,
      amountCents: Money.fromReais(item.parsedAmount ?? 0),
      purchaseDate: item.eventTimestamp,
      categoryId: _categoryChoice[item.id] ?? _defaultCategory(),
      paymentMethod: method,
      cardId: card?.id,
      sourceNotificationId: item.id,
      createdAt: DateTime.now(),
    );
    await notifier.confirmInboxNotification(inboxId: item.id, transaction: transaction);
    _toast('"${transaction.description}" foi para o extrato.');
  }

  Future<void> _edit(InboxNotification item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewTransactionScreen(
          notifier: notifier,
          initialDescription: item.parsedMerchant ?? item.rawTitle,
          initialAmount: item.parsedAmount,
          initialPaymentMethod: item.suggestedPaymentMethod,
          initialSourceNotificationId: item.id,
        ),
      ),
    );
    if (result == true) await notifier.markInboxConfirmed(item.id);
  }

  Future<void> _pickCategory(InboxNotification item) async {
    final categories = notifier.categories.where((c) => c.isExpense).toList();
    final current = _categoryChoice[item.id] ?? _defaultCategory();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Categoria', style: Sumi.bodyStrong.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in categories)
                    ChoiceChipSumi(
                      label: cat.name,
                      selected: cat.id == current,
                      onTap: () => Navigator.of(ctx).pop(cat.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) setState(() => _categoryChoice[item.id] = chosen);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final inbox = notifier.inbox;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Caixa de entrada'),
            actions: [
              IconButton(
                  tooltip: 'Importar fatura (CSV)',
                  icon: const Icon(Icons.upload_file_outlined),
                  onPressed: _showImportSheet),
              IconButton(tooltip: 'Buscar notificações', icon: const Icon(Icons.sync), onPressed: _sync),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _sync,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Sumi.gutter, 4, Sumi.gutter, 32),
              children: [
                if (inbox.isEmpty) ...[
                  const SizedBox(height: 80),
                  const Center(child: Text('Nada para revisar', style: Sumi.bodyStrong)),
                  const SizedBox(height: 6),
                  const Text(
                    'As compras lidas das notificações do banco aparecem aqui. Puxe para baixo para buscar '
                    'ou importe a fatura do Nubank em CSV.',
                    style: Sumi.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: OutlinedButton(onPressed: _showImportSheet, child: const Text('Importar fatura (CSV)')),
                  ),
                ] else ...[
                  Text(
                    '${inbox.length} compra${inbox.length > 1 ? 's' : ''} para revisar. '
                    'Confirme para mandar ao extrato, ou edite antes.',
                    style: Sumi.caption,
                  ),
                  const SizedBox(height: 16),
                  for (final item in inbox) _buildItem(item),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(InboxNotification item) {
    final method = _methodFor(item);
    final card = method == PaymentMethod.creditCard ? _cardFor(item) : null;
    final categoryId = _categoryChoice[item.id] ?? _defaultCategory();
    final category = notifier.categories.where((c) => c.id == categoryId).firstOrNull;
    final methodLabel = switch (method) {
      PaymentMethod.pix => 'Pix',
      PaymentMethod.cash => 'Dinheiro/Débito',
      PaymentMethod.creditCard => card?.name ?? 'Cartão',
      PaymentMethod.other => 'Outro',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(Sumi.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.detectedSources.join(' + '), style: Sumi.caption)),
              Text(_timeLabel(item.eventTimestamp), style: Sumi.caption),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Text(item.parsedMerchant ?? item.rawTitle, style: Sumi.bodyStrong.copyWith(fontSize: 16))),
              const SizedBox(width: 12),
              if (item.parsedAmount != null) Text(CurrencyUtils.format(item.parsedAmount!), style: Sumi.figures(19)),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.rawText, style: Sumi.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (item.isDuplicate || item.isPossibleDuplicate) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.copy_all_outlined, size: 14, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.isDuplicate
                        ? 'Duas notificações da mesma compra foram juntadas aqui'
                        : 'Pode ser a mesma compra de outra notificação',
                    style: Sumi.caption.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChipSumi(
                label: category?.name ?? 'Categoria',
                selected: false,
                semanticLabel: 'Categoria: ${category?.name ?? 'nenhuma'}. Toque para trocar',
                onTap: () => _pickCategory(item),
              ),
              Text(methodLabel, style: Sumi.caption),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                onPressed: () async {
                  await notifier.ignoreInboxNotification(item.id);
                  _toast('Notificação ignorada.');
                },
                child: const Text('Ignorar'),
              ),
              const Spacer(),
              OutlinedButton(onPressed: () => _edit(item), child: const Text('Editar')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: item.parsedAmount == null ? null : () => _confirm(item),
                style: ElevatedButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImportSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Importar fatura (CSV)', style: Sumi.bodyStrong.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              const Text(
                'Os lançamentos da fatura do Nubank entram aqui para você revisar e confirmar um a um.',
                style: Sumi.caption,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _pickCsvFile();
                  },
                  child: const Text('Escolher arquivo .csv'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showPasteDialog();
                  },
                  child: const Text('Colar o conteúdo da fatura'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCsvFile() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }
      await _processCsv(content);
    } catch (e) {
      _toast('Não foi possível ler o arquivo: $e');
    }
  }

  void _showPasteDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Colar fatura (CSV)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cole o texto da fatura exportada (colunas date, title, amount):', style: Sumi.caption),
            const SizedBox(height: 10),
            TextField(
              controller: textCtrl,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: const InputDecoration(
                hintText: 'date,title,amount\n2026-09-24,Cantina Dona Amelia,"9,80"',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final text = textCtrl.text.trim();
              Navigator.of(ctx).pop();
              if (text.isNotEmpty) _processCsv(text);
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  Future<void> _processCsv(String content) async {
    final entries = NubankCsvParser.parseCsv(content);
    if (entries.isEmpty) {
      _toast('Nenhum lançamento válido encontrado no CSV.');
      return;
    }
    final notifications = NubankCsvParser.convertToInboxNotifications(entries: entries);
    final count = await notifier.importInboxNotifications(notifications);
    _toast('$count lançamento${count > 1 ? 's' : ''} da fatura importado${count > 1 ? 's' : ''}. Revise e confirme.');
  }
}
