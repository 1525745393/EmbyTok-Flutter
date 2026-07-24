import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class IPlaybackController {
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> setLooping(bool loop);
  Future<void> dispose();

  Duration get position;
  Duration get duration;
  bool get isInitialized;
  bool get isPlaying;
  bool get hasError;
  double get playbackSpeed;
  int get playerId;

  VoidCallback? onPositionChanged;
  VoidCallback? onPlaybackStateChanged;
  VoidCallback? onError;

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}
