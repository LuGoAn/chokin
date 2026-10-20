import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/category.dart';
import 'database_schema.dart';
import 'migration_v6.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper();

  final String? path;

  final Future<void> Function(String backupJson)? preMigrationBackup;

  Database? _database;

  DatabaseHelper({this.path, Future<void> Function(String backupJson)? preMigrationBackup})
      : preMigrationBackup = preMigrationBackup ?? _savePreMigrationBackup;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = path ?? join(await getDatabasesPath(), 'chokin_database.db');

    return await openDatabase(
      dbPath,
      version: DatabaseSchema.version,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _savePreMigrationBackup(String backupJson) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/ChokinBackups');
    if (!await dir.exists()) await dir.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    await File('${dir.path}/chokin_backup_antes_da_v6_$stamp.json').writeAsString(backupJson);
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
    if (oldVersion < 6) {
      await MigrationV6.upgrade(db, saveBackup: preMigrationBackup);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    for (final ddl in DatabaseSchema.tables.values) {
      await db.execute(ddl);
    }

    for (final cat in Category.defaultCategories()) {
      await db.insert('categories', cat.toMap());
    }

    await db.insert('people', {
      'id': 'ME',
      'name': 'Eu',
      'phone': null,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
