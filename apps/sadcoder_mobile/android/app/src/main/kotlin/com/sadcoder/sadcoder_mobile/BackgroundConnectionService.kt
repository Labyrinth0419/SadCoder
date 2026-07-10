package com.sadcoder.sadcoder_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class BackgroundConnectionService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_RETAIN) {
            stopSelf()
            return START_NOT_STICKY
        }

        createNotificationChannel()
        val notification = buildNotification(
            profileId = intent.getStringExtra(EXTRA_PROFILE_ID),
            endpoint = intent.getStringExtra(EXTRA_ENDPOINT),
            threadId = intent.getStringExtra(EXTRA_THREAD_ID),
            turnId = intent.getStringExtra(EXTRA_TURN_ID),
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (exception: RuntimeException) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SadCoder active task",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the active SadCoder connection alive while the app is in the background."
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(
        profileId: String?,
        endpoint: String?,
        threadId: String?,
        turnId: String?,
    ): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.apply {
            action = ACTION_OPEN_ACTIVE_TASK
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_PROFILE_ID, profileId)
            putExtra(EXTRA_ENDPOINT, endpoint)
            putExtra(EXTRA_THREAD_ID, threadId)
            putExtra(EXTRA_TURN_ID, turnId)
        }
        val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            pendingIntentFlags,
        )
        val content = listOfNotNull(
            endpoint?.takeIf { it.isNotBlank() },
            threadId?.takeIf { it.isNotBlank() }?.let { "thread $it" },
            turnId?.takeIf { it.isNotBlank() }?.let { "turn $it" },
        ).joinToString(" - ").ifBlank {
            "Active Codex task is still running."
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("SadCoder active task")
            .setContentText(content)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    companion object {
        private const val ACTION_RETAIN =
            "com.sadcoder.sadcoder_mobile.background_connection.RETAIN"
        private const val ACTION_OPEN_ACTIVE_TASK =
            "com.sadcoder.sadcoder_mobile.background_connection.OPEN_ACTIVE_TASK"
        private const val CHANNEL_ID = "sadcoder_active_task"
        private const val NOTIFICATION_ID = 1001
        private const val EXTRA_PROFILE_ID = "profileId"
        private const val EXTRA_ENDPOINT = "endpoint"
        private const val EXTRA_THREAD_ID = "threadId"
        private const val EXTRA_TURN_ID = "turnId"

        fun retainIntent(
            context: Context,
            profileId: String?,
            endpoint: String?,
            threadId: String?,
            turnId: String?,
        ): Intent {
            return Intent(context, BackgroundConnectionService::class.java).apply {
                action = ACTION_RETAIN
                putExtra(EXTRA_PROFILE_ID, profileId)
                putExtra(EXTRA_ENDPOINT, endpoint)
                putExtra(EXTRA_THREAD_ID, threadId)
                putExtra(EXTRA_TURN_ID, turnId)
            }
        }

        fun releaseIntent(context: Context): Intent {
            return Intent(context, BackgroundConnectionService::class.java)
        }

        fun notificationRoute(intent: Intent?): Map<String, String?>? {
            if (intent?.action != ACTION_OPEN_ACTIVE_TASK) {
                return null
            }
            return mapOf(
                EXTRA_PROFILE_ID to intent.getStringExtra(EXTRA_PROFILE_ID),
                EXTRA_ENDPOINT to intent.getStringExtra(EXTRA_ENDPOINT),
                EXTRA_THREAD_ID to intent.getStringExtra(EXTRA_THREAD_ID),
                EXTRA_TURN_ID to intent.getStringExtra(EXTRA_TURN_ID),
            )
        }
    }
}
