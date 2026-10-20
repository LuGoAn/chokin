import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import '../../data/backup/backup_service.dart';
import '../../data/repositories/financial_repository.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/inbox_notification.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/engine/financial_movement_engine.dart';
import '../../domain/notifications/deduplication/deduplication_engine.dart';
import '../../domain/notifications/notification_bridge_service.dart';
import '../../services/update_service.dart';

enum RecurringDeleteOption {
  onlyThisMonth,
  fromNowOn,
  allOccurrences,
}

class FinancialStateNotifier extends ChangeNotifier {
  final FinancialRepository repository;
  final BackupService backupService;
  final NotificationBridgeService notificationBridge;
  final UpdateService updateService;

  FinancialState _state = const FinancialState();
  List<Category> _categories = [];
  List<InboxNotification> _inbox = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  AppUpdateInfo? _availableUpdate;

  FinancialStateNotifier({
    FinancialRepository? repository,
    BackupService? backupService,
    NotificationBridgeService? notificationBridge,
    UpdateService? updateService,
  })  : repository = repository ?? FinancialRepository(),
        backupService = backupService ?? BackupService(),
        notificationBridge = notificationBridge ?? NotificationBridgeService(),
        updateService = updateService ?? UpdateService(repository: repository ?? FinancialRepository());

  FinancialState get state => _state;
  List<Category> get categories => _categories;
  List<InboxNotification> get inbox => _inbox;
  bool get isLoading => _isLoading;
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;
  AppUpdateInfo? get availableUpdate => _availableUpdate;

  DashboardSummary get dashboardSummary => FinancialMovementEngine.calculateDashboardSummary(
        state: _state,
        month: _selectedMonth,
        year: _selectedYear,
        pendingInboxCount: _inbox.length,
      );

  StreamSubscription? _notifSubscription;

  @visibleForTesting
  void debugSeed(FinancialState state, {List<InboxNotification> inbox = const [], List<Category>? categories}) {
    _state = state;
    _inbox = List.of(inbox);
    if (categories != null) _categories = categories;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _state = await repository.loadFinancialState();
    _categories = await repository.getCategories();
    _inbox = await repository.getInboxNotifications();

    notificationBridge.initialize();
    _notifSubscription?.cancel();
    _notifSubscription = notificationBridge.onNotificationReceived.listen((newNotif) {
      _handleIncomingNotification(newNotif);
    });

    await notificationBridge.rebindService();

    await syncRecurrencesAhead();

    await syncPendingNotifications();

    try {
      await backupService.checkAndRunAutoBackup();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();

    unawaited(checkForUpdates(silent: true));
  }

  Future<void> syncRecurrencesAhead({int? upToMonth, int? upToYear}) async {
    final now = DateTime.now();
    final futureHorizon = DateTime(now.year, now.month + 12, 1);
    int targetM = futureHorizon.month;
    int targetY = futureHorizon.year;

    if (upToMonth != null && upToYear != null) {
      final requestedDate = DateTime(upToYear, upToMonth, 1);
      if (requestedDate.isAfter(futureHorizon)) {
        targetM = requestedDate.month;
        targetY = requestedDate.year;
      }
    }

    _state = FinancialMovementEngine.syncRecurringTransactions(
      currentState: _state,
      targetMonth: targetM,
      targetYear: targetY,
    );
    await repository.persistFinancialState(_state);
  }

  Future<int> syncPendingNotifications() async {
    await notificationBridge.rebindService();
    final pendingFromNative = await notificationBridge.fetchPendingNotificationsFromNative();
    for (final notif in pendingFromNative) {
      await _handleIncomingNotification(notif);
    }
    return pendingFromNative.length;
  }

  Future<void> simulateTestNotification() async {
    final item = await notificationBridge.simulateTestNotification();
    if (item != null) {
      await _handleIncomingNotification(item);
    }
  }

  Future<void> changePeriod(int month, int year) async {
    _selectedMonth = month;
    _selectedYear = year;
    await syncRecurrencesAhead(upToMonth: month, upToYear: year);
    notifyListeners();
  }

  Future<void> deleteRecurringTransaction({
    required String transactionId,
    required RecurringDeleteOption option,
    required int currentMonth,
    required int currentYear,
  }) async {
    final targetTx = _state.transactions.firstWhere((t) => t.id == transactionId);
    final rootId = targetTx.effectiveRecurringGroupId;

    switch (option) {
      case RecurringDeleteOption.onlyThisMonth:
        _state = FinancialMovementEngine.deleteTransaction(
          currentState: _state,
          transactionId: transactionId,
        );

        final monthKey = '$currentYear-${currentMonth.toString().padLeft(2, '0')}';
        final rootIndex = _state.transactions.indexWhere((t) => t.effectiveRecurringGroupId == rootId);
        if (rootIndex != -1) {
          final rootTx = _state.transactions[rootIndex];
          final updatedExceptions = List<String>.from(rootTx.recurrenceExceptions)..add(monthKey);
          final updatedRoot = rootTx.copyWith(recurrenceExceptions: updatedExceptions);
          final updatedTxs = List<FinancialTransaction>.from(_state.transactions);
          updatedTxs[rootIndex] = updatedRoot;
          _state = _state.copyWith(transactions: updatedTxs);
        }
        break;

      case RecurringDeleteOption.fromNowOn:
        final txsToDelete = _state.transactions.where((t) =>
            t.effectiveRecurringGroupId == rootId &&
            (t.purchaseDate.year > currentYear ||
                (t.purchaseDate.year == currentYear && t.purchaseDate.month >= currentMonth))).toList();

        for (final t in txsToDelete) {
          _state = FinancialMovementEngine.deleteTransaction(
            currentState: _state,
            transactionId: t.id,
          );
        }

        final cutoffDate = DateTime(currentYear, currentMonth, 1);
        final rootIndex = _state.transactions.indexWhere((t) => t.effectiveRecurringGroupId == rootId);
        if (rootIndex != -1) {
          final rootTx = _state.transactions[rootIndex];
          final updatedRoot = rootTx.copyWith(recurrenceEndedAt: cutoffDate);
          final updatedTxs = List<FinancialTransaction>.from(_state.transactions);
          updatedTxs[rootIndex] = updatedRoot;
          _state = _state.copyWith(transactions: updatedTxs);
        }
        break;

      case RecurringDeleteOption.allOccurrences:
        final allTxs = _state.transactions.where((t) =>
            t.effectiveRecurringGroupId == rootId).toList();

        for (final t in allTxs) {
          _state = FinancialMovementEngine.deleteTransaction(
            currentState: _state,
            transactionId: t.id,
          );
        }
        break;
    }

    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> _handleIncomingNotification(InboxNotification newNotif) async {
    final updatedInbox = DeduplicationEngine.integrateNotification(
      existingInbox: _inbox,
      newNotification: newNotif,
    );
    _inbox = updatedInbox;
    await repository.saveInboxNotification(newNotif);
    notifyListeners();
  }

  Future<void> addTransaction(FinancialTransaction transaction) async {
    _state = FinancialMovementEngine.processNewTransaction(
      currentState: _state,
      transaction: transaction,
    );
    if (transaction.isRecurring) {
      await syncRecurrencesAhead();
    } else {
      await repository.persistFinancialState(_state);
    }
    notifyListeners();
  }

  Future<void> refundTransaction({
    required String transactionId,
    required int refundAmountCents,
    required PaymentMethod refundMethod,
    DateTime? refundDate,
    String? notes,
  }) async {
    _state = FinancialMovementEngine.processTransactionRefund(
      currentState: _state,
      transactionId: transactionId,
      refundAmountCents: refundAmountCents,
      refundMethod: refundMethod,
      refundDate: refundDate,
      notes: notes,
    );
    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> payInvoice(String invoiceId, DateTime paymentDate, {int? customAmountCents}) async {
    _state = FinancialMovementEngine.processInvoicePayment(
      currentState: _state,
      invoiceId: invoiceId,
      paymentDate: paymentDate,
      customAmountCents: customAmountCents,
    );
    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> receiveReimbursement({
    required String reimbursementId,
    required int amountCents,
    required DateTime date,
    String? notes,
  }) async {
    _state = FinancialMovementEngine.processReimbursementPayment(
      currentState: _state,
      reimbursementId: reimbursementId,
      amountReceivedCents: amountCents,
      paymentDate: date,
      notes: notes,
    );
    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> revertReimbursementPayment({
    required String reimbursementId,
    String? paymentId,
  }) async {
    _state = FinancialMovementEngine.revertReimbursementPayment(
      currentState: _state,
      reimbursementId: reimbursementId,
      paymentId: paymentId,
    );
    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> deleteTransaction(String transactionId) async {
    _state = FinancialMovementEngine.deleteTransaction(
      currentState: _state,
      transactionId: transactionId,
    );
    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> updateTransaction({
    required String oldTransactionId,
    required FinancialTransaction newTransaction,
  }) async {
    var intermediateState = FinancialMovementEngine.deleteTransaction(
      currentState: _state,
      transactionId: oldTransactionId,
    );
    _state = FinancialMovementEngine.processNewTransaction(
      currentState: intermediateState,
      transaction: newTransaction,
    );
    if (newTransaction.isRecurring) {
      await syncRecurrencesAhead();
    } else {
      await repository.persistFinancialState(_state);
    }
    notifyListeners();
  }

  Future<void> transferSurplusToReserve() async {
    _state = FinancialMovementEngine.transferSurplusToReserve(
      currentState: _state,
      periodDate: DateTime.now(),
    );
    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> confirmInboxNotification({
    required String inboxId,
    required FinancialTransaction transaction,
  }) async {
    await addTransaction(transaction);
    await repository.updateInboxStatus(inboxId, InboxStatus.confirmed);
    _inbox.removeWhere((item) => item.id == inboxId);
    notifyListeners();
  }

  Future<int> importInboxNotifications(List<InboxNotification> notifications) async {
    var count = 0;
    for (final notif in notifications) {
      final updatedInbox = DeduplicationEngine.integrateNotification(
        existingInbox: _inbox,
        newNotification: notif,
      );
      _inbox = updatedInbox;
      await repository.saveInboxNotification(notif);
      count++;
    }
    notifyListeners();
    return count;
  }

  Future<void> markInboxConfirmed(String inboxId) async {
    await repository.updateInboxStatus(inboxId, InboxStatus.confirmed);
    _inbox.removeWhere((item) => item.id == inboxId);
    notifyListeners();
  }

  Future<void> ignoreInboxNotification(String inboxId) async {
    await repository.updateInboxStatus(inboxId, InboxStatus.ignored);
    _inbox.removeWhere((item) => item.id == inboxId);
    notifyListeners();
  }

  Future<void> addPerson(String name, {String? phone}) async {
    final newPerson = Person(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phone: phone,
      createdAt: DateTime.now(),
    );
    await repository.addPerson(newPerson);
    _state = await repository.loadFinancialState();
    notifyListeners();
  }

  Future<void> updatePerson(Person person) async {
    await repository.updatePerson(person);
    _state = await repository.loadFinancialState();
    notifyListeners();
  }

  Future<void> deletePerson(String personId) async {
    if (personId == 'ME') return;
    await repository.deletePerson(personId);
    _state = await repository.loadFinancialState();
    notifyListeners();
  }

  Future<void> settleAllReimbursementsForPerson({
    required String personId,
    required DateTime date,
    String? notes,
  }) async {
    final pending = _state.reimbursements.where((r) => r.personId == personId && !r.isSettled).toList();
    for (final r in pending) {
      _state = FinancialMovementEngine.processReimbursementPayment(
        currentState: _state,
        reimbursementId: r.id,
        amountReceivedCents: r.remainingAmountCents,
        paymentDate: date,
        notes: notes ?? 'Quitação total de pendências',
      );
    }
    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> settleMonthReimbursementsForPerson({
    required String personId,
    required int month,
    required int year,
    required DateTime date,
    String? notes,
  }) async {
    final personReimbs = _state.reimbursements.where((r) => r.personId == personId && !r.isSettled).toList();

    for (final r in personReimbs) {
      final tx = _state.transactions.firstWhere(
        (t) => t.id == r.transactionId,
        orElse: () => FinancialTransaction(
          id: '',
          description: '',
          amountCents: r.totalAmountCents,
          purchaseDate: r.createdAt,
          categoryId: 'cat_other',
          paymentMethod: PaymentMethod.pix,
        ),
      );

      final amountToPay = FinancialMovementEngine.calculateReimbursementDueForMonthCents(
        transaction: tx,
        reimbursement: r,
        targetMonth: month,
        targetYear: year,
      );

      if (amountToPay > 0) {
        _state = FinancialMovementEngine.processReimbursementPayment(
          currentState: _state,
          reimbursementId: r.id,
          amountReceivedCents: amountToPay,
          paymentDate: date,
          notes: notes ?? 'Quitação referente ao mês $month/$year',
        );
      }
    }

    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<void> settleCurrentMonthReimbursementsForPerson({
    required String personId,
    required DateTime date,
    String? notes,
  }) async {
    await settleMonthReimbursementsForPerson(
      personId: personId,
      month: _selectedMonth,
      year: _selectedYear,
      date: date,
      notes: notes,
    );
  }

  Future<void> addCreditCard(CreditCard card) async {
    await repository.addCreditCard(card);
    _state = await repository.loadFinancialState();
    notifyListeners();
  }

  Future<void> updateCreditCard(CreditCard card) async {
    await repository.updateCreditCard(card);
    _state = await repository.loadFinancialState();
    notifyListeners();
  }

  Future<void> deleteCreditCard(String cardId) async {
    await repository.deleteCreditCard(cardId);
    _state = await repository.loadFinancialState();
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    await repository.addCategory(category);
    _categories = await repository.getCategories();
    notifyListeners();
  }

  Future<void> updateCategory(Category category) async {
    await repository.updateCategory(category);
    _categories = await repository.getCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(String categoryId) async {
    await repository.deleteCategory(categoryId);
    _categories = await repository.getCategories();
    notifyListeners();
  }

  Future<void> reorderCategories(List<Category> updatedCategories) async {
    _categories = updatedCategories;
    notifyListeners();
    await repository.saveCategoriesOrder(updatedCategories);
  }

  Future<void> setInitialBalances({required int availableCents, int? reserveCents}) async {
    _state = FinancialMovementEngine.adjustBalances(
      currentState: _state,
      availableCents: availableCents,
      reserveCents: reserveCents,
    );
    await repository.persistFinancialState(_state);
    notifyListeners();
  }

  Future<String> exportBackup() async {
    return await backupService.exportBackupToJson();
  }

  Future<bool> importBackup(String jsonContent) async {
    final success = await backupService.importBackupFromJson(jsonContent);
    if (success) {
      _state = await repository.loadFinancialState();
      _categories = await repository.getCategories();
      _inbox = await repository.getInboxNotifications();
      notifyListeners();
    }
    return success;
  }

  Future<AppUpdateInfo> checkForUpdates({bool silent = false}) async {
    try {
      final info = await updateService.checkForUpdates();
      if (info.hasUpdate) {
        _availableUpdate = info;
        notifyListeners();
      }
      return info;
    } catch (_) {
      return AppUpdateInfo.noUpdate(UpdateService.currentVersion);
    }
  }

  void dismissUpdateNotification() {
    _availableUpdate = null;
    notifyListeners();
  }

  Future<bool> openUrl(String url) async {
    return await notificationBridge.openUrl(url);
  }
}
