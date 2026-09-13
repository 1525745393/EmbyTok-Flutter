// 性能监控悬浮面板
//
// P2-5：内存监控面板
// 功能：
// - 悬浮显示性能数据（内存/FPS/重建次数/API 请求）
// - 可拖拽移动位置
// - 可折叠/展开
// - 仅在开发模式下显示
//
// 使用方法：
// 在 MaterialApp 的 builder 中添加 PerformanceOverlay()

import 'package:flutter/material.dart';

import '../utils/performance_monitor.dart';

/// 性能监控悬浮面板
class AppPerformanceOverlay extends StatefulWidget {

  const AppPerformanceOverlay({
    super.key,
    required this.child,
    this.showByDefault = false,
  });
  /// 子组件（通常是应用的根组件）
  final Widget child;

  /// 是否默认显示
  final bool showByDefault;

  @override
  State<AppPerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<AppPerformanceOverlay> {
  bool _visible = false;
  bool _expanded = true;
  Offset _position = const Offset(16, 100);

  @override
  void initState() {
    super.initState();
    _visible = widget.showByDefault;
    if (_visible) {
      PerformanceMonitor.instance.enable();
    }
  }

  @override
  void dispose() {
    PerformanceMonitor.instance.disable();
    super.dispose();
  }

  void _toggleVisibility() {
    setState(() {
      _visible = !_visible;
      if (_visible) {
        PerformanceMonitor.instance.enable();
      } else {
        PerformanceMonitor.instance.disable();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // 悬浮面板
        if (_visible)
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: _buildPanel(),
          ),
        // 显示/隐藏按钮（右下角）
        Positioned(
          right: 16,
          bottom: 100,
          child: FloatingActionButton(
            mini: true,
            heroTag: 'perf_toggle',
            backgroundColor: _visible ? Colors.green : Colors.grey,
            onPressed: _toggleVisibility,
            child: Icon(
              _visible ? Icons.visibility : Icons.analytics,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _position += details.delta;
        });
      },
      child: Container(
        width: _expanded ? 240 : 120,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<PerformanceSnapshot>(
          stream: PerformanceMonitor.instance.stream,
          initialData: PerformanceMonitor.instance.currentSnapshot,
          builder: (context, snapshot) {
            final data = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '性能监控',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 8),
                  // 内存使用
                  _buildMemoryRow(data),
                  const SizedBox(height: 6),
                  // 内存进度条
                  _buildMemoryBar(data),
                  const SizedBox(height: 8),
                  // 帧率
                  _buildFpsRow(data),
                  const SizedBox(height: 8),
                  // 重建次数
                  _buildStatRow(
                    icon: Icons.widgets,
                    label: 'Widget 重建',
                    value: '${data.buildCount}',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 4),
                  // API 请求
                  _buildStatRow(
                    icon: Icons.http,
                    label: 'API 请求',
                    value: '${data.apiRequestCount} (失败: ${data.apiErrorCount})',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 8),
                  // 重置按钮
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => PerformanceMonitor.instance.reset(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: const Size(0, 28),
                          ),
                          child: const Text(
                            '重置统计',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _toggleVisibility,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: const Size(0, 28),
                          ),
                          child: const Text(
                            '隐藏',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMemoryRow(PerformanceSnapshot data) {
    final status = data.memoryStatus;
    final color = switch (status) {
      MemoryStatus.normal => Colors.green,
      MemoryStatus.warning => Colors.orange,
      MemoryStatus.critical => Colors.red,
    };

    return Row(
      children: [
        Icon(Icons.memory, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          '内存: ${data.currentMemoryMB.toStringAsFixed(1)}/${data.maxMemoryMB.toStringAsFixed(1)} MB',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMemoryBar(PerformanceSnapshot data) {
    final status = data.memoryStatus;
    final color = switch (status) {
      MemoryStatus.normal => Colors.green,
      MemoryStatus.warning => Colors.orange,
      MemoryStatus.critical => Colors.red,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: data.memoryRatio.clamp(0.0, 1.0),
        minHeight: 4,
        backgroundColor: Colors.white24,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _buildFpsRow(PerformanceSnapshot data) {
    final status = data.fpsStatus;
    final color = switch (status) {
      FpsStatus.high => Colors.green,
      FpsStatus.medium => Colors.orange,
      FpsStatus.low => Colors.red,
    };

    return Row(
      children: [
        Icon(Icons.speed, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          'FPS: ${data.fps.toStringAsFixed(0)} (平均: ${data.avgFps.toStringAsFixed(0)})',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
