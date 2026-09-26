// 播放器专项测试：样例源播放、倍速切换

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PlayerTestPage extends StatefulWidget {
  const PlayerTestPage({super.key});

  @override
  State<PlayerTestPage> createState() => _PlayerTestPageState();
}

class _PlayerTestPageState extends State<PlayerTestPage> {
  VideoPlayerController? _controller;
  String? _status;
  double _speed = 1.0;

  static const _sampleSources = [
    ['Big Buck Bunny (MP4)',
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'],
    ['Elephants Dream (MP4)',
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'],
  ];

  Future<void> _play(String url) async {
    setState(() {
      _status = '加载中: $url';
      _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    });
    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();
      setState(() => _status = '播放中（${_controller!.value.duration.inSeconds}s）');
    } catch (e) {
      setState(() => _status = '加载失败: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放器专项测试')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          const SizedBox(height: 12),
          Text(_status ?? '选择样例源开始播放',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          const Divider(),
          const Text('样例源：', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final s in _sampleSources)
            ListTile(
              leading: const Icon(Icons.video_collection_outlined),
              title: Text(s[0]),
              onTap: () => _play(s[1]),
            ),
          const Divider(),
          const Text('倍速控制：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [0.5, 1.0, 1.5, 2.0].map((s) {
              return ChoiceChip(
                label: Text('${s}x'),
                selected: _speed == s,
                onSelected: (_) async {
                  setState(() => _speed = s);
                  await _controller?.setPlaybackSpeed(s);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => _controller?.play(),
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: () => _controller?.pause(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
