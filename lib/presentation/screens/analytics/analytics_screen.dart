import 'package:flutter/material.dart' hide Category;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/transaction.dart';
import '../categories/categories_management_screen.dart';
import '../../state/financial_state_notifier.dart';

class AnalyticsScreen extends StatelessWidget {
  final FinancialStateNotifier notifier;

  const AnalyticsScreen({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final state = notifier.state;
    final categories = notifier.categories;
    final selectedMonth = notifier.selectedMonth;
    final selectedYear = notifier.selectedYear;

    final monthExpenses = state.transactions.where((t) {
      return t.type == TransactionType.expense &&
          !t.isForThirdParty &&
          t.purchaseDate.month == selectedMonth &&
          t.purchaseDate.year == selectedYear;
    }).toList();

    double totalSpent = 0.0;
    double pixTotal = 0.0;
    double cardTotal = 0.0;
    double cashTotal = 0.0;
    final Map<String, double> categorySums = {};

    for (final tx in monthExpenses) {
      final monthlyAmount = tx.totalInstallments > 1 ? (tx.netAmount / tx.totalInstallments) : tx.netAmount;
      totalSpent += monthlyAmount;
      if (tx.isPix) {
        pixTotal += monthlyAmount;
      } else if (tx.isCreditCard) {
        cardTotal += monthlyAmount;
      } else {
        cashTotal += monthlyAmount;
      }
      categorySums[tx.categoryId] = (categorySums[tx.categoryId] ?? 0.0) + monthlyAmount;
    }

    final sortedEntries = categorySums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise & Gráficos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Total do Mês
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Gasto no Mês', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyUtils.format(totalSpent),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Distribuição por Forma de Pagamento
            const Text('Formas de Pagamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentStatCard('Pix', pixTotal, totalSpent, AppColors.income, Icons.pix),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPaymentStatCard('Cartão', cardTotal, totalSpent, AppColors.committed, Icons.credit_card),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPaymentStatCard('Dinheiro', cashTotal, totalSpent, AppColors.reserve, Icons.attach_money),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Gastos por Categoria
            const Text('Gastos por Categoria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),

            if (sortedEntries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text('Nenhuma despesa registrada neste período.', style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ...sortedEntries.map((entry) {
                final cat = categories.firstWhere(
                  (c) => c.id == entry.key,
                  orElse: () => const Category(id: 'cat_other', name: 'Outros', icon: 'category', colorHex: '0xFF94A3B8'),
                );
                final percentage = totalSpent > 0 ? (entry.value / totalSpent) : 0.0;
                Color catColor;
                try {
                  catColor = Color(int.parse(cat.colorHex));
                } catch (_) {
                  catColor = AppColors.primary;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: catColor.withValues(alpha: 0.2),
                                child: Icon(CategoriesManagementScreen.getIconData(cat.icon), size: 14, color: catColor),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyUtils.format(entry.value),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: AppColors.background,
                          valueColor: AlwaysStoppedAnimation<Color>(catColor),
                          minHeight: 6,
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

  Widget _buildPaymentStatCard(String label, double amount, double total, Color color, IconData icon) {
    final pct = total > 0 ? (amount / total * 100).toStringAsFixed(0) : '0';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(CurrencyUtils.format(amount), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('$pct%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}
