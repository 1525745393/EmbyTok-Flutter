// 10 段均衡器（PRD #23）
//
// Android：通过 MethodChannel 接 AudioEffect.Equalizer（真实 DSP）。
// iOS / 不支持设备：调用返回 false，UI 降级为"当前设备不支持"。
// 频段增益持久化到 SharedPreferences。

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EqualizerService {
  static const _ch = MethodChannel('com.embytok/equalizer');
  static const _kEnabled = 'syno_eq_enabled';
  static const _kLevels = 'syno_eq_levels_mb';

  bool _available = false;
  int _bands = 0;
  int _minMb = 0;
  int _maxMb = 0;
  List<int> _freqs = [];
  List<int> _levels = [];

  bool get available => _available;
  int get bands => _bands;
  int get minMb => _minMb;
  int get maxMb => _maxMb;
  List<int> get freqs => List.unmodifiable(_freqs);
  List<int> get levels => List.unmodifiable(_levels);

  /// 初始化并恢复上次增益
  Future<bool> init() async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('init');
      if (r == null) return false;
      _bands = (r['bands'] as num).toInt();
      _minMb = (r['min'] as num).toInt();
      _maxMb = (r['max'] as num).toInt();
      _freqs = (r['freqs'] as List).map((e) => (e as num).toInt()).toList();
      _available = _bands > 0;
      if (!_available) return false;

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kEnabled) ?? true;
      final raw = prefs.getString(_kLevels);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => (e as num).toInt())
            .toList();
        if (list.length == _bands) _levels = list;
      }
      _levels = List.generate(_bands, (i) => i < _levels.length ? _levels[i] : 0);
      await _ch.invokeMethod('setEnabled', {'on': enabled});
      // 恢复各频段
      for (var i = 0; i < _bands; i++) {
        await _ch.invokeMethod('setBandLevel', {'band': i, 'mb': _levels[i]});
      }
      return true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  Future<void> setBand(int band, int mb) async {
    if (!_available || band < 0 || band >= _bands) return;
    final clamped = mb.clamp(_minMb, _maxMb);
    _levels[band] = clamped;
    await _ch.invokeMethod('setBandLevel', {'band': band, 'mb': clamped});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLevels, jsonEncode(_levels));
  }

  Future<void> setEnabled(bool on) async {
    if (!_available) return;
    await _ch.invokeMethod('setEnabled', {'on': on});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, on);
  }

  /// 应用预设（8 个内置）
  Future<void> applyPreset(List<int> levels) async {
    for (var i = 0; i < _bands && i < levels.length; i++) {
      await setBand(i, levels[i]);
    }
  }
}

final equalizerService = EqualizerService();

/// 8 个内置预设（单位 mB，±12dB = ±1200mB；按 10 段近似）
const eqPresets = <String, List<int>>{
  '平直': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  '流行': [200, 400, 600, 400, 200, 0, 0, 200, 400, 500],
  '摇滚': [500, 400, 200, 0, -200, -200, 0, 200, 400, 500],
  '古典': [400, 300, 200, 0, 0, 0, 0, 200, 300, 400],
  '爵士': [300, 200, 0, 200, 400, 400, 200, 0, 200, 300],
  '人声': [-200, 0, 200, 400, 600, 600, 400, 200, 0, -200],
  '低音增强': [800, 700, 500, 300, 100, 0, 0, 0, 0, 0],
  '高音增强': [0, 0, 0, 0, 0, 200, 400, 600, 700, 800],
};
