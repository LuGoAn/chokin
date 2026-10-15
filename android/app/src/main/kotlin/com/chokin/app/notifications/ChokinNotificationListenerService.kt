package com.chokin.app.notifications

import android.app.Notification
import android.content.ComponentName
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.chokin.app.channel.NotificationEventChannelHandler
import java.util.UUID

class ChokinNotificationListenerService : NotificationListenerService() {

    private lateinit var dbHelper: NativeBufferDatabaseHelper
    private lateinit var monitoredManager: MonitoredPackagesManager

    companion object {
        @Volatile
        var isConnected: Boolean = false
    }

    override fun onCreate() {
        super.onCreate()
        dbHelper = NativeBufferDatabaseHelper(applicationContext)
        monitoredManager = MonitoredPackagesManager(applicationContext)
    }

    override fun onStartCommand(intent: android.content.Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        return START_STICKY
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
        // No Android 7.0+ (Nougat em diante), tenta auto-rebind caso desconectado pelo SO (como ocorre no HyperOS/MIUI)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            try {
                val cn = ComponentName(this, ChokinNotificationListenerService::class.java)
                requestRebind(cn)
            } catch (_: Exception) {}
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        if (!monitoredManager.isPackageMonitored(packageName)) {
            return
        }

        val extras = sbn.notification.extras ?: android.os.Bundle()
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString()
            ?: ""

        // Extrai todas as fontes potenciais de texto da notificação (BigTextStyle, InboxStyle, etc.)
        val extraText = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        val textLines = (extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES) ?: emptyArray())
            .joinToString("\n")
        val tickerText = sbn.notification.tickerText?.toString()

        val textCandidates = listOfNotNull(
            extraText.takeIf { !it.isNullOrBlank() },
            bigText.takeIf { !it.isNullOrBlank() && it != extraText },
            textLines.takeIf { it.isNotBlank() },
            subText.takeIf { !it.isNullOrBlank() && it != extraText && it != bigText },
            tickerText.takeIf { !it.isNullOrBlank() && it != extraText && it != bigText }
        )

        val text = textCandidates.joinToString(" ").trim()

        // Ignora notificações vazias ou apenas informativas sem texto
        if (title.isBlank() && text.isBlank()) {
            return
        }

        // Filtra estritamente para apenas salvar se for uma movimentação financeira real com valor
        if (!isFinancialTransaction(title, text, packageName)) {
            return
        }

        val id = UUID.randomUUID().toString()
        val appName = getApplicationName(packageName)
        val timestamp = sbn.postTime

        val payload = mapOf(
            "id" to id,
            "packageName" to packageName,
            "appName" to appName,
            "rawTitle" to title,
            "rawText" to text,
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

    private fun isFinancialTransaction(title: String?, text: String?, packageName: String): Boolean {
        val full = ((title ?: "") + " " + (text ?: "")).lowercase()

        // Palavras de promoção/marketing/avisos que devem ser ignoradas
        val promoKeywords = listOf(
            "empréstimo", "emprestimo", "limite aumentou", "aumento de limite", "novo limite",
            "ajuste seu limite", "aumentar seu limite", "cupom", "desconto", "cashback", "ganhe",
            "convide", "indique", "informe de rendimentos", "declaração", "declaracao", "irpf",
            "código de segurança", "codigo de seguranca", "código de acesso", "token", "código:",
            "codigo:", "fatura fechou", "fatura disponível", "fatura disponivel", "fatura fechada",
            "fatura vence", "cartão chegou", "cartao chegou", "cartão a caminho", "cartao a caminho",
            "senha", "promoção", "promocao", "ofertas", "oferta", "investimento", "cdb", "cripto",
            "rendimento", "atualize seu app", "novidade", "pontos", "milhas", "seguro de vida",
            "portabilidade", "guardar dinheiro", "resgate seu", "aproveite", "parabéns", "parabens",
            "sorteio"
        )

        for (kw in promoKeywords) {
            if (full.contains(kw)) {
                return false
            }
        }

        // Deve conter padrão numérico de moeda (ex: R$ 50,00 ou R$ 38.50 ou 50,00 ou BRL 20)
        val hasAmount = full.contains("r$") || full.contains("brl") || Regex("""\d+([.,]\d{2})""").containsMatchIn(full)
        if (!hasAmount) return false

        // Se for carteira digital explícita (Google Wallet / Google Pay), qualquer notificação com valor é financeira
        val isDigitalWallet = packageName.contains("wallet") ||
                packageName.contains("walletnfcrel") ||
                packageName.contains("google.android.gms") ||
                full.contains("carteira") ||
                full.contains("wallet") ||
                full.contains("google pay") ||
                full.contains("gpay")
        if (isDigitalWallet) return true

        // Deve conter indicação de transação financeira ou menção a compras/pagamentos
        val transactionKeywords = listOf(
            "compra", "pagou", "pago", "pagamento", "pagar", "pix", "transferência", "transferencia",
            "transferiu", "enviou", "enviado", "enviada", "recebeu", "recebido", "recebida",
            "débito", "debito", "crédito", "credito", "aprovada", "aprovado", "autorizada",
            "autorizado", "confirmada", "confirmado", "transação", "transacao", "saque", "boleto",
            "carteira", "wallet", "google pay", "gpay", "aproximação", "aproximacao", "contactless",
            "gasto", "gastou"
        )

        val hasTransactionKeyword = transactionKeywords.any { full.contains(it) }
        val hasMerchantPattern = Regex("""(em|no|na|para|de)\s+[a-z0-9]""").containsMatchIn(full)

        return hasTransactionKeyword || hasMerchantPattern
    }

    private fun getApplicationName(packageName: String): String {
        return try {
            val pm = applicationContext.packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            val label = pm.getApplicationLabel(ai).toString()
            if (packageName == "com.google.android.gms") {
                "Google Wallet"
            } else {
                label
            }
        } catch (e: Exception) {
            val lower = packageName.lowercase()
            when {
                lower.contains("nu.production") || lower.contains("nubank") -> "Nubank"
                lower.contains("walletnfcrel") || lower.contains("google.android.gms") || lower.contains("wallet") -> "Google Wallet"
                lower.contains("spay") || lower.contains("samsung") -> "Samsung Pay"
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
