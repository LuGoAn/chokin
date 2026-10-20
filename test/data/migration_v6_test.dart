import 'dart:convert';
import 'dart:io';

import 'package:chokin/data/backup/backup_service.dart';
import 'package:chokin/data/database/database_helper.dart';
import 'package:chokin/data/database/migration_v6.dart';
import 'package:chokin/data/repositories/financial_repository.dart';
import 'package:chokin/domain/engine/financial_movement_engine.dart';
import 'package:chokin/domain/engine/ledger.dart';
import 'package:chokin/domain/entities/financial_movement.dart';
import 'package:chokin/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/schema_v5.dart';

TableRows sampleV5() => {
      'people': [
        {'id': 'ME', 'name': 'Eu', 'phone': null, 'createdAt': '2026-08-01T00:00:00.000'},
        {'id': 'p_ana', 'name': 'Ana', 'phone': null, 'createdAt': '2026-08-01T00:00:00.000'},
      ],
      'categories': [
        {
          'id': 'cat_other',
          'name': 'Outros',
          'icon': 'more',
          'colorHex': '0xFF000000',
          'type': 'expense',
          'isCustom': 0,
          'displayOrder': 0
        },
      ],
      'credit_cards': [
        {
          'id': 'card',
          'name': 'Nubank',
          'closingDay': 3,
          'dueDay': 10,
          'creditLimit': 5000.0,
          'flag': null,
          'colorHex': '0xFF6366F1'
        },
      ],
      'invoices': [
        _invoice('inv_card_2026_8', 8, 126.67000000000002,
            status: 'paid', paidAt: '2026-09-08T00:00:00.000', paidAmount: 126.67000000000002),
        _invoice('inv_card_2026_9', 9, 66.67),
        _invoice('inv_card_2026_10', 10, 16.659999999999997),
      ],
      'transactions': [
        _tx('t_salary', 2171.7, '2026-08-05T09:00:00.000', type: 'income'),
        _tx('t_market', 295.9, '2026-08-10T09:00:00.000'),
        _tx('t_tv', 200.0, '2026-08-01T09:00:00.000', method: 'creditCard', installments: 3, refund: 50.0),
        _tx('t_ana', 60.0, '2026-08-01T10:00:00.000', method: 'creditCard', person: 'p_ana'),
      ],
      'installments': [
        _inst('i1', 't_tv', 'inv_card_2026_8', 1, 3, 66.67),
        _inst('i2', 't_tv', 'inv_card_2026_9', 2, 3, 66.67),
        _inst('i3', 't_tv', 'inv_card_2026_10', 3, 3, 16.659999999999997),
        _inst('i4', 't_ana', 'inv_card_2026_8', 1, 1, 60.0),
      ],
      'reimbursements': [
        {
          'id': 'r_ana',
          'personId': 'p_ana',
          'transactionId': 't_ana',
          'totalAmount': 60.0,
          'remainingAmount': 20.000000000000004,
          'status': 'partiallyPaid',
          'createdAt': '2026-08-01T10:00:00.000'
        },
      ],
      'reimbursement_payments': [
        {
          'id': 'rp1',
          'reimbursementId': 'r_ana',
          'amount': 40.0,
          'paymentDate': '2026-08-20T00:00:00.000',
          'notes': null
        },
      ],
      'financial_movements': [
        _mov('m1', 'income', 2171.7, '2026-08-05T09:00:00.000', transactionId: 't_salary'),
        _mov('m2', 'expensePaid', 295.9, '2026-08-10T09:00:00.000', transactionId: 't_market'),
        _mov('m3', 'reimbursementReceived', 40.0, '2026-08-20T00:00:00.000', reimbursementId: 'r_ana'),
        _mov('m4', 'transferToReserve', 300.0, '2026-08-31T00:00:00.000'),
        _mov('m5', 'invoicePayment', 126.67000000000002, '2026-09-08T00:00:00.000', invoiceId: 'inv_card_2026_8'),
        _mov('m6', 'refund', 50.0, '2026-09-12T00:00:00.000',
            transactionId: 't_tv', description: 'Estorno na fatura (TV): crédito de R\$ 50,00'),
      ],
      'inbox_notifications': [],
      'app_settings': [
        {'key': 'available_balance', 'value': '1850.25'},
        {'key': 'reserve_balance', 'value': '0.0'},
        {'key': 'outra_config', 'value': 'mantida'},
      ],
    };

Map<String, Object?> _invoice(String id, int month, double total,
        {String status = 'open', String? paidAt, double? paidAmount}) =>
    {
      'id': id,
      'cardId': 'card',
      'month': month,
      'year': 2026,
      'closingDate': '2026-${month.toString().padLeft(2, '0')}-03T00:00:00.000',
      'dueDate': '2026-${month.toString().padLeft(2, '0')}-10T00:00:00.000',
      'effectiveDueDate': '2026-${month.toString().padLeft(2, '0')}-10T00:00:00.000',
      'totalAmount': total,
      'status': status,
      'paidAt': paidAt,
      'paidAmount': paidAmount,
    };

Map<String, Object?> _tx(String id, double amount, String date,
        {String type = 'expense',
        String method = 'pix',
        int installments = 1,
        String person = 'ME',
        double refund = 0.0}) =>
    {
      'id': id,
      'description': id,
      'amount': amount,
      'purchaseDate': date,
      'categoryId': 'cat_other',
      'type': type,
      'paymentMethod': method,
      'personId': person,
      'cardId': method == 'creditCard' ? 'card' : null,
      'totalInstallments': installments,
      'notes': null,
      'sourceNotificationId': null,
      'isCancelled': 0,
      'isRecurring': 0,
      'recurrence': 'none',
      'recurringGroupId': null,
      'recurrenceEndedAt': null,
      'recurrenceExceptions': '',
      'createdAt': date,
      'refundAmount': refund,
      'refundedAt': refund > 0 ? '2026-09-12T00:00:00.000' : null,
      'refundMethod': refund > 0 ? 'creditCard' : null,
      'refundNotes': null,
    };

Map<String, Object?> _inst(String id, String tx, String inv, int n, int total, double amount) => {
      'id': id,
      'transactionId': tx,
      'invoiceId': inv,
      'installmentNumber': n,
      'totalInstallments': total,
      'amount': amount,
      'personId': tx == 't_ana' ? 'p_ana' : null,
    };

Map<String, Object?> _mov(String id, String type, double amount, String date,
        {String? transactionId, String? invoiceId, String? reimbursementId, String? description}) =>
    {
      'id': id,
      'transactionId': transactionId,
      'invoiceId': invoiceId,
      'reimbursementId': reimbursementId,
      'type': type,
      'amount': amount,
      'movementDate': date,
      'description': description ?? id,
    };

Future<void> createV5Database(String path, TableRows tables) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 5,
      onCreate: (db, _) async {
        for (final ddl in schemaV5.values) {
          await db.execute(ddl);
        }
      },
    ),
  );
  for (final entry in tables.entries) {
    for (final row in entry.value) {
      await db.insert(entry.key, row);
    }
  }
  await db.close();
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async => tempDir = await Directory.systemTemp.createTemp('chokin_migration_'));
  tearDown(() async => tempDir.delete(recursive: true));

  group('Conversão das tabelas (função pura)', () {
    final v6 = MigrationV6.migrateTables(sampleV5(), now: DateTime(2026, 10, 20));

    test('Todos os valores viram centavos, sem resíduos', () {
      expect(v6['transactions']!.map((t) => t['amountCents']), [217170, 29590, 20000, 6000]);
      expect(v6['transactions']!.firstWhere((t) => t['id'] == 't_tv')['refundAmountCents'], 5000);
      expect(v6['installments']!.map((i) => i['amountCents']), [6667, 6667, 1666, 6000]);
      expect(v6['invoices']!.map((i) => i['totalAmountCents']), [12667, 6667, 1666]);
      expect(v6['invoices']!.first['paidAmountCents'], 12667);
      expect(v6['reimbursements']!.single['remainingAmountCents'], 2000);
      expect(v6['reimbursement_payments']!.single['amountCents'], 4000);
      expect(v6['credit_cards']!.single['creditLimitCents'], 500000);
      expect(v6['transactions']!.first.containsKey('amount'), isFalse);
    });

    test('Estorno antigo na fatura ganha tipo próprio', () {
      final m6 = v6['financial_movements']!.firstWhere((m) => m['id'] == 'm6');
      expect(m6['type'], MovementType.cardRefund.name);
    });

    test('O saldo que o usuário via é preservado como saldo inicial', () {
      final movements = v6['financial_movements']!.map(FinancialMovement.fromMap).toList();
      expect(Ledger.balances(movements), (available: 185025, reserve: 0));

      final opening = movements.firstWhere((m) => m.id == 'opening_available');
      expect(opening.description, 'Saldo inicial');
      expect(opening.movementDate, DateTime(2026, 8, 1, 9));
    });

    test('Saldos antigos saem de app_settings e outras configurações ficam', () {
      expect(v6['app_settings'], [
        {'key': 'outra_config', 'value': 'mantida'},
      ]);
    });
  });

  group('Atualização do banco no celular (v5 -> v6)', () {
    test('Migra o arquivo, faz cópia antes e mantém os saldos', () async {
      final path = '${tempDir.path}/chokin.db';
      await createV5Database(path, sampleV5());

      String? preMigrationCopy;
      final helper = DatabaseHelper(path: path, preMigrationBackup: (json) async => preMigrationCopy = json);
      final state = await FinancialRepository(dbHelper: helper).loadFinancialState();

      expect(state.availableCents, 185025);
      expect(state.reserveCents, 0);
      expect(state.transactions.length, 4);
      expect(state.invoices.firstWhere((i) => i.month == 8).totalAmountCents, 12667);

      final db = await helper.database;
      expect(await db.getVersion(), 6);
      final columns = (await db.rawQuery('PRAGMA table_info(transactions)')).map((c) => c['name']).toSet();
      expect(columns, containsAll(['amountCents', 'refundAmountCents']));
      expect(columns.contains('amount'), isFalse);

      final copy = jsonDecode(preMigrationCopy!) as Map<String, dynamic>;
      expect(copy['version'], 1);
      expect((copy['tables']['transactions'] as List).length, 4);
      expect((copy['tables']['transactions'] as List).first['amount'], 2171.7);

      final restored = await BackupService(dbHelper: helper).importBackupFromJson(preMigrationCopy!);
      expect(restored, isTrue);
      final afterRestore = await FinancialRepository(dbHelper: helper).loadFinancialState();
      expect(afterRestore.availableCents, 185025);
      expect(afterRestore.movements.length, state.movements.length);

      await helper.close();
    });

    test('Gravação incremental escreve só o que mudou', () async {
      final path = '${tempDir.path}/chokin.db';
      await createV5Database(path, sampleV5());
      final helper = DatabaseHelper(path: path, preMigrationBackup: (_) async {});
      final repo = FinancialRepository(dbHelper: helper);
      final db = await helper.database;

      var state = await repo.loadFinancialState();
      state = FinancialMovementEngine.processNewTransaction(
        currentState: state,
        transaction: FinancialTransaction(
          id: 't_new',
          description: 'Padaria',
          amountCents: 1250,
          purchaseDate: DateTime(2026, 10, 1),
          categoryId: 'cat_other',
          paymentMethod: PaymentMethod.pix,
        ),
      );

      Future<int> totalChanges() async => (await db.rawQuery('SELECT total_changes() AS c')).first['c'] as int;
      final before = await totalChanges();
      await repo.persistFinancialState(state);
      final written = await totalChanges() - before;

      expect(written, 2);

      final reloaded = await FinancialRepository(dbHelper: helper).loadFinancialState();
      expect(reloaded.availableCents, 185025 - 1250);
      expect(reloaded.transactions.length, 5);

      final before2 = await totalChanges();
      await repo.persistFinancialState(state);
      expect(await totalChanges() - before2, 0);

      await helper.close();
    });
  });

  group('Backup', () {
    test('Exportar e restaurar no formato novo devolve os mesmos dados', () async {
      final path = '${tempDir.path}/chokin.db';
      await createV5Database(path, sampleV5());
      final helper = DatabaseHelper(path: path, preMigrationBackup: (_) async {});
      final backup = BackupService(dbHelper: helper);

      final exported = await backup.exportBackupToJson();
      expect(jsonDecode(exported)['version'], 2);

      expect(await backup.importBackupFromJson(exported), isTrue);
      expect(await backup.exportBackupToJson(), _sameTablesAs(exported));

      await helper.close();
    });

    test('O token do GitHub não sai do celular nos backups', () async {
      final path = '${tempDir.path}/chokin.db';
      final v5 = sampleV5();
      v5['app_settings']!.add({'key': 'github_token', 'value': 'segredo-do-celular'});
      await createV5Database(path, v5);

      String? preMigrationCopy;
      final helper = DatabaseHelper(path: path, preMigrationBackup: (json) async => preMigrationCopy = json);
      final backup = BackupService(dbHelper: helper);

      final exported = await backup.exportBackupToJson();
      expect(exported.contains('segredo-do-celular'), isFalse);
      expect(preMigrationCopy!.contains('segredo-do-celular'), isFalse);

      expect(await backup.importBackupFromJson(exported), isTrue);
      final db = await helper.database;
      final token = await db.query('app_settings', where: 'key = ?', whereArgs: ['github_token']);
      expect(token.single['value'], 'segredo-do-celular');

      await helper.close();
    });

    test('Um arquivo inválido não apaga nada', () async {
      final path = '${tempDir.path}/chokin.db';
      await createV5Database(path, sampleV5());
      final helper = DatabaseHelper(path: path, preMigrationBackup: (_) async {});
      final backup = BackupService(dbHelper: helper);

      final broken = jsonEncode({
        'version': 2,
        'tables': {
          'transactions': [
            {'id': 'x', 'naoExiste': 1},
          ],
        },
      });
      expect(await backup.importBackupFromJson(broken), isFalse);

      final state = await FinancialRepository(dbHelper: helper).loadFinancialState();
      expect(state.transactions.length, 4);
      expect(state.availableCents, 185025);

      await helper.close();
    });
  });

  final realBackupPath = Platform.environment['CHOKIN_REAL_BACKUP'];
  group('Backup real do usuário', () {
    test('Migra sem perder nada e mantém saldo e caixinha', () async {
      final original = jsonDecode(File(realBackupPath!).readAsStringSync()) as Map<String, dynamic>;
      final v5Tables = <String, List<Map<String, Object?>>>{
        for (final e in (original['tables'] as Map<String, dynamic>).entries)
          e.key: [for (final r in e.value as List) Map<String, Object?>.from(r as Map)],
      };
      final settings = {for (final r in v5Tables['app_settings']!) r['key']: r['value']};
      final expectedAvailable = (double.parse(settings['available_balance'] as String) * 100).round();
      final expectedReserve = (double.parse(settings['reserve_balance'] as String) * 100).round();

      final path = '${tempDir.path}/real.db';
      await createV5Database(path, v5Tables);
      final helper = DatabaseHelper(path: path, preMigrationBackup: (_) async {});
      final state = await FinancialRepository(dbHelper: helper).loadFinancialState();

      expect(state.availableCents, expectedAvailable);
      expect(state.reserveCents, expectedReserve);
      expect(state.people.length, v5Tables['people']!.length);
      expect(state.cards.length, v5Tables['credit_cards']!.length);
      expect(state.transactions.length, v5Tables['transactions']!.length);
      expect(state.installments.length, v5Tables['installments']!.length);
      expect(state.invoices.length, v5Tables['invoices']!.length);
      expect(state.reimbursements.length, v5Tables['reimbursements']!.length);
      expect(state.reimbursements.expand((r) => r.payments).length, v5Tables['reimbursement_payments']!.length);
      final openings = state.movements.where((m) => m.id.startsWith('opening_')).length;
      expect(state.movements.length, v5Tables['financial_movements']!.length + openings);

      int cents(Object? v) => ((v as num) * 100).round();
      final txById = {for (final t in state.transactions) t.id: t};
      for (final t in v5Tables['transactions']!) {
        expect(txById[t['id']]!.amountCents, cents(t['amount']), reason: 'transação ${t['id']}');
      }
      final invById = {for (final i in state.invoices) i.id: i};
      for (final i in v5Tables['invoices']!) {
        expect(invById[i['id']]!.totalAmountCents, cents(i['totalAmount']), reason: 'fatura ${i['id']}');
      }
      final reimbById = {for (final r in state.reimbursements) r.id: r};
      for (final r in v5Tables['reimbursements']!) {
        expect(reimbById[r['id']]!.remainingAmountCents, cents(r['remainingAmount']), reason: 'cobrança ${r['id']}');
      }

      for (final inv in state.invoices) {
        final sum = state.installments.where((i) => i.invoiceId == inv.id).fold<int>(0, (a, i) => a + i.amountCents);
        expect(inv.totalAmountCents, sum, reason: 'fatura ${inv.id}');
      }

      final now = DateTime.now();
      final horizon = DateTime(now.year, now.month + 12, 1);
      final synced = FinancialMovementEngine.syncRecurringTransactions(
        currentState: state,
        targetMonth: horizon.month,
        targetYear: horizon.year,
      );
      expect(synced.availableCents, expectedAvailable);
      expect(synced.reserveCents, expectedReserve);
      await FinancialRepository(dbHelper: helper).persistFinancialState(synced);

      final freshHelper = DatabaseHelper(path: '${tempDir.path}/fresh.db', preMigrationBackup: (_) async {});
      final restored =
          await BackupService(dbHelper: freshHelper).importBackupFromJson(File(realBackupPath).readAsStringSync());
      expect(restored, isTrue);
      final fromBackup = await FinancialRepository(dbHelper: freshHelper).loadFinancialState();
      expect(fromBackup.availableCents, expectedAvailable);
      expect(fromBackup.reserveCents, expectedReserve);
      expect(fromBackup.transactions.length, v5Tables['transactions']!.length);

      await helper.close();
      await freshHelper.close();
    });
  },
      skip: realBackupPath == null || !File(realBackupPath).existsSync()
          ? 'Defina CHOKIN_REAL_BACKUP para rodar'
          : false);
}

Matcher _sameTablesAs(String exportedJson) {
  Map<String, dynamic> tables(String json) =>
      (jsonDecode(json) as Map<String, dynamic>)['tables'] as Map<String, dynamic>;
  final expected = tables(exportedJson);
  return predicate<String>(
      (actual) => jsonEncode(tables(actual)) == jsonEncode(expected), 'mesmas tabelas do backup exportado');
}
