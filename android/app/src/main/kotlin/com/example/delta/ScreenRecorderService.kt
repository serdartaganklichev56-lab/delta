package com.example.delta

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.*
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.File

class ScreenRecorderService : Service() {

    companion object {
        const val ACTION_START      = "ACTION_START_RECORDING"
        const val ACTION_STOP       = "ACTION_STOP_RECORDING"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA        = "data"
        const val EXTRA_FILE_PATH   = "filePath"
        const val CHANNEL_ID        = "screen_recorder_channel"
        const val NOTIF_ID          = 2

        // Ekran ulashish resultCode va data
        var screenCaptureResultCode: Int = 0
        var screenCaptureData: Intent? = null

        // Oxirgi yozilgan fayl yo'li
        var lastFilePath: String = ""
    }

    private var mediaProjection: MediaProjection? = null
    private var ownMediaProjection: Boolean = false
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaCodec: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var audioRecord: AudioRecord? = null

    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var muxerStarted    = false
    private var isRecording     = false
    private var outputFile: String = ""

    private var videoThread: Thread? = null
    private var audioThread: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                outputFile = intent.getStringExtra(EXTRA_FILE_PATH) ?: ""
                startForeground(NOTIF_ID, buildNotification())

                // FIX 1: Android 14+ da bir resultCode/data faqat BIR MediaProjection uchun
                // ishlatilishi mumkin. Shuning uchun screenCaptureData dan yangi MP ochilmaydi.
                // Intent orqali kelgan resultCode/data ishlatiladi (REQUEST_RECORD holati).
                when {
                    intent.getIntExtra(EXTRA_RESULT_CODE, 0) != 0 -> {
                        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                        val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                            intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
                        else
                            @Suppress("DEPRECATION") intent.getParcelableExtra(EXTRA_DATA)

                        if (data != null) {
                            val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                                    as MediaProjectionManager
                            mediaProjection = mgr.getMediaProjection(resultCode, data)
                            ownMediaProjection = true
                            startRecording()
                        } else stopSelf()
                    }
                    else -> stopSelf()
                }

                if (outputFile.isNotEmpty()) lastFilePath = outputFile
            }
            ACTION_STOP -> {
                stopRecording()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startRecording() {
        if (outputFile.isEmpty()) { stopSelf(); return }

        val metrics = DisplayMetrics()
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val display = display ?: wm.defaultDisplay
            display.getRealMetrics(metrics)
        } else {
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
        }

        val density = metrics.densityDpi
        var width   = metrics.widthPixels
        var height  = metrics.heightPixels

        // 720p ga cheklaymiz
        if (width > 1280 || height > 1280) {
            val scale = 1280.0 / maxOf(width, height)
            width  = (width  * scale).toInt() and 0xFFFFFFFE.toInt()
            height = (height * scale).toInt() and 0xFFFFFFFE.toInt()
        }

        try {
            setupVideoCodec(width, height)
            setupAudioRecord()
            setupMuxer()
            setupVirtualDisplay(width, height, density)
            isRecording = true
            startVideoThread()
            startAudioThread()
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    private fun setupVideoCodec(width: Int, height: Int) {
        val format = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE,       3_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE,     30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }
        mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        mediaCodec!!.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    }

    private fun setupVirtualDisplay(width: Int, height: Int, density: Int) {
        val surface = mediaCodec!!.createInputSurface()
        mediaCodec!!.start()
        virtualDisplay = mediaProjection!!.createVirtualDisplay(
            "DeltaRecorder",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            surface, null, null
        )
    }

    // FIX 2: setupAudioCodec emas, faqat AudioRecord ni bu yerda tayyor qilamiz.
    // AudioCodec ni audioThread ichida yasaymiz (thread-safe).
    private fun setupAudioRecord() {
        val sampleRate  = 44100
        val channelConf = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufSize  = AudioRecord.getMinBufferSize(sampleRate, channelConf, audioFormat)

        // FIX 3: VOICE_COMMUNICATION ishlatiladi — MIC gürültüyü ko'proq beradi,
        // VOICE_COMMUNICATION esa echo cancellation bilan yaxshiroq ishlaydi.
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            sampleRate, channelConf, audioFormat,
            minBufSize * 4  // FIX 4: buffer kattaroq — underrun oldini olish uchun
        )
    }

    private fun setupMuxer() {
        val f = File(outputFile)
        if (f.exists()) f.delete()
        mediaMuxer = MediaMuxer(outputFile, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    private fun startVideoThread() {
        videoThread = Thread {
            val bufferInfo = MediaCodec.BufferInfo()
            while (isRecording) {
                val index = mediaCodec!!.dequeueOutputBuffer(bufferInfo, 10_000)
                when {
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        videoTrackIndex = mediaMuxer!!.addTrack(mediaCodec!!.outputFormat)
                        startMuxerIfReady()
                    }
                    index >= 0 -> {
                        if (muxerStarted &&
                            bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                            val buf = mediaCodec!!.getOutputBuffer(index)!!
                            mediaMuxer!!.writeSampleData(videoTrackIndex, buf, bufferInfo)
                        }
                        mediaCodec!!.releaseOutputBuffer(index, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                    }
                }
            }
        }.also { it.start() }
    }

    private fun startAudioThread() {
        audioThread = Thread {
            val sampleRate = 44100
            val bitRate    = 128_000
            val minBufSize = AudioRecord.getMinBufferSize(
                sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)

            val audioFormat = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 1).apply {
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                setInteger(MediaFormat.KEY_AAC_PROFILE,
                    MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, minBufSize * 2)
            }

            val audioCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            audioCodec.configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            audioCodec.start()
            audioRecord!!.startRecording()

            val pcmBuf     = ByteArray(minBufSize)
            val bufferInfo = MediaCodec.BufferInfo()
            var presentationTimeUs = 0L

            while (isRecording) {
                val read = audioRecord!!.read(pcmBuf, 0, pcmBuf.size)
                if (read > 0) {
                    val inputIndex = audioCodec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuf = audioCodec.getInputBuffer(inputIndex)!!
                        inputBuf.clear()
                        inputBuf.put(pcmBuf, 0, read)
                        audioCodec.queueInputBuffer(inputIndex, 0, read, presentationTimeUs, 0)
                        presentationTimeUs += (read * 1_000_000L) / (sampleRate * 2)
                    }
                }

                // FIX 5: INFO_OUTPUT_FORMAT_CHANGED (-2) manfiy son, while (>= 0) ga kirmasligi kerak.
                // Alohida tekshiruv bilan olib chiqamiz.
                var outputIndex = audioCodec.dequeueOutputBuffer(bufferInfo, 0)
                while (outputIndex != MediaCodec.INFO_TRY_AGAIN_LATER) {
                    when {
                        outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            audioTrackIndex = mediaMuxer!!.addTrack(audioCodec.outputFormat)
                            startMuxerIfReady()
                        }
                        outputIndex >= 0 -> {
                            if (muxerStarted &&
                                bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                                val buf = audioCodec.getOutputBuffer(outputIndex)!!
                                mediaMuxer!!.writeSampleData(audioTrackIndex, buf, bufferInfo)
                            }
                            audioCodec.releaseOutputBuffer(outputIndex, false)
                        }
                    }
                    outputIndex = audioCodec.dequeueOutputBuffer(bufferInfo, 0)
                }
            }

            audioRecord!!.stop()
            audioCodec.stop()
            audioCodec.release()
        }.also { it.start() }
    }

    @Synchronized
    private fun startMuxerIfReady() {
        if (!muxerStarted && videoTrackIndex >= 0 && audioTrackIndex >= 0) {
            mediaMuxer!!.start()
            muxerStarted = true
        }
    }

    private fun stopRecording() {
        isRecording = false

        // FIX 6: signalEndOfInputStream AVVAL chaqirilishi kerak (thread join dan oldin),
        // aks holda videoThread hech qachon END_OF_STREAM ni olmaydi va join timeout beradi.
        try { mediaCodec?.signalEndOfInputStream() } catch (_: Exception) {}

        try { videoThread?.join(3000) } catch (_: Exception) {}
        try { audioThread?.join(3000) } catch (_: Exception) {}

        try { mediaCodec?.stop(); mediaCodec?.release() } catch (_: Exception) {}
        try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
        try { virtualDisplay?.release() } catch (_: Exception) {}
        if (ownMediaProjection) {
            try { mediaProjection?.stop() } catch (_: Exception) {}
        }

        // FIX 7: mediaMuxer?.stop() va mediaMuxer?.release() bir try blokida bo'lishi kerak,
        // lekin stop() ishlamasa release() ham chaqirilmay qoladi. Ikki try ajratildi.
        try { if (muxerStarted) mediaMuxer?.stop() } catch (_: Exception) {}
        try { mediaMuxer?.release() } catch (_: Exception) {}

        mediaCodec      = null
        audioRecord     = null
        virtualDisplay  = null
        mediaProjection = null
        mediaMuxer      = null
        muxerStarted    = false
        videoTrackIndex = -1
        audioTrackIndex = -1
    }

    override fun onDestroy() {
        if (isRecording) stopRecording()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "Ekran yozish",
                NotificationManager.IMPORTANCE_LOW
            ).apply { setShowBadge(false); setSound(null, null) }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Delta — Yozilmoqda")
                .setContentText("Ekran yozish davom etmoqda...")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Delta — Yozilmoqda")
                .setContentText("Ekran yozish davom etmoqda...")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .build()
        }
    }
}
