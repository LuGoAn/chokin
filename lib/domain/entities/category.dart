class Category {
  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final String type;
  final bool isCustom;
  final int displayOrder;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    this.type = 'EXPENSE',
    this.isCustom = false,
    this.displayOrder = 0,
  });

  bool get isIncome => type == 'INCOME' || type == 'BOTH';
  bool get isExpense => type == 'EXPENSE' || type == 'BOTH';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'colorHex': colorHex,
      'type': type,
      'isCustom': isCustom ? 1 : 0,
      'displayOrder': displayOrder,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      colorHex: map['colorHex'] as String,
      type: map['type'] as String? ?? 'EXPENSE',
      isCustom: (map['isCustom'] as int? ?? 0) == 1,
      displayOrder: map['displayOrder'] as int? ?? 0,
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? colorHex,
    String? type,
    bool? isCustom,
    int? displayOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      type: type ?? this.type,
      isCustom: isCustom ?? this.isCustom,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  static List<Category> defaultCategories() {
    return [
      const Category(id: 'cat_food', name: 'Alimentação', icon: 'restaurant', colorHex: '0xFFEF4444', type: 'EXPENSE', displayOrder: 0),
      const Category(id: 'cat_transport', name: 'Transporte', icon: 'directions_car', colorHex: '0xFFF59E0B', type: 'EXPENSE', displayOrder: 1),
      const Category(id: 'cat_home', name: 'Moradia / Casa', icon: 'home', colorHex: '0xFFD97706', type: 'EXPENSE', displayOrder: 2),
      const Category(id: 'cat_education', name: 'Educação', icon: 'school', colorHex: '0xFF3B82F6', type: 'EXPENSE', displayOrder: 3),
      const Category(id: 'cat_subscriptions', name: 'Assinaturas / Streaming', icon: 'subscriptions', colorHex: '0xFF8B5CF6', type: 'EXPENSE', displayOrder: 4),
      const Category(id: 'cat_leisure', name: 'Lazer & Jogos', icon: 'sports_esports', colorHex: '0xFFEC4899', type: 'EXPENSE', displayOrder: 5),
      const Category(id: 'cat_health', name: 'Saúde & Farmácia', icon: 'medical_services', colorHex: '0xFF10B981', type: 'EXPENSE', displayOrder: 6),
      const Category(id: 'cat_tech', name: 'Tecnologia', icon: 'computer', colorHex: '0xFF06B6D4', type: 'EXPENSE', displayOrder: 7),
      const Category(id: 'cat_clothing', name: 'Roupas & Vestuário', icon: 'checkroom', colorHex: '0xFF64748B', type: 'EXPENSE', displayOrder: 8),
      const Category(id: 'cat_other_expense', name: 'Outras Despesas', icon: 'category', colorHex: '0xFF94A3B8', type: 'EXPENSE', displayOrder: 9),

      const Category(id: 'cat_salary', name: 'Salário Principal', icon: 'account_balance_wallet', colorHex: '0xFF10B981', type: 'INCOME', displayOrder: 0),
      const Category(id: 'cat_freelance', name: 'Freelance & Serviços', icon: 'work_outline', colorHex: '0xFF3B82F6', type: 'INCOME', displayOrder: 1),
      const Category(id: 'cat_investments', name: 'Rendimentos & Dividendos', icon: 'trending_up', colorHex: '0xFFF59E0B', type: 'INCOME', displayOrder: 2),
      const Category(id: 'cat_gift', name: 'Presente & Mesada', icon: 'card_giftcard', colorHex: '0xFFEC4899', type: 'INCOME', displayOrder: 3),
      const Category(id: 'cat_cashback', name: 'Cashback & Estornos', icon: 'savings', colorHex: '0xFF06B6D4', type: 'INCOME', displayOrder: 4),
      const Category(id: 'cat_other_income', name: 'Outras Receitas', icon: 'attach_money', colorHex: '0xFF8B5CF6', type: 'INCOME', displayOrder: 5),
    ];
  }
}
