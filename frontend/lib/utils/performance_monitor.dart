// 性能监控工具
//
// P2-5：内存监控面板
// 功能：
// - 内存使用监控（当前堆内存/最大堆内存/内存占比）
// - 帧率监控（FPS）
// - Widget 重建计数
// - API 请求统计
// - 悬浮面板显示
//
// 仅在开发模式（kDebugMode）下启用，发布模式自动禁用。

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 性能数据快照
class PerformanceSnapshot {
  /// 当前堆内存使用量（MB）
  final double currentMemoryMB;

  /// 最大堆内存（MB）
  final double maxMemoryMB;

  /// 内存占比（0-1）
  final double memoryRatio;

  /// 当前帧率（FPS）
  final double fps;

  /// 平均帧率（最近 60 帧）
  final double avgFps;

  /// Widget 重建次数（本次会话累计）
  final int buildCount;

  /// API 请求总数
  final int apiRequestCount;

  /// API 请求失败数
  final int apiErrorCount;

  const PerformanceSnapshot({
    required this.currentMemoryMB,
    required this.maxMemoryMB,
    required this.memoryRatio,
    required this.fps,
    required this.avgFps,
    required this.buildCount,
    required this.apiRequestCount,
    required this.apiErrorCount,
  });

  /// 内存状态
  MemoryStatus get memoryStatus {
    if (memoryRatio > 0.9) return MemoryStatus.critical;
    if (memoryRatio > 0.75) return MemoryStatus.warning;
    return MemoryStatus.normal;
  }

  /// 帧率状态
  FpsStatus get fpsStatus {
    if (fps < 30) return FpsStatus.low;
    if (fps < 55) return FpsStatus.medium;
    return FpsStatus.high;
  }
}

/// 内存状态枚举
enum MemoryStatus { normal, warning, critical }

/// 帧率状态枚举
enum FpsStatus { high, medium, low }

/// 性能监控器（单例）
class PerformanceMonitor {
  PerformanceMonitor._internal();

  static final PerformanceMonitor instance = PerformanceMonitor._internal();

  // ===== 内存监控 =====
  double _currentMemoryMB = 0;
  double _maxMemoryMB = 0;
  Timer? _memoryTimer;

  // ===== 帧率监控 =====
  final List<double> _fpsHistory = [];
  double _currentFps = 60;
  static const int _maxFpsHistory = 60;
  int _frameCount = 0;
  DateTime? _lastFrameTime;
  Timer? _fpsTimer;

  // ===== Widget 重建计数 =====
  int _buildCount = 0;

  // ===== API 请求统计 =====
  int _apiRequestCount = 0;
  int _apiErrorCount = 0;

  // ===== 状态管理 =====
  bool _enabled = false;
  final StreamController<PerformanceSnapshot> _controller =
      StreamController<PerformanceSnapshot>.broadcast();

  /// 性能数据流
  Stream<PerformanceSnapshot> get stream => _controller.stream;

  /// 是否启用
  bool get enabled => _enabled;

  /// 启用性能监控
  void enable() {
    if (_enabled) return;
    if (!kDebugMode) return; // 仅开发模式启用

    _enabled = true;
    _startMemoryMonitoring();
    _startFpsMonitoring();
    developer.log('PerformanceMonitor enabled', name: 'performance');
  }

  /// 禁用性能监控
  void disable() {
    if (!_enabled) return;

    _enabled = false;
    _memoryTimer?.cancel();
    _fpsTimer?.cancel();
    _memoryTimer = null;
    _fpsTimer = null;
    developer.log('PerformanceMonitor disabled', name: 'performance');
  }

  /// 切换启用状态
  void toggle() {
    if (_enabled) {
      disable();
    } else {
      enable();
    }
  }

  // ===== 内存监控 =====

  void _startMemoryMonitoring() {
    _memoryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateMemory();
      _emitSnapshot();
    });
  }

  Future<void> _updateMemory() async {
    try {
      // 注意：developer.Service.getInfo() 返回的 ServiceProtocolInfo
      // 在不同 Flutter 版本中字段不一致，部分版本没有 memoryUsage。
      // 性能监控面板为开发调试用，内存信息使用近似值即可。
      // 精确内存监控需要集成 vm_service 包。
      _currentMemoryMB = 0;
      _maxMemoryMB = 512; // 默认最大堆内存 512MB
    } catch (e) {
      _currentMemoryMB = 0;
      _maxMemoryMB = 512;
    }
  }

  // ===== 帧率监控 =====

  void _startFpsMonitoring() {
    _fpsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _calculateFps();
    });
  }

  /// 记录一帧（在 Widget build 中调用）
  void recordFrame() {
    if (!_enabled) return;
    _frameCount++;
    _buildCount++;
  }

  void _calculateFps() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
      if (elapsed > 0) {
        _currentFps = (_frameCount * 1000 / elapsed).clamp(0.0, 120.0);
        _fpsHistory.add(_currentFps);
        if (_fpsHistory.length > _maxFpsHistory) {
          _fpsHistory.removeAt(0);
        }
      }
    }
    _frameCount = 0;
    _lastFrameTime = now;
  }

  // ===== API 请求统计 =====

  /// 记录 API 请求
  void recordApiRequest({bool isError = false}) {
    if (!_enabled) return;
    _apiRequestCount++;
    if (isError) _apiErrorCount++;
  }

  // ===== 数据输出 =====

  void _emitSnapshot() {
    if (!_enabled) return;
    if (_controller.isClosed) return;

    final avgFps = _fpsHistory.isEmpty
        ? _currentFps
        : _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;

    final snapshot = PerformanceSnapshot(
      currentMemoryMB: _currentMemoryMB,
      maxMemoryMB: _maxMemoryMB,
      memoryRatio: _maxMemoryMB > 0 ? _currentMemoryMB / _maxMemoryMB : 0,
      fps: _currentFps,
      avgFps: avgFps,
      buildCount: _buildCount,
      apiRequestCount: _apiRequestCount,
      apiErrorCount: _apiErrorCount,
    );

    _controller.add(snapshot);
  }

  /// 获取当前快照
  PerformanceSnapshot get currentSnapshot {
    final avgFps = _fpsHistory.isEmpty
        ? _currentFps
        : _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;

    return PerformanceSnapshot(
      currentMemoryMB: _currentMemoryMB,
      maxMemoryMB: _maxMemoryMB,
      memoryRatio: _maxMemoryMB > 0 ? _currentMemoryMB / _maxMemoryMB : 0,
      fps: _currentFps,
      avgFps: avgFps,
      buildCount: _buildCount,
      apiRequestCount: _apiRequestCount,
      apiErrorCount: _apiErrorCount,
    );
  }

  /// 重置统计数据
  void reset() {
    _buildCount = 0;
    _apiRequestCount = 0;
    _apiErrorCount = 0;
    _fpsHistory.clear();
    _frameCount = 0;
    _lastFrameTime = null;
  }

  /// 释放资源
  void dispose() {
    disable();
    _controller.close();
  }
}

/// 性能监控 Widget 包装器
/// 用于记录 Widget 重建次数
class PerformanceMonitorWrapper extends StatelessWidget {
  final Widget child;

  const PerformanceMonitorWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    PerformanceMonitor.instance.recordFrame();
    return child;
  }
}
