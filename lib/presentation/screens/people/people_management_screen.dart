import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../../domain/entities/person.dart';
import '../../state/financial_state_notifier.dart';

class PeopleManagementScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const PeopleManagementScreen({super.key, required this.notifier});

  @override
  State<PeopleManagementScreen> createState() => _PeopleManagementScreenState();
}

class _PeopleManagementScreenState extends State<PeopleManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        final state = widget.notifier.state;
        final people = List.of(state.people)
          ..sort((a, b) => a.isMe != b.isMe ? (a.isMe ? -1 : 1) : a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pessoas'),
            actions: [
              IconButton(
                  tooltip: 'Nova pessoa', icon: const Icon(Icons.add), onPressed: () => _showPersonDialog(context)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(Sumi.gutter, 4, Sumi.gutter, 32),
            children: [
              const Text(
                'Quando uma compra é para outra pessoa, ela vira uma cobrança e fica fora do seu gasto pessoal.',
                style: Sumi.caption,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < people.length; i++)
                _buildPersonRow(context, state, people[i], isLast: i == people.length - 1),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child:
                    OutlinedButton(onPressed: () => _showPersonDialog(context), child: const Text('Adicionar pessoa')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonRow(BuildContext context, FinancialState state, Person person, {required bool isLast}) {
    final pending = state.reimbursements.where((r) => r.personId == person.id && !r.isSettled).toList();
    final pendingCents = pending.fold<int>(0, (acc, r) => acc + r.remainingAmountCents);
    final details = [
      if (person.phone != null && person.phone!.isNotEmpty) person.phone!,
      if (person.isMe)
        'seus gastos pessoais'
      else if (pendingCents > 0)
        'a receber ${CurrencyUtils.formatCents(pendingCents)} em ${pending.length} compra${pending.length > 1 ? 's' : ''}'
      else
        'nada pendente',
    ];

    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: AppColors.border),
          bottom: isLast ? const BorderSide(color: AppColors.border) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(person.name, style: Sumi.bodyStrong)),
                      if (person.isMe) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'VOCÊ',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(details.join(' · '), style: Sumi.caption),
                ],
              ),
            ),
          ),
          if (!person.isMe) ...[
            IconButton(
              tooltip: 'Editar ${person.name}',
              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
              onPressed: () => _showPersonDialog(context, personToEdit: person),
            ),
            IconButton(
              tooltip: 'Excluir ${person.name}',
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSecondary),
              onPressed: () => _confirmDeletePerson(context, person, pendingCents / 100),
            ),
          ],
        ],
      ),
    );
  }

  void _showPersonDialog(BuildContext context, {Person? personToEdit}) {
    final nameCtrl = TextEditingController(text: personToEdit?.name ?? '');
    final phoneCtrl = TextEditingController(text: personToEdit?.phone ?? '');
    final isEditing = personToEdit != null;

    showDialog(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isEditing ? 'Editar pessoa' : 'Nova pessoa',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nome da Pessoa',
                  hintText: 'Ex: Mãe, Herbert, João...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Telefone / WhatsApp (Opcional)',
                  hintText: '(85) 99999-9999',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                if (isEditing) {
                  final updated = personToEdit.copyWith(
                    name: name,
                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                  );
                  await widget.notifier.updatePerson(updated);
                } else {
                  await widget.notifier.addPerson(
                    name,
                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                  );
                }

                if (dCtx.mounted) Navigator.of(dCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEditing ? 'Pessoa atualizada!' : 'Pessoa adicionada!')),
                  );
                }
              },
              child: Text(isEditing ? 'Salvar' : 'Adicionar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePerson(BuildContext context, Person person, double pendingTotal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Excluir pessoa?'),
          content: Text(
            pendingTotal > 0
                ? 'Atenção: "${person.name}" possui ${CurrencyUtils.format(pendingTotal)} em cobranças pendentes.\n\nDeseja realmente remover o cadastro?'
                : 'Deseja remover o cadastro de "${person.name}"?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.notifier.deletePerson(person.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pessoa "${person.name}" removida com sucesso.')),
        );
      }
    }
  }
}
