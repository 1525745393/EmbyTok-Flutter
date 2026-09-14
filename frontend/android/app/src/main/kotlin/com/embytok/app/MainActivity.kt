package com.embytok.app

import android.media.audiofx.Equalizer
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 应用主 Activity。
 *
 * 全面屏手势适配 + 10 段均衡器（Android AudioEffect.Equalizer，绑定全局 audioSession=0）。
 */
class MainActivity : FlutterActivity() {

    private var equalizer: Equalizer? = null
    private val eqChannel = "com.embytok/equalizer"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, eqChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        try {
                            if (equalizer == null) {
                                equalizer = Equalizer(0, 0).apply { enabled = true }
                            }
                            result.success(mapOf(
                                "bands" to (equalizer?.numberOfBands ?: 0),
                                "min" to (equalizer?.bandLevelRange?.get(0)?.toInt() ?: 0),
                                "max" to (equalizer?.bandLevelRange?.get(1)?.toInt() ?: 0),
                                "freqs" to (0 until (equalizer?.numberOfBands ?: 0))
                                    .map { equalizer?.getCenterFreq(it.toShort()) ?: 0 }
                            ))
                        } catch (e: Exception) {
                            result.error("EQ_UNAVAILABLE", e.message, null)
                        }
                    }
                    "setBandLevel" -> {
                        val band = call.argument<Int>("band") ?: 0
                        val mb = call.argument<Int>("mb") ?: 0
                        try {
                            equalizer?.setBandLevel(band.toShort(), mb.toShort())
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("EQ_FAIL", e.message, null)
                        }
                    }
                    "getBandLevel" -> {
                        val band = call.argument<Int>("band") ?: 0
                        result.success(equalizer?.getBandLevel(band.toShort())?.toInt() ?: 0)
                    }
                    "setEnabled" -> {
                        val on = call.argument<Boolean>("on") ?: true
                        equalizer?.enabled = on
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        equalizer?.release()
        equalizer = null
        super.onDestroy()
    }
}
