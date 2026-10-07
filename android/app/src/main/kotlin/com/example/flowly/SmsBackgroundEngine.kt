package com.example.flowly

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object SmsBackgroundEngine {
    private const val CHANNEL = "com.flowly/sms_background"
    private const val TIMEOUT_MINUTES = 5L

    data class Result(
        val retry: Boolean,
        val changed: Boolean,
        val acknowledgedId: Long?,
        val acknowledgedAt: Long?,
    )

    fun process(context: Context, rows: List<Map<String, Any>>): Result? {
        val completed = CountDownLatch(1)
        var response: Result? = null
        var engine: FlutterEngine? = null

        Handler(Looper.getMainLooper()).post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context.applicationContext)
                loader.ensureInitializationComplete(context.applicationContext, null)
                val flutterEngine = FlutterEngine(context.applicationContext)
                engine = flutterEngine
                val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                channel.setMethodCallHandler { call: MethodCall, reply: MethodChannel.Result ->
                    if (call.method == "isAutomaticDetectionEnabled") {
                        reply.success(
                            AutomaticDetectionStore.isEnabled(context) &&
                                AutomaticDetectionStore.hasRequiredPermissions(context),
                        )
                        return@setMethodCallHandler
                    }
                    if (call.method != "backgroundReady") {
                        reply.notImplemented()
                        return@setMethodCallHandler
                    }
                    reply.success(null)
                    channel.invokeMethod("processRows", rows, object : MethodChannel.Result {
                        override fun success(value: Any?) {
                            val map = value as? Map<*, *>
                            response = Result(
                                retry = map?.get("retry") as? Boolean ?: true,
                                changed = map?.get("changed") as? Boolean ?: false,
                                acknowledgedId = (map?.get("acknowledgedId") as? Number)?.toLong(),
                                acknowledgedAt = (map?.get("acknowledgedAt") as? Number)?.toLong(),
                            )
                            completed.countDown()
                        }

                        override fun error(code: String, message: String?, details: Any?) {
                            completed.countDown()
                        }

                        override fun notImplemented() {
                            completed.countDown()
                        }
                    })
                }
                val entrypoint = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "smsBackgroundMain",
                )
                flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
            } catch (_: Throwable) {
                completed.countDown()
            }
        }

        completed.await(TIMEOUT_MINUTES, TimeUnit.MINUTES)
        Handler(Looper.getMainLooper()).post { engine?.destroy() }
        return response
    }
}
