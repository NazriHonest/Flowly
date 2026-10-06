package com.example.flowly

import io.flutter.plugin.common.EventChannel
import java.util.ArrayDeque
import android.util.Log

/**
 * Holds an SMS only in process memory while Flutter is starting. This closes
 * the Activity/EventChannel startup race without writing or logging raw SMS
 * data. The bounded queue is flushed as soon as Dart attaches its listener.
 */
object SmsEventBridge : EventChannel.StreamHandler {
    private const val TAG = "FlowlySMS"
    private data class PendingSms(
        val sender: String,
        val body: String,
        val receivedAt: Long,
    )

    private const val MAX_PENDING_EVENTS = 20
    private val pending = ArrayDeque<PendingSms>()
    private val lock = Any()
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val toDeliver = synchronized(lock) {
            sink = events
            pending.toList().also { pending.clear() }
        }
        toDeliver.forEach { event ->
            events?.success(
                mapOf(
                    "sender" to event.sender,
                    "body" to event.body,
                    "receivedAt" to event.receivedAt,
                ),
            )
        }
        Log.d(TAG, "dart_listener_attached pending=${toDeliver.size}")
    }

    override fun onCancel(arguments: Any?) {
        synchronized(lock) { sink = null }
        Log.d(TAG, "dart_listener_detached")
    }

    /** Delivers immediately only when Dart is already listening. */
    fun publish(sender: String, body: String, receivedAt: Long): Boolean {
        val activeSink = synchronized(lock) { sink } ?: return false
        activeSink.success(mapOf("sender" to sender, "body" to body, "receivedAt" to receivedAt))
        return true
    }

    /** Used after Activity startup; queues once if Dart has not attached yet. */
    fun publishOrQueue(sender: String, body: String, receivedAt: Long) {
        val activeSink = synchronized(lock) {
            sink ?: run {
                if (pending.size == MAX_PENDING_EVENTS) pending.removeFirst()
                pending.addLast(PendingSms(sender, body, receivedAt))
                Log.d(TAG, "native_event_queued")
                null
            }
        }
        activeSink?.success(
            mapOf("sender" to sender, "body" to body, "receivedAt" to receivedAt),
        )
    }
}
