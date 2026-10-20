import 'package:flutter/foundation.dart' show mapEquals;
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

  FinancialState? _persisted;
  Future<void> _writeQueue = Future.value();

  Future<FinancialState> loadFinancialState() async {
    final db = await dbHelper.database;

    final people = (await db.query('people')).map(Person.fromMap).toList();
    final cards = (await db.query('credit_cards')).map(CreditCard.fromMap).toList();
    final invoices = (await db.query('invoices')).map(Invoice.fromMap).toList();
    final installments = (await db.query('installments')).map(Installment.fromMap).toList();

    final allPayments = (await db.query('reimbursement_payments')).map(ReimbursementPayment.fromMap).toList();
    final paymentsByReimbursement = <String, List<ReimbursementPayment>>{};
    for (final p in allPayments) {
      paymentsByReimbursement.putIfAbsent(p.reimbursementId, () => []).add(p);
    }
    final reimbursements = (await db.query('reimbursements'))
        .map((m) => Reimbursement.fromMap(m, payments: paymentsByReimbursement[m['id']] ?? const []))
        .toList();

    final transactions = (await db.query('transactions', orderBy: 'purchaseDate DESC, createdAt DESC'))
        .map(FinancialTransaction.fromMap)
        .toList();
    final movements = (await db.query('financial_movements', orderBy: 'movementDate DESC'))
        .map(FinancialMovement.fromMap)
        .toList();

    final state = FinancialState(
      transactions: transactions,
      invoices: invoices,
      installments: installments,
      reimbursements: reimbursements,
      movements: movements,
      cards: cards,
      people: people,
    );
    _persisted = state;
    return state;
  }

  Future<void> persistFinancialState(FinancialState state) {
    final write = _writeQueue.then((_) => _persist(state));
    _writeQueue = write.catchError((_) {});
    return write;
  }

  Future<void> _persist(FinancialState state) async {
    final db = await dbHelper.database;
    final before = _persisted ?? await loadFinancialState();

    await db.transaction((txn) async {
      await _syncTable(txn, 'invoices', before.invoices.map((e) => e.toMap()), state.invoices.map((e) => e.toMap()));
      await _syncTable(txn, 'installments', before.installments.map((e) => e.toMap()), state.installments.map((e) => e.toMap()));
      await _syncTable(txn, 'transactions', before.transactions.map((e) => e.toMap()), state.transactions.map((e) => e.toMap()));
      await _syncTable(txn, 'reimbursements', before.reimbursements.map((e) => e.toMap()), state.reimbursements.map((e) => e.toMap()));
      await _syncTable(
        txn,
        'reimbursement_payments',
        before.reimbursements.expand((r) => r.payments).map((e) => e.toMap()),
        state.reimbursements.expand((r) => r.payments).map((e) => e.toMap()),
      );
      await _syncTable(txn, 'financial_movements', before.movements.map((e) => e.toMap()), state.movements.map((e) => e.toMap()));
    });

    _persisted = state;
  }

  static Future<void> _syncTable(
    Transaction txn,
    String table,
    Iterable<Map<String, dynamic>> before,
    Iterable<Map<String, dynamic>> after,
  ) async {
    final oldRows = {for (final r in before) r['id'] as String: r};
    final newRows = {for (final r in after) r['id'] as String: r};

    final batch = txn.batch();
    for (final id in oldRows.keys) {
      if (!newRows.containsKey(id)) batch.delete(table, where: 'id = ?', whereArgs: [id]);
    }
    for (final entry in newRows.entries) {
      final old = oldRows[entry.key];
      if (old == null || !mapEquals(old, entry.value)) {
        batch.insert(table, entry.value, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

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
      for (final cat in Category.defaultCategories()) {
        await db.insert('categories', cat.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final newMaps = await db.query('categories', orderBy: 'displayOrder ASC');
      return newMaps.map((m) => Category.fromMap(m)).toList();
    }
    return maps.map((m) => Category.fromMap(m)).toList();
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
