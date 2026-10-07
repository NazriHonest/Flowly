package com.example.flowly

import io.flutter.plugin.common.EventChannel
import android.util.Log

/**
 * Low-latency delivery for a currently running foreground Flutter engine.
 * Durable correctness belongs to the WorkManager inbox drain.
 */
object SmsEventBridge : EventChannel.StreamHandler {
    private const val TAG = "FlowlySMS"
    private val lock = Any()
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        synchronized(lock) { sink = events }
        Log.d(TAG, "dart_listener_attached")
    }

    override fun onCancel(arguments: Any?) {
        synchronized(lock) { sink = null }
        Log.d(TAG, "dart_listener_detached")
    }

    fun publish(sender: String, body: String, receivedAt: Long): Boolean {
        val activeSink = synchronized(lock) { sink } ?: return false
        activeSink.success(
            mapOf(
                "type" to "sms",
                "sender" to sender,
                "body" to body,
                "receivedAt" to receivedAt,
            ),
        )
        return true
    }

    fun publishDatabaseChanged() {
        val activeSink = synchronized(lock) { sink } ?: return
        activeSink.success(mapOf("type" to "database_changed"))
    }
}
