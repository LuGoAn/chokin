package com.chokin.app.notifications

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class NotificationLog(context: Context) {
    private val prefs = context.getSharedPreferences("chokin_notification_log", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_ENTRIES = "entries"
        private const val KEY_TOTAL = "total_received"
        private const val KEY_LAST_AT = "last_received_at"
        private const val KEY_CONNECTED_AT = "connected_at"
        private const val MAX_ENTRIES = 40
    }

    @Synchronized
    fun countReceived(timestamp: Long) {
        prefs.edit()
            .putLong(KEY_TOTAL, prefs.getLong(KEY_TOTAL, 0L) + 1)
            .putLong(KEY_LAST_AT, timestamp)
            .apply()
    }

    @Synchronized
    fun markConnected(timestamp: Long) {
        prefs.edit().putLong(KEY_CONNECTED_AT, timestamp).apply()
    }

    @Synchronized
    fun add(timestamp: Long, packageName: String, title: String, text: String, outcome: String) {
        val current = try {
            JSONArray(prefs.getString(KEY_ENTRIES, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val entry = JSONObject()
            .put("timestamp", timestamp)
            .put("packageName", packageName)
            .put("title", title)
            .put("text", text)
            .put("outcome", outcome)
        val updated = JSONArray()
        updated.put(entry)
        var i = 0
        while (i < current.length() && updated.length() < MAX_ENTRIES) {
            updated.put(current.get(i))
            i++
        }
        prefs.edit().putString(KEY_ENTRIES, updated.toString()).apply()
    }

    @Synchronized
    fun snapshot(): Map<String, Any> {
        val list = mutableListOf<Map<String, Any>>()
        val array = try {
            JSONArray(prefs.getString(KEY_ENTRIES, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        for (i in 0 until array.length()) {
            val o = array.getJSONObject(i)
            list.add(
                mapOf(
                    "timestamp" to o.optLong("timestamp"),
                    "packageName" to o.optString("packageName"),
                    "title" to o.optString("title"),
                    "text" to o.optString("text"),
                    "outcome" to o.optString("outcome")
                )
            )
        }
        return mapOf(
            "totalReceived" to prefs.getLong(KEY_TOTAL, 0L),
            "lastReceivedAt" to prefs.getLong(KEY_LAST_AT, 0L),
            "connectedAt" to prefs.getLong(KEY_CONNECTED_AT, 0L),
            "entries" to list
        )
    }

    @Synchronized
    fun clear() {
        prefs.edit().remove(KEY_ENTRIES).remove(KEY_TOTAL).remove(KEY_LAST_AT).apply()
    }
}
