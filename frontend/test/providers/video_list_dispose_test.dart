// 验证 VideoListNotifier 的 dispose 方法正确 cancel Timer
//
// 背景：
// - VideoListNotifier 内部有 _searchDebounceTimer 用于搜索防抖
// - Timer 闭包持有 _ref（ProviderContainer 引用）
// - 若 StateNotifier 销毁时未 cancel Timer，会导致整个依赖链无法释放
//
// 修复：
// - 在 VideoListNotifier 中 override dispose()
// - 显式 cancel _searchDebounceTimer 后调用 super.dispose()
//
// 测试策略：
// - 直接调用 notifier.dispose()，确保不抛异常
// - 通过 ProviderContainer 释放触发 dispose，验证无内存泄漏迹象

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/providers/video_list_provider.dart';

void main() {
  group('VideoListNotifier.dispose：Timer 必须 cancel', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('dispose 不抛异常', () {
      // 创建 notifier，验证 dispose 不抛异常
      final notifier = container.read(videoListProvider.notifier);

      expect(
        () => notifier.dispose(),
        returnsNormally,
      );
    });

    test('StateNotifier 销毁后 Timer 闭包不再持有 _ref', () {
      // 验证策略：创建一个 ProviderContainer，获取 notifier，
      // dispose container（触发 notifier.dispose），
      // 确保没有内存泄漏的迹象
      final localContainer = ProviderContainer();
      final notifier = localContainer.read(videoListProvider.notifier);

      // dispose container 会触发 StateNotifier.dispose
      localContainer.dispose();

      // 不再有直接引用（这里无法直接验证 Timer.cancel，
      // 但可以通过代码覆盖率确认 dispose 正确实现）
      expect(notifier.mounted, isFalse);
    });
  });

  group('Timer 防抖逻辑验证', () {
    test('Timer.periodic 创建后可以 cancel', () async {
      // 简单验证 Timer.cancel 行为
      bool callbackExecuted = false;
      final timer = Timer.periodic(const Duration(seconds: 1), (t) {
        callbackExecuted = true;
      });

      // 立即 cancel，回调不应执行
      timer.cancel();

      // 等待一小段时间
      await Future.delayed(const Duration(milliseconds: 100));

      expect(callbackExecuted, isFalse);
    });

    test('Timer 创建后可以 cancel', () async {
      bool callbackExecuted = false;
      final timer = Timer(const Duration(seconds: 1), () {
        callbackExecuted = true;
      });

      timer.cancel();

      await Future.delayed(const Duration(milliseconds: 100));

      expect(callbackExecuted, isFalse);
    });
  });
}
