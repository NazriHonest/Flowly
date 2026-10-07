package com.example.flowly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Durably signals inbox work before optionally delivering a transient event
 * to an already-running Flutter engine. It never persists an SMS body.
 */
class SmsReceiver : BroadcastReceiver() {
    private companion object {
        const val TAG = "FlowlySMS"
        val schedulerExecutor = Executors.newSingleThreadExecutor()
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION != intent.action) return
        Log.d(TAG, "receiver_received")
        if (!AutomaticDetectionStore.isEnabled(context)) {
            Log.d(TAG, "receiver_ignored_detection_disabled")
            return
        }
        if (!AutomaticDetectionStore.hasRequiredPermissions(context)) {
            Log.d(TAG, "receiver_ignored_permission_missing")
            return
        }
        // Android supplies one SmsMessage per PDU. Provider messages can span
        // several PDUs, so forwarding each fragment separately makes the live
        // parser disagree with the reconstructed body read by Historical Import.
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        val bySender = messages.groupBy { it.originatingAddress ?: "" }
        val events = bySender.map { (sender, parts) ->
            val body = parts.joinToString(separator = "") { it.messageBody ?: "" }
            val receivedAt = parts.maxOfOrNull { it.timestampMillis } ?: 0L
            Log.d(TAG, "multipart_reconstructed parts=${parts.size}")
            AutomaticDetectionStore.recordSignal(
                context,
                if (receivedAt > 0L) receivedAt else System.currentTimeMillis(),
            )
            Triple(sender, body, receivedAt)
        }
        if (events.isEmpty()) return

        val pendingResult = goAsync()
        schedulerExecutor.execute {
            try {
                SmsWorkScheduler.enqueue(context).result.get(8, TimeUnit.SECONDS)
                Log.d(TAG, "durable_work_enqueued")
                val fastEvents = events.mapNotNull { (sender, body, _) ->
                    val inboxReceivedAt = runCatching {
                        SmsInboxReader.findMatchingReceivedAt(context, sender, body)
                    }.getOrNull() ?: return@mapNotNull null
                    Triple(sender, body, inboxReceivedAt)
                }
                Handler(Looper.getMainLooper()).post {
                    for ((sender, body, receivedAt) in fastEvents) {
                        if (SmsEventBridge.publish(sender, body, receivedAt)) {
                            Log.d(TAG, "native_event_emitted")
                        }
                    }
                    pendingResult.finish()
                }
            } catch (_: Throwable) {
                Log.d(TAG, "durable_work_enqueue_failed")
                pendingResult.finish()
            }
        }
    }
}
