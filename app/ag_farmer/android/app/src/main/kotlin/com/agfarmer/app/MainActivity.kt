package com.agfarmer.app

import android.content.ClipData
import android.content.ClipDescription
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val playUpdateRequest = 41012
    private var farmerSpeech: FarmerSpeech? = null
    private var beepMuted = false
    private val savedVolumes = HashMap<Int, Int>()
    private val beepStreams = intArrayOf(
        AudioManager.STREAM_MUSIC,
        AudioManager.STREAM_SYSTEM,
        AudioManager.STREAM_NOTIFICATION,
        AudioManager.STREAM_RING,
        AudioManager.STREAM_DTMF,
        AudioManager.STREAM_VOICE_CALL,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        farmerSpeech = FarmerSpeech(this).also { it.attach(flutterEngine.dartExecutor.binaryMessenger) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ag_farmer/mic_beep")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "mute" -> {
                        // Do not zero STREAM_MUSIC. That silenced the spoken reply.
                        result.success(true)
                    }
                    "unmute" -> {
                        restoreBeepVolume()
                        result.success(true)
                    }
                    "ensureMusic" -> {
                        ensureMusicAudible()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ag_farmer/app_release")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> result.success(appVersion())
                    "openStore" -> {
                        openPlayStore()
                        result.success(true)
                    }
                    "playUpdate" -> askPlayUpdate(result)
                    "startUpdate" -> startPlayUpdate(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ag_farmer/share_pdf")
            .setMethodCallHandler { call, result ->
                if (call.method != "share") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val caption = call.argument<String>("caption") ?: ""
                if (path.isNullOrBlank()) {
                    result.error("bad_path", "missing file", null)
                    return@setMethodCallHandler
                }
                try {
                    sharePdf(path, caption)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("share_failed", e.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ag_farmer/upi")
            .setMethodCallHandler { call, result ->
                if (call.method != "installed") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val order = listOf(
                    "phonepe" to "com.phonepe.app",
                    "google_pay" to "com.google.android.apps.nbu.paisa.user",
                    "paytm" to "net.one97.paytm",
                )
                val found = order.filter { (_, pkg) -> isInstalled(pkg) }.map { it.first }
                result.success(found)
            }
    }

    override fun onResume() {
        super.onResume()
        resumePlayUpdateIfNeeded()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == playUpdateRequest) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        farmerSpeech?.destroy()
        farmerSpeech = null
        restoreBeepVolume()
        super.onDestroy()
    }

    private fun audioManager(): AudioManager? {
        return getSystemService(AUDIO_SERVICE) as? AudioManager
    }

    // The speech recognizer beep is a system sound. Drop every output
    // stream to zero while the mic is open, then put the old levels back.
    private fun muteBeep() {
        val am = audioManager() ?: return
        if (!beepMuted) {
            for (stream in beepStreams) {
                try {
                    savedVolumes[stream] = am.getStreamVolume(stream)
                } catch (_: Exception) {
                }
            }
            beepMuted = true
            Log.i("AgFarmer", "mic beep muted")
        }
        for (stream in beepStreams) {
            try {
                am.setStreamVolume(stream, 0, 0)
                am.adjustStreamVolume(stream, AudioManager.ADJUST_MUTE, 0)
            } catch (_: Exception) {
            }
        }
    }

    private fun ensureMusicAudible() {
        val am = audioManager() ?: return
        try {
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_UNMUTE, 0)
            val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            if (current > 0) return
            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val floor = (max * 0.7).toInt().coerceAtLeast(1)
            am.setStreamVolume(AudioManager.STREAM_MUSIC, floor, 0)
            Log.i("AgFarmer", "music volume restored")
        } catch (_: Exception) {
        }
    }

    private fun restoreBeepVolume() {
        if (!beepMuted) return
        val am = audioManager() ?: return
        beepMuted = false
        Log.i("AgFarmer", "mic beep restored")
        for ((stream, volume) in savedVolumes) {
            try {
                am.adjustStreamVolume(stream, AudioManager.ADJUST_UNMUTE, 0)
                am.setStreamVolume(stream, volume, 0)
            } catch (_: Exception) {
            }
        }
        savedVolumes.clear()
    }

    private fun sharePdf(path: String, caption: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(this, "$packageName.share", file)
        val text = caption.trim()
        val clip = ClipData(
            ClipDescription("AG Farmer", arrayOf("application/pdf", "text/plain")),
            ClipData.Item(text, null, null, uri),
        )
        val send = Intent(Intent.ACTION_SEND).apply {
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_TITLE, text)
            putExtra(Intent.EXTRA_SUBJECT, text)
            putExtra("caption", text)
            putExtra(Intent.EXTRA_STREAM, uri)
            type = "application/pdf"
            this.clipData = clip
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val targets = packageManager.queryIntentActivities(send, PackageManager.MATCH_DEFAULT_ONLY)
        for (info in targets) {
            grantUriPermission(
                info.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
        for (pkg in arrayOf("com.whatsapp", "com.whatsapp.w4b")) {
            if (!isInstalled(pkg)) continue
            grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, "शेयर")
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        chooser.clipData = clip
        chooser.putExtra(Intent.EXTRA_TEXT, text)
        startActivity(chooser)
    }

    private fun appVersion(): Map<String, Any> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= 28) {
            info.longVersionCode.toInt()
        } else {
            @Suppress("DEPRECATION")
            info.versionCode
        }
        return mapOf("code" to code, "name" to (info.versionName ?: ""))
    }

    private fun installedFromPlay(): Boolean {
        return try {
            val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                packageManager.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
            installer == "com.android.vending"
        } catch (_: Exception) {
            false
        }
    }

    private fun askPlayUpdate(result: MethodChannel.Result) {
        val once = AtomicBoolean(false)
        fun finish(value: Map<String, Any>) {
            if (once.compareAndSet(false, true)) result.success(value)
        }
        if (!installedFromPlay()) {
            finish(mapOf("state" to "no", "versionCode" to 0))
            return
        }
        val manager = AppUpdateManagerFactory.create(this)
        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                val availability = info.updateAvailability()
                val offered = availability == UpdateAvailability.UPDATE_AVAILABLE ||
                    availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                val code = if (offered) info.availableVersionCode() else 0
                val newer = code > (appVersion()["code"] as Int)
                finish(
                    mapOf(
                        "state" to if (offered && newer) "yes" else "no",
                        "versionCode" to if (newer) code else 0,
                    ),
                )
            }
            .addOnFailureListener {
                finish(mapOf("state" to "unknown", "versionCode" to 0))
            }
    }

    private fun startPlayUpdate(result: MethodChannel.Result) {
        val once = AtomicBoolean(false)
        fun finish(ok: Boolean) {
            if (once.compareAndSet(false, true)) result.success(ok)
        }
        if (!installedFromPlay()) {
            finish(false)
            return
        }
        val manager = AppUpdateManagerFactory.create(this)
        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                val availability = info.updateAvailability()
                val offered = availability == UpdateAvailability.UPDATE_AVAILABLE ||
                    availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                if (!offered || !info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
                    finish(false)
                    return@addOnSuccessListener
                }
                try {
                    @Suppress("DEPRECATION")
                    manager.startUpdateFlowForResult(
                        info,
                        AppUpdateType.IMMEDIATE,
                        this,
                        playUpdateRequest,
                    )
                    finish(true)
                } catch (_: Exception) {
                    finish(false)
                }
            }
            .addOnFailureListener { finish(false) }
    }

    private fun resumePlayUpdateIfNeeded() {
        if (!installedFromPlay()) return
        val manager = AppUpdateManagerFactory.create(this)
        manager.appUpdateInfo.addOnSuccessListener { info ->
            if (info.updateAvailability() != UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                return@addOnSuccessListener
            }
            if (!info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) return@addOnSuccessListener
            try {
                @Suppress("DEPRECATION")
                manager.startUpdateFlowForResult(
                    info,
                    AppUpdateType.IMMEDIATE,
                    this,
                    playUpdateRequest,
                )
            } catch (_: Exception) {
            }
        }
    }

    private fun openPlayStore() {
        val market = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$packageName"),
        ).apply {
            setPackage("com.android.vending")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val web = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("https://play.google.com/store/apps/details?id=$packageName"),
        ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        try {
            startActivity(market)
        } catch (_: Exception) {
            startActivity(web)
        }
    }

    private fun isInstalled(packageName: String): Boolean {
        return try {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
