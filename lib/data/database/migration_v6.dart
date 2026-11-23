import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/money.dart';
import '../../domain/engine/ledger.dart';
import '../../domain/entities/financial_movement.dart';
import 'database_schema.dart';

typedef TableRows = Map<String, List<Map<String, Object?>>>;

abstract final class MigrationV6 {
  static const Map<String, Map<String, String>> moneyColumns = {
    'credit_cards': {'creditLimit': 'creditLimitCents'},
    'invoices': {'totalAmount': 'totalAmountCents', 'paidAmount': 'paidAmountCents'},
    'transactions': {'amount': 'amountCents', 'refundAmount': 'refundAmountCents'},
    'installments': {'amount': 'amountCents'},
    'reimbursements': {'totalAmount': 'totalAmountCents', 'remainingAmount': 'remainingAmountCents'},
    'reimbursement_payments': {'amount': 'amountCents'},
    'financial_movements': {'amount': 'amountCents'},
  };

  static const List<String> rebuiltTables = [
    'credit_cards',
    'invoices',
    'transactions',
    'installments',
    'reimbursements',
    'reimbursement_payments',
    'financial_movements',
    'app_settings',
  ];

  static const _legacyAvailableKey = 'available_balance';
  static const _legacyReserveKey = 'reserve_balance';

  static TableRows migrateTables(TableRows v5, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    final result = <String, List<Map<String, Object?>>>{};

    for (final entry in v5.entries) {
      final renames = moneyColumns[entry.key];
      result[entry.key] = [
        for (final row in entry.value) renames == null ? Map.of(row) : _convertRow(row, renames),
      ];
    }

    for (final m in result['financial_movements'] ?? const <Map<String, Object?>>[]) {
      final description = m['description'] as String? ?? '';
      if (m['type'] == MovementType.refund.name && description.startsWith('Estorno na fatura')) {
        m['type'] = MovementType.cardRefund.name;
      }
    }

    final settings = result['app_settings'] ?? <Map<String, Object?>>[];
    final legacyAvailable = _legacySetting(settings, _legacyAvailableKey);
    final legacyReserve = _legacySetting(settings, _legacyReserveKey);
    settings.removeWhere((r) => r['key'] == _legacyAvailableKey || r['key'] == _legacyReserveKey);

    final movementRows = result['financial_movements'] ?? <Map<String, Object?>>[];
    final movements = movementRows.map(FinancialMovement.fromMap).toList();
    final openings = Ledger.openingAdjustments(
      movements: movements,
      targetAvailableCents: legacyAvailable + legacyReserve,
      date: _earliestActivity(result, refNow),
    );
    if (openings.isNotEmpty) {
      result['financial_movements'] = [...openings.map((m) => m.toMap()), ...movementRows];
    }

    return result;
  }

  static Future<void> upgrade(DatabaseExecutor db, {Future<void> Function(String backupJson)? saveBackup}) async {
    final v5 = <String, List<Map<String, Object?>>>{};
    for (final table in DatabaseSchema.tables.keys) {
      v5[table] = (await db.query(table)).map((r) => Map<String, Object?>.of(r)).toList();
    }

    if (saveBackup != null) {
      final backup = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'reason': 'Cópia automática antes da atualização do banco para a versão 6',
        'tables': {
          ...v5,
          'app_settings': [
            for (final r in v5['app_settings'] ?? const <Map<String, Object?>>[])
              if (r['key'] != 'github_token') r,
          ],
        },
      });
      try {
        await saveBackup(backup);
      } catch (_) {
      }
    }

    final v6 = migrateTables(v5);
    for (final table in rebuiltTables) {
      await db.execute('DROP TABLE IF EXISTS $table');
      await db.execute(DatabaseSchema.tables[table]!);
      for (final row in v6[table] ?? const <Map<String, Object?>>[]) {
        await db.insert(table, row);
      }
    }
  }

  static Map<String, Object?> _convertRow(Map<String, Object?> row, Map<String, String> renames) {
    final converted = <String, Object?>{};
    for (final e in row.entries) {
      final newName = renames[e.key];
      if (newName == null) {
        converted[e.key] = e.value;
      } else {
        final value = e.value;
        converted[newName] = value == null ? null : Money.fromReais(value as num);
      }
    }
    return converted;
  }

  static int _legacySetting(List<Map<String, Object?>> settings, String key) {
    for (final r in settings) {
      if (r['key'] == key) {
        final value = double.tryParse('${r['value']}');
        return value == null ? 0 : Money.fromReais(value);
      }
    }
    return 0;
  }

  static DateTime _earliestActivity(TableRows tables, DateTime now) {
    DateTime? earliest;
    void consider(Object? iso) {
      final date = iso is String ? DateTime.tryParse(iso) : null;
      if (date == null || date.isAfter(now)) return;
      if (earliest == null || date.isBefore(earliest!)) earliest = date;
    }

    for (final m in tables['financial_movements'] ?? const <Map<String, Object?>>[]) {
      consider(m['movementDate']);
    }
    for (final t in tables['transactions'] ?? const <Map<String, Object?>>[]) {
      consider(t['purchaseDate']);
    }
    return earliest ?? now;
  }
}
