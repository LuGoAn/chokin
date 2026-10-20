import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../domain/entities/category.dart';
import '../../widgets/sumi_widgets.dart';
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

class _CategoriesManagementScreenState extends State<CategoriesManagementScreen> {
  bool _showIncome = false;

  Color _parseColor(String? hex) {
    try {
      return Color(int.parse(hex ?? ''));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        final all = widget.notifier.categories;
        final expense = all.where((c) => c.isExpense).toList();
        final income = all.where((c) => c.isIncome).toList();
        final list = _showIncome ? income : expense;
        final listType = _showIncome ? 'INCOME' : 'EXPENSE';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Categorias'),
            actions: [
              IconButton(
                tooltip: 'Nova categoria',
                icon: const Icon(Icons.add),
                onPressed: () => _showCategoryDialog(context, defaultType: listType),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 8),
                child: SegmentedChoice<bool>(
                  underline: true,
                  options: [(false, 'Despesas (${expense.length})'), (true, 'Receitas (${income.length})')],
                  value: _showIncome,
                  onChanged: (v) => setState(() => _showIncome = v),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Sumi.gutter, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.drag_handle, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Arraste pela alça para mudar a ordem em que aparecem no lançamento.',
                        style: Sumi.caption,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildCategoryList(context, list, listType)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryList(BuildContext context, List<Category> list, String listType) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(Sumi.gutter, 8, Sumi.gutter, 32),
      buildDefaultDragHandles: false,
      itemCount: list.length,
      footer: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _showCategoryDialog(context, defaultType: listType),
            child: Text(listType == 'INCOME' ? 'Nova categoria de receita' : 'Nova categoria de despesa'),
          ),
        ),
      ),
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) newIndex -= 1;
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        final all = List<Category>.from(widget.notifier.categories)
          ..removeWhere((c) => listType == 'EXPENSE' ? c.isExpense : c.isIncome)
          ..addAll(list);
        widget.notifier.reorderCategories(all);
      },
      itemBuilder: (context, index) {
        final cat = list[index];
        return Container(
          key: ValueKey(cat.id),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: const BorderSide(color: AppColors.border),
              bottom: index == list.length - 1 ? const BorderSide(color: AppColors.border) : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _parseColor(cat.colorHex), shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Icon(CategoriesManagementScreen.getIconData(cat.icon), size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name, style: Sumi.body),
                    if (cat.type == 'BOTH') const Text('despesa e receita', style: Sumi.caption),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar ${cat.name}',
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                onPressed: () => _showCategoryDialog(context, existingCategory: cat),
              ),
              IconButton(
                tooltip: 'Excluir ${cat.name}',
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                onPressed: () => _confirmDeleteCategory(context, cat),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20, semanticLabel: 'Arrastar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryDialog(BuildContext context, {Category? existingCategory, String defaultType = 'EXPENSE'}) {
    final isEditing = existingCategory != null;
    final nameCtrl = TextEditingController(text: existingCategory?.name ?? '');
    var selectedIcon = existingCategory?.icon ?? (defaultType == 'INCOME' ? 'account_balance_wallet' : 'restaurant');
    var selectedColorHex = existingCategory?.colorHex ?? (defaultType == 'INCOME' ? '0xFF10B981' : '0xFFEF4444');
    var selectedType = existingCategory?.type ?? defaultType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Sumi.gutter, 0, Sumi.gutter, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEditing ? 'Editar categoria' : 'Nova categoria',
                        style: Sumi.bodyStrong.copyWith(fontSize: 18)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      style: Sumi.body,
                      decoration: underlineDecoration('Nome', hint: 'Ex: Academia, Pet, Freelance'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Vale para', style: Sumi.caption),
                    const SizedBox(height: 8),
                    SegmentedChoice<String>(
                      options: const [('EXPENSE', 'Despesa'), ('INCOME', 'Receita'), ('BOTH', 'As duas')],
                      value: selectedType,
                      onChanged: (v) => setSheet(() => selectedType = v),
                    ),
                    const SizedBox(height: 20),
                    const Text('Ícone', style: Sumi.caption),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in CategoriesManagementScreen.categoryIcons)
                          Builder(builder: (context) {
                            final key = item['key'] as String;
                            final selected = key == selectedIcon;
                            return Semantics(
                              button: true,
                              selected: selected,
                              label: item['label'] as String,
                              child: InkWell(
                                onTap: () => setSheet(() => selectedIcon = key),
                                borderRadius: BorderRadius.circular(Sumi.radius),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.textPrimary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(Sumi.radius),
                                    border:
                                        Border.all(color: selected ? AppColors.textPrimary : AppColors.borderStrong),
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    size: 20,
                                    color: selected ? AppColors.background : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Cor', style: Sumi.caption),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in CategoriesManagementScreen.categoryColors)
                          Semantics(
                            button: true,
                            selected: c['hex'] == selectedColorHex,
                            label: c['name'] as String,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => setSheet(() => selectedColorHex = c['hex'] as String),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c['hex'] == selectedColorHex ? AppColors.textPrimary : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(color: c['color'] as Color, shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Informe o nome da categoria.')),
                            );
                            return;
                          }
                          final newCat = Category(
                            id: existingCategory?.id ?? 'cat_custom_${const Uuid().v4()}',
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
                              SnackBar(content: Text(isEditing ? 'Categoria atualizada.' : 'Categoria criada.')),
                            );
                          }
                        },
                        child: Text(isEditing ? 'Salvar alterações' : 'Criar categoria'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Excluir categoria?'),
        content: Text('A categoria "${category.name}" será excluída. Os lançamentos que a usam continuam no extrato.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(dCtx).pop(true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      await widget.notifier.deleteCategory(category.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria excluída.')));
      }
    }
  }
}
