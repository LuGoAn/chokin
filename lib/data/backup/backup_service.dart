import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

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

  Future<String> exportBackupToJson() async {
    final db = await dbHelper.database;

    final data = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': {
        'people': await db.query('people'),
        'categories': await db.query('categories'),
        'credit_cards': await db.query('credit_cards'),
        'invoices': await db.query('invoices'),
        'transactions': await db.query('transactions'),
        'installments': await db.query('installments'),
        'reimbursements': await db.query('reimbursements'),
        'reimbursement_payments': await db.query('reimbursement_payments'),
        'financial_movements': await db.query('financial_movements'),
        'app_settings': await db.query('app_settings'),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<bool> importBackupFromJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final tables = decoded['tables'] as Map<String, dynamic>?;
      if (tables == null) return false;

      final db = await dbHelper.database;

      await db.transaction((txn) async {
        // Limpa tabelas atuais
        await txn.delete('reimbursement_payments');
        await txn.delete('reimbursements');
        await txn.delete('installments');
        await txn.delete('transactions');
        await txn.delete('invoices');
        await txn.delete('credit_cards');
        await txn.delete('categories');
        await txn.delete('people');
        await txn.delete('financial_movements');
        await txn.delete('app_settings');

        // Repovoa com os dados do backup
        for (final entry in tables.entries) {
          final tableName = entry.key;
          final rows = entry.value as List<dynamic>?;
          if (rows != null) {
            for (final row in rows) {
              await txn.insert(tableName, Map<String, dynamic>.from(row as Map));
            }
          }
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Retorna o diretório local onde os backups são salvos
  Future<Directory> getBackupDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${baseDir.path}/ChokinBackups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Salva o arquivo de backup localmente na pasta ChokinBackups
  Future<File> saveBackupToFile({String? customFileName}) async {
    final jsonContent = await exportBackupToJson();
    final dir = await getBackupDirectory();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fileName = customFileName ?? 'chokin_backup_$dateStr.json';
    final file = File('${dir.path}/$fileName');
    return await file.writeAsString(jsonContent);
  }

  /// Salva um arquivo de texto qualquer (ex: CSV) no diretório de exportações
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

  /// Executa o backup automático se a frequência selecionada exigir
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
