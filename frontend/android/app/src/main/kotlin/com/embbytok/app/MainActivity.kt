package com.embbytok.app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity

/**
 * 应用主 Activity。
 *
 * enableEdgeToEdge() 让 App 绘制到系统栏（状态栏 + 导航栏）后面，
 * 配合 Flutter 端的 AnnotatedRegion<SystemUiOverlayStyle> 显式控制
 * 状态栏 / 导航栏的文字/图标颜色，避免白底白字不可见。
 *
 * Android 15 (API 35) 强制要求 targetSdk >= 35 的 App 默认 edge-to-edge，
 * 不再支持 opt-out；为了在更低 targetSdk（当前 34）下也保持一致体验，
 * 这里主动调用一次。
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须 super.onCreate 之前调用：enableEdgeToEdge 内部会设置 WindowCompat 的标志位
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
