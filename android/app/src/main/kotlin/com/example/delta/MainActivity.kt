package com.example.delta

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterFragmentActivity() {

    private val RECORD_CHANNEL = "com.example.delta/record"
    private val REQUEST_RECORD = 1002

    private var pendingRecordResult: MethodChannel.Result? = null
    private var pendingRecordFilePath: String = ""

    companion object {
        var sharedMediaProjection: MediaProjection? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Faqat yozish channel — ekran ulashish LiveKit o'zi hal qiladi
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        val sdf = SimpleDateFormat("yyyyMMdd_HHmm", Locale.getDefault())
                        val fileName = "delta_${sdf.format(Date())}.mp4"
                        val dir = getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: filesDir
                        if (!dir.exists()) dir.mkdirs()
                        val filePath = File(dir, fileName).absolutePath

                        // Yozish uchun har doim yangi ruxsat — LiveKit ning MP siga tegmaymiz
                        pendingRecordFilePath = filePath
                        pendingRecordResult = result
                        val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                                as MediaProjectionManager
                        startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_RECORD)
                    }
                    "stopRecording" -> {
                        stopService(Intent(this, ScreenRecorderService::class.java).apply {
                            action = ScreenRecorderService.ACTION_STOP
                        })
                        sharedMediaProjection?.stop()
                        sharedMediaProjection = null
                        ScreenRecorderService.sharedMediaProjection = null
                        result.success(true)
                    }
                    "getFilePath" -> {
                        result.success(ScreenRecorderService.lastFilePath)
                    }
                    else -> result.notImplemented()
                }
            }

        createNotificationChannels()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_RECORD) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                        as MediaProjectionManager
                val mp = mgr.getMediaProjection(resultCode, data)
                sharedMediaProjection = mp
                ScreenRecorderService.sharedMediaProjection = mp

                val serviceIntent = Intent(this, ScreenRecorderService::class.java).apply {
                    action = ScreenRecorderService.ACTION_START
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
                "livekit_screen_capture"           to "Ekran ulashish",
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
