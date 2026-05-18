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
import java.io.IOException

class ScreenRecorderService : Service() {

    companion object {
        const val ACTION_START = "ACTION_START_RECORDING"
        const val ACTION_STOP  = "ACTION_STOP_RECORDING"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA        = "data"
        const val EXTRA_FILE_PATH   = "filePath"
        const val CHANNEL_ID        = "screen_recorder_channel"
        const val NOTIF_ID          = 2
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay?   = null
    private var mediaCodec: MediaCodec?           = null
    private var mediaMuxer: MediaMuxer?           = null
    private var audioRecord: AudioRecord?         = null

    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var muxerStarted   = false
    private var isRecording    = false

    private var outputFile: String = ""

    // Thread lar
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
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                val data       = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                    intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
                else
                    @Suppress("DEPRECATION") intent.getParcelableExtra(EXTRA_DATA)
                outputFile = intent.getStringExtra(EXTRA_FILE_PATH) ?: ""

                startForeground(NOTIF_ID, buildNotification())

                if (data != null && outputFile.isNotEmpty()) {
                    val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    mediaProjection = mgr.getMediaProjection(resultCode, data)
                    startRecording()
                } else {
                    stopSelf()
                }
            }
            ACTION_STOP -> {
                stopRecording()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    // ─── Yozishni boshlash ────────────────────────────────────────────────────

    private fun startRecording() {
        val metrics = DisplayMetrics()
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val display = display ?: wm.defaultDisplay
            display.getRealMetrics(metrics)
        } else {
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
        }

        // Ekran o'lchamlari — 720p ga cheklaymiz (xotira tejash)
        val density = metrics.densityDpi
        var width   = metrics.widthPixels
        var height  = metrics.heightPixels
        if (width > 1280 || height > 1280) {
            val scale = 1280.0 / maxOf(width, height)
            width  = (width  * scale).toInt() and 0xFFFFFFFE.toInt()
            height = (height * scale).toInt() and 0xFFFFFFFE.toInt()
        }

        try {
            setupVideoCodec(width, height)
            setupAudioCodec()
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

    // ─── Video codec ──────────────────────────────────────────────────────────

    private fun setupVideoCodec(width: Int, height: Int) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE,   4_000_000)  // 4 Mbps
            setInteger(MediaFormat.KEY_FRAME_RATE,  30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }
        mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        mediaCodec!!.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    }

    private fun setupVirtualDisplay(width: Int, height: Int, density: Int) {
        val surface = mediaCodec!!.createInputSurface()
        mediaCodec!!.start()
        virtualDisplay = mediaProjection!!.createVirtualDisplay(
            "ScreenRecorder",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            surface, null, null
        )
    }

    // ─── Audio codec ──────────────────────────────────────────────────────────

    private fun setupAudioCodec() {
        val sampleRate  = 44100
        val channelConf = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufSize  = AudioRecord.getMinBufferSize(sampleRate, channelConf, audioFormat)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate, channelConf, audioFormat,
            minBufSize * 2
        )
    }

    // ─── Muxer (video + audio → mp4) ─────────────────────────────────────────

    private fun setupMuxer() {
        // Fayl mavjud bo'lsa o'chiramiz
        val f = File(outputFile)
        if (f.exists()) f.delete()
        mediaMuxer = MediaMuxer(outputFile, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    // ─── Video thread ─────────────────────────────────────────────────────────

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
                        if (muxerStarted && bufferInfo.flags and
                            MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
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

    // ─── Audio thread ─────────────────────────────────────────────────────────

    private fun startAudioThread() {
        audioThread = Thread {
            val sampleRate  = 44100
            val bitRate     = 128_000
            val minBufSize  = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )

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

            val pcmBuf = ByteArray(minBufSize)
            val bufferInfo = MediaCodec.BufferInfo()
            var presentationTimeUs = 0L

            while (isRecording) {
                // PCM dan audio o'qiymiz
                val read = audioRecord!!.read(pcmBuf, 0, pcmBuf.size)
                if (read > 0) {
                    val inputIndex = audioCodec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuf = audioCodec.getInputBuffer(inputIndex)!!
                        inputBuf.clear()
                        inputBuf.put(pcmBuf, 0, read)
                        audioCodec.queueInputBuffer(
                            inputIndex, 0, read, presentationTimeUs, 0)
                        presentationTimeUs += (read * 1_000_000L) / (sampleRate * 2)
                    }
                }

                // Encode qilingan audio ni muxer ga yozamiz
                var outputIndex = audioCodec.dequeueOutputBuffer(bufferInfo, 0)
                while (outputIndex >= 0) {
                    when {
                        outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            audioTrackIndex = mediaMuxer!!.addTrack(audioCodec.outputFormat)
                            startMuxerIfReady()
                        }
                        outputIndex >= 0 -> {
                            if (muxerStarted && bufferInfo.flags and
                                MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                                val buf = audioCodec.getOutputBuffer(outputIndex)!!
                                mediaMuxer!!.writeSampleData(audioTrackIndex, buf, bufferInfo)
                            }
                            audioCodec.releaseOutputBuffer(outputIndex, false)
                        }
                    }
                    outputIndex = audioCodec.dequeueOutputBuffer(bufferInfo, 0)
                }
            }

            // Tozalash
            audioRecord!!.stop()
            audioCodec.stop()
            audioCodec.release()
        }.also { it.start() }
    }

    // ─── Muxer boshlash (video + audio tayyor bo'lganda) ─────────────────────

    @Synchronized
    private fun startMuxerIfReady() {
        if (!muxerStarted && videoTrackIndex >= 0 && audioTrackIndex >= 0) {
            mediaMuxer!!.start()
            muxerStarted = true
        }
    }

    // ─── Yozishni to'xtatish ──────────────────────────────────────────────────

    private fun stopRecording() {
        isRecording = false
        try { videoThread?.join(3000) } catch (_: Exception) {}
        try { audioThread?.join(3000) } catch (_: Exception) {}

        try { mediaCodec?.signalEndOfInputStream() } catch (_: Exception) {}
        try { mediaCodec?.stop(); mediaCodec?.release() } catch (_: Exception) {}
        try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
        try { virtualDisplay?.release() } catch (_: Exception) {}
        try { mediaProjection?.stop() } catch (_: Exception) {}
        try { if (muxerStarted) mediaMuxer?.stop(); mediaMuxer?.release() } catch (_: Exception) {}

        mediaCodec     = null
        audioRecord    = null
        virtualDisplay = null
        mediaProjection = null
        mediaMuxer     = null
        muxerStarted   = false
        videoTrackIndex = -1
        audioTrackIndex = -1
    }

    override fun onDestroy() {
        if (isRecording) stopRecording()
        super.onDestroy()
    }

    // ─── Notification ─────────────────────────────────────────────────────────

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
