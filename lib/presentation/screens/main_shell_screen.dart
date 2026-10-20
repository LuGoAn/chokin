import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/sumi.dart';
import '../state/financial_state_notifier.dart';
import 'dashboard/dashboard_screen.dart';
import 'more/more_screen.dart';
import 'reimbursements/reimbursements_screen.dart';
import 'transactions/new_transaction_screen.dart';
import 'transactions/transaction_history_screen.dart';

class MainShellScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const MainShellScreen({super.key, required this.notifier});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _openNewTransaction() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewTransactionScreen(notifier: widget.notifier)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        if (widget.notifier.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final screens = [
          DashboardScreen(notifier: widget.notifier),
          TransactionHistoryScreen(notifier: widget.notifier),
          ReimbursementsScreen(notifier: widget.notifier),
          MoreScreen(notifier: widget.notifier),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: _SumiNavBar(
            currentIndex: _currentIndex,
            pendingInboxCount: widget.notifier.inbox.length,
            onSelect: (index) => setState(() => _currentIndex = index),
            onNewTransaction: _openNewTransaction,
          ),
        );
      },
    );
  }
}

class _SumiNavBar extends StatelessWidget {
  final int currentIndex;
  final int pendingInboxCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewTransaction;

  const _SumiNavBar({
    required this.currentIndex,
    required this.pendingInboxCount,
    required this.onSelect,
    required this.onNewTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            children: [
              _NavItem(
                  icon: Icons.home_outlined, label: 'Início', selected: currentIndex == 0, onTap: () => onSelect(0)),
              _NavItem(icon: Icons.notes, label: 'Extrato', selected: currentIndex == 1, onTap: () => onSelect(1)),
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: 'Novo lançamento',
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(side: BorderSide(color: AppColors.primary, width: 1.5)),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onNewTransaction,
                        child: const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.add, color: AppColors.primary, size: 26, semanticLabel: 'Novo lançamento'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.people_outline,
                label: 'Cobranças',
                selected: currentIndex == 2,
                onTap: () => onSelect(2),
              ),
              _NavItem(
                icon: Icons.more_horiz,
                label: 'Mais',
                selected: currentIndex == 3,
                badgeCount: pendingInboxCount,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Sumi.radius),
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text('$badgeCount'),
                  backgroundColor: AppColors.primary,
                  textColor: AppColors.textOnPrimary,
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: Sumi.uiFont,
                    fontSize: 11,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
