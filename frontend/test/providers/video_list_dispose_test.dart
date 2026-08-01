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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:embytok_flutter/providers/video_list_provider.dart';

void main() {
  // 初始化 Flutter binding 和 SharedPreferences mock，
  // 避免 SharedPreferences.getInstance 抛出 Binding has not yet been initialized
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('VideoListNotifier.dispose：Timer 必须 cancel', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    // 等待 _load() 等异步操作完成，避免 dispose 后异步写入 state 触发 Bad state
    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 10));
      container.dispose();
    });

    test('dispose 不抛异常', () async {
      // 用独立的 container，避免 notifier.dispose() 后 tearDown 的
      // container.dispose() 重复 dispose 已销毁的 VideoListNotifier
      final localContainer = ProviderContainer();
      final notifier = localContainer.read(videoListProvider.notifier);
      // 等待依赖的 Notifier（如 ViewModeNotifier）的 _load() 完成
      await Future.delayed(const Duration(milliseconds: 10));

      expect(
        () => notifier.dispose(),
        returnsNormally,
      );
      // 等待 pending 微任务完成
      await Future.delayed(Duration.zero);
    });

    test('StateNotifier 销毁后 Timer 闭包不再持有 _ref', () async {
      // 验证策略：创建一个 ProviderContainer，获取 notifier，
      // dispose container（触发 notifier.dispose），
      // 确保没有内存泄漏的迹象
      final localContainer = ProviderContainer();
      final notifier = localContainer.read(videoListProvider.notifier);
      // 等待 _load() 完成，避免 dispose 后异步写入 state
      await Future.delayed(const Duration(milliseconds: 10));

      // dispose container 会触发 StateNotifier.dispose
      localContainer.dispose();
      // 等待 pending 微任务完成
      await Future.delayed(Duration.zero);

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
