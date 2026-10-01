package com.example.flowly

import android.Manifest
import android.content.pm.PackageManager
import android.provider.Telephony
import android.content.Intent
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_SMS_SENDER = "flowly_sms_sender"
        const val EXTRA_SMS_BODY = "flowly_sms_body"
        const val EXTRA_SMS_RECEIVED_AT = "flowly_sms_received_at"
    }
    private val channelName = "com.flowly/sms_permissions"
    private val requestCode = 4801
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(hasSmsPermission())
                "request" -> requestSmsPermission(result)
                "historical" -> readHistoricalSms(result)
                "openSettings" -> {
                    startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "setAutomaticDetection" -> {
                    getSharedPreferences("flowly_sms", MODE_PRIVATE).edit()
                        .putBoolean("enabled", call.arguments as? Boolean ?: false)
                        .apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flowly/sms_events")
            .setStreamHandler(SmsEventBridge)
        publishIntentSms(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        publishIntentSms(intent)
    }

    private fun publishIntentSms(intent: Intent?) {
        val sender = intent?.getStringExtra(EXTRA_SMS_SENDER) ?: return
        val body = intent.getStringExtra(EXTRA_SMS_BODY) ?: return
        val receivedAt = intent.getLongExtra(EXTRA_SMS_RECEIVED_AT, 0L)
        SmsEventBridge.publish(sender, body, receivedAt)
        intent.removeExtra(EXTRA_SMS_SENDER)
        intent.removeExtra(EXTRA_SMS_BODY)
        intent.removeExtra(EXTRA_SMS_RECEIVED_AT)
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
