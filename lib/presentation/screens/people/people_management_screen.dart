import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
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
        final people = state.people;
        final reimbursements = state.reimbursements;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gerenciar Pessoas', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                tooltip: 'Nova Pessoa',
                icon: const Icon(Icons.person_add, color: AppColors.primary),
                onPressed: () => _showPersonDialog(context),
              ),
            ],
          ),
          body: people.isEmpty
              ? const Center(
                  child: Text('Nenhuma pessoa cadastrada.', style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: people.length,
                  itemBuilder: (ctx, index) {
                    final person = people[index];
                    final isMe = person.isMe;

                    final personReimbursements = reimbursements.where((r) => r.personId == person.id && !r.isSettled).toList();
                    final pendingTotal = personReimbursements.fold<double>(0.0, (acc, r) => acc + r.remainingAmount);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: pendingTotal > 0 ? AppColors.reimbursement.withValues(alpha: 0.3) : AppColors.border,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: isMe
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.reimbursement.withValues(alpha: 0.15),
                          child: Icon(
                            isMe ? Icons.account_circle : Icons.person_outline,
                            color: isMe ? AppColors.primaryLight : AppColors.reimbursement,
                            size: 24,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                person.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'EU / TITULAR',
                                  style: TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (person.phone != null && person.phone!.isNotEmpty)
                              Text(
                                'Tel: ${person.phone}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            if (!isMe)
                              Text(
                                pendingTotal > 0
                                    ? 'A receber: ${CurrencyUtils.format(pendingTotal)} (${personReimbursements.length} pendência${personReimbursements.length > 1 ? "s" : ""})'
                                    : 'Nenhum valor pendente',
                                style: TextStyle(
                                  color: pendingTotal > 0 ? AppColors.reimbursement : AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: pendingTotal > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        trailing: isMe
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                                    onPressed: () => _showPersonDialog(context, personToEdit: person),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
                                    onPressed: () => _confirmDeletePerson(context, person, pendingTotal),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Nova Pessoa', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => _showPersonDialog(context),
          ),
        );
      },
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
            isEditing ? 'Editar Pessoa' : 'Adicionar Pessoa',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
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
          title: const Text('Excluir Pessoa?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
