// 均衡器设置页（PRD #23）
//
// 开关 + 8 预设 + 10 段滑条（Android 真实 DSP，iOS 提示不支持）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/equalizer_service.dart';

class EqualizerView extends ConsumerStatefulWidget {
  const EqualizerView({super.key});
  @override
  ConsumerState<EqualizerView> createState() => _EqualizerViewState();
}

class _EqualizerViewState extends ConsumerState<EqualizerView> {
  bool _inited = false;
  bool _available = false;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await equalizerService.init();
    if (!mounted) return;
    setState(() {
      _available = ok;
      _inited = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('均衡器')),
      body: SafeArea(
        child: !_inited
            ? const Center(child: CircularProgressIndicator())
            : !_available
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                          '当前设备不支持硬件均衡器\n（需 Android AudioEffect，iOS 暂不支持）',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SwitchListTile(
                        title: const Text('启用均衡器'),
                        value: _enabled,
                        onChanged: (v) async {
                          await equalizerService.setEnabled(v);
                          setState(() => _enabled = v);
                        },
                      ),
                      const Divider(),
                      const Text('预设',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: eqPresets.keys.map((name) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(name),
                                onPressed: _enabled
                                    ? () async {
                                        await equalizerService
                                            .applyPreset(eqPresets[name]!);
                                        setState(() {});
                                      }
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('频段调节（mB）',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: _enabled
                                ? () async {
                                    await equalizerService
                                        .applyPreset(eqPresets['平直']!);
                                    setState(() {});
                                  }
                                : null,
                            icon: const Icon(Icons.restore, size: 18),
                            label: const Text('恢复默认'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(equalizerService.bands, (i) {
                        final freq = equalizerService.freqs[i];
                        final freqText = freq >= 1000
                            ? '${(freq / 1000).toStringAsFixed(1)}kHz'
                            : '${freq}Hz';
                        return Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text(freqText,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              child: Slider(
                                min: (equalizerService.minMb / 100).toDouble(),
                                max: (equalizerService.maxMb / 100).toDouble(),
                                value: (equalizerService.levels[i] / 100)
                                    .clamp(
                                        (equalizerService.minMb / 100)
                                            .toDouble(),
                                        (equalizerService.maxMb / 100)
                                            .toDouble())
                                    .toDouble(),
                                label:
                                    '${(equalizerService.levels[i] / 100).toStringAsFixed(1)}dB',
                                onChanged: _enabled
                                    ? (v) async {
                                        await equalizerService.setBand(
                                            i, (v * 100).round());
                                        setState(() {});
                                      }
                                    : null,
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${(equalizerService.levels[i] / 100).toStringAsFixed(1)}dB',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
      ),
    );
  }
}
