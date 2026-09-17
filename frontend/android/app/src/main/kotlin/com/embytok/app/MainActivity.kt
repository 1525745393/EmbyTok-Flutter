package com.embytok.app

import android.graphics.Rect
import android.media.audiofx.Equalizer
import android.os.Build
import android.os.Bundle
import android.view.View
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 应用主 Activity。
 *
 * 全面屏手势适配 + 10 段均衡器（Android AudioEffect.Equalizer，绑定全局 audioSession=0）。
 *
 * 系统手势排除（com.embytok/system_gesture）：
 * - setFullscreenExclusion(enabled: Boolean)
 *   全屏播放时排除屏幕左右边缘的返回手势区域，避免用户从边缘起手
 *   水平拖动进度时被系统返回手势抢占而退出全屏。退出全屏时清除。
 *   仅 Android 10+（API 29）支持，低版本自动忽略。
 */
class MainActivity : FlutterActivity() {

    private var equalizer: Equalizer? = null
    private val eqChannel = "com.embytok/equalizer"
    private val gestureChannel = "com.embytok/system_gesture"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, gestureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setFullscreenExclusion" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread { applyFullscreenGestureExclusion(enabled) }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 全屏播放时排除左右边缘返回手势区域。
     * 边缘宽度 40dp，覆盖 Android 手势导航默认边缘宽度（约 20-32dp）。
     * 旋转后需重新调用（原生按当前窗口尺寸重算）。
     */
    private fun applyFullscreenGestureExclusion(enabled: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val decorView: View = window.decorView
        val density = resources.displayMetrics.density
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels
        val edge = (40 * density).toInt().coerceAtMost(screenWidth / 4)
        val rects = if (enabled && edge > 0) {
            listOf(
                Rect(0, 0, edge, screenHeight),
                Rect(screenWidth - edge, 0, edge, screenHeight)
            )
        } else {
            emptyList()
        }
        decorView.setSystemGestureExclusionRects(rects)
    }

    override fun onDestroy() {
        equalizer?.release()
        equalizer = null
        super.onDestroy()
    }
}
