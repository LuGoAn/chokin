package com.chokin.app

import com.chokin.app.channel.NotificationEventChannelHandler
import com.chokin.app.channel.NotificationMethodChannelHandler
import com.chokin.app.notifications.KeepAliveService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val METHOD_CHANNEL = "com.chokin.app/notifications_channel"
        const val EVENT_CHANNEL = "com.chokin.app/notifications_stream"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(NotificationMethodChannelHandler(applicationContext))

        val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(NotificationEventChannelHandler)
    }

    override fun onResume() {
        super.onResume()
        NotificationMethodChannelHandler.forceRebind(applicationContext)
        KeepAliveService.start(applicationContext)
    }
}
