package com.chokin.app.channel

import io.flutter.plugin.common.EventChannel

object NotificationEventChannelHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun isListening(): Boolean = eventSink != null

    fun sendNotification(notification: Map<String, Any>) {
        eventSink?.success(notification)
    }
}
