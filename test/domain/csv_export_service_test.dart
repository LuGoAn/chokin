import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/core/utils/date_time_utils.dart';
import 'package:chokin/data/export/csv_export_service.dart';
import 'package:chokin/domain/engine/financial_movement_engine.dart';
import 'package:chokin/domain/entities/category.dart';
import 'package:chokin/domain/entities/transaction.dart';

void main() {
  group('CsvExportService Tests', () {
    final catFood = Category(id: 'cat_food', name: 'Alimentação', icon: 'fastfood', colorHex: '0xFFFF0000', type: 'EXPENSE');
    final catSalary = Category(id: 'cat_salary', name: 'Salário', icon: 'attach_money', colorHex: '0xFF00FF00', type: 'INCOME');

    final tx1 = FinancialTransaction(
      id: 'tx_1',
      description: 'Supermercado Central',
      amount: 150.50,
      purchaseDate: DateTime(2026, 9, 10, 14, 0),
      categoryId: 'cat_food',
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.creditCard,
    );

    final tx2 = FinancialTransaction(
      id: 'tx_2',
      description: 'Salário Mensal',
      amount: 4000.00,
      purchaseDate: DateTime(2026, 9, 5, 10, 0),
      categoryId: 'cat_salary',
      type: TransactionType.income,
      paymentMethod: PaymentMethod.pix,
    );

    final tx3 = FinancialTransaction(
      id: 'tx_3',
      description: 'Restaurante Outubro',
      amount: 80.00,
      purchaseDate: DateTime(2026, 10, 2, 12, 0),
      categoryId: 'cat_food',
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.pix,
    );

    final state = FinancialState(
      transactions: [tx1, tx2, tx3],
    );

    test('Exports specific month correctly (September 2026)', () {
      final csv = CsvExportService.generateCsv(
        state: state,
        categories: [catFood, catSalary],
        options: const CsvExportOptions(
          scope: CsvExportScope.specificMonth,
          month: 9,
          year: 2026,
        ),
      );

      expect(csv.contains('Data;Mês/Ano;Descrição;Categoria;Tipo;Forma de Pagamento;Parcela;Pessoa;Valor (R\$)'), isTrue);
      expect(csv.contains('Supermercado Central'), isTrue);
      expect(csv.contains('Salário Mensal'), isTrue);
      expect(csv.contains('Restaurante Outubro'), isFalse);
    });

    test('Exports entire year with month sections (Year 2026)', () {
      final csv = CsvExportService.generateCsv(
        state: state,
        categories: [catFood, catSalary],
        options: const CsvExportOptions(
          scope: CsvExportScope.entireYear,
          year: 2026,
        ),
      );

      expect(csv.contains('Supermercado Central'), isTrue);
      expect(csv.contains('Salário Mensal'), isTrue);
      expect(csv.contains('Restaurante Outubro'), isTrue);
      expect(csv.contains(DateTimeUtils.formatMonthYear(DateTime(2026, 9))), isTrue);
      expect(csv.contains(DateTimeUtils.formatMonthYear(DateTime(2026, 10))), isTrue);
    });
  });
}
