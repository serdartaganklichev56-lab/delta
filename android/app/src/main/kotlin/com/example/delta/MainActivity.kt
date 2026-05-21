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

    private val SCREEN_CHANNEL = "com.example.delta/screen"
    private val RECORD_CHANNEL = "com.example.delta/record"
    private val REQUEST_SCREEN = 1001

    private var pendingScreenResult: MethodChannel.Result? = null
    private var pendingRecordResult: MethodChannel.Result? = null
    private var pendingRecordFilePath: String = ""

    companion object {
        // Yagona MediaProjection — LiveKit ham, Recorder ham shu orqali ishlaydi
        var sharedMediaProjection: MediaProjection? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ekran ulashish channel (LiveKit uchun)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScreenCapture" -> {
                        if (sharedMediaProjection != null) {
                            // Allaqachon bor — qayta ruxsat so'ramaymiz
                            result.success(true)
                        } else {
                            pendingScreenResult = result
                            val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                                    as MediaProjectionManager
                            startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_SCREEN)
                        }
                    }
                    "stopScreenCapture" -> {
                        // Recorder ham ishlab turgan bo'lishi mumkin — avval to'xtatamiz
                        stopService(Intent(this, ScreenRecorderService::class.java).apply {
                            action = ScreenRecorderService.ACTION_STOP
                        })
                        stopService(Intent(this, ScreenCaptureService::class.java))
                        sharedMediaProjection?.stop()
                        sharedMediaProjection = null
                        ScreenRecorderService.sharedMediaProjection = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Ekran yozish channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        val sdf = SimpleDateFormat("yyyyMMdd_HHmm", Locale.getDefault())
                        val fileName = "delta_${sdf.format(Date())}.mp4"
                        val dir = getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: filesDir
                        if (!dir.exists()) dir.mkdirs()
                        val filePath = File(dir, fileName).absolutePath

                        if (sharedMediaProjection != null) {
                            // ✅ Ekran ulashish ochiq — shu MediaProjection dan 2-VirtualDisplay
                            ScreenRecorderService.sharedMediaProjection = sharedMediaProjection
                            val serviceIntent = Intent(this, ScreenRecorderService::class.java).apply {
                                action = ScreenRecorderService.ACTION_START
                                putExtra(ScreenRecorderService.EXTRA_FILE_PATH, filePath)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                                startForegroundService(serviceIntent)
                            else
                                startService(serviceIntent)
                            result.success(filePath)
                        } else {
                            // Ekran ulashish yo'q — ruxsat so'raymiz (bu ham LiveKit uchun ochadi)
                            pendingRecordFilePath = filePath
                            pendingRecordResult = result
                            // REQUEST_SCREEN ishlatamiz — bir ruxsat har ikkisiga yetadi
                            pendingScreenResult = null
                            val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                                    as MediaProjectionManager
                            startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_SCREEN)
                        }
                    }
                    "stopRecording" -> {
                        stopService(Intent(this, ScreenRecorderService::class.java).apply {
                            action = ScreenRecorderService.ACTION_STOP
                        })
                        // sharedMediaProjection qoladi — LiveKit davom etadi
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
        if (requestCode == REQUEST_SCREEN) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                // Yagona MediaProjection ochiladi
                val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                        as MediaProjectionManager
                val mp = mgr.getMediaProjection(resultCode, data)
                sharedMediaProjection = mp

                // LiveKit uchun foreground service
                val serviceIntent = Intent(this, ScreenCaptureService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    startForegroundService(serviceIntent)
                else
                    startService(serviceIntent)

                if (pendingRecordResult != null) {
                    // Yozish uchun kelgan — recorder ni ham shu MP bilan ishga tushuramiz
                    ScreenRecorderService.sharedMediaProjection = mp
                    val recIntent = Intent(this, ScreenRecorderService::class.java).apply {
                        action = ScreenRecorderService.ACTION_START
                        putExtra(ScreenRecorderService.EXTRA_FILE_PATH, pendingRecordFilePath)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        startForegroundService(recIntent)
                    else
                        startService(recIntent)
                    pendingRecordResult?.success(pendingRecordFilePath)
                    pendingRecordResult = null
                    pendingRecordFilePath = ""
                }

                pendingScreenResult?.success(true)
            } else {
                pendingScreenResult?.error("PERMISSION_DENIED", "Ruxsat berilmadi", null)
                pendingRecordResult?.error("PERMISSION_DENIED", "Ruxsat berilmadi", null)
                pendingRecordResult = null
                pendingRecordFilePath = ""
            }
            pendingScreenResult = null
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
