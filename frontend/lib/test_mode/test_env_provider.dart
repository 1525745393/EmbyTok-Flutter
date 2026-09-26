// 测试模式环境覆盖状态：非默认环境时在 App 顶部显示红色横幅
// 仅 debug 构建生效，release 不包含此逻辑

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 环境覆盖状态：null 表示使用正式配置，非空表示临时覆盖的 baseUrl
/// 仅测试模式写入，退出测试模式或重启后自动清空
final testEnvOverrideProvider = StateProvider<String?>((ref) => null);
