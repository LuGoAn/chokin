import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../state/financial_state_notifier.dart';
import 'analytics/analytics_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'inbox/inbox_screen.dart';
import 'invoices/invoices_screen.dart';
import 'reimbursements/reimbursements_screen.dart';
import 'settings/settings_screen.dart';
import 'transactions/transaction_history_screen.dart';

class MainShellScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const MainShellScreen({super.key, required this.notifier});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        if (widget.notifier.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final pendingInboxCount = widget.notifier.inbox.length;

        final screens = [
          DashboardScreen(notifier: widget.notifier),
          TransactionHistoryScreen(notifier: widget.notifier),
          InvoicesScreen(notifier: widget.notifier),
          ReimbursementsScreen(notifier: widget.notifier),
          InboxScreen(notifier: widget.notifier),
          AnalyticsScreen(notifier: widget.notifier),
          SettingsScreen(notifier: widget.notifier),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Início',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Extrato',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.credit_card_outlined),
                activeIcon: Icon(Icons.credit_card),
                label: 'Faturas',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Cobranças',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingInboxCount > 0,
                  label: Text('$pendingInboxCount'),
                  child: const Icon(Icons.inbox_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: pendingInboxCount > 0,
                  label: Text('$pendingInboxCount'),
                  child: const Icon(Icons.inbox),
                ),
                label: 'Inbox',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                activeIcon: Icon(Icons.analytics),
                label: 'Análise',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        );
      },
    );
  }
}
