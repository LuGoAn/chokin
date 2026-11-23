import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../state/financial_state_notifier.dart';

void showBalanceDialog(BuildContext context, FinancialStateNotifier notifier) {
  final now = DateTime.now();
  final currentAvail = FinancialMovementEngine.calculateHistoricalBalance(
    state: notifier.state,
    month: now.month,
    year: now.year,
  );
  final saldoCtrl = TextEditingController(text: currentAvail.toStringAsFixed(2).replaceAll('.', ','));

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Definir Saldo Inicial', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: saldoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyTextInputFormatter()],
              decoration: const InputDecoration(labelText: 'Saldo disponível hoje (R\$)', prefixText: 'R\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final saldo = CurrencyUtils.parseCents(saldoCtrl.text) ?? 0;
              notifier.setInitialBalances(availableCents: saldo);
              notifier.dismissBalanceHint();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saldo atualizado! A diferença ficou registrada como ajuste.')),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      );
    },
  );
}
