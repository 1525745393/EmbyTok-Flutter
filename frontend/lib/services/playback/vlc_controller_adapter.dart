import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'i_playback_controller.dart';

class VlcControllerAdapter implements IPlaybackController {
  final VlcPlayerController _vlcController;

  VlcPlayerController get vlcController => _vlcController;

  final List<VoidCallback> _listeners = [];

  VlcControllerAdapter._(this._vlcController) {
    _vlcController.addListener(_onVlcChanged);
  }

  static Future<VlcControllerAdapter> networkUrl(
    String url, {
    Map<String, String>? httpHeaders,
  }) async {
    final vlcController = VlcPlayerController.network(
      url,
      hwAcc: HwAcc.auto,
      autoInitialize: false,
      autoPlay: false,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2000),
        ]),
      ),
    );

    return VlcControllerAdapter._(vlcController);
  }

  void _onVlcChanged() {
    for (final listener in _listeners) {
      listener();
    }
    onPositionChanged?.call();
  }

  @override
  Future<void> initialize() => _vlcController.initialize();

  @override
  Future<void> play() => _vlcController.play();

  @override
  Future<void> pause() => _vlcController.pause();

  @override
  Future<void> seekTo(Duration position) => _vlcController.seekTo(position);

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _vlcController.setPlaybackSpeed(speed);

  @override
  Future<void> setVolume(double volume) =>
      _vlcController.setVolume(volume.toInt());

  @override
  Future<void> setLooping(bool loop) =>
      _vlcController.setLooping(loop);

  @override
  Future<void> dispose() async {
    await _vlcController.stop();
    _vlcController.dispose();
    _listeners.clear();
  }

  @override
  Duration get position => _vlcController.value.position;

  @override
  Duration get duration => _vlcController.value.duration;

  @override
  bool get isInitialized => _vlcController.value.isInitialized;

  @override
  bool get isPlaying => _vlcController.value.isPlaying;

  @override
  bool get isBuffering => _vlcController.value.isBuffering;

  @override
  bool get hasError => _vlcController.value.hasError;

  @override
  double get playbackSpeed => _vlcController.value.playbackSpeed;

  @override
  int get playerId => identityHashCode(_vlcController);

  @override
  VoidCallback? onPositionChanged;

  @override
  VoidCallback? onPlaybackStateChanged;

  @override
  VoidCallback? onError;

  @override
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}
