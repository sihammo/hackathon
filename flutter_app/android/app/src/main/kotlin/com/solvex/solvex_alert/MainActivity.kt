package com.solvex.solvex_alert

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge "solvex/emergency":
 *  - sendSms(number, text): sends an SMS directly (no user interaction), split in parts if long.
 *  - call(number): places a phone call directly (CALL_PHONE permission).
 *  - showOverLockScreen(on): lets the alarm screen appear over the lock screen.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "solvex/emergency"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val number = call.argument<String>("number")
                        val text = call.argument<String>("text")
                        if (number.isNullOrBlank() || text.isNullOrEmpty()) {
                            result.error("ARG", "number and text are required", null)
                        } else {
                            try {
                                val sms = smsManager()
                                val parts = sms.divideMessage(text)
                                sms.sendMultipartTextMessage(number, null, parts, null, null)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SMS", e.message, null)
                            }
                        }
                    }
                    "call" -> {
                        val number = call.argument<String>("number")
                        if (number.isNullOrBlank()) {
                            result.error("ARG", "number is required", null)
                        } else {
                            try {
                                val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:" + Uri.encode(number)))
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("CALL", e.message, null)
                            }
                        }
                    }
                    "showOverLockScreen" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        setLockScreenFlags(on)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun smsManager(): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            applicationContext.getSystemService(SmsManager::class.java)
        } else {
            SmsManager.getDefault()
        }

    @Suppress("DEPRECATION")
    private fun setLockScreenFlags(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
