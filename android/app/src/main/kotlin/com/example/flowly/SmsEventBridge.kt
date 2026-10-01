package com.example.flowly

import io.flutter.plugin.common.EventChannel

/** The sink exists only while a Flutter listener is attached. */
object SmsEventBridge : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun publish(sender: String, body: String, receivedAt: Long): Boolean {
        val activeSink = sink ?: return false
        activeSink.success(mapOf("sender" to sender, "body" to body, "receivedAt" to receivedAt))
        return true
    }
}
