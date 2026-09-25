import 'package:flutter/material.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/category.dart';
import '../../state/financial_state_notifier.dart';

class CategoriesManagementScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const CategoriesManagementScreen({super.key, required this.notifier});

  static const List<Map<String, dynamic>> categoryColors = [
    {'name': 'Vermelho', 'hex': '0xFFEF4444', 'color': Color(0xFFEF4444)},
    {'name': 'Laranja', 'hex': '0xFFF59E0B', 'color': Color(0xFFF59E0B)},
    {'name': 'Âmbar', 'hex': '0xFFD97706', 'color': Color(0xFFD97706)},
    {'name': 'Verde', 'hex': '0xFF10B981', 'color': Color(0xFF10B981)},
    {'name': 'Esmeralda Claro', 'hex': '0xFF34D399', 'color': Color(0xFF34D399)},
    {'name': 'Ciano', 'hex': '0xFF06B6D4', 'color': Color(0xFF06B6D4)},
    {'name': 'Azul', 'hex': '0xFF3B82F6', 'color': Color(0xFF3B82F6)},
    {'name': 'Roxo', 'hex': '0xFF8B5CF6', 'color': Color(0xFF8B5CF6)},
    {'name': 'Rosa', 'hex': '0xFFEC4899', 'color': Color(0xFFEC4899)},
    {'name': 'Cinza Grafite', 'hex': '0xFF64748B', 'color': Color(0xFF64748B)},
  ];

  static const List<Map<String, dynamic>> categoryIcons = [
    {'key': 'restaurant', 'icon': Icons.restaurant, 'label': 'Comida'},
    {'key': 'directions_car', 'icon': Icons.directions_car, 'label': 'Carro'},
    {'key': 'home', 'icon': Icons.home, 'label': 'Casa'},
    {'key': 'school', 'icon': Icons.school, 'label': 'Educação'},
    {'key': 'subscriptions', 'icon': Icons.subscriptions, 'label': 'Streaming'},
    {'key': 'sports_esports', 'icon': Icons.sports_esports, 'label': 'Jogos'},
    {'key': 'medical_services', 'icon': Icons.medical_services, 'label': 'Saúde'},
    {'key': 'computer', 'icon': Icons.computer, 'label': 'Tecnologia'},
    {'key': 'checkroom', 'icon': Icons.checkroom, 'label': 'Roupas'},
    {'key': 'shopping_cart', 'icon': Icons.shopping_cart, 'label': 'Mercado'},
    {'key': 'account_balance_wallet', 'icon': Icons.account_balance_wallet, 'label': 'Salário'},
    {'key': 'work_outline', 'icon': Icons.work_outline, 'label': 'Trabalho'},
    {'key': 'trending_up', 'icon': Icons.trending_up, 'label': 'Investimentos'},
    {'key': 'card_giftcard', 'icon': Icons.card_giftcard, 'label': 'Presente'},
    {'key': 'savings', 'icon': Icons.savings, 'label': 'Poupança'},
    {'key': 'attach_money', 'icon': Icons.attach_money, 'label': 'Dinheiro'},
    {'key': 'local_gas_station', 'icon': Icons.local_gas_station, 'label': 'Combustível'},
    {'key': 'pets', 'icon': Icons.pets, 'label': 'Pet'},
    {'key': 'fitness_center', 'icon': Icons.fitness_center, 'label': 'Academia'},
    {'key': 'flight', 'icon': Icons.flight, 'label': 'Viagem'},
    {'key': 'category', 'icon': Icons.category, 'label': 'Geral'},
  ];

  static IconData getIconData(String iconKey) {
    final found = categoryIcons.firstWhere(
      (item) => item['key'] == iconKey,
      orElse: () => {'icon': Icons.category},
    );
    return found['icon'] as IconData;
  }

  @override
  State<CategoriesManagementScreen> createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends State<CategoriesManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  IconData _getIconData(String iconKey) => CategoriesManagementScreen.getIconData(iconKey);
  List<Map<String, dynamic>> get _categoryIcons => CategoriesManagementScreen.categoryIcons;
  List<Map<String, dynamic>> get _categoryColors => CategoriesManagementScreen.categoryColors;

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF3B82F6);
    try {
      return Color(int.parse(hex));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        final allCategories = widget.notifier.categories;
        final expenseCategories = allCategories.where((c) => c.isExpense).toList();
        final incomeCategories = allCategories.where((c) => c.isIncome).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gerenciar Categorias', style: TextStyle(fontWeight: FontWeight.bold)),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  text: 'Despesas (${expenseCategories.length})',
                ),
                Tab(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  text: 'Receitas (${incomeCategories.length})',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(expenseCategories, 'EXPENSE'),
              _buildCategoryList(incomeCategories, 'INCOME'),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final defaultType = _tabController.index == 0 ? 'EXPENSE' : 'INCOME';
              _showCategoryDialog(context, defaultType: defaultType);
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Nova Categoria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildCategoryList(List<Category> list, String listType) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Nenhuma categoria de ${listType == "EXPENSE" ? "despesa" : "receita"} cadastrada.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surface.withValues(alpha: 0.5),
          child: const Row(
            children: [
              Icon(Icons.drag_indicator, size: 16, color: AppColors.textMuted),
              SizedBox(width: 8),
              Text(
                'Arraste pelo ícone da direita para reordenar a prioridade',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
            itemCount: list.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);

              // Atualiza lista completa respeitando a nova ordem deste tipo
              final all = List<Category>.from(widget.notifier.categories);
              all.removeWhere((c) => listType == 'EXPENSE' ? c.isExpense : c.isIncome);
              all.addAll(list);
              widget.notifier.reorderCategories(all);
            },
            itemBuilder: (context, index) {
              final cat = list[index];
              final color = _parseColor(cat.colorHex);
              final iconData = _getIconData(cat.icon);

              return Container(
                key: ValueKey(cat.id),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(iconData, color: color, size: 20),
                  ),
                  title: Text(
                    cat.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    cat.type == 'BOTH' ? 'Despesa & Receita' : (cat.type == 'INCOME' ? 'Receita' : 'Despesa'),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                        tooltip: 'Editar',
                        onPressed: () => _showCategoryDialog(context, existingCategory: cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.expense),
                        tooltip: 'Excluir',
                        onPressed: () => _confirmDeleteCategory(context, cat),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCategoryDialog(BuildContext context, {Category? existingCategory, String defaultType = 'EXPENSE'}) {
    final isEditing = existingCategory != null;
    final nameCtrl = TextEditingController(text: existingCategory?.name ?? '');
    String selectedIcon = existingCategory?.icon ?? (defaultType == 'INCOME' ? 'account_balance_wallet' : 'restaurant');
    String selectedColorHex = existingCategory?.colorHex ?? (defaultType == 'INCOME' ? '0xFF10B981' : '0xFFEF4444');
    String selectedType = existingCategory?.type ?? defaultType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentColor = _parseColor(selectedColorHex);
            final currentIcon = _getIconData(selectedIcon);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Editar Categoria' : 'Nova Categoria',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Preview Visual da Categoria
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: currentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: currentColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundColor: currentColor,
                              radius: 18,
                              child: Icon(currentIcon, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              nameCtrl.text.isEmpty ? 'Nome da Categoria' : nameCtrl.text,
                              style: TextStyle(fontWeight: FontWeight.bold, color: currentColor, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Nome
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nome da Categoria',
                        hintText: 'Ex: Academia, Salário, Jogos...',
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Tipo de Categoria (Despesa / Receita)
                    const Text('Aplicável para:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedType = 'EXPENSE'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedType == 'EXPENSE' ? AppColors.expense.withValues(alpha: 0.2) : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: selectedType == 'EXPENSE' ? AppColors.expense : AppColors.border),
                              ),
                              child: Center(
                                child: Text('Despesa', style: TextStyle(fontWeight: FontWeight.bold, color: selectedType == 'EXPENSE' ? AppColors.expense : AppColors.textSecondary)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedType = 'INCOME'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedType == 'INCOME' ? AppColors.income.withValues(alpha: 0.2) : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: selectedType == 'INCOME' ? AppColors.income : AppColors.border),
                              ),
                              child: Center(
                                child: Text('Receita', style: TextStyle(fontWeight: FontWeight.bold, color: selectedType == 'INCOME' ? AppColors.income : AppColors.textSecondary)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Seletor de Ícone
                    const Text('Escolha um Ícone', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _categoryIcons.length,
                        itemBuilder: (context, i) {
                          final item = _categoryIcons[i];
                          final key = item['key'] as String;
                          final icon = item['icon'] as IconData;
                          final isSelected = selectedIcon == key;

                          return GestureDetector(
                            onTap: () => setModalState(() => selectedIcon = key),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? currentColor.withValues(alpha: 0.2) : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? currentColor : AppColors.border, width: isSelected ? 2 : 1),
                              ),
                              child: Icon(icon, color: isSelected ? currentColor : AppColors.textSecondary, size: 20),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Seletor de Cores
                    const Text('Cor da Categoria', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categoryColors.map((colorItem) {
                        final hex = colorItem['hex'] as String;
                        final color = colorItem['color'] as Color;
                        final isSelected = selectedColorHex == hex;

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedColorHex = hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Botão Salvar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Informe o nome da categoria.')),
                            );
                            return;
                          }

                          final catId = existingCategory?.id ?? 'cat_custom_${const Uuid().v4()}';
                          final newCat = Category(
                            id: catId,
                            name: name,
                            icon: selectedIcon,
                            colorHex: selectedColorHex,
                            type: selectedType,
                            isCustom: true,
                            displayOrder: existingCategory?.displayOrder ?? 999,
                          );

                          if (isEditing) {
                            await widget.notifier.updateCategory(newCat);
                          } else {
                            await widget.notifier.addCategory(newCat);
                          }

                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Categoria atualizada!' : 'Categoria criada com sucesso!')),
                            );
                          }
                        },
                        child: Text(isEditing ? 'Salvar Alterações' : 'Criar Categoria'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir Categoria', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Tem certeza que deseja excluir a categoria "${category.name}"?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.notifier.deleteCategory(category.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoria excluída com sucesso!')),
        );
      }
    }
  }
}
