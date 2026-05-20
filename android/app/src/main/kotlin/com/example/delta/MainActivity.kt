package com.example.delta

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterFragmentActivity() {

    private val SCREEN_CHANNEL   = "com.example.delta/screen"
    private val RECORD_CHANNEL   = "com.example.delta/record"
    private val REQUEST_SCREEN   = 1001
    private val REQUEST_RECORD   = 1002

    private var pendingScreenResult: MethodChannel.Result? = null
    private var pendingRecordResult: MethodChannel.Result? = null
    private var pendingRecordFilePath: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ekran ulashish channel (LiveKit uchun)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScreenCapture" -> {
                        pendingScreenResult = result
                        val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                                as MediaProjectionManager
                        startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_SCREEN)
                    }
                    "stopScreenCapture" -> {
                        stopService(Intent(this, ScreenCaptureService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Ekran yozish channel (native MediaCodec)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        // Fayl yo'li tayyorlaymiz
                        val sdf = SimpleDateFormat("yyyyMMdd_HHmm", Locale.getDefault())
                        val fileName = "delta_${sdf.format(Date())}.mp4"
                        val dir = getExternalFilesDir(Environment.DIRECTORY_MOVIES)
                            ?: filesDir
                        if (!dir.exists()) dir.mkdirs()
                        pendingRecordFilePath = File(dir, fileName).absolutePath
                        pendingRecordResult = result

                        // MediaProjection ruxsati so'raymiz
                        val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                                as MediaProjectionManager
                        startActivityForResult(
                            mgr.createScreenCaptureIntent(), REQUEST_RECORD)
                    }
                    "stopRecording" -> {
                        val stopIntent = Intent(this, ScreenRecorderService::class.java).apply {
                            action = ScreenRecorderService.ACTION_STOP
                        }
                        stopService(stopIntent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        createNotificationChannels()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {

            REQUEST_SCREEN -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val serviceIntent = Intent(this, ScreenCaptureService::class.java).apply {
                        putExtra("resultCode", resultCode)
                        putExtra("data", data)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        startForegroundService(serviceIntent)
                    else
                        startService(serviceIntent)

                    // LiveKit MediaProjection ni ScreenRecorderService bilan ulashamiz
                    val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                            as MediaProjectionManager
                    ScreenRecorderService.sharedMediaProjection =
                        mgr.getMediaProjection(resultCode, data)

                    pendingScreenResult?.success(true)
                } else {
                    pendingScreenResult?.error("PERMISSION_DENIED", "Ruxsat berilmadi", null)
                }
                pendingScreenResult = null
            }

            REQUEST_RECORD -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val serviceIntent = Intent(this, ScreenRecorderService::class.java).apply {
                        action = ScreenRecorderService.ACTION_START
                        putExtra(ScreenRecorderService.EXTRA_RESULT_CODE, resultCode)
                        putExtra(ScreenRecorderService.EXTRA_DATA, data)
                        putExtra(ScreenRecorderService.EXTRA_FILE_PATH, pendingRecordFilePath)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        startForegroundService(serviceIntent)
                    else
                        startService(serviceIntent)
                    pendingRecordResult?.success(pendingRecordFilePath)
                } else {
                    pendingRecordResult?.error("PERMISSION_DENIED", "Ruxsat berilmadi", null)
                }
                pendingRecordResult = null
                pendingRecordFilePath = ""
            }
        }
        // LiveKit ham shu intent ni tinglaydi
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            listOf(
                "livekit_screen_capture"          to "Ekran ulashish",
                "io.livekit.android.screencapture" to "LiveKit Screen Capture",
                "screen_capture_channel"           to "Ekran ulashish xizmati",
                ScreenRecorderService.CHANNEL_ID   to "Ekran yozish"
            ).forEach { (id, name) ->
                val ch = NotificationChannel(id, name, NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                    setSound(null, null)
                }
                manager.createNotificationChannel(ch)
            }
        }
    }
}

