import 'package:sqflite/sqflite.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/financial_movement.dart';
import '../../domain/entities/inbox_notification.dart';
import '../../domain/entities/installment.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/reimbursement.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/engine/financial_movement_engine.dart';
import '../database/database_helper.dart';

class FinancialRepository {
  final DatabaseHelper dbHelper;

  FinancialRepository({DatabaseHelper? dbHelper}) : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<FinancialState> loadFinancialState() async {
    final db = await dbHelper.database;

    // 1. Saldos (unifica Caixinha/Reserva no Saldo principal)
    final settingsMaps = await db.query('app_settings');
    double available = 0.0;
    double reserve = 0.0;
    for (final map in settingsMaps) {
      if (map['key'] == 'available_balance') {
        available = double.tryParse(map['value'] as String) ?? 0.0;
      } else if (map['key'] == 'reserve_balance') {
        reserve = double.tryParse(map['value'] as String) ?? 0.0;
      }
    }

    if (reserve > 0) {
      available += reserve;
      reserve = 0.0;
      await db.insert('app_settings', {'key': 'available_balance', 'value': available.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {'key': 'reserve_balance', 'value': '0.0'}, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // 2. Pessoas
    final peopleMaps = await db.query('people');
    final people = peopleMaps.map((m) => Person.fromMap(m)).toList();

    // 3. Categorias
    final catMaps = await db.query('categories');
    final categories = catMaps.map((m) => Category.fromMap(m)).toList();

    // 4. Cartões
    final cardMaps = await db.query('credit_cards');
    final cards = cardMaps.map((m) => CreditCard.fromMap(m)).toList();

    // 5. Faturas
    final invoiceMaps = await db.query('invoices');
    final invoices = invoiceMaps.map((m) => Invoice.fromMap(m)).toList();

    // 6. Parcelas
    final installmentMaps = await db.query('installments');
    final installments = installmentMaps.map((m) => Installment.fromMap(m)).toList();

    // 7. Reembolsos e Pagamentos
    final reimbPaymentMaps = await db.query('reimbursement_payments');
    final allPayments = reimbPaymentMaps.map((m) => ReimbursementPayment.fromMap(m)).toList();

    final reimbMaps = await db.query('reimbursements');
    final reimbursements = reimbMaps.map((m) {
      final rId = m['id'] as String;
      final payments = allPayments.where((p) => p.reimbursementId == rId).toList();
      return Reimbursement.fromMap(m, payments: payments);
    }).toList();

    // 8. Transações
    final txMaps = await db.query('transactions', where: 'isCancelled = 0', orderBy: 'purchaseDate DESC, createdAt DESC');
    final transactions = txMaps.map((m) => FinancialTransaction.fromMap(m)).toList();

    final now = DateTime.now();

    // 9. Higienização: remove qualquer movimentação financeira futura indevidamente criada no ledger
    final futureTxIds = transactions.where((t) => t.purchaseDate.isAfter(now)).map((t) => t.id).toList();
    if (futureTxIds.isNotEmpty) {
      final placeholders = List.filled(futureTxIds.length, '?').join(',');
      await db.delete(
        'financial_movements',
        where: 'movementDate > ? OR transactionId IN ($placeholders)',
        whereArgs: [now.toIso8601String(), ...futureTxIds],
      );
    } else {
      await db.delete('financial_movements', where: 'movementDate > ?', whereArgs: [now.toIso8601String()]);
    }

    final movMaps = await db.query('financial_movements', orderBy: 'movementDate DESC');
    final movements = movMaps.map((m) => FinancialMovement.fromMap(m)).toList();

    // 10. Higienização de saldo inflacionado por recorrências futuras no app_settings
    final futureRecurringIncomeSum = transactions
        .where((t) => t.isRecurring && t.type == TransactionType.income && t.purchaseDate.isAfter(now))
        .fold<double>(0.0, (acc, t) => acc + t.amount);

    final futureRecurringExpenseSum = transactions
        .where((t) => t.isRecurring && t.type == TransactionType.expense && !t.isCreditCard && t.purchaseDate.isAfter(now))
        .fold<double>(0.0, (acc, t) => acc + t.amount);

    if (futureRecurringIncomeSum > 0 && available >= futureRecurringIncomeSum) {
      available = double.parse((available - futureRecurringIncomeSum + futureRecurringExpenseSum).toStringAsFixed(2));
      await db.insert('app_settings', {'key': 'available_balance', 'value': available.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    return FinancialState(
      availableBalance: available,
      reserveBalance: reserve,
      transactions: transactions,
      invoices: invoices,
      installments: installments,
      reimbursements: reimbursements,
      movements: movements,
      cards: cards,
      people: people,
    );
  }

  /// Salva atomicamente o novo estado após qualquer operação financeira
  Future<void> persistFinancialState(FinancialState state) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // 1. Atualiza saldos
      await txn.insert('app_settings', {'key': 'available_balance', 'value': state.availableBalance.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('app_settings', {'key': 'reserve_balance', 'value': state.reserveBalance.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Sincroniza faturas
      await txn.delete('invoices');
      for (final inv in state.invoices) {
        await txn.insert('invoices', inv.toMap());
      }

      // 3. Sincroniza parcelas
      await txn.delete('installments');
      for (final inst in state.installments) {
        await txn.insert('installments', inst.toMap());
      }

      // 4. Sincroniza transações
      await txn.delete('transactions');
      for (final tx in state.transactions) {
        await txn.insert('transactions', tx.toMap());
      }

      // 5. Sincroniza reembolsos e pagamentos
      await txn.delete('reimbursements');
      await txn.delete('reimbursement_payments');
      for (final r in state.reimbursements) {
        await txn.insert('reimbursements', r.toMap());
        for (final p in r.payments) {
          await txn.insert('reimbursement_payments', p.toMap());
        }
      }

      // 6. Sincroniza movimentações
      await txn.delete('financial_movements');
      for (final m in state.movements) {
        await txn.insert('financial_movements', m.toMap());
      }
    });
  }

  // --- Inbox Operations ---
  Future<List<InboxNotification>> getInboxNotifications() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'inbox_notifications',
      where: 'status = ?',
      whereArgs: [InboxStatus.pending.name],
      orderBy: 'eventTimestamp DESC',
    );
    return maps.map((m) => InboxNotification.fromMap(m)).toList();
  }

  Future<void> saveInboxNotification(InboxNotification item) async {
    final db = await dbHelper.database;
    await db.insert('inbox_notifications', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateInboxStatus(String id, InboxStatus status) async {
    final db = await dbHelper.database;
    await db.update(
      'inbox_notifications',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Cadastro de Cartões, Pessoas e Categorias ---
  Future<void> addCreditCard(CreditCard card) async {
    final db = await dbHelper.database;
    await db.insert('credit_cards', card.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCreditCard(CreditCard card) async {
    final db = await dbHelper.database;
    await db.update('credit_cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }

  Future<void> deleteCreditCard(String cardId) async {
    final db = await dbHelper.database;
    await db.delete('credit_cards', where: 'id = ?', whereArgs: [cardId]);
  }

  Future<void> addPerson(Person person) async {
    final db = await dbHelper.database;
    await db.insert('people', person.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePerson(Person person) async {
    final db = await dbHelper.database;
    await db.update('people', person.toMap(), where: 'id = ?', whereArgs: [person.id]);
  }

  Future<void> deletePerson(String personId) async {
    final db = await dbHelper.database;
    await db.delete('people', where: 'id = ?', whereArgs: [personId]);
  }

  Future<List<Person>> getPeople() async {
    final db = await dbHelper.database;
    final maps = await db.query('people', orderBy: 'createdAt ASC');
    return maps.map((m) => Person.fromMap(m)).toList();
  }

  Future<void> addCategory(Category category) async {
    final db = await dbHelper.database;
    await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(Category category) async {
    final db = await dbHelper.database;
    await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> deleteCategory(String categoryId) async {
    final db = await dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
  }

  Future<void> saveCategoriesOrder(List<Category> categories) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (int i = 0; i < categories.length; i++) {
      final updated = categories[i].copyWith(displayOrder: i);
      batch.update('categories', updated.toMap(), where: 'id = ?', whereArgs: [updated.id]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Category>> getCategories() async {
    final db = await dbHelper.database;
    final maps = await db.query('categories', orderBy: 'displayOrder ASC');
    if (maps.isEmpty) {
      // Se estiver vazio, popula as categorias padrão
      for (final cat in Category.defaultCategories()) {
        await db.insert('categories', cat.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final newMaps = await db.query('categories', orderBy: 'displayOrder ASC');
      return newMaps.map((m) => Category.fromMap(m)).toList();
    }
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<void> setInitialBalances({required double available, required double reserve}) async {
    final db = await dbHelper.database;
    await db.insert('app_settings', {'key': 'available_balance', 'value': available.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('app_settings', {'key': 'reserve_balance', 'value': reserve.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await dbHelper.database;
    final maps = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await dbHelper.database;
    await db.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
