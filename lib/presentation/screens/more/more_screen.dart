import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../state/financial_state_notifier.dart';
import '../analytics/analytics_screen.dart';
import '../inbox/inbox_screen.dart';
import '../invoices/invoices_screen.dart';
import '../settings/settings_screen.dart';

class MoreScreen extends StatelessWidget {
  final FinancialStateNotifier notifier;

  const MoreScreen({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final pending = notifier.inbox.length;

    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Sumi.gutter, vertical: 8),
        children: [
          _MoreEntry(
            icon: Icons.credit_card,
            title: 'Faturas e cartões',
            subtitle: 'Faturas por mês, pagamentos e limites',
            onTap: () => open(InvoicesScreen(notifier: notifier)),
          ),
          _MoreEntry(
            icon: Icons.inbox_outlined,
            title: 'Caixa de entrada',
            subtitle: pending > 0
                ? '$pending notificaç${pending == 1 ? 'ão' : 'ões'} para revisar'
                : 'Compras lidas das notificações do banco',
            badgeCount: pending,
            onTap: () => open(InboxScreen(notifier: notifier)),
          ),
          _MoreEntry(
            icon: Icons.insights_outlined,
            title: 'Análise',
            subtitle: 'Gastos por categoria e forma de pagamento',
            onTap: () => open(AnalyticsScreen(notifier: notifier)),
          ),
          _MoreEntry(
            icon: Icons.tune,
            title: 'Ajustes',
            subtitle: 'Saldo, backup, categorias, pessoas e leitor de notificações',
            onTap: () => open(SettingsScreen(notifier: notifier)),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _MoreEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isLast;

  const _MoreEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            top: const BorderSide(color: AppColors.border),
            bottom: isLast ? const BorderSide(color: AppColors.border) : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Sumi.bodyStrong),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Sumi.caption),
                ],
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textOnPrimary),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
