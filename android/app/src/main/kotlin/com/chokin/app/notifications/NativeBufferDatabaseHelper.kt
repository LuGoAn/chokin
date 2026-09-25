package com.chokin.app.notifications

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class NativeBufferDatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME = "chokin_native_buffer.db"
        const val DATABASE_VERSION = 1
        const val TABLE_NAME = "raw_notifications"

        const val COLUMN_ID = "id"
        const val COLUMN_PACKAGE = "package_name"
        const val COLUMN_APP_NAME = "app_name"
        const val COLUMN_TITLE = "raw_title"
        const val COLUMN_TEXT = "raw_text"
        const val COLUMN_TIMESTAMP = "timestamp"
        const val COLUMN_SYNCED = "synced"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createQuery = """
            CREATE TABLE $TABLE_NAME (
                $COLUMN_ID TEXT PRIMARY KEY,
                $COLUMN_PACKAGE TEXT NOT NULL,
                $COLUMN_APP_NAME TEXT NOT NULL,
                $COLUMN_TITLE TEXT,
                $COLUMN_TEXT TEXT,
                $COLUMN_TIMESTAMP INTEGER NOT NULL,
                $COLUMN_SYNCED INTEGER NOT NULL DEFAULT 0
            )
        """.trimIndent()
        db.execSQL(createQuery)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_NAME")
        onCreate(db)
    }

    fun insertNotification(id: String, packageName: String, appName: String, title: String?, text: String?, timestamp: Long, synced: Boolean): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_ID, id)
            put(COLUMN_PACKAGE, packageName)
            put(COLUMN_APP_NAME, appName)
            put(COLUMN_TITLE, title)
            put(COLUMN_TEXT, text)
            put(COLUMN_TIMESTAMP, timestamp)
            put(COLUMN_SYNCED, if (synced) 1 else 0)
        }
        val result = db.insertWithOnConflict(TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        return result != -1L
    }

    fun getUnsyncedNotifications(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val db = readableDatabase
        val cursor = db.query(
            TABLE_NAME,
            null,
            "$COLUMN_SYNCED = 0",
            null,
            null,
            null,
            "$COLUMN_TIMESTAMP ASC"
        )
        cursor.use {
            while (it.moveToNext()) {
                val map = mapOf(
                    "id" to it.getString(it.getColumnIndexOrThrow(COLUMN_ID)),
                    "packageName" to it.getString(it.getColumnIndexOrThrow(COLUMN_PACKAGE)),
                    "appName" to it.getString(it.getColumnIndexOrThrow(COLUMN_APP_NAME)),
                    "rawTitle" to (it.getString(it.getColumnIndexOrThrow(COLUMN_TITLE)) ?: ""),
                    "rawText" to (it.getString(it.getColumnIndexOrThrow(COLUMN_TEXT)) ?: ""),
                    "timestamp" to it.getLong(it.getColumnIndexOrThrow(COLUMN_TIMESTAMP))
                )
                list.add(map)
            }
        }
        return list
    }

    fun markAsSynced(ids: List<String>) {
        if (ids.isEmpty()) return
        val db = writableDatabase
        val placeholders = ids.joinToString(",") { "?" }
        val values = ContentValues().apply {
            put(COLUMN_SYNCED, 1)
        }
        db.update(TABLE_NAME, values, "$COLUMN_ID IN ($placeholders)", ids.toTypedArray())
    }
}
