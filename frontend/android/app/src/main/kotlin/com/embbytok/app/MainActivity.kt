package com.embbytok.app

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

/**
 * 应用主 Activity。
 *
 * 全面屏手势适配：
 * - 用 WindowCompat.setDecorFitsSystemWindows(window, false) 让 App 内容延伸到
 *   系统栏（状态栏 + 导航栏）背后，配合 Flutter 端 AnnotatedRegion 显式控制
 *   状态栏/导航栏文字颜色，避免白底白字不可见。
 * - 不用 androidx.activity.enableEdgeToEdge()：FlutterActivity 直接继承
 *   android.app.Activity（不继承 ComponentActivity），扩展函数 receiver 不匹配。
 * - 不需要额外 androidx 依赖：WindowCompat 来自 androidx.core:core，Flutter 已隐式
 *   传递依赖。
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 让窗口内容延伸到系统栏背后
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
