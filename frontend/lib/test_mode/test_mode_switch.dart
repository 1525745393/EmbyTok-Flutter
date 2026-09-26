// 测试模式全局开关：仅 debug 构建或显式 dart-define 开启
// release / profile 下 kDebugMode 为 false，所有入口与路由自动失效

import 'package:flutter/foundation.dart';

/// 是否启用测试模式控制台。
///
/// 开启条件（取或）：
/// 1. debug 构建（kDebugMode == true）
/// 2. 通过 `--dart-define=TEST_MODE=true` 显式开启（用于 profile 真机调试）
///
/// release 构建下二者均为 false，测试入口、路由、子页面全部不注册。
bool get isAppTestMode {
  if (kDebugMode) return true;
  const fromDefine = bool.fromEnvironment('TEST_MODE', defaultValue: false);
  return fromDefine;
}

/// 测试模式呼出所需连续点击次数
const int kTestModeTapThreshold = 5;

/// 连续点击超时窗口（毫秒）：超过后计数归零
const int kTestModeTapResetMs = 2000;
