package com.chokin.app.channel

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import com.chokin.app.notifications.ChokinNotificationListenerService
import com.chokin.app.notifications.MonitoredPackagesManager
import com.chokin.app.notifications.NativeBufferDatabaseHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationMethodChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    private val dbHelper = NativeBufferDatabaseHelper(context)
    private val monitoredManager = MonitoredPackagesManager(context)

    companion object {
        /// Força o Android / HyperOS / MIUI a reestabelecer o binding do NotificationListenerService
        fun forceRebind(context: Context) {
            try {
                val cn = ComponentName(context, ChokinNotificationListenerService::class.java)
                val pm = context.packageManager
                // Alterna temporariamente o status do componente para forçar o NotificationManagerService
                // a recriar a conexão IPC do listener caso tenha sido desconectada pelo sistema
                pm.setComponentEnabledSetting(cn, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                pm.setComponentEnabledSetting(cn, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    android.service.notification.NotificationListenerService.requestRebind(cn)
                }
            } catch (_: Exception) {}
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPendingNotifications" -> {
                try {
                    val pending = dbHelper.getUnsyncedNotifications()
                    result.success(pending)
                } catch (e: Exception) {
                    result.error("DB_ERROR", e.message, null)
                }
            }
            "ackNotification" -> {
                try {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    dbHelper.markAsSynced(ids)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ACK_ERROR", e.message, null)
                }
            }
            "checkPermission" -> {
                val isGranted = isNotificationServiceEnabled()
                if (isGranted) {
                    forceRebind(context)
                }
                result.success(isGranted)
            }
            "rebindService" -> {
                try {
                    if (isNotificationServiceEnabled()) {
                        forceRebind(context)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("REBIND_ERROR", e.message, null)
                }
            }
            "openPermissionSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INTENT_ERROR", e.message, null)
                }
            }
            "openAppSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.fromParts("package", context.packageName, null)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INTENT_ERROR", e.message, null)
                }
            }
            "getMonitoredApps" -> {
                result.success(monitoredManager.getMonitoredPackages().toList())
            }
            "updateMonitoredApps" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                monitoredManager.updateMonitoredPackages(packages.toSet())
                result.success(true)
            }
            "openUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_URL_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_URL", "URL cannot be null", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val cn = ComponentName(context, ChokinNotificationListenerService::class.java)
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }
}
