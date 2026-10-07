package com.example.flowly

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Telephony
import androidx.core.content.ContextCompat

object AutomaticDetectionStore {
    private const val PREFS = "flowly_sms"
    private const val ENABLED = "enabled"
    private const val MIGRATED = "native_state_migrated_v2"
    private const val BASELINE_ID = "inbox_baseline_id"
    private const val CURSOR_ID = "inbox_cursor_id"
    private const val CURSOR_DATE = "inbox_cursor_date"
    private const val LATEST_SIGNAL_AT = "latest_signal_at"
    private const val SIGNAL_SEQUENCE = "signal_sequence"
    private const val ACKNOWLEDGED_SIGNAL_SEQUENCE = "acknowledged_signal_sequence"

    data class Checkpoint(
        val baselineId: Long,
        val cursorId: Long,
        val cursorDate: Long,
    )

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean =
        preferences(context).getBoolean(ENABLED, false)

    fun restore(context: Context, legacyEnabled: Boolean?): Boolean {
        val prefs = preferences(context)
        if (!prefs.getBoolean(MIGRATED, false)) {
            val enabled = if (prefs.contains(ENABLED)) {
                prefs.getBoolean(ENABLED, false)
            } else {
                legacyEnabled ?: false
            }
            if (enabled && !prefs.contains(BASELINE_ID)) {
                establishBaseline(context)
            }
            prefs.edit().putBoolean(ENABLED, enabled).putBoolean(MIGRATED, true).commit()
        } else if (prefs.getBoolean(ENABLED, false) && !prefs.contains(BASELINE_ID)) {
            establishBaseline(context)
        }
        return isEnabled(context)
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        val prefs = preferences(context)
        val wasEnabled = prefs.getBoolean(ENABLED, false)
        if (enabled && (!wasEnabled || !prefs.contains(BASELINE_ID))) {
            establishBaseline(context)
        }
        prefs.edit().putBoolean(ENABLED, enabled).putBoolean(MIGRATED, true).commit()
        if (!enabled) {
            prefs.edit()
                .putLong(
                    ACKNOWLEDGED_SIGNAL_SEQUENCE,
                    prefs.getLong(SIGNAL_SEQUENCE, 0L),
                )
                .remove(LATEST_SIGNAL_AT)
                .apply()
            SmsWorkScheduler.cancel(context)
        }
    }

    fun hasRequiredPermissions(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECEIVE_SMS) ==
            PackageManager.PERMISSION_GRANTED

    fun checkpoint(context: Context): Checkpoint {
        val prefs = preferences(context)
        return Checkpoint(
            baselineId = prefs.getLong(BASELINE_ID, 0L),
            cursorId = prefs.getLong(CURSOR_ID, 0L),
            cursorDate = prefs.getLong(CURSOR_DATE, 0L),
        )
    }

    fun acknowledge(context: Context, id: Long, receivedAt: Long) {
        val prefs = preferences(context)
        val currentId = prefs.getLong(CURSOR_ID, 0L)
        if (id <= currentId) return
        prefs.edit().putLong(CURSOR_ID, id).putLong(CURSOR_DATE, receivedAt).commit()
    }

    fun recordSignal(context: Context, receivedAt: Long) {
        val prefs = preferences(context)
        val nextSequence = prefs.getLong(SIGNAL_SEQUENCE, 0L) + 1L
        val currentReceivedAt = prefs.getLong(LATEST_SIGNAL_AT, 0L)
        prefs.edit()
            .putLong(SIGNAL_SEQUENCE, nextSequence)
            .putLong(LATEST_SIGNAL_AT, maxOf(receivedAt, currentReceivedAt))
            .commit()
    }

    fun hasPendingSignal(context: Context): Boolean =
        signalSequence(context) >
            preferences(context).getLong(ACKNOWLEDGED_SIGNAL_SEQUENCE, 0L)

    fun signalSequence(context: Context): Long =
        preferences(context).getLong(SIGNAL_SEQUENCE, 0L)

    fun acknowledgeSignal(context: Context, sequence: Long) {
        val prefs = preferences(context)
        val current = prefs.getLong(ACKNOWLEDGED_SIGNAL_SEQUENCE, 0L)
        if (sequence <= current) return
        prefs.edit().putLong(ACKNOWLEDGED_SIGNAL_SEQUENCE, sequence).apply()
    }

    private fun establishBaseline(context: Context) {
        check(hasRequiredPermissions(context)) { "SMS permission is required" }
        var id = 0L
        var date = System.currentTimeMillis()
        val cursor = context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms._ID, Telephony.Sms.DATE),
            null,
            null,
            "${Telephony.Sms._ID} DESC LIMIT 1",
        ) ?: error("SMS inbox is unavailable")
        cursor.use {
            if (it.moveToFirst()) {
                id = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms._ID))
                date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
            }
        }
        preferences(context).edit()
            .putLong(BASELINE_ID, id)
            .putLong(CURSOR_ID, id)
            .putLong(CURSOR_DATE, date)
            .putLong(
                ACKNOWLEDGED_SIGNAL_SEQUENCE,
                preferences(context).getLong(SIGNAL_SEQUENCE, 0L),
            )
            .remove(LATEST_SIGNAL_AT)
            .commit()
    }
}
