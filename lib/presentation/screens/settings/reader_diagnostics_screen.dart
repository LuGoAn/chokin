import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sumi.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/notifications/notification_payload.dart';
import '../../state/financial_state_notifier.dart';
import '../../widgets/sumi_widgets.dart';

class ReaderDiagnosticsScreen extends StatefulWidget {
  final FinancialStateNotifier notifier;

  const ReaderDiagnosticsScreen({super.key, required this.notifier});

  @override
  State<ReaderDiagnosticsScreen> createState() => _ReaderDiagnosticsScreenState();
}

class _ReaderDiagnosticsScreenState extends State<ReaderDiagnosticsScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.notifier.notificationBridge.getDiagnostics();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  String _when(num? millis) {
    if (millis == null || millis == 0) return 'nunca';
    return DateTimeUtils.formatDateTime(DateTime.fromMillisecondsSinceEpoch(millis.toInt()));
  }

  @override
  Widget build(BuildContext context) {
    final bridge = widget.notifier.notificationBridge;
    final entries = ((_data['entries'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final permission = _data['permissionGranted'] == true;
    final connected = _data['connected'] == true;
    final total = (_data['totalReceived'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico do leitor'),
        actions: [
          IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            tooltip: 'Limpar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await bridge.clearDiagnostics();
              await _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(Sumi.gutter, 4, Sumi.gutter, 32),
              children: [
                const SectionTitle('O que o Android entregou'),
                const SizedBox(height: 8),
                _line('Permissão de acesso', permission ? 'concedida' : 'não concedida'),
                _line('Serviço do leitor', connected ? 'conectado' : 'desconectado'),
                _line('Última conexão', _when(_data['connectedAt'] as num?)),
                _line('Notificações recebidas', '$total'),
                _line('Última recebida', _when(_data['lastReceivedAt'] as num?)),
                const SizedBox(height: 8),
                Text(
                  total == 0
                      ? 'Nenhuma notificação chegou ao Chokin. Se o status acima diz conectado, o sistema '
                          'não está entregando: revise permissões restritas, início automático e bateria.'
                      : 'Faça uma compra e toque em atualizar. Chegando aqui, o Android está entregando.',
                  style: Sumi.caption,
                ),
                const SizedBox(height: 28),
                const SectionTitle('Notificações de bancos e carteiras'),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  const Text('Nenhuma notificação de app monitorado ainda.', style: Sumi.caption)
                else
                  for (final e in entries) _entry(e),
              ],
            ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Sumi.body)),
          Text(value, style: Sumi.bodyStrong),
        ],
      ),
    );
  }

  Widget _entry(Map<String, dynamic> e) {
    final payload = RawNotificationPayload(
      id: '',
      packageName: e['packageName'] as String? ?? '',
      appName: '',
      rawTitle: e['title'] as String? ?? '',
      rawText: e['text'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch((e['timestamp'] as num?)?.toInt() ?? 0),
    );
    final nativeOutcome = e['outcome'] as String? ?? '';
    final accepted = nativeOutcome.startsWith('aceita');
    final appOutcome = accepted ? widget.notifier.notificationBridge.describeOutcome(payload) : null;
    final ok = appOutcome != null && appOutcome.startsWith('vira');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_when(payload.timestamp.millisecondsSinceEpoch)} · ${payload.packageName}', style: Sumi.caption),
          const SizedBox(height: 4),
          if (payload.rawTitle.isNotEmpty) Text(payload.rawTitle, style: Sumi.bodyStrong),
          if (payload.rawText.isNotEmpty) Text(payload.rawText, style: Sumi.body),
          const SizedBox(height: 6),
          Text(
            appOutcome ?? nativeOutcome,
            style: Sumi.caption.copyWith(color: ok ? AppColors.income : AppColors.warning),
          ),
        ],
      ),
    );
  }
}
