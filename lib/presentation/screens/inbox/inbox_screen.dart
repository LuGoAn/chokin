import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/parsers/nubank_csv_parser.dart';
import '../transactions/new_transaction_screen.dart';
import '../../state/financial_state_notifier.dart';

class InboxScreen extends StatelessWidget {
  final FinancialStateNotifier notifier;

  const InboxScreen({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final inbox = notifier.inbox;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novas Movimentações (Inbox)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Importar Fatura (CSV)',
            icon: const Icon(Icons.file_upload_outlined, color: AppColors.primary),
            onPressed: () => _showImportCsvModal(context),
          ),
          IconButton(
            tooltip: 'Sincronizar Notificações',
            icon: const Icon(Icons.sync, color: AppColors.primary),
            onPressed: () async {
              final count = await notifier.syncPendingNotifications();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      count > 0
                          ? '$count nova(s) notificação(ões) financeira(s) importada(s)!'
                          : 'Nenhuma nova notificação financeira pendente.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final count = await notifier.syncPendingNotifications();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  count > 0
                      ? '$count nova(s) notificação(ões) importada(s)!'
                      : 'Nenhuma nova notificação financeira encontrada.',
                ),
              ),
            );
          }
        },
        child: inbox.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Caixa de entrada limpa!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Apenas compras e transações reais aparecerão aqui. Puxe para baixo para sincronizar ou importe sua fatura.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _showImportCsvModal(context),
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('Importar Fatura (CSV)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inbox.length,
              itemBuilder: (ctx, index) {
                final item = inbox[index];
                final isDuplicate = item.isDuplicate;
                final isPossibleDup = item.isPossibleDuplicate;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDuplicate ? AppColors.warning : AppColors.border,
                      width: isDuplicate ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header com Apps Detectados e Alerta de Duplicidade
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ...item.detectedSources.map((src) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    src,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                  ),
                                );
                              }),
                            ],
                          ),
                          Text(
                            DateTimeUtils.formatDateTime(item.eventTimestamp),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Alerta de Duplicidade
                      if (isDuplicate || isPossibleDup) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                isDuplicate ? '⚠️ Possível Duplicidade Detectada (Agrupado)' : 'Possível compra duplicada',
                                style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Estabelecimento e Valor
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.parsedMerchant ?? item.rawTitle,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ),
                          if (item.parsedAmount != null)
                            Text(
                              CurrencyUtils.format(item.parsedAmount!),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Texto original da notificação
                      Text(
                        item.rawText,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),

                      // Ações
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                notifier.ignoreInboxNotification(item.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notificação ignorada.')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('Ignorar', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (ctx) => NewTransactionScreen(
                                      notifier: notifier,
                                      initialDescription: item.parsedMerchant ?? item.rawTitle,
                                      initialAmount: item.parsedAmount,
                                      initialPaymentMethod: item.suggestedPaymentMethod,
                                      initialSourceNotificationId: item.id,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  notifier.ignoreInboxNotification(item.id);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('Editar e Adicionar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }

  Future<void> _showImportCsvModal(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.file_upload_outlined, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text('Importar Fatura (CSV)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Importe os lançamentos da fatura do Nubank para revisar, categorizar e confirmar individualmente antes de salvar.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _pickAndProcessCsvFile(context);
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Selecionar Arquivo .CSV do Celular'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showPasteCsvDialog(context);
                  },
                  icon: const Icon(Icons.paste),
                  label: const Text('Colar Conteúdo da Fatura Manualmente'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndProcessCsvFile(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      await _processCsvContent(context, content);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ler arquivo: $e')),
        );
      }
    }
  }

  void _showPasteCsvDialog(BuildContext context) {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Colar Fatura (CSV)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole o texto da fatura exportada (colunas date, title, amount):',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textCtrl,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: const InputDecoration(
                hintText: 'date,title,amount\n2026-09-24,Cantina Dona Amelia,"9,80"\n2026-09-01,Aliexpress - Parcela 2/4,"75,71"',
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
              if (text.isNotEmpty) {
                _processCsvContent(context, text);
              }
            },
            child: const Text('Processar'),
          ),
        ],
      ),
    );
  }

  Future<void> _processCsvContent(BuildContext context, String content) async {
    final entries = NubankCsvParser.parseCsv(content);
    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum lançamento válido encontrado no CSV da fatura.')),
        );
      }
      return;
    }

    final notifications = NubankCsvParser.convertToInboxNotifications(entries: entries);
    final count = await notifier.importInboxNotifications(notifications);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count lançamentos da fatura importados para o Inbox! Revise e confirme cada um.'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }
}
