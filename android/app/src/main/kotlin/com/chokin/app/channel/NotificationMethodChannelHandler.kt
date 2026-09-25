package com.chokin.app.channel

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.chokin.app.notifications.ChokinNotificationListenerService
import com.chokin.app.notifications.MonitoredPackagesManager
import com.chokin.app.notifications.NativeBufferDatabaseHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationMethodChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    private val dbHelper = NativeBufferDatabaseHelper(context)
    private val monitoredManager = MonitoredPackagesManager(context)

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
                if (isGranted && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    try {
                        val cn = ComponentName(context, ChokinNotificationListenerService::class.java)
                        android.service.notification.NotificationListenerService.requestRebind(cn)
                    } catch (_: Exception) {}
                }
                result.success(isGranted)
            }
            "rebindService" -> {
                try {
                    if (isNotificationServiceEnabled() && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                        val cn = ComponentName(context, ChokinNotificationListenerService::class.java)
                        android.service.notification.NotificationListenerService.requestRebind(cn)
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
                        val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).apply {
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
