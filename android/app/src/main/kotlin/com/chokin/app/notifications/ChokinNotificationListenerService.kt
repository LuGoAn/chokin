package com.chokin.app.notifications

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.chokin.app.channel.NotificationEventChannelHandler
import java.util.UUID

class ChokinNotificationListenerService : NotificationListenerService() {

    private lateinit var dbHelper: NativeBufferDatabaseHelper
    private lateinit var monitoredManager: MonitoredPackagesManager

    override fun onCreate() {
        super.onCreate()
        dbHelper = NativeBufferDatabaseHelper(applicationContext)
        monitoredManager = MonitoredPackagesManager(applicationContext)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        if (!monitoredManager.isPackageMonitored(packageName)) {
            return
        }

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()

        // Ignora notificações vazias ou apenas informativas sem texto
        if (title.isNullOrBlank() && text.isNullOrBlank()) {
            return
        }

        // Filtra estritamente para apenas salvar se for uma movimentação financeira real com valor
        if (!isFinancialTransaction(title, text)) {
            return
        }

        val id = UUID.randomUUID().toString()
        val appName = getApplicationName(packageName)
        val timestamp = sbn.postTime

        val payload = mapOf(
            "id" to id,
            "packageName" to packageName,
            "appName" to appName,
            "rawTitle" to (title ?: ""),
            "rawText" to (text ?: ""),
            "timestamp" to timestamp
        )

        val isFlutterListening = NotificationEventChannelHandler.isListening()

        // Persiste no SQLite nativo buffer sempre como NÃO sincronizado (synced = false)
        // Isso garante que se o app estiver em segundo plano ou fechado, a notificação nunca é perdida.
        // Ela só será marcada como synced=1 quando o Flutter enviar o ACK de confirmação de leitura.
        dbHelper.insertNotification(
            id = id,
            packageName = packageName,
            appName = appName,
            title = title,
            text = text,
            timestamp = timestamp,
            synced = false
        )

        // Se o Flutter estiver ativo no momento, emite imediatamente no EventChannel
        if (isFlutterListening) {
            NotificationEventChannelHandler.sendNotification(payload)
        }
    }

    private fun isFinancialTransaction(title: String?, text: String?): Boolean {
        val full = ((title ?: "") + " " + (text ?: "")).lowercase()

        // Palavras de promoção/marketing/avisos que devem ser ignoradas
        val promoKeywords = listOf(
            "empréstimo", "emprestimo", "limite aumentou", "aumento de limite", "novo limite",
            "ajuste seu limite", "aumentar seu limite", "cupom", "desconto", "cashback", "ganhe",
            "convide", "indique", "informe de rendimentos", "declaração", "irpf", "código de segurança",
            "codigo de seguranca", "token", "código:", "codigo:", "fatura fechou", "fatura disponível",
            "fatura fechada", "fatura vence", "cartão chegou", "cartao chegou", "cartão a caminho",
            "senha", "promoção", "promocao", "ofertas", "oferta", "investimento", "cdb", "cripto",
            "rendimento", "atualize", "novidade", "pontos", "milhas", "seguro de vida", "portabilidade"
        )

        for (kw in promoKeywords) {
            if (full.contains(kw)) {
                return false
            }
        }

        // Deve conter indicação de transação financeira
        val transactionKeywords = listOf(
            "compra", "pagou", "pago", "pagamento", "pix", "transferência", "transferencia",
            "recebeu", "recebido", "débito", "debito", "crédito", "credito", "aprovada",
            "aprovado", "transação", "transacao", "saque", "boleto"
        )

        val hasTransactionKeyword = transactionKeywords.any { full.contains(it) }
        if (!hasTransactionKeyword) return false

        // Deve conter padrão numérico de moeda (ex: R$ 50,00 ou 50,00 ou R$50)
        val hasAmount = full.contains("r$") || full.contains("brl") || Regex("""\d+([.,]\d{2})""").containsMatchIn(full)

        return hasAmount
    }

    private fun getApplicationName(packageName: String): String {
        return try {
            val pm = applicationContext.packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(ai).toString()
        } catch (e: Exception) {
            val lower = packageName.lowercase()
            when {
                lower.contains("nu.production") || lower.contains("nubank") -> "Nubank"
                lower.contains("spay") || lower.contains("samsung") -> "Samsung Pay"
                lower.contains("walletnfcrel") -> "Google Wallet"
                lower.contains("bb.android") -> "Banco do Brasil"
                lower.contains("itau") -> "Itaú"
                lower.contains("santander") -> "Santander"
                lower.contains("intermedium") || lower.contains("inter") -> "Banco Inter"
                lower.contains("c6bank") -> "C6 Bank"
                lower.contains("mercadopago") || lower.contains("mercadolibre") -> "Mercado Pago"
                lower.contains("picpay") -> "PicPay"
                lower.contains("bradesco") -> "Bradesco"
                lower.contains("caixa") -> "Caixa"
                else -> packageName
            }
        }
    }
}
