import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../data/backup/backup_service.dart';
import '../../../data/export/csv_export_service.dart';
import '../categories/categories_management_screen.dart';
import '../people/people_management_screen.dart';
import '../../../domain/engine/financial_movement_engine.dart';
import '../../../services/update_service.dart';
import '../../state/financial_state_notifier.dart';

class SettingsScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const SettingsScreen({super.key, required this.notifier});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool _notificationAccessGranted = false;
  bool _serviceConnected = false;
  AutoBackupFrequency _autoBackupFreq = AutoBackupFrequency.disabled;
  DateTime? _lastAutoBackupDate;
  String? _backupDirPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _loadAutoBackupSettings();
  }

  Future<void> _loadAutoBackupSettings() async {
    final freq = await widget.notifier.backupService.getAutoBackupFrequency();
    final last = await widget.notifier.backupService.getLastAutoBackupDate();
    final dir = await widget.notifier.backupService.getBackupDirectory();
    if (mounted) {
      setState(() {
        _autoBackupFreq = freq;
        _lastAutoBackupDate = last;
        _backupDirPath = dir.path;
      });
    }
  }

  String _autoBackupLabel(AutoBackupFrequency freq) {
    switch (freq) {
      case AutoBackupFrequency.disabled:
        return 'Desativado';
      case AutoBackupFrequency.daily:
        return 'Diário (Todo dia)';
      case AutoBackupFrequency.everyThreeDays:
        return 'A cada 3 dias';
      case AutoBackupFrequency.weekly:
        return 'Semanal (Toda semana)';
      case AutoBackupFrequency.monthly:
        return 'Mensal (Todo mês)';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await widget.notifier.notificationBridge.checkPermission();
    final connected = await widget.notifier.notificationBridge.isServiceConnected();
    if (mounted) {
      setState(() {
        _notificationAccessGranted = granted;
        _serviceConnected = connected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.notifier.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações & Backup', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Ajuste de Saldos Iniciais & Categorias
          _buildSectionHeader('Finanças & Pessoas'),
          Builder(
            builder: (_) {
              final now = DateTime.now();
              final (currentAvail, currentReserve) = FinancialMovementEngine.calculateHistoricalBalances(
                state: state,
                month: now.month,
                year: now.year,
              );
              return _buildSettingsTile(
                icon: Icons.account_balance,
                title: 'Configurar Saldo Inicial',
                subtitle: 'Saldo configurado: ${CurrencyUtils.format(currentAvail + currentReserve)}',
                onTap: _showInitialBalancesDialog,
              );
            },
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            icon: Icons.people_outline,
            title: 'Gerenciar Pessoas & Contatos',
            subtitle: 'Adicione, edite ou remova pessoas para quem você faz compras',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PeopleManagementScreen(notifier: widget.notifier),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            icon: Icons.category,
            title: 'Gerenciar Categorias',
            subtitle: 'Adicione, edite, exclua e reordene categorias de despesa e receita',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoriesManagementScreen(notifier: widget.notifier),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 2. Leitura de Notificações Android
          _buildSectionHeader('Automação & Notificações Android'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Leitura de Notificações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            !_notificationAccessGranted
                                ? 'Permissão desativada nas configurações'
                                : (_serviceConnected
                                    ? 'Serviço ativo e conectado ao Android'
                                    : 'Permissão concedida (aguardando sistema)'),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (!_notificationAccessGranted
                                ? AppColors.expense
                                : (_serviceConnected ? AppColors.income : Colors.orange))
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        !_notificationAccessGranted
                            ? 'DESATIVADO'
                            : (_serviceConnected ? 'ATIVO (CONECTADO)' : 'AGUARDANDO SO'),
                        style: TextStyle(
                          color: !_notificationAccessGranted
                              ? AppColors.expense
                              : (_serviceConnected ? AppColors.income : Colors.orange),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await widget.notifier.notificationBridge.openPermissionSettings();
                      await Future.delayed(const Duration(seconds: 1));
                      _checkPermission();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      _notificationAccessGranted ? 'Revisar Permissões no Android' : 'Conceder Permissão de Leitura',
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.sync, size: 15),
                        label: const Text('Reconectar', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          await widget.notifier.notificationBridge.rebindService();
                          await _checkPermission();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_serviceConnected
                                    ? 'Leitor reconectado com sucesso ao Android!'
                                    : 'Sinal de reconexão enviado ao sistema.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.science_outlined, size: 15),
                        label: const Text('Testar Inbox', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          await widget.notifier.simulateTestNotification();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notificação de teste (R\$ 25,50) enviada! Veja na aba Inbox.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _showXiaomiPocoGuideDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.phone_android, size: 16, color: AppColors.primaryLight),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Instruções para Xiaomi, Poco e Redmi (HyperOS)',
                            style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 16, color: AppColors.primaryLight),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Exportação & Backup 100% Local
          _buildSectionHeader('Exportação & Backup 100% Local'),
          _buildSettingsTile(
            icon: Icons.table_chart_outlined,
            title: 'Exportar em Planilha (CSV)',
            subtitle: 'Gera extrato/faturas em formato .csv compatível com Excel',
            onTap: _exportCsvDialog,
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            icon: Icons.schedule_outlined,
            title: 'Backup Automático',
            subtitle: 'Frequência: ${_autoBackupLabel(_autoBackupFreq)}',
            onTap: _showAutoBackupDialog,
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            icon: Icons.upload_file,
            title: 'Exportar Backup Completo (JSON)',
            subtitle: 'Gera cópia de segurança completa de transações, faturas e pessoas',
            onTap: _exportBackupDialog,
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            icon: Icons.download_for_offline,
            title: 'Restaurar Backup (JSON)',
            subtitle: 'Importa arquivo de backup e reconstrói o estado financeiro',
            onTap: _importBackupDialog,
          ),
          const SizedBox(height: 24),

          // 4. Garantia de Privacidade
          // 4. Aplicativo & Atualizações
          _buildSectionHeader('Aplicativo & Atualizações'),
          _buildSettingsTile(
            icon: Icons.system_update_alt,
            title: 'Verificar Atualizações',
            subtitle: 'Versão instalada: v${UpdateService.currentVersion} • Toque para checar no GitHub',
            onTap: _checkUpdatesManually,
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            icon: Icons.vpn_key_outlined,
            title: 'Token do GitHub',
            subtitle: 'Configurado para repositório privado • Toque para alterar',
            onTap: _showGithubTokenDialog,
          ),
          const SizedBox(height: 16),

          // 5. Aviso de Privacidade Offline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.primaryLight, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('100% Offline & Seguro', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
                      SizedBox(height: 2),
                      Text(
                        'Nenhum dado é enviado para servidores externos. Suas finanças ficam exclusivamente no seu celular.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.background,
          child: Icon(icon, color: AppColors.primaryLight, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        onTap: onTap,
      ),
    );
  }

  void _showInitialBalancesDialog() {
    final state = widget.notifier.state;
    final now = DateTime.now();
    final (currentAvail, currentReserve) = FinancialMovementEngine.calculateHistoricalBalances(
      state: state,
      month: now.month,
      year: now.year,
    );
    final totalSaldo = currentAvail + currentReserve;
    final saldoCtrl = TextEditingController(text: totalSaldo.toStringAsFixed(2).replaceAll('.', ','));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Definir Saldo Inicial', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: saldoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyTextInputFormatter()],
                decoration: const InputDecoration(labelText: 'Saldo Inicial no Banco (R\$)', prefixText: 'R\$ '),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final saldo = CurrencyUtils.parse(saldoCtrl.text) ?? 0.0;
                widget.notifier.setInitialBalances(available: saldo, reserve: 0.0);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saldo atualizado com sucesso!')),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _exportBackupDialog() async {
    final json = await widget.notifier.exportBackup();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Backup Gerado com Sucesso', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('O JSON do backup foi gerado. Você pode salvar em arquivo ou copiar o conteúdo:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.textMuted)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Escolher Pasta & Salvar'),
              onPressed: () async {
                final now = DateTime.now();
                final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                final defaultFileName = 'chokin_backup_$dateStr.json';
                final bytes = Uint8List.fromList(utf8.encode(json));

                // Salva uma cópia de segurança no diretório interno do aplicativo
                await widget.notifier.backupService.saveBackupToFile(customFileName: defaultFileName);

                // Abre a janela nativa do Android para o usuário escolher o local onde quer salvar
                final resultUri = await FilePicker.saveFile(
                  dialogTitle: 'Escolha onde deseja salvar o backup do Chokin',
                  fileName: defaultFileName,
                  bytes: bytes,
                  mimeType: 'application/json',
                );

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  if (resultUri != null) {
                    final displayPath = resultUri.path.isNotEmpty ? resultUri.path : resultUri.toString();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 4),
                        content: Text('Backup salvo com sucesso em:\n$displayPath'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cópia interna mantida em ChokinBackups.'),
                      ),
                    );
                  }
                }
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar JSON'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup copiado para a área de transferência!')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _exportCsvDialog() {
    final now = DateTime.now();
    var selectedScope = CsvExportScope.specificMonth;
    var selectedMonth = now.month;
    var selectedYear = now.year;
    DateTime? startDate = DateTime(now.year, now.month, 1);
    DateTime? endDate = now;

    final monthsList = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final yearsList = [now.year - 2, now.year - 1, now.year, now.year + 1];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Row(
                children: [
                  Icon(Icons.table_chart_outlined, color: AppColors.primaryLight),
                  SizedBox(width: 8),
                  Text('Exportar Planilha (CSV)', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Escolha o período que deseja exportar para o formato CSV (compatível com Excel e Google Planilhas):',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<CsvExportScope>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mês Específico', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      value: CsvExportScope.specificMonth,
                      groupValue: selectedScope,
                      onChanged: (val) => setDialogState(() => selectedScope = val!),
                    ),
                    if (selectedScope == CsvExportScope.specificMonth)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                value: selectedMonth,
                                decoration: const InputDecoration(labelText: 'Mês', isDense: true),
                                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(monthsList[i]))),
                                onChanged: (v) => setDialogState(() => selectedMonth = v ?? selectedMonth),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int>(
                                value: selectedYear,
                                decoration: const InputDecoration(labelText: 'Ano', isDense: true),
                                items: yearsList.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                                onChanged: (v) => setDialogState(() => selectedYear = v ?? selectedYear),
                              ),
                            ),
                          ],
                        ),
                      ),
                    RadioListTile<CsvExportScope>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ano Inteiro', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      value: CsvExportScope.entireYear,
                      groupValue: selectedScope,
                      onChanged: (val) => setDialogState(() => selectedScope = val!),
                    ),
                    if (selectedScope == CsvExportScope.entireYear)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(labelText: 'Ano', isDense: true),
                          items: yearsList.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                          onChanged: (v) => setDialogState(() => selectedYear = v ?? selectedYear),
                        ),
                      ),
                    RadioListTile<CsvExportScope>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Todo o Histórico (Todos os Anos)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      value: CsvExportScope.allHistory,
                      groupValue: selectedScope,
                      onChanged: (val) => setDialogState(() => selectedScope = val!),
                    ),
                    RadioListTile<CsvExportScope>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Período Personalizado (De/Até)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      value: CsvExportScope.customRange,
                      groupValue: selectedScope,
                      onChanged: (val) => setDialogState(() => selectedScope = val!),
                    ),
                    if (selectedScope == CsvExportScope.customRange)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: startDate ?? now,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => startDate = picked);
                                  }
                                },
                                child: Text(startDate != null ? DateTimeUtils.formatDate(startDate!) : 'De'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: endDate ?? now,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => endDate = picked);
                                  }
                                },
                                child: Text(endDate != null ? DateTimeUtils.formatDate(endDate!) : 'Até'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar CSV'),
                  onPressed: () {
                    final csv = _generateCsvString(selectedScope, selectedMonth, selectedYear, startDate, endDate);
                    Clipboard.setData(ClipboardData(text: csv));
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CSV copiado para a área de transferência!')),
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Escolher Pasta & Salvar'),
                  onPressed: () async {
                    final csv = _generateCsvString(selectedScope, selectedMonth, selectedYear, startDate, endDate);
                    final fileName = _buildCsvFileName(selectedScope, selectedMonth, selectedYear, startDate, endDate);
                    final bytes = Uint8List.fromList(utf8.encode(csv));

                    // Salva cópia local interna
                    await widget.notifier.backupService.saveExportFile(fileName, csv);

                    // Abre a janela nativa do Android para o usuário escolher a pasta de destino
                    final resultUri = await FilePicker.saveFile(
                      dialogTitle: 'Escolha onde deseja salvar a planilha CSV',
                      fileName: fileName,
                      bytes: bytes,
                      mimeType: 'text/csv',
                    );

                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      if (resultUri != null) {
                        final displayPath = resultUri.path.isNotEmpty ? resultUri.path : resultUri.toString();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 4),
                            content: Text('Planilha salva com sucesso em:\n$displayPath'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cópia interna da planilha salva em ChokinBackups.')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _generateCsvString(
    CsvExportScope scope,
    int month,
    int year,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final state = widget.notifier.state;
    final options = CsvExportOptions(
      scope: scope,
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
    return CsvExportService.generateCsv(
      state: state,
      categories: widget.notifier.categories,
      options: options,
    );
  }

  String _buildCsvFileName(
    CsvExportScope scope,
    int month,
    int year,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final now = DateTime.now();
    final dateSuffix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    switch (scope) {
      case CsvExportScope.specificMonth:
        return 'extrato_${year}_${month.toString().padLeft(2, '0')}.csv';
      case CsvExportScope.entireYear:
        return 'extrato_${year}_completo.csv';
      case CsvExportScope.allHistory:
        return 'extrato_historico_completo_$dateSuffix.csv';
      case CsvExportScope.customRange:
        return 'extrato_periodo_$dateSuffix.csv';
    }
  }

  void _showAutoBackupDialog() {
    var tempFreq = _autoBackupFreq;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final lastBackupText = _lastAutoBackupDate != null
                ? DateTimeUtils.formatDateTime(_lastAutoBackupDate!)
                : 'Nenhum backup realizado ainda';

            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Row(
                children: [
                  Icon(Icons.schedule_outlined, color: AppColors.primaryLight),
                  SizedBox(width: 8),
                  Text('Backup Automático', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Você pode salvar cópias automáticas de segurança no armazenamento do celular. Se você sincronizar a pasta com o Google Drive, seus dados estarão sempre a salvo na nuvem.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text('Frequência do Backup:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    ...AutoBackupFrequency.values.map((freq) {
                      return RadioListTile<AutoBackupFrequency>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_autoBackupLabel(freq), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                        value: freq,
                        groupValue: tempFreq,
                        onChanged: (val) => setDialogState(() => tempFreq = val!),
                      );
                    }),
                    const Divider(height: 24, color: AppColors.border),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.folder_outlined, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pasta: ${_backupDirPath ?? "ChokinBackups"}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.history, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Último backup: $lastBackupText',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.backup_outlined, size: 16),
                  label: const Text('Fazer Backup Agora'),
                  onPressed: () async {
                    final file = await widget.notifier.backupService.saveBackupToFile();
                    await _loadAutoBackupSettings();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 4),
                          content: Text('Backup salvo com sucesso em:\n${file.path}'),
                        ),
                      );
                    }
                  },
                ),
                ElevatedButton(
                  onPressed: () async {
                    await widget.notifier.backupService.setAutoBackupFrequency(tempFreq);
                    if (tempFreq != AutoBackupFrequency.disabled) {
                      await widget.notifier.backupService.checkAndRunAutoBackup();
                    }
                    await _loadAutoBackupSettings();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Frequência de backup alterada para: ${_autoBackupLabel(tempFreq)}')),
                      );
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _importBackupDialog() {
    final jsonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Restaurar Backup (JSON)', style: TextStyle(color: AppColors.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_open_outlined, color: AppColors.primary),
                      label: const Text('Selecionar Arquivo .JSON do Celular'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final file = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (file != null && file.path != null) {
                          final content = await File(file.path!).readAsString();
                          if (content.isNotEmpty) {
                            setModalState(() {
                              jsonCtrl.text = content;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Ou cole o conteúdo JSON abaixo:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: jsonCtrl,
                      maxLines: 6,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      decoration: const InputDecoration(
                        labelText: 'Conteúdo JSON do backup',
                        hintText: '{\n  "version": 1,\n  "tables": { ... }\n}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    final content = jsonCtrl.text.trim();
                    if (content.isNotEmpty) {
                      final success = await widget.notifier.importBackup(content);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? 'Backup restaurado com sucesso!' : 'Erro ao restaurar backup. Verifique o formato do JSON.')),
                        );
                      }
                    }
                  },
                  child: const Text('Restaurar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showXiaomiPocoGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.phone_android, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Xiaomi, Poco & HyperOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No Xiaomi HyperOS / MIUI, o sistema encerra agressivamente serviços em segundo plano. Para garantir que o Chokin leia notificações de compras sem falhar:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                SizedBox(height: 12),
                Text('1. Início Automático (Autostart):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                Text('Toque no botão abaixo "Abrir Configurações do App" e ATIVE a chave "Início automático".', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                Text('2. Economia de Bateria:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                Text('Em "Economia de Bateria", altere de Economizador MIUI para "Sem restrições".', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                Text('3. Travar com Cadeado (Recentes):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                Text('Abra a tela de aplicativos recentes do seu Poco/Xiaomi, segure o dedo sobre o cartão do Chokin e toque no ícone de CADEADO. Isso impede que a limpeza de memória da Xiaomi mate o aplicativo.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                Text('4. Outras Permissões (Pop-up em 2º plano):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                Text('Nas configurações do app, vá em "Outras permissões" e permita "Exibir janelas pop-up em segundo plano".', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                Text('5. Configurações Restritas (se a permissão estiver cinza):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                Text('Se o Android bloquear a permissão de notificações, abra as Informações do App, toque nos 3 pontinhos no canto superior direito e selecione "Permitir configurações restritas".', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Abrir Configurações do App'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await widget.notifier.notificationBridge.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkUpdatesManually() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Consultando lançamentos no GitHub...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final info = await widget.notifier.checkForUpdates();

    if (!mounted) return;

    if (info.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('Chokin v${info.latestVersion}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Uma nova versão do aplicativo está pronta para download.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Novidades:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      info.releaseNotes!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Depois'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Baixar chokin.apk'),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (info.apkDownloadUrl != null) {
                  widget.notifier.openUrl(info.apkDownloadUrl!);
                }
              },
            ),
          ],
        ),
      );
    } else if (info.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao checar atualizações: ${info.errorMessage}'),
          action: SnackBarAction(
            label: 'Configurar Token',
            onPressed: _showGithubTokenDialog,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.income, size: 22),
              SizedBox(width: 8),
              Text('Aplicativo Atualizado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          content: Text(
            'Você já está utilizando a versão mais recente do Chokin (v${UpdateService.currentVersion}).',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  void _showGithubTokenDialog() async {
    final currentToken = await widget.notifier.updateService.getEffectiveToken() ?? '';
    final tokenCtrl = TextEditingController(text: currentToken);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Token GitHub (Repositório Privado)', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como o repositório é privado, um token de acesso pessoal (Personal Access Token) é necessário para consultar as releases do app.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token',
                hintText: 'gho_...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final token = tokenCtrl.text.trim();
              await widget.notifier.updateService.saveGithubToken(token);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token do GitHub salvo com sucesso.')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
