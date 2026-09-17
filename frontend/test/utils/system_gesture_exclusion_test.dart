/// SystemGestureExclusion（Android 边缘手势排除通道）测试
///
/// 重点验证：
/// - setFullscreenExclusion(true/false) 正确调用原生 MethodChannel 及参数
/// - 通道不可用（MissingPluginException）时静默吞掉，不影响播放

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/utils/system_gesture_exclusion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.embytok/system_gesture');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('setFullscreenExclusion(true) 调用原生通道并携带 enabled=true', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });

    await SystemGestureExclusion.setFullscreenExclusion(true);

    expect(received, isNotNull);
    expect(received!.method, 'setFullscreenExclusion');
    expect(received!.arguments, {'enabled': true});
  });

  test('setFullscreenExclusion(false) 调用原生通道并携带 enabled=false', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });

    await SystemGestureExclusion.setFullscreenExclusion(false);

    expect(received, isNotNull);
    expect(received!.method, 'setFullscreenExclusion');
    expect(received!.arguments, {'enabled': false});
  });

  test('通道不存在（非 Android 平台）时静默忽略，不抛异常', () async {
    // 不注册 mock handler：invokeMethod 会抛出 MissingPluginException
    // setFullscreenExclusion 应捕获并返回，不向调用方抛错
    await SystemGestureExclusion.setFullscreenExclusion(true);
    await SystemGestureExclusion.setFullscreenExclusion(false);
  });

  test('原生端返回错误时静默忽略', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'CHANNEL_ERROR', message: 'mock failure');
    });

    await SystemGestureExclusion.setFullscreenExclusion(true);
  });
}
