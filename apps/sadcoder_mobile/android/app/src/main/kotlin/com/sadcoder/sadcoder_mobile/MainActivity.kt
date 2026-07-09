package com.sadcoder.sadcoder_mobile

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sadcoder.sadcoder_mobile/background_connection",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "retain" -> {
                    val args = call.arguments as? Map<*, *>
                    val intent = BackgroundConnectionService.retainIntent(
                        context = this,
                        endpoint = args?.get("endpoint") as? String,
                        threadId = args?.get("threadId") as? String,
                        turnId = args?.get("turnId") as? String,
                    )
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                    } catch (exception: RuntimeException) {
                        result.error(
                            "foreground_service_unavailable",
                            exception.message,
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    result.success(null)
                }
                "release" -> {
                    try {
                        stopService(BackgroundConnectionService.releaseIntent(this))
                    } catch (exception: RuntimeException) {
                        result.error(
                            "foreground_service_release_failed",
                            exception.message,
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
