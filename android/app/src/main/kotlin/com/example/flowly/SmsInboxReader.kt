package com.example.flowly

import android.content.Context
import android.provider.Telephony

object SmsInboxReader {
    const val BATCH_SIZE = 100
    private const val OVERLAP_MILLIS = 5 * 60 * 1000L

    /** Returns the inbox timestamp only when Android has already stored the
     * exact transient broadcast body. No raw value is retained by Flowly. */
    fun findMatchingReceivedAt(
        context: Context,
        sender: String,
        body: String,
    ): Long? {
        val recent = System.currentTimeMillis() - 10 * 60 * 1000L
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms.DATE),
            "${Telephony.Sms.ADDRESS}=? AND ${Telephony.Sms.BODY}=? AND ${Telephony.Sms.DATE}>=?",
            arrayOf(sender, body, recent.toString()),
            "${Telephony.Sms._ID} DESC LIMIT 1",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getLong(cursor.getColumnIndexOrThrow(Telephony.Sms.DATE))
            }
        }
        return null
    }

    fun read(context: Context, checkpoint: AutomaticDetectionStore.Checkpoint): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val overlapStart = (checkpoint.cursorDate - OVERLAP_MILLIS).coerceAtLeast(0L)
        val selection =
            "${Telephony.Sms._ID}>? AND (${Telephony.Sms._ID}>? OR ${Telephony.Sms.DATE}>=?)"
        val arguments = arrayOf(
            checkpoint.baselineId.toString(),
            checkpoint.cursorId.toString(),
            overlapStart.toString(),
        )
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
            ),
            selection,
            arguments,
            "${Telephony.Sms._ID} ASC LIMIT $BATCH_SIZE",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
            val senderColumn = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyColumn = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateColumn = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        "id" to cursor.getLong(idColumn),
                        "sender" to (cursor.getString(senderColumn) ?: ""),
                        "body" to (cursor.getString(bodyColumn) ?: ""),
                        "receivedAt" to cursor.getLong(dateColumn),
                    ),
                )
            }
        }
        return rows
    }
}
