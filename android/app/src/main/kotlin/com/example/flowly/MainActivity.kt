package com.example.flowly

import android.Manifest
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.provider.Telephony
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.flowly/sms_permissions"
    private val screenshotChannelName = "com.flowly/screenshot_security"
    private val requestCode = 4801
    private var pendingResult: MethodChannel.Result? = null
    private var activityResumed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenshotChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "setScreenshotMode" -> {
                    val arguments = call.arguments
                    val enabled = when (arguments) {
                        is Boolean -> arguments
                        is Map<*, *> -> arguments["enabled"] as? Boolean
                        else -> null
                    }
                    val reason = (arguments as? Map<*, *>)?.get("reason") as? String
                        ?: "legacy_request"
                    if (enabled == null) {
                        debugScreenshotLog("setScreenshotMode rejected reason=$reason invalidArguments=true")
                        result.error(
                            "invalid_screenshot_mode_arguments",
                            "Android received an invalid screenshot mode request.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    runOnUiThread {
                        try {
                            val secureBefore = isSecureWindowEnabled()
                            debugScreenshotLog(
                                "setScreenshotMode requested=$enabled reason=$reason resumed=$activityResumed secureBefore=$secureBefore"
                            )
                            if (enabled && !activityResumed) {
                                debugScreenshotLog(
                                    "setScreenshotMode rejected reason=$reason activityResumed=false secure=$secureBefore"
                                )
                            } else if (enabled) {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            val secureEnabled = isSecureWindowEnabled()
                            val screenshotAllowed = !secureEnabled
                            debugScreenshotLog(
                                "setScreenshotMode completed requested=$enabled reason=$reason secureAfter=$secureEnabled screenshotAllowed=$screenshotAllowed"
                            )
                            result.success(
                                mapOf(
                                    "requestedEnabled" to enabled,
                                    "secureEnabled" to secureEnabled,
                                    "screenshotAllowed" to screenshotAllowed,
                                    "activityResumed" to activityResumed,
                                    "reason" to reason,
                                )
                            )
                        } catch (error: Throwable) {
                            debugScreenshotLog(
                                "setScreenshotMode failed reason=$reason type=${error.javaClass.simpleName}"
                            )
                            result.error(
                                "screenshot_mode_update_failed",
                                "Android could not update screenshot protection.",
                                null,
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(hasSmsPermission())
                "request" -> requestSmsPermission(result)
                "historical" -> readHistoricalSms(result)
                "openSettings" -> {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "automaticDetectionState" -> {
                    try {
                        val arguments = call.arguments as? Map<*, *>
                        val legacy = arguments?.get("legacyEnabled") as? Boolean
                        result.success(AutomaticDetectionStore.restore(this, legacy))
                    } catch (_: Throwable) {
                        result.error("automatic_detection_state_failed", "Could not restore automatic detection", null)
                    }
                }
                "setAutomaticDetection" -> {
                    try {
                        val enabled = call.arguments as? Boolean ?: false
                        AutomaticDetectionStore.setEnabled(this, enabled)
                        if (enabled) SmsWorkScheduler.enqueue(this)
                        result.success(null)
                    } catch (_: Throwable) {
                        result.error("automatic_detection_update_failed", "Could not update automatic detection", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flowly/sms_events")
            .setStreamHandler(SmsEventBridge)
    }

    override fun onResume() {
        super.onResume()
        activityResumed = true
        debugScreenshotLog("onResume secure=${isSecureWindowEnabled()}")
    }

    override fun onPause() {
        activityResumed = false
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        debugScreenshotLog("onPause restored secure=${isSecureWindowEnabled()}")
        super.onPause()
    }

    private fun isSecureWindowEnabled(): Boolean =
        (window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0

    private fun debugScreenshotLog(message: String) {
        val debuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (debuggable) Log.d("SpenFloScreenshot", message)
    }

    private fun hasReadSmsPermission() = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
    private fun hasSmsPermission() = hasReadSmsPermission() && ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) { result.success(true); return }
        pendingResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS), requestCode)
    }

    /** Delivers inbox rows to Dart only for a user initiated import. Dart
     * normalizes them immediately and never persists the message body. */
    private fun readHistoricalSms(result: MethodChannel.Result) {
        if (!hasReadSmsPermission()) { result.error("permission_denied", "SMS read permission is required", null); return }
        try {
            val rows = mutableListOf<Map<String, Any>>()
            contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                null, null, "${Telephony.Sms.DATE} DESC"
            )?.use { cursor ->
                val address = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val body = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val date = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
                while (cursor.moveToNext()) {
                    rows.add(mapOf(
                        "sender" to (cursor.getString(address) ?: ""),
                        "body" to (cursor.getString(body) ?: ""),
                        "receivedAt" to cursor.getLong(date),
                    ))
                }
            }
            result.success(rows)
        } catch (error: Exception) {
            result.error("sms_query_failed", error.message, null)
        }
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == requestCode) { pendingResult?.success(hasSmsPermission()); pendingResult = null }
    }
}
