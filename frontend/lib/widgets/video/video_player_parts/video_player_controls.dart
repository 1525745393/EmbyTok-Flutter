// 从 video_player_widget.dart 拆分（part 文件，无行为变化）

part of '../video_player_widget.dart';

// ==================== 播放控制与初始化 ====================

extension _VideoPlayerControls on VideoPlayerWidgetState {
  void _scheduleBackgroundReleaseIfNeeded() {
    if (widget.isCurrentPage || _isDisposed) return;
    _backgroundReleaseTimer?.cancel();
    // 快速滑动中：立即释放，防止累积多个 controller 导致 OOM
    if (ref.read(isPageScrollingProvider)) {
      _releaseCurrentController();
      return;
    }
    _backgroundReleaseTimer =
        Timer(VideoPlayerWidgetState._backgroundReleaseDelay, () {
      if (_isDisposed || !mounted) return;
      if (!widget.isCurrentPage && _controller != null) {
        AppLogger.debug('非当前页初始化完成后超时，释放 controller 资源',
            data: {'itemId': widget.item.id});
        _releaseCurrentController();
        if (mounted) {
          setState(() {
            _initialized = false;
          });
        }
      }
    });
  }

  void _releaseCurrentController() {
    final c = _controller;
    if (c != null) {
      try {
        c.removeListener(_onControllerChanged);
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
      try {
        c.pause();
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
      try {
        c.dispose();
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
    }
    _controller = null;
    _sizeWasEmpty = false;
    widget.onControllerReleased?.call();
  }

  Future<void> _reinitForNewItem() async {
    if (_isDisposed) return;
    final token = ++_reinitToken;
    // 取消所有待执行的计时器
    _backgroundReleaseTimer?.cancel();
    // 释放旧 controller
    _releaseCurrentController();
    // 重置状态
    if (!mounted || _isDisposed) return;
    if (_reinitToken != token) return;
    // item 切换时重置预加载标记，允许使用新 item 的预加载 controller
    _preloadedControllerUsed = false;
    // 视频切换时清空本地字幕轨道（本地字幕是针对特定视频的）
    ref.read(localSubtitleTracksProvider.notifier).clear();
    setState(() {
      _initialized = false;
      _hasError = false;
      _errorMessage = null;
      _subtitleCues = const <SubtitleCue>[]; // 清空旧字幕，避免新视频初始时显示旧字幕
    });
    // 重新初始化
    if (_canPlayVideo) {
      await _initVideo(token: token);
    } else if (mounted && !_isDisposed) {
      setState(() {
        _hasError = true;
        _errorMessage = AppError.notFound(message: '无法获取播放地址');
      });
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    // 错误处理：标记错误状态
    if (controller.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = AppError.playback(message: '播放出错');
      });
    }
    // 位置变化：更新字幕
    final ms = controller.value.position.inMilliseconds;
    if ((ms - _positionMs.value).abs() >= 50) {
      _positionMs.value = ms;
    }
    // 视频尺寸从 Size.zero 变为有效尺寸时，触发重建以隐藏加载指示器
    if (controller.value.isInitialized &&
        !controller.value.size.isEmpty &&
        _sizeWasEmpty) {
      _sizeWasEmpty = false;
      setState(() {});
    }
  }

  Future<void> _initVideo({int token = 0}) async {
    if (_isDisposed) return;

    bool isCancelled() => _reinitToken != token || _isDisposed;
    // 同步当前 item.id，供 didUpdateWidget 后续对比
    _currentItemId = widget.item.id;

    // ---- 路径 1：有预加载控制器 ----
    // 由于 widget.preloadedController 是字段，Dart 流分析不会对其判空后续访问做类型提升。
    // 解决方式：在 if 块内用本地 lambda 包装，让 preloaded 作为非空参数传入，
    // lambda 内部对 c 即为非空 VideoPlayerController，可正常调用方法。
    final preloaded = widget.preloadedController;
    bool preloadedInitSucceeded = false;
    // 关键修复：如果预加载 controller 已被使用过（可能已被 dispose），
    // 不再重复使用，直接走动态创建路径。
    // 场景：非当前页 controller 被 _backgroundReleaseTimer 释放后，
    // 用户滑回该页面，didUpdateWidget 重新调用 _initVideo()，
    // 此时 widget.preloadedController 指向的 controller 已被 dispose，
    // 重复使用会导致 play/seek 等操作静默失败，视频无法播放。
    if (preloaded != null && !_preloadedControllerUsed) {
      _preloadedControllerUsed = true;
      // IIFE：把非空参数传入，函数体内 Dart 会把形参 c 视为非空
      Future<void> usePreloaded(VideoPlayerController c) async {
        _controller = c;
        c.addListener(_onControllerChanged);
        if (!c.value.isInitialized) {
          await c.initialize().timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw TimeoutException('视频初始化超时'),
              );
        }
        if (isCancelled()) {
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          return;
        }
        if (_isDisposed) {
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          return;
        }
        c.setLooping(widget.loop);
        if (mounted && !_isDisposed) {
          // 修复：先 play 再 setState，确保 VideoPlayer 构建时 controller 已在播放
          // 原顺序：setState → onControllerReady → seek → play
          //   导致 VideoPlayer 首次构建时 controller 未播放，纹理不初始化，画面黑屏
          _applyInitialVolume(c);
          _autoLoadDefaultSubtitle();
          // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
          await _seekToResumePosition();
          if (isCancelled()) {
            try {
              c.dispose();
            } catch (_) {
              // 资源释放失败不影响主流程，静默处理
            }
            return;
          }
          // 根据是否当前页决定播放/暂停（非当前页静音暂停，避免并发播放）
          _syncPlaybackState(c);
          if (mounted && !_isDisposed) {
            setState(() {
              _initialized = true;
              _hasError = false;
            });
            widget.onControllerReady?.call(c);
            // 修复：init 完成时若已是非当前页（init 期间页面切走的竞态），
            // 立即调度释放计时器，防止 controller 永久驻留
            _scheduleBackgroundReleaseIfNeeded();
          }
        }
      }

      try {
        await usePreloaded(preloaded);
        if (isCancelled()) return;
        if (!_isDisposed) {
          preloadedInitSucceeded = true;
        }
      } catch (e) {
        AppLogger.debug('VideoPlayer preloaded init error，回退到动态创建',
            data: {'error': e.toString()});
        // 预加载失败：清理可能已被赋值的 _controller 后回退到动态创建
        _releaseCurrentController();
      }
    }
    if (preloadedInitSucceeded) return;
    if (_isDisposed) return;

    // ---- 路径 2：动态创建控制器（含 DirectPlay → DirectStream → HLS 降级链）----
    // OOM 防护：PageView 缓存的相邻页面若也创建控制器，每个 1080p 控制器
    // 解码缓冲区约 30-50MB，快速滑动时 3-5 个控制器同时存在可导致 OOM。
    // 非当前页跳过动态创建，仅在 isCurrentPage 变为 true 时由 didUpdateWidget 触发创建。
    if (!widget.isCurrentPage) {
      AppLogger.debug('非当前页跳过动态创建控制器，仅显示缩略图', data: {'itemId': widget.item.id});
      return;
    }

    // 降级链：DirectPlay → DirectStream → HLS（与 VideoPoolService.preload 一致）。
    // 部分视频 DirectPlay 编码/封装 ExoPlayer 不兼容（HEVC 10bit、特殊音轨等），
    // 直接失败会导致"播放异常"，降级到转码流可显著提升播放成功率。
    final playSessionId = 'emb-dyn-${DateTime.now().microsecondsSinceEpoch}';
    final urls = <int, String?>{
      0: _playbackUrl,
      1: widget.item.computeDirectStreamUrl(widget.embyServerUrl, widget.token),
      2: widget.item.computeHlsUrl(widget.embyServerUrl, widget.token,
          playSessionId: playSessionId),
    };

    for (int level = 0; level < 3; level++) {
      final url = urls[level];
      if (url == null || url.isEmpty) continue;
      final headers = widget.item.authHeaders(widget.token);

      VideoPlayerController? c;
      try {
        c = VideoPlayerController.networkUrl(
          Uri.parse(url),
          httpHeaders: headers,
        );
        _controller = c;

        c.addListener(_onControllerChanged);

        c.setLooping(widget.loop);
        await c.initialize().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('视频初始化超时');
          },
        );
        if (isCancelled()) {
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          return;
        }
        if (_isDisposed) {
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          return;
        }
        if (mounted && !_isDisposed) {
          // 修复：先 play 再 setState，确保 VideoPlayer 构建时 controller 已在播放
          _applyInitialVolume(c);
          _autoLoadDefaultSubtitle();
          // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
          await _seekToResumePosition();
          if (isCancelled()) {
            try {
              c.dispose();
            } catch (_) {
              // 资源释放失败不影响主流程，静默处理
            }
            return;
          }
          // 根据是否当前页决定播放/暂停（非当前页静音暂停，避免并发播放）
          _syncPlaybackState(c);
          if (mounted && !_isDisposed) {
            setState(() {
              _initialized = true;
              _hasError = false;
            });
            widget.onControllerReady?.call(c);
            // 修复：init 完成时若已是非当前页（init 期间页面切走的竞态），
            // 立即调度释放计时器，防止 controller 永久驻留
            _scheduleBackgroundReleaseIfNeeded();
          }
        }
        return; // 当前级别成功，降级链结束
      } catch (e) {
        AppLogger.debug('VideoPlayer dynamic init failed, 尝试降级',
            data: {'level': level, 'error': e.toString()});
        // 清理当前失败的 controller，继续下一级降级
        if (c != null) {
          try {
            c.removeListener(_onControllerChanged);
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
        }
        _controller = null;
      }
    }

    // 三级全部失败：显示错误状态（不崩溃）
    if (_isDisposed) return;
    if (mounted && !_isDisposed) {
      setState(() {
        _initialized = false;
        _hasError = true;
        _errorMessage = AppError.playback(message: '视频加载失败');
      });
    }
  }

  Future<void> _seekToResumePosition() async {
    if (!widget.startFromResumePosition) return;
    final c = _controller;
    if (c == null) return;
    final posTicks = widget.item.userData?.playbackPositionTicks ?? 0.0;
    if (posTicks <= 0.0) return;
    final posMs = (posTicks / 10000.0).round();
    if (posMs <= 0) return;
    try {
      await c.seekTo(Duration(milliseconds: posMs));
      AppLogger.debug('续播 seek', data: {'positionMs': posMs});
    } catch (e) {
      AppLogger.debug('续播 seek 失败', data: {'error': e.toString()});
    }
  }

  Future<void> _loadSubtitle(String? selectedTrackId) async {
    AppLogger.debug('字幕加载请求', data: {
      'itemId': widget.item.id,
      'selectedTrackId': selectedTrackId,
    });
    if (!mounted) return;
    if (selectedTrackId == null) {
      AppLogger.debug('字幕：关闭字幕');
      setState(() {
        _subtitleCues = const <SubtitleCue>[];
      });
      return;
    }

    // 先从本地字幕轨道中查找
    final localTracks = ref.read(localSubtitleTracksProvider);
    SubtitleTrack? selectedTrack;
    int? trackIndex;
    bool isLocal = false;

    for (final track in localTracks) {
      if (track.id == selectedTrackId) {
        selectedTrack = track;
        isLocal = true;
        break;
      }
    }

    // 本地没找到，再从服务器字幕轨道中查找
    if (selectedTrack == null) {
      final tracks = widget.item.subtitleTracks;
      AppLogger.debug('字幕轨道列表（服务器）', data: {
        'tracksCount': tracks.length,
        'tracks': tracks
            .map((t) => '${t.id}:${t.language}:${t.displayName}')
            .toList(),
      });
      for (int i = 0; i < tracks.length; i++) {
        if (tracks[i].id == selectedTrackId) {
          selectedTrack = tracks[i];
          trackIndex = int.tryParse(tracks[i].id);
          break;
        }
      }
      // 如果没找到匹配的 track，尝试直接解析 selectedTrackId 作为索引
      trackIndex ??= int.tryParse(selectedTrackId);
    }

    if (selectedTrack == null) {
      AppLogger.warn('字幕加载失败：找不到匹配的字幕轨道', data: {
        'itemId': widget.item.id,
        'selectedTrackId': selectedTrackId,
      });
      return;
    }

    // 服务器字幕需要 mediaSourceId
    String? mediaSourceId;
    if (!isLocal) {
      final sources = widget.item.mediaSources;
      mediaSourceId =
          (sources != null && sources.isNotEmpty) ? sources.first.id : null;
      if (mediaSourceId == null || mediaSourceId.isEmpty) {
        AppLogger.warn('字幕加载失败：无有效 mediaSourceId', data: {
          'itemId': widget.item.id,
          'sourcesCount': sources?.length ?? 0,
        });
        return;
      }
      if (trackIndex == null) {
        AppLogger.warn('字幕加载失败：无效的轨道索引', data: {
          'itemId': widget.item.id,
          'selectedTrackId': selectedTrackId,
        });
        return;
      }
    }

    AppLogger.debug('开始加载字幕', data: {
      'itemId': widget.item.id,
      'mediaSourceId': mediaSourceId,
      'trackIndex': trackIndex,
      'format': selectedTrack.format,
      'language': selectedTrack.language,
      'isLocal': isLocal,
    });

    final embService = ref.read(embytokServiceProvider);
    // 注入当前认证信息（确保字幕请求头包含 Token）
    final authState = ref.read(authProvider);
    final serverUrl = authState.embyServerUrl;
    final token = authState.token;
    if (serverUrl != null && token != null) {
      embService.setupAuth(
        embyServerUrl: serverUrl,
        apiKey: token,
        userId: authState.user?.id,
      );
    }
    try {
      List<SubtitleCue> cues;
      // 本地外挂字幕：从文件读取
      if (isLocal &&
          selectedTrack.localFilePath != null &&
          selectedTrack.localFilePath!.isNotEmpty) {
        cues = await embService.getSubtitleCuesFromFile(
          filePath: selectedTrack.localFilePath!,
          format: selectedTrack.format,
        );
      } else {
        // 服务器字幕：按轨道的原始格式请求，保留原生样式（ASS/VTT 等）
        cues = await embService.getSubtitleCues(
          itemId: widget.item.id,
          mediaSourceId: mediaSourceId!,
          index: trackIndex!,
          format: selectedTrack.format,
        );
      }
      AppLogger.debug('字幕加载完成', data: {
        'itemId': widget.item.id,
        'trackIndex': trackIndex,
        'format': selectedTrack.format,
        'isLocal': selectedTrack.localFilePath != null,
        'cuesCount': cues.length,
      });
      // 双重检查：避免 dispose 后 setState
      if (mounted && !_isDisposed) {
        setState(() {
          _subtitleCues = cues;
        });
      }
    } catch (e) {
      // 字幕加载失败不影响播放，记录详细日志
      AppLogger.warn('字幕加载异常', data: {
        'itemId': widget.item.id,
        'mediaSourceId': mediaSourceId,
        'trackIndex': trackIndex,
        'error': e.toString(),
      });
      if (mounted && !_isDisposed) {
        setState(() {
          _subtitleCues = const <SubtitleCue>[];
        });
      }
    }
  }

  void _autoLoadDefaultSubtitle() {
    final tracks = widget.item.subtitleTracks;
    if (tracks.isEmpty) {
      ref.read(selectedSubtitleProvider.notifier).state = null;
      return;
    }
    final settings = ref.read(subtitleSettingsProvider);
    SubtitleTrack? matchedTrack;

    // 用户有偏好语言时，优先匹配
    if (settings.language.isNotEmpty) {
      // 精确匹配语言代码
      matchedTrack = tracks.firstWhere(
        (t) => t.language.toLowerCase() == settings.language.toLowerCase(),
        orElse: () => tracks.first,
      );
      // firstWhere 的 orElse 会返回 first，但需要验证是否真的匹配到了
      if (matchedTrack.language.toLowerCase() !=
          settings.language.toLowerCase()) {
        matchedTrack = null;
      }
    }

    // 未匹配到偏好语言，选默认或第一个
    matchedTrack ??= tracks.firstWhere(
      (t) => t.isDefault,
      orElse: () => tracks.first,
    );

    ref.read(selectedSubtitleProvider.notifier).state = matchedTrack.id;
    // 直接加载字幕，不依赖 ref.listen（避免时序竞态）
    _loadSubtitle(matchedTrack.id);
  }

  void _applyInitialVolume(VideoPlayerController c) {
    final isMuted = ref.read(isMutedProvider);
    try {
      if (!widget.isCurrentPage) {
        c.setVolume(0.0);
        return;
      }
      // 非自动播放场景默认有声；自动播放场景根据静音开关决定
      final shouldMute = widget.autoPlay && isMuted;
      c.setVolume(shouldMute ? 0.0 : 1.0);
    } catch (e) {
      // controller 可能已释放或异常，静默处理避免中断初始化流程
      AppLogger.warn('设置初始音量失败', data: {'error': e.toString()});
    }
  }

  void _syncPlaybackState(VideoPlayerController c) {
    if (!c.value.isInitialized) return;
    if (widget.isCurrentPage) {
      _applyInitialVolume(c);
      if (widget.autoPlay) {
        try {
          c.play();
        } catch (_) {
          // 资源释放失败不影响主流程，静默处理
        }
      }
    } else {
      try {
        c.pause();
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
      try {
        c.setVolume(0.0);
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
    }
  }

  Widget _buildThumbnailPlaceholder(BuildContext context) {
    // 根据屏幕像素密度动态计算缓存宽度，避免解码过大图片浪费内存
    final mq = MediaQuery.of(context);
    final cacheWidth =
        (mq.size.width * mq.devicePixelRatio).round().clamp(400, 1080);

    // 优先使用带认证信息的缩略图 URL，maxWidth 与 memCacheWidth 对齐，
    // 让服务端也缩放到对应尺寸，减少网络传输量
    final url = widget.item.thumbnailUrlWithAuth(
      widget.embyServerUrl,
      widget.token,
      maxWidth: cacheWidth,
    );
    // 获取认证头用于图片请求
    final headers = widget.item.authHeaders(widget.token);
    final scheme = Theme.of(context).colorScheme;
    final errMsg = _errorMessage;
    // 根据错误类型选择图标：网络类用 wifi_off，播放类用 error_outline
    final errorIcon = switch (errMsg?.type) {
      ErrorType.network || ErrorType.timeout => Icons.wifi_off_outlined,
      ErrorType.notFound => Icons.movie_filter_outlined,
      ErrorType.playback => Icons.error_outline,
      _ => Icons.movie_outlined,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url,
            cacheManager: AppImageCacheManager.thumbnail,
            fit: BoxFit.cover,
            httpHeaders: headers.isNotEmpty ? headers : null,
            memCacheWidth: cacheWidth,
            placeholder: (_, __) => Container(
              color: scheme.surface.withValues(alpha: 0.3),
              child: Center(
                child: CircularProgressIndicator(
                    color: scheme.primary, strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: scheme.surface.withValues(alpha: 0.3),
              child: Center(
                child: Icon(Icons.broken_image,
                    size: 64, color: scheme.onSurface.withValues(alpha: 0.4)),
              ),
            ),
          )
        else
          Container(
            color: scheme.surface.withValues(alpha: 0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    errorIcon,
                    size: 64,
                    color: _hasError
                        ? scheme.error.withValues(alpha: 0.7)
                        : scheme.onSurface.withValues(alpha: 0.4),
                  ),
                  if (_hasError && errMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errMsg.message,
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    // 可重试错误显示重试按钮
                    if (errMsg.isRetryable) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: retryInitialization,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('重试', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        // web 环境或无法播放时的播放图标占位
        if (kIsWeb || !_canPlayVideo)
          Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 96,
              color: scheme.onSurface.withValues(alpha: 0.7),
              shadows: [
                Shadow(
                  color: scheme.surface.withValues(alpha: 0.54),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
