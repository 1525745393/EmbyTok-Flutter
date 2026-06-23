# Checklist

- [x] Checkpoint 1: VideoControls 使用 ValueListenableBuilder 局部重建，不再每帧 setState
- [x] Checkpoint 2: VideoPageItem 使用 select 选择器，isPlaying 变化仅局部重建
- [x] Checkpoint 3: _authServerUrl() 和 _authToken() 使用 ref.read 而非 ref.watch
- [x] Checkpoint 4: 所有 CachedNetworkImage 传入 AppImageCacheManager
- [x] Checkpoint 5: 匿名 listener 已提取为命名方法，dispose 中正确移除
- [x] Checkpoint 6: EmbytokService GET 请求去重机制生效
