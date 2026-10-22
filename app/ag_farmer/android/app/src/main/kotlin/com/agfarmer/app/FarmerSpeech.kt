package com.agfarmer.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * On-device speech bridge used by the Play build (version 12 AAB).
 * Channels: ag_farmer/speech_ctl + ag_farmer/speech
 */
class FarmerSpeech(private val activity: Activity) : EventChannel.StreamHandler {
    companion object {
        private const val TAG = "AgFarmerSpeech"
        private const val CHANNEL_CTL = "ag_farmer/speech_ctl"
        private const val CHANNEL_EVENTS = "ag_farmer/speech"
        private const val REQ_MIC = 4401
    }

    private val main = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var events: EventChannel.EventSink? = null
    private var running = false
    private var restarting = false
    private var hot = false
    private var lang = "hi-IN"
    private var silenceMs = 5000
    private var lastRmsAt = 0L
    private var lastStartAt = 0L
    private var readyCb: ((Boolean) -> Unit)? = null
    private var heardSpeech = false
    private var cue: TextToSpeech? = null
    private var cueReady = false
    private var systemMuted = false
    private val savedBeeps = HashMap<Int, Int>()
    private val beepStreams = intArrayOf(
        AudioManager.STREAM_MUSIC,
        AudioManager.STREAM_NOTIFICATION,
        AudioManager.STREAM_SYSTEM,
        AudioManager.STREAM_DTMF,
    )

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            Log.i(TAG, "ready")
            hot = true
            markReady()
            emit(mapOf("type" to "ready"))
        }

        override fun onBeginningOfSpeech() {
            Log.i(TAG, "begin")
            heardSpeech = true
            emit(mapOf("type" to "begin"))
        }

        override fun onRmsChanged(rmsdB: Float) {
            lastRmsAt = SystemClock.uptimeMillis()
            emit(mapOf("type" to "rms", "db" to rmsdB.toDouble()))
        }

        override fun onBufferReceived(buffer: ByteArray?) {}

        override fun onEndOfSpeech() {
            Log.i(TAG, "end")
            hot = false
            emit(mapOf("type" to "end"))
        }

        override fun onError(error: Int) {
            val wasHot = hot
            Log.w(TAG, "error $error hot=$wasHot")
            hot = false
            emit(mapOf("type" to "error", "code" to error))
            val cb = readyCb
            if (cb != null && error != 7 && error != 6) {
                readyCb = null
                cb(false)
            }
            if (!running || error == 9) return
            if (error == 5 && wasHot) {
                Log.i(TAG, "ignore client error during live session")
                hot = true
                return
            }
            if (error == 8 || error == 10) {
                main.post {
                    killRecognizer()
                    if (!running) return@post
                    ensureRecognizer()
                    scheduleRestart(2800)
                }
                return
            }
            scheduleRestart(1400)
        }

        override fun onResults(results: Bundle?) {
            hot = false
            val text = best(results)
            if (text.isNotEmpty()) {
                heardSpeech = true
                Log.i(TAG, "final=$text")
                emit(mapOf("type" to "final", "text" to text))
            }
            if (running) scheduleRestart(400)
        }

        override fun onPartialResults(results: Bundle?) {
            val text = best(results)
            if (text.isNotEmpty()) {
                heardSpeech = true
                Log.i(TAG, "partial=$text")
                emit(mapOf("type" to "partial", "text" to text))
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    fun attach(messenger: BinaryMessenger) {
        ensureCue()
        EventChannel(messenger, CHANNEL_EVENTS).setStreamHandler(this)
        MethodChannel(messenger, CHANNEL_CTL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    lang = call.argument<String>("lang") ?: "hi-IN"
                    silenceMs = call.argument<Int>("silenceMs") ?: 7000
                    if (!hasMic()) {
                        ActivityCompat.requestPermissions(
                            activity,
                            arrayOf(android.Manifest.permission.RECORD_AUDIO),
                            REQ_MIC,
                        )
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    start { ok ->
                        try {
                            result.success(ok)
                        } catch (_: Exception) {
                        }
                    }
                }
                "stop" -> {
                    stop(cancel = false)
                    result.success(true)
                }
                "cancel" -> {
                    stop(cancel = true)
                    result.success(true)
                }
                "available" -> {
                    result.success(SpeechRecognizer.isRecognitionAvailable(activity))
                }
                else -> result.notImplemented()
            }
        }
    }

    fun destroy() {
        main.post {
            killRecognizer()
            restoreSystemBeeps()
            try {
                cue?.stop()
                cue?.shutdown()
            } catch (_: Exception) {
            }
            cue = null
            cueReady = false
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.events = events
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    private fun hasMic(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            android.Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun start(cb: (Boolean) -> Unit) {
        if (running && hot) {
            Log.i(TAG, "already hot")
            cb(true)
            return
        }
        failReady()
        readyCb = cb
        running = true
        restarting = false
        heardSpeech = false
        main.post {
            muteSystemBeeps()
            ensureCue()
            speakCue(end = false) {
                if (!running) return@speakCue
                ensureRecognizer()
                if (!hot) listen()
            }
        }
        main.postDelayed({
            if (readyCb === cb) {
                Log.w(TAG, "ready timeout")
                readyCb = null
                cb(hot)
            }
        }, 6000)
    }

    private fun stop(cancel: Boolean) {
        running = false
        restarting = false
        hot = false
        failReady()
        main.post {
            try {
                if (cancel) recognizer?.cancel() else recognizer?.stopListening()
            } catch (_: Exception) {
            }
            if (!cancel && heardSpeech) {
                speakCue(end = true) { restoreSystemBeeps() }
            } else {
                restoreSystemBeeps()
            }
        }
    }

    private fun listen() {
        if (!running || restarting || hot) {
            Log.i(TAG, "skip listen running=$running restarting=$restarting hot=$hot")
            return
        }
        val now = SystemClock.uptimeMillis()
        val since = now - lastStartAt
        if (since < 1200) {
            scheduleRestart(1200 - since)
            return
        }
        lastStartAt = now
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra("calling_package", activity.packageName)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                silenceMs.toLong(),
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                silenceMs.toLong(),
            )
        }
        try {
            recognizer?.startListening(intent)
            Log.i(TAG, "startListening lang=$lang")
        } catch (e: Exception) {
            Log.e(TAG, "startListening failed", e)
            emit(mapOf("type" to "error", "error" to (e.message ?: "start")))
            scheduleRestart(1600)
        }
    }

    private fun scheduleRestart(delayMs: Long) {
        if (!running || restarting) return
        restarting = true
        main.postDelayed({
            restarting = false
            if (running && !hot) listen()
        }, delayMs.coerceAtLeast(1200))
    }

    private fun ensureRecognizer() {
        if (recognizer != null) return
        recognizer = SpeechRecognizer.createSpeechRecognizer(activity).also {
            it.setRecognitionListener(listener)
        }
        Log.i(TAG, "recognizer created default")
    }

    private fun killRecognizer() {
        try {
            recognizer?.destroy()
        } catch (_: Exception) {
        }
        recognizer = null
    }

    private fun best(results: Bundle?): String {
        val list = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return list?.firstOrNull()?.trim().orEmpty()
    }

    private fun emit(data: Map<String, Any?>) {
        main.post {
            try {
                events?.success(data)
            } catch (e: Exception) {
                Log.w(TAG, "emit failed ${e.message}")
            }
        }
    }

    private fun failReady() {
        val cb = readyCb
        readyCb = null
        cb?.invoke(false)
    }

    private fun markReady() {
        val cb = readyCb
        readyCb = null
        cb?.invoke(true)
    }

    private fun audio(): AudioManager? {
        return activity.getSystemService(Activity.AUDIO_SERVICE) as? AudioManager
    }

    private fun muteSystemBeeps() {
        val am = audio() ?: return
        if (!systemMuted) {
            for (stream in beepStreams) {
                try {
                    savedBeeps[stream] = am.getStreamVolume(stream)
                } catch (_: Exception) {
                }
            }
            systemMuted = true
        }
        for (stream in beepStreams) {
            try {
                am.setStreamVolume(stream, 0, 0)
                am.adjustStreamVolume(stream, AudioManager.ADJUST_MUTE, 0)
            } catch (_: Exception) {
            }
        }
    }

    private fun restoreSystemBeeps() {
        if (!systemMuted) return
        val am = audio() ?: return
        systemMuted = false
        for ((stream, volume) in savedBeeps) {
            try {
                am.adjustStreamVolume(stream, AudioManager.ADJUST_UNMUTE, 0)
                am.setStreamVolume(stream, volume, 0)
            } catch (_: Exception) {
            }
        }
        savedBeeps.clear()
    }

    private fun ensureCue() {
        if (cue != null) return
        cue = TextToSpeech(activity) { status ->
            cueReady = status == TextToSpeech.SUCCESS
            if (cueReady) cue?.setSpeechRate(0.92f)
        }
    }

    private fun speakCue(end: Boolean, then: () -> Unit) {
        val tts = cue
        if (tts == null || !cueReady) {
            then()
            return
        }
        val done = booleanArrayOf(false)
        fun finish() {
            if (done[0]) return
            done[0] = true
            main.post(then)
        }
        try {
            val hindi = lang.startsWith("hi")
            val text = when {
                hindi && end -> "ठीक है"
                hindi -> "बोलिए"
                end -> "Okay"
                else -> "Go ahead"
            }
            tts.language = if (hindi) Locale("hi", "IN") else Locale.US
            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) = finish()
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) = finish()
            })
            val id = if (end) "cue-end" else "cue-start"
            if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, id) != TextToSpeech.SUCCESS) {
                finish()
            }
            main.postDelayed({ finish() }, 1600)
        } catch (e: Exception) {
            Log.w(TAG, "cue skipped ${e.message}")
            finish()
        }
    }
}
