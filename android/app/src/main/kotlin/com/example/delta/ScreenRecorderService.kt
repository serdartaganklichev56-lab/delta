package com.example.delta

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.*
import android.media.projection.MediaProjection
import android.os.*
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.File

class ScreenRecorderService : Service() {

    companion object {
        const val ACTION_START      = "ACTION_START_RECORDING"
        const val ACTION_STOP       = "ACTION_STOP_RECORDING"
        const val EXTRA_FILE_PATH   = "filePath"
        const val CHANNEL_ID        = "screen_recorder_channel"
        const val NOTIF_ID          = 2

        // MainActivity tomonidan beriladi — LiveKit bilan birgalikdagi MediaProjection
        var sharedMediaProjection: MediaProjection? = null

        var lastFilePath: String = ""
    }

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
                if (outputFile.isEmpty() || sharedMediaProjection == null) {
                    stopSelf(); return START_NOT_STICKY
                }
                if (outputFile.isNotEmpty()) lastFilePath = outputFile
                startForeground(NOTIF_ID, buildNotification())
                startRecording()
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

        if (width > 1280 || height > 1280) {
            val scale = 1280.0 / maxOf(width, height)
            width  = (width  * scale).toInt() and 0xFFFFFFFE.toInt()
            height = (height * scale).toInt() and 0xFFFFFFFE.toInt()
        }

        try {
            setupVideoCodec(width, height)
            setupAudioRecord()
            setupMuxer()
            // ✅ sharedMediaProjection dan 2-VirtualDisplay — LiveKit ning 1-si davom etadi
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
            setInteger(MediaFormat.KEY_BIT_RATE,         3_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE,       30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }
        mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        mediaCodec!!.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    }

    private fun setupVirtualDisplay(width: Int, height: Int, density: Int) {
        val surface = mediaCodec!!.createInputSurface()
        mediaCodec!!.start()
        // ✅ sharedMediaProjection.createVirtualDisplay — 2-VirtualDisplay
        virtualDisplay = sharedMediaProjection!!.createVirtualDisplay(
            "DeltaRecorder",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            surface, null, null
        )
    }

    private fun setupAudioRecord() {
        val sampleRate  = 44100
        val channelConf = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufSize  = AudioRecord.getMinBufferSize(sampleRate, channelConf, audioFormat)
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            sampleRate, channelConf, audioFormat,
            minBufSize * 4
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
                            mediaMuxer!!.writeSampleData(
                                videoTrackIndex, mediaCodec!!.getOutputBuffer(index)!!, bufferInfo)
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
            val minBufSize = AudioRecord.getMinBufferSize(
                sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)

            val audioFormat = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 1).apply {
                setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
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
                                mediaMuxer!!.writeSampleData(
                                    audioTrackIndex, audioCodec.getOutputBuffer(outputIndex)!!, bufferInfo)
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
        try { mediaCodec?.signalEndOfInputStream() } catch (_: Exception) {}
        try { videoThread?.join(3000) } catch (_: Exception) {}
        try { audioThread?.join(3000) } catch (_: Exception) {}
        try { mediaCodec?.stop(); mediaCodec?.release() } catch (_: Exception) {}
        try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
        // ✅ VirtualDisplay release — MediaProjection'ga ta'sir qilmaydi, LiveKit davom etadi
        try { virtualDisplay?.release() } catch (_: Exception) {}
        try { if (muxerStarted) mediaMuxer?.stop() } catch (_: Exception) {}
        try { mediaMuxer?.release() } catch (_: Exception) {}

        mediaCodec      = null
        audioRecord     = null
        virtualDisplay  = null
        mediaMuxer      = null
        muxerStarted    = false
        videoTrackIndex = -1
        audioTrackIndex = -1
        // ✅ sharedMediaProjection ni STOP qilmaymiz — LiveKit uchun kerak
    }

    override fun onDestroy() {
        if (isRecording) stopRecording()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "Ekran yozish", NotificationManager.IMPORTANCE_LOW
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
