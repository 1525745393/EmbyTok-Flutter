// 大数据 JSON 解析统一入口（移动端专项 #3）
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// JSON 字符串长度阈值：超过即走 isolate 解析。
///
/// compute 需要跨 isolate 拷贝字符串 + 线程调度，对几十 KB 以下的小响应
/// 收益为负（可能比同步解析更慢），因此仅当响应体较大时启用。
const int kLargeJsonBytes = 256 * 1024; // 256KB

/// 解析 JSON，返回值与 `jsonDecode` 相同（dynamic）。
///
/// - 字符串长度 > [kLargeJsonBytes]（万级媒体库列表、大缓存清单等）：
///   走 [compute] isolate，避免主线程 JSON 解析卡顿掉帧；
/// - 小响应：直接 [jsonDecode]，避免无谓的 isolate 调度开销。
///
/// 调用方原有的类型转换（`as List<dynamic>` / `as Map<String, dynamic>`）
/// 保持不变，本工具只替换「解析」这一步。
Future<dynamic> decodeJson(String source) {
  if (source.length > kLargeJsonBytes) {
    return compute(_parseJson, source);
  }
  return Future.value(jsonDecode(source));
}

// compute 要求顶层（非闭包）函数
dynamic _parseJson(String source) => jsonDecode(source);
