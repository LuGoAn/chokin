package com.chokin.app.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class KeepAliveService : Service() {

    companion object {
        private const val CHANNEL_ID = "leitor_ativo"
        private const val NOTIFICATION_ID = 4107
        private const val PREFS = "chokin_keep_alive"
        private const val KEY_ENABLED = "enabled"

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

        fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
            if (enabled) start(context) else stop(context)
        }

        fun start(context: Context) {
            if (!isEnabled(context)) return
            try {
                context.startForegroundService(Intent(context, KeepAliveService::class.java))
            } catch (_: Exception) {}
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, KeepAliveService::class.java))
            } catch (_: Exception) {}
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(CHANNEL_ID, "Leitor ativo", NotificationManager.IMPORTANCE_MIN).apply {
            description = "Mantém o leitor de notificações do Chokin em funcionamento"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)

        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launch?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Chokin lendo notificações")
            .setContentText("Compras dos bancos vão para a Caixa de entrada")
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }
}
