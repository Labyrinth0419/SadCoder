package com.sadcoder.sadcoder_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionRetainRequest: RetainRequest? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sadcoder.sadcoder_mobile/background_connection",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "retain" -> {
                    val args = call.arguments as? Map<*, *>
                    retainWithNotificationPermission(
                        RetainRequest(
                            endpoint = args?.get("endpoint") as? String,
                            threadId = args?.get("threadId") as? String,
                            turnId = args?.get("turnId") as? String,
                        ),
                        result,
                    )
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) {
            return
        }

        val result = pendingNotificationPermissionResult ?: return
        val retainRequest = pendingNotificationPermissionRetainRequest
        pendingNotificationPermissionResult = null
        pendingNotificationPermissionRetainRequest = null

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        if (granted && retainRequest != null) {
            startRetainService(retainRequest, result)
            return
        }

        result.error(
            "notification_permission_denied",
            "Notification permission is required to keep an active task connected in the background.",
            null,
        )
    }

    private fun retainWithNotificationPermission(
        retainRequest: RetainRequest,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            startRetainService(retainRequest, result)
            return
        }

        if (pendingNotificationPermissionResult != null) {
            result.error(
                "notification_permission_request_pending",
                "A notification permission request is already in progress.",
                null,
            )
            return
        }

        pendingNotificationPermissionResult = result
        pendingNotificationPermissionRetainRequest = retainRequest
        try {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE,
            )
        } catch (exception: RuntimeException) {
            pendingNotificationPermissionResult = null
            pendingNotificationPermissionRetainRequest = null
            result.error(
                "notification_permission_unavailable",
                exception.message,
                null,
            )
        }
    }

    private fun startRetainService(
        retainRequest: RetainRequest,
        result: MethodChannel.Result,
    ) {
        val intent = BackgroundConnectionService.retainIntent(
            context = this,
            endpoint = retainRequest.endpoint,
            threadId = retainRequest.threadId,
            turnId = retainRequest.turnId,
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
            return
        }
        result.success(null)
    }

    private data class RetainRequest(
        val endpoint: String?,
        val threadId: String?,
        val turnId: String?,
    )

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002
    }
}
