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
    private lateinit var log: NotificationLog

    companion object {
        @Volatile
        var isConnected: Boolean = false

        private val PROMO_KEYWORDS = listOf(
            "empréstimo", "emprestimo", "limite aumentou", "aumento de limite", "novo limite",
            "ajuste seu limite", "aumentar seu limite", "cupom", "desconto", "cashback", "ganhe",
            "convide", "indique", "informe de rendimentos", "declaração", "declaracao", "irpf",
            "código de segurança", "codigo de seguranca", "código de acesso", "token", "código:",
            "codigo:", "fatura fechou", "fatura disponível", "fatura disponivel", "fatura fechada",
            "fatura vence", "cartão chegou", "cartao chegou", "cartão a caminho", "cartao a caminho",
            "senha", "promoção", "promocao", "ofertas", "oferta", "investimento", "cdb", "cripto",
            "rendimento", "atualize seu app", "novidade", "pontos", "milhas", "seguro de vida",
            "portabilidade", "guardar dinheiro", "resgate seu", "aproveite", "parabéns", "parabens",
            "sorteio", "venda de qualquer lugar", "maquininha", "receba em", "de graça", "de graca",
            "grátis", "gratis", "taxa", "taxas", "a partir de", "por apenas", "apenas r$", "só r$",
            "pré-aprovado", "pré-aprovada", "pre-aprovado", "pre-aprovada", "próxima compra",
            "proxima compra", "simule", "simular", "contrate", "contratar", "libere", "conheça",
            "conheca", "experimente", "saiba mais", "baixe", "ative", "ativar", "abra sua conta",
            "peça", "peca", "tap", "campanha", "vantagens", "benefício", "beneficio", "anuidade"
        )

        private val TRANSACTION_KEYWORDS = listOf(
            "compra", "pagou", "pagamento", "pix enviado", "pix recebido", "pix de",
            "transferência enviada", "transferência recebida", "transferencia enviada",
            "transferencia recebida", "transferiu", "enviou um pix", "enviou", "recebeu um pix",
            "recebeu", "você pagou", "voce pagou", "você recebeu", "voce recebeu", "aprovada",
            "aprovado", "autorizada", "autorizado", "confirmada", "confirmado", "transação",
            "transacao", "saque", "boleto pago", "recarga realizada", "aproximação", "aproximacao",
            "contactless", "gasto", "gastou", "débito automático", "debito automatico"
        )
    }

    override fun onCreate() {
        super.onCreate()
        dbHelper = NativeBufferDatabaseHelper(applicationContext)
        monitoredManager = MonitoredPackagesManager(applicationContext)
        log = NotificationLog(applicationContext)
    }

    override fun onStartCommand(intent: android.content.Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        return START_STICKY
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
        log.markConnected(System.currentTimeMillis())
        KeepAliveService.start(applicationContext)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
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
        log.countReceived(sbn.postTime)
        if (!monitoredManager.isPackageMonitored(packageName)) {
            return
        }

        val extras = sbn.notification.extras ?: android.os.Bundle()
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString()
            ?: ""

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
        val timestamp = sbn.postTime

        if (title.isBlank() && text.isBlank()) {
            log.add(timestamp, packageName, title, text, "sem título e sem texto: o sistema não entregou o conteúdo")
            return
        }

        if (!isFinancialTransaction(title, text)) {
            log.add(timestamp, packageName, title, text, "descartada pelo filtro do leitor")
            return
        }

        try {
            val id = UUID.randomUUID().toString()
            val appName = getApplicationName(packageName)

            val payload = mapOf(
                "id" to id,
                "packageName" to packageName,
                "appName" to appName,
                "rawTitle" to title,
                "rawText" to text,
                "timestamp" to timestamp
            )

            val isFlutterListening = NotificationEventChannelHandler.isListening()

            dbHelper.insertNotification(
                id = id,
                packageName = packageName,
                appName = appName,
                title = title,
                text = text,
                timestamp = timestamp,
                synced = false
            )

            if (isFlutterListening) {
                NotificationEventChannelHandler.sendNotification(payload)
            }
            log.add(timestamp, packageName, title, text, "aceita e enviada ao app")
        } catch (e: Exception) {
            log.add(timestamp, packageName, title, text, "erro ao salvar: ${e.message}")
        }
    }

    private fun isFinancialTransaction(title: String?, text: String?): Boolean {
        val full = ((title ?: "") + " " + (text ?: "")).lowercase()

        val hasAmount = full.contains("r$") || full.contains("brl") || Regex("""\d+([.,]\d{2})""").containsMatchIn(full)
        if (!hasAmount) return false

        return !containsAny(full, PROMO_KEYWORDS) && containsAny(full, TRANSACTION_KEYWORDS)
    }

    private fun containsAny(text: String, keywords: List<String>): Boolean {
        return keywords.any { Regex("""(?<!\p{L})""" + Regex.escape(it) + """(?!\p{L})""").containsMatchIn(text) }
    }

    private fun getApplicationName(packageName: String): String {
        return try {
            val pm = applicationContext.packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            val label = pm.getApplicationLabel(ai).toString()
            label
        } catch (e: Exception) {
            val lower = packageName.lowercase()
            when {
                lower.contains("nu.production") || lower.contains("nubank") -> "Nubank"
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
