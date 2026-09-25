import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/category.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chokin_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0;');
        await db.execute('ALTER TABLE transactions ADD COLUMN recurrence TEXT NOT NULL DEFAULT "none";');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN displayOrder INTEGER NOT NULL DEFAULT 0;');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN createdAt TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN refundAmount REAL NOT NULL DEFAULT 0.0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN refundedAt TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN refundMethod TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN refundNotes TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN recurringGroupId TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN recurrenceEndedAt TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN recurrenceExceptions TEXT;');
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Pessoas
    await db.execute('''
      CREATE TABLE people (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 2. Categorias
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        colorHex TEXT NOT NULL,
        type TEXT NOT NULL,
        isCustom INTEGER NOT NULL DEFAULT 0,
        displayOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Cartões de Crédito
    await db.execute('''
      CREATE TABLE credit_cards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        closingDay INTEGER NOT NULL,
        dueDay INTEGER NOT NULL,
        creditLimit REAL,
        flag TEXT,
        colorHex TEXT NOT NULL
      )
    ''');

    // 4. Faturas
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        cardId TEXT NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        closingDate TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        effectiveDueDate TEXT NOT NULL,
        totalAmount REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL,
        paidAt TEXT,
        paidAmount REAL,
        FOREIGN KEY (cardId) REFERENCES credit_cards (id) ON DELETE CASCADE
      )
    ''');

    // 5. Transações
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        purchaseDate TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        type TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        personId TEXT NOT NULL,
        cardId TEXT,
        totalInstallments INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        sourceNotificationId TEXT,
        isCancelled INTEGER NOT NULL DEFAULT 0,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrence TEXT NOT NULL DEFAULT 'none',
        recurringGroupId TEXT,
        recurrenceEndedAt TEXT,
        recurrenceExceptions TEXT,
        createdAt TEXT,
        refundAmount REAL NOT NULL DEFAULT 0.0,
        refundedAt TEXT,
        refundMethod TEXT,
        refundNotes TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (personId) REFERENCES people (id),
        FOREIGN KEY (cardId) REFERENCES credit_cards (id)
      )
    ''');

    // 6. Parcelas
    await db.execute('''
      CREATE TABLE installments (
        id TEXT PRIMARY KEY,
        transactionId TEXT NOT NULL,
        invoiceId TEXT NOT NULL,
        installmentNumber INTEGER NOT NULL,
        totalInstallments INTEGER NOT NULL,
        amount REAL NOT NULL,
        personId TEXT,
        FOREIGN KEY (transactionId) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    // 7. Reembolsos
    await db.execute('''
      CREATE TABLE reimbursements (
        id TEXT PRIMARY KEY,
        personId TEXT NOT NULL,
        transactionId TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        remainingAmount REAL NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (personId) REFERENCES people (id),
        FOREIGN KEY (transactionId) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // 8. Pagamentos Parciais de Reembolso
    await db.execute('''
      CREATE TABLE reimbursement_payments (
        id TEXT PRIMARY KEY,
        reimbursementId TEXT NOT NULL,
        amount REAL NOT NULL,
        paymentDate TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (reimbursementId) REFERENCES reimbursements (id) ON DELETE CASCADE
      )
    ''');

    // 9. Movimentações Financeiras (Ledger Central)
    await db.execute('''
      CREATE TABLE financial_movements (
        id TEXT PRIMARY KEY,
        transactionId TEXT,
        invoiceId TEXT,
        reimbursementId TEXT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        movementDate TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');

    // 10. Caixa de Entrada de Notificações (Inbox)
    await db.execute('''
      CREATE TABLE inbox_notifications (
        id TEXT PRIMARY KEY,
        rawId TEXT NOT NULL,
        packageName TEXT NOT NULL,
        appName TEXT NOT NULL,
        rawTitle TEXT NOT NULL,
        rawText TEXT NOT NULL,
        parsedAmount REAL,
        parsedMerchant TEXT,
        suggestedPaymentMethod TEXT,
        eventTimestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        duplicateGroupId TEXT,
        duplicateScore REAL NOT NULL DEFAULT 0.0,
        detectedSources TEXT
      )
    ''');

    // 11. Saldos e Configurações Globais
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Popula categorias padrão
    for (final cat in Category.defaultCategories()) {
      await db.insert('categories', cat.toMap());
    }

    // Inicializa pessoa "Eu" (ME)
    await db.insert('people', {
      'id': 'ME',
      'name': 'Eu',
      'phone': null,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Inicializa saldos iniciais
    await db.insert('app_settings', {'key': 'available_balance', 'value': '0.0'});
    await db.insert('app_settings', {'key': 'reserve_balance', 'value': '0.0'});
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
