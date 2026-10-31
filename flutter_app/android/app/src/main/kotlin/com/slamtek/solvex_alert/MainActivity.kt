package com.slamtek.solvex_alert

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "solvex/emergency"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "call" -> {
                    val rawNumber = call.argument<String>("number")
                    if (rawNumber.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val number = rawNumber.trim().replace(Regex("[^0-9+]"), "")
                    if (number.isBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val hasCallPerm = ActivityCompat.checkSelfPermission(
                            this,
                            Manifest.permission.CALL_PHONE
                        ) == PackageManager.PERMISSION_GRANTED

                        val intent = if (hasCallPerm) {
                            Intent(Intent.ACTION_CALL, Uri.parse("tel:$number"))
                        } else {
                            Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number"))
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number"))
                            dialIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(dialIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "sendSms" -> {
                    val rawNumber = call.argument<String>("number")
                    val text = call.argument<String>("text")
                    if (rawNumber.isNullOrBlank() || text.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val number = rawNumber.trim().replace(Regex("[^0-9+]"), "")
                    if (number.isBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val hasSmsPerm = ActivityCompat.checkSelfPermission(
                            this,
                            Manifest.permission.SEND_SMS
                        ) == PackageManager.PERMISSION_GRANTED

                        if (hasSmsPerm) {
                            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }
                            val parts = smsManager.divideMessage(text)
                            smsManager.sendMultipartTextMessage(number, null, parts, null, null)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "showOverLockScreen" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                            setShowWhenLocked(on)
                            setTurnScreenOn(on)
                        } else {
                            @Suppress("DEPRECATION")
                            if (on) {
                                window.addFlags(
                                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                                )
                            } else {
                                window.clearFlags(
                                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                                )
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
