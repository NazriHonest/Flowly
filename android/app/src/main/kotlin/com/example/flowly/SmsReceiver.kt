package com.example.flowly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Delivers SMS data only to the in-process Flutter event bridge. It does not
 * write, log, cache, or otherwise persist SMS bodies.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION != intent.action) return
        if (!context.getSharedPreferences("flowly_sms", Context.MODE_PRIVATE).getBoolean("enabled", false)) return
        for (message in Telephony.Sms.Intents.getMessagesFromIntent(intent)) {
            val sender = message.originatingAddress ?: ""
            val body = message.messageBody ?: ""
            val receivedAt = message.timestampMillis
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
                context.startActivity(launch)
            }
        }
    }
}
