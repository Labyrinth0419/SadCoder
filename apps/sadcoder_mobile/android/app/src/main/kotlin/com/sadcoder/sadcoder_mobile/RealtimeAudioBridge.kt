package com.sadcoder.sadcoder_mobile

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

class RealtimeAudioBridge : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val captureExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val playbackExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    @Volatile
    private var inputSink: EventChannel.EventSink? = null
    @Volatile
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var playbackSampleRate: Int? = null
    private var playbackChannels: Int? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        inputSink = events
    }

    override fun onCancel(arguments: Any?) {
        inputSink = null
        stopCapture()
    }

    fun startCapture(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val sampleRate = positiveInt(args?.get("sampleRate"), 24000)
        val numChannels = positiveInt(args?.get("numChannels"), 1)
        val samplesPerChannel = positiveInt(args?.get("samplesPerChannel"), 480)
        if (numChannels != 1) {
            result.error(
                "unsupported_audio_channels",
                "Android realtime capture currently supports mono PCM only.",
                null,
            )
            return
        }
        val frameBytes = samplesPerChannel * numChannels * BYTES_PER_SAMPLE
        val minBufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBufferSize <= 0) {
            result.error(
                "audio_input_unavailable",
                "The requested microphone format is unavailable.",
                null,
            )
            return
        }

        stopCapture()
        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                max(minBufferSize, frameBytes * 4),
            )
        } catch (exception: RuntimeException) {
            result.error("audio_input_unavailable", exception.message, null)
            return
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            result.error(
                "audio_input_unavailable",
                "The microphone could not be initialized.",
                null,
            )
            return
        }

        try {
            record.startRecording()
        } catch (exception: RuntimeException) {
            record.release()
            result.error("audio_input_unavailable", exception.message, null)
            return
        }
        audioRecord = record
        result.success(null)

        captureExecutor.execute {
            val buffer = ByteArray(frameBytes)
            while (audioRecord === record && record.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                val read = try {
                    record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
                } catch (_: RuntimeException) {
                    break
                }
                if (read <= 0) {
                    break
                }
                if (read != buffer.size) {
                    continue
                }
                val frame = buffer.copyOf()
                mainHandler.post {
                    if (audioRecord === record) {
                        inputSink?.success(
                            mapOf(
                                "data" to frame,
                                "sampleRate" to sampleRate,
                                "numChannels" to numChannels,
                                "samplesPerChannel" to samplesPerChannel,
                            ),
                        )
                    }
                }
            }
        }
    }

    fun stopCapture() {
        val record = audioRecord ?: return
        audioRecord = null
        try {
            if (record.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                record.stop()
            }
        } catch (_: RuntimeException) {
            // Release still needs to run after a failed stop.
        } finally {
            record.release()
        }
    }

    fun play(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val bytes = try {
            bytes(args?.get("data"))
        } catch (exception: IllegalArgumentException) {
            result.error("invalid_audio_frame", exception.message, null)
            return
        }
        val sampleRate = positiveInt(args?.get("sampleRate"), 24000)
        val numChannels = positiveInt(args?.get("numChannels"), 1)
        if (numChannels != 1) {
            result.error(
                "unsupported_audio_channels",
                "Android realtime playback currently supports mono PCM only.",
                null,
            )
            return
        }
        playbackExecutor.execute {
            try {
                val track = ensureAudioTrack(sampleRate, numChannels, bytes.size)
                track.write(bytes, 0, bytes.size, AudioTrack.WRITE_BLOCKING)
                mainHandler.post { result.success(null) }
            } catch (exception: RuntimeException) {
                mainHandler.post {
                    result.error("audio_output_unavailable", exception.message, null)
                }
            }
        }
    }

    fun stopPlayback() {
        synchronized(this) {
            val track = audioTrack ?: return
            audioTrack = null
            playbackSampleRate = null
            playbackChannels = null
            try {
                track.stop()
            } catch (_: RuntimeException) {
                // Release the track even when it has already stopped.
            } finally {
                track.release()
            }
        }
    }

    fun dispose() {
        inputSink = null
        stopCapture()
        stopPlayback()
        captureExecutor.shutdownNow()
        playbackExecutor.shutdownNow()
    }

    private fun ensureAudioTrack(
        sampleRate: Int,
        numChannels: Int,
        frameBytes: Int,
    ): AudioTrack {
        synchronized(this) {
            val current = audioTrack
            if (current != null &&
                playbackSampleRate == sampleRate &&
                playbackChannels == numChannels
            ) {
                return current
            }
            stopPlayback()
            val minBufferSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            if (minBufferSize <= 0) {
                throw IllegalStateException("The requested speaker format is unavailable.")
            }
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setBufferSizeInBytes(max(minBufferSize, frameBytes * 4))
                .build()
            if (track.state != AudioTrack.STATE_INITIALIZED) {
                track.release()
                throw IllegalStateException("The speaker could not be initialized.")
            }
            track.play()
            audioTrack = track
            playbackSampleRate = sampleRate
            playbackChannels = numChannels
            return track
        }
    }

    private fun positiveInt(value: Any?, fallback: Int): Int {
        val parsed = when (value) {
            is Number -> value.toInt()
            else -> value?.toString()?.toIntOrNull()
        }
        return if (parsed != null && parsed > 0) parsed else fallback
    }

    private fun bytes(value: Any?): ByteArray {
        return when (value) {
            is ByteArray -> value
            is List<*> -> ByteArray(value.size) { index ->
                (value[index] as? Number)?.toByte()
                    ?: throw IllegalArgumentException("Audio data contains a non-byte value.")
            }
            else -> throw IllegalArgumentException("Audio data must be PCM bytes.")
        }
    }

    companion object {
        private const val BYTES_PER_SAMPLE = 2
    }
}
