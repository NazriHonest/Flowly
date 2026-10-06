package com.example.flowly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

/**
 * Delivers SMS data only to the in-process Flutter event bridge. It does not
 * write, log, cache, or otherwise persist SMS bodies.
 */
class SmsReceiver : BroadcastReceiver() {
    private companion object {
        const val TAG = "FlowlySMS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION != intent.action) return
        Log.d(TAG, "receiver_triggered")
        if (!context.getSharedPreferences("flowly_sms", Context.MODE_PRIVATE).getBoolean("enabled", false)) {
            Log.d(TAG, "receiver_ignored_detection_disabled")
            return
        }
        // Android supplies one SmsMessage per PDU. Provider messages can span
        // several PDUs, so forwarding each fragment separately makes the live
        // parser disagree with the reconstructed body read by Historical Import.
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        val bySender = messages.groupBy { it.originatingAddress ?: "" }
        for ((sender, parts) in bySender) {
            val body = parts.joinToString(separator = "") { it.messageBody ?: "" }
            val receivedAt = parts.maxOfOrNull { it.timestampMillis } ?: 0L
            Log.d(TAG, "multipart_reconstructed parts=${parts.size}")
            if (!SmsEventBridge.publish(sender, body, receivedAt)) {
                // The Flutter engine may be stopped. Launching the existing
                // activity hands the transient event to Dart without writing
                // the SMS to disk or introducing a raw-message queue.
                val launch = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra(MainActivity.EXTRA_SMS_SENDER, sender)
                    putExtra(MainActivity.EXTRA_SMS_BODY, body)
                    putExtra(MainActivity.EXTRA_SMS_RECEIVED_AT, receivedAt)
                }
                Log.d(TAG, "native_event_handed_to_activity")
                context.startActivity(launch)
            } else {
                Log.d(TAG, "native_event_emitted")
            }
        }
    }
}
