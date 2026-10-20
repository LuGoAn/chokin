import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/transaction.dart';
import '../../widgets/sumi_widgets.dart';
import '../../state/financial_state_notifier.dart';

class AnalyticsScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const AnalyticsScreen({super.key, required this.notifier});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late int _month = widget.notifier.selectedMonth;
  late int _year = widget.notifier.selectedYear;

  int _shareInMonth(FinancialTransaction t) {
    if (t.type != TransactionType.expense || t.isForThirdParty || t.isCancelled) return 0;
    final inMonth = t.purchaseDate.month == _month && t.purchaseDate.year == _year;
    if (!t.isCreditCard || t.totalInstallments <= 1) return inMonth ? t.netAmountCents : 0;
    final diff = (_year * 12 + _month - 1) - (t.purchaseDate.year * 12 + t.purchaseDate.month - 1);
    if (diff < 0 || diff >= t.totalInstallments) return 0;
    return Money.installmentAt(t.netAmountCents, t.totalInstallments, diff + 1);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        final state = widget.notifier.state;
        final categories = widget.notifier.categories;

        var total = 0;
        var thirdParty = 0;
        final byMethod = <String, int>{'Pix': 0, 'Cartão': 0, 'Dinheiro/Débito': 0};
        final byCategory = <String, int>{};

        for (final t in state.transactions) {
          if (t.type == TransactionType.expense && t.isForThirdParty) {
            final asPersonal = t.copyWith(personId: 'ME');
            thirdParty += _shareInMonth(asPersonal);
            continue;
          }
          final share = _shareInMonth(t);
          if (share <= 0) continue;
          total += share;
          final method = t.isPix ? 'Pix' : (t.isCreditCard ? 'Cartão' : 'Dinheiro/Débito');
          byMethod[method] = byMethod[method]! + share;
          byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + share;
        }

        final methods = byMethod.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
        final cats = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final monthName = DateTimeUtils.formatMonthYear(DateTime(_year, _month)).split(' ').first.toLowerCase();

        return Scaffold(
          appBar: AppBar(title: const Text('Análise')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 32),
            children: [
              MonthStrip(
                  month: _month,
                  year: _year,
                  onChanged: (m, y) => setState(() {
                        _month = m;
                        _year = y;
                      })),
              const SizedBox(height: 28),
              Text('Gasto pessoal em $monthName', style: Sumi.label),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(CurrencyUtils.formatCents(total), style: Sumi.figures(44)),
              ),
              if (thirdParty > 0) ...[
                const SizedBox(height: 4),
                Text('fora daqui: ${CurrencyUtils.formatCents(thirdParty)} em compras para outras pessoas',
                    style: Sumi.caption),
              ],
              const SizedBox(height: 32),
              const SectionTitle('Por forma de pagamento'),
              const SizedBox(height: 8),
              if (methods.isEmpty)
                const _EmptyLine()
              else
                for (final e in methods) _ShareBar(label: e.key, cents: e.value, total: total),
              const SizedBox(height: 32),
              const SectionTitle('Por categoria'),
              const SizedBox(height: 8),
              if (cats.isEmpty)
                const _EmptyLine()
              else
                for (final e in cats)
                  _ShareBar(
                    label: categories.where((c) => c.id == e.key).firstOrNull?.name ?? 'Outros',
                    cents: e.value,
                    total: total,
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text('Nenhum gasto pessoal neste mês.', style: Sumi.caption),
    );
  }
}

class _ShareBar extends StatelessWidget {
  final String label;
  final int cents;
  final int total;

  const _ShareBar({required this.label, required this.cents, required this.total});

  @override
  Widget build(BuildContext context) {
    final share = total > 0 ? cents / total : 0.0;
    final pct = (share * 100).round();
    return Semantics(
      label: '$label: ${CurrencyUtils.formatCents(cents)}, $pct por cento',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(label, style: Sumi.body)),
                Text(CurrencyUtils.formatCents(cents), style: Sumi.figures(16)),
                SizedBox(
                  width: 44,
                  child: Text('$pct%', textAlign: TextAlign.right, style: Sumi.caption),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(
                      height: 6,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
                  Container(
                    height: 6,
                    width: constraints.maxWidth * share.clamp(0.0, 1.0),
                    decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
