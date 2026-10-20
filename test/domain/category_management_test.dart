import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/domain/entities/category.dart';

void main() {
  group('Category Domain & Filtering Tests', () {
    test('Default categories correctly separate expense and income', () {
      final defaults = Category.defaultCategories();
      final expenses = defaults.where((c) => c.isExpense).toList();
      final incomes = defaults.where((c) => c.isIncome).toList();

      expect(expenses.isNotEmpty, isTrue);
      expect(incomes.isNotEmpty, isTrue);

      expect(expenses.any((c) => c.id == 'cat_food'), isTrue);
      expect(expenses.any((c) => c.id == 'cat_transport'), isTrue);
      expect(expenses.any((c) => c.id == 'cat_salary'), isFalse);

      expect(incomes.any((c) => c.id == 'cat_salary'), isTrue);
      expect(incomes.any((c) => c.id == 'cat_freelance'), isTrue);
      expect(incomes.any((c) => c.id == 'cat_food'), isFalse);
    });

    test('Category serialization and deserialization with displayOrder', () {
      const cat = Category(
        id: 'cat_test_1',
        name: 'Investimentos',
        icon: 'trending_up',
        colorHex: '0xFFF59E0B',
        type: 'INCOME',
        isCustom: true,
        displayOrder: 4,
      );

      final map = cat.toMap();
      expect(map['displayOrder'], 4);
      expect(map['type'], 'INCOME');
      expect(map['isCustom'], 1);

      final fromMap = Category.fromMap(map);
      expect(fromMap.id, 'cat_test_1');
      expect(fromMap.name, 'Investimentos');
      expect(fromMap.displayOrder, 4);
      expect(fromMap.isIncome, isTrue);
      expect(fromMap.isExpense, isFalse);
    });

    test('Category copyWith updates displayOrder correctly', () {
      const cat = Category(
        id: 'cat_test_2',
        name: 'Lazer',
        icon: 'sports_esports',
        colorHex: '0xFFEC4899',
        type: 'EXPENSE',
        displayOrder: 0,
      );

      final updated = cat.copyWith(displayOrder: 5, name: 'Jogos & Lazer');
      expect(updated.displayOrder, 5);
      expect(updated.name, 'Jogos & Lazer');
      expect(updated.id, 'cat_test_2');
    });
  });
}
