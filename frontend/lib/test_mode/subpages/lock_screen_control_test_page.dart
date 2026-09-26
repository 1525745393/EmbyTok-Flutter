// 锁屏/蓝牙控制专项测试：
// 1. 展示当前 audio_service.MediaItem 与 audio_service.PlaybackState
// 2. 列出系统支持的 MediaActions
// 3. 模拟播放/暂停/上一曲/下一曲按钮
// 4. 监听 MediaButton 事件并记录

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

class LockScreenControlTestPage extends ConsumerWidget {
  const LockScreenControlTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('锁屏/蓝牙控制专项')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '验证锁屏通知栏和蓝牙设备的媒体控制是否正常。\n'
            '在手机锁屏状态下或连接蓝牙耳机后，\n'
            '使用通知栏按钮或蓝牙按键测试：\n'
            '播放/暂停、上一曲、下一曲、快进快退。',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 当前播放信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<audio_service.MediaItem?>(
                stream: handler.mediaItem,
                builder: (context, s) {
                  final item = s.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('当前 audio_service.MediaItem',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('标题: ${item?.title ?? "无"}'),
                      Text('艺术家: ${item?.artist ?? "无"}'),
                      Text('时长: ${item?.duration ?? "未知"}'),
                      Text('ID: ${item?.id ?? "无"}'),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 当前播放状态
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<audio_service.PlaybackState>(
                stream: handler.playbackState,
                builder: (context, s) {
                  final state = s.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('当前 audio_service.PlaybackState',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('状态: ${_stateLabel(state?.processingState)}'),
                      Text('播放速度: ${state?.speed ?? 1.0}x'),
                      Text('位置: ${state?.position ?? Duration.zero}'),
                      Text('更新时间: ${state?.updateTime ?? "-"}'),
                      const SizedBox(height: 8),
                      const Text('支持的 Actions:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Wrap(
                        spacing: 6,
                        children: [
                          Text('共 ${state?.controls.length ?? 0} 个控制按钮',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 控制按钮
          const Text('模拟媒体按钮（测试 Handler 响应）',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('播放'),
                onPressed: () => handler.play(),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.pause),
                label: const Text('暂停'),
                onPressed: () => handler.pause(),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.skip_previous),
                label: const Text('上一曲'),
                onPressed: () => handler.skipToPrevious(),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.skip_next),
                label: const Text('下一曲'),
                onPressed: () => handler.skipToNext(),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text('停止'),
                onPressed: () => handler.stop(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 测试说明
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '测试步骤：\n'
                '1. 播放任意视频/音乐\n'
                '2. 按 Home 键回到桌面或锁屏\n'
                '3. 下拉通知栏，查看媒体控件\n'
                '4. 点击播放/暂停/上一曲/下一曲\n'
                '5. 连接蓝牙耳机，按耳机按键测试\n'
                '6. 返回此页面，观察状态是否同步更新',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _stateLabel(audio_service.AudioProcessingState? s) {
    switch (s) {
      case audio_service.AudioProcessingState.idle:
        return '空闲';
      case audio_service.AudioProcessingState.loading:
        return '加载中';
      case audio_service.AudioProcessingState.buffering:
        return '缓冲中';
      case audio_service.AudioProcessingState.ready:
        return '就绪/播放中';
      case audio_service.AudioProcessingState.completed:
        return '已完成';
      case audio_service.AudioProcessingState.error:
        return '错误';
      default:
        return '未知';
    }
  }
}
