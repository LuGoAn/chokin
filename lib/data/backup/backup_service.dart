import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../database/database_helper.dart';
import '../database/database_schema.dart';
import '../database/migration_v6.dart';

enum AutoBackupFrequency {
  disabled,
  daily,
  everyThreeDays,
  weekly,
  monthly,
}

class BackupService {
  final DatabaseHelper dbHelper;
  static const String _prefFreqKey = 'auto_backup_frequency';
  static const String _prefLastKey = 'auto_backup_last_timestamp';

  BackupService({DatabaseHelper? dbHelper}) : dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const int backupFormatVersion = 2;

  static const Set<String> _privateSettings = {'github_token'};

  Future<String> exportBackupToJson() async {
    final db = await dbHelper.database;

    final tables = <String, Object?>{};
    for (final table in DatabaseSchema.tables.keys) {
      final rows = await db.query(table);
      tables[table] = table == 'app_settings' ? rows.where((r) => !_privateSettings.contains(r['key'])).toList() : rows;
    }

    final data = <String, dynamic>{
      'version': backupFormatVersion,
      'schemaVersion': DatabaseSchema.version,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<bool> importBackupFromJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final rawTables = decoded['tables'] as Map<String, dynamic>?;
      if (rawTables == null) return false;

      final version = decoded['version'] as int? ?? 1;
      if (version > backupFormatVersion) return false;

      TableRows tables = {
        for (final entry in rawTables.entries)
          if (DatabaseSchema.tables.containsKey(entry.key))
            entry.key: [
              for (final row in (entry.value as List<dynamic>? ?? const [])) Map<String, Object?>.from(row as Map),
            ],
      };
      if (version < 2) tables = MigrationV6.migrateTables(tables);

      tables['app_settings']?.removeWhere((r) => _privateSettings.contains(r['key']));

      final db = await dbHelper.database;
      await db.transaction((txn) async {
        final kept = await txn.query(
          'app_settings',
          where: 'key IN (${List.filled(_privateSettings.length, '?').join(',')})',
          whereArgs: _privateSettings.toList(),
        );
        for (final table in DatabaseSchema.tables.keys) {
          if (table == 'inbox_notifications' && !tables.containsKey(table)) continue;
          await txn.delete(table);
        }
        for (final entry in tables.entries) {
          for (final row in entry.value) {
            await txn.insert(entry.key, row);
          }
        }
        for (final row in kept) {
          await txn.insert('app_settings', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Directory> getBackupDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${baseDir.path}/ChokinBackups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<File> saveBackupToFile({String? customFileName}) async {
    final jsonContent = await exportBackupToJson();
    final dir = await getBackupDirectory();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fileName = customFileName ?? 'chokin_backup_$dateStr.json';
    final file = File('${dir.path}/$fileName');
    return await file.writeAsString(jsonContent);
  }

  Future<File> saveExportFile(String fileName, String content) async {
    final dir = await getBackupDirectory();
    final file = File('${dir.path}/$fileName');
    return await file.writeAsString(content);
  }

  Future<AutoBackupFrequency> getAutoBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_prefFreqKey) ?? AutoBackupFrequency.disabled.name;
    return AutoBackupFrequency.values.firstWhere(
      (e) => e.name == val,
      orElse: () => AutoBackupFrequency.disabled,
    );
  }

  Future<void> setAutoBackupFrequency(AutoBackupFrequency freq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFreqKey, freq.name);
  }

  Future<DateTime?> getLastAutoBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_prefLastKey);
    return val != null ? DateTime.tryParse(val) : null;
  }

  Future<bool> checkAndRunAutoBackup() async {
    final freq = await getAutoBackupFrequency();
    if (freq == AutoBackupFrequency.disabled) return false;

    final last = await getLastAutoBackupDate();
    final now = DateTime.now();

    var shouldRun = false;
    if (last == null) {
      shouldRun = true;
    } else {
      final diff = now.difference(last);
      switch (freq) {
        case AutoBackupFrequency.daily:
          shouldRun = diff.inHours >= 24;
          break;
        case AutoBackupFrequency.everyThreeDays:
          shouldRun = diff.inHours >= 72;
          break;
        case AutoBackupFrequency.weekly:
          shouldRun = diff.inDays >= 7;
          break;
        case AutoBackupFrequency.monthly:
          shouldRun = diff.inDays >= 30;
          break;
        case AutoBackupFrequency.disabled:
          shouldRun = false;
          break;
      }
    }

    if (shouldRun) {
      await saveBackupToFile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastKey, now.toIso8601String());
      return true;
    }

    return false;
  }
}
