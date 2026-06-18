# EmbyTok × Emby API 对接 —— 任务清单（tasks.md）

所有任务围绕主路径（前端直连 Emby）展开。后端代理路径的改动
在对应 task 中以"同时修改"标注。

## 依赖图概览

```
[Task 1] 服务层补齐（无外部依赖）
   │
   ├──▶ [Task 2] 播放降级链 widget 层（依赖 Task 1 中的降级等级字段）
   │
   ├──▶ [Task 3] 播放上报链 widget 层（依赖 Task 1 中的 report* 方法签名）
   │
   └──▶ [Task 4] 跨设备续播云同步触发（依赖 Task 1 的 saveCloudSync/checkCloudSync）

[Task 5] 后端代理路径 Fields 补齐（独立，任意时机）
[Task 6] 收藏端点统一（独立，任意时机）
```

---

## [ ] Task 1：服务层与模型层补齐 —— 暴露"降级等级"和 PlaySessionId

- **优先级**：P0
- **依赖**：无（底层变更）
- **描述**：
  1. `embbytok_service.dart`：为 `reportPlaybackStart` /
     `reportPlaybackPosition` / `reportPlaybackStopped` 增加
     `playSessionId` 可选参数，并在没有传入时自动生成一个
     UUID（例如 `Uuid().v4()`）。
  2. `embbytok_service.dart`：将 `toggleFavorite` 的端点路径
     改为带 userId 变体 `/Users/{userId}/FavoriteItems/{itemId}`
     （与 EmbyX 完全对齐；当前的 `/UserFavoriteItems/{itemId}`
     也能工作，但统一后更清晰）。
  3. `MediaItem` 模型：新增一个 **瞬时** 字段 `playbackLevel`
     （int，0/1/2）用于 widget 层记住当前实际使用的 URL 等级，
     便于上报时正确设置 `PlayMethod`（Level 0/1 → "DirectPlay"，
     Level 2 → "Transcode"）。该字段不参与 fromJson/toJson 的
     序列化，仅在播放会话中持有。
- **验收标准对应**：AC-4（完整上报链需要 PlaySessionId & PlayMethod）
- **测试要求**：
  - `programmatic`：新增 `playbackLevel` 字段的 getter 在 3 级
    URL 上分别返回预期值；PlaySessionId 为空时自动生成 UUID。
- **备注**：Task 1 是 Task 2/3/4 的基础。

---

## [ ] Task 2：播放降级链 widget 层 —— 运行时 error 触发降级

- **优先级**：P0
- **依赖**：Task 1（用于在降级成功后同步 playbackLevel）
- **描述**：
  1. 在 `_VideoPlayerWidgetState` 中，对 `_controller` 添加
     **运行时 listener**，当检测到 `controller.value.hasError`
     由 `false → true` 且 `_fallbackLevel < 2` 时：
     - 记录当前播放位置（为降级后 seek 做准备）
     - dispose 当前 controller
     - `_fallbackLevel++` 并使用新 URL 重新 `_initVideo`
     - 初始化成功后 seek 到失败前的位置（不中断用户观看感）
  2. `_fallbackLevel >= 2` 时不降级，显示占位图并提示用户
     "无法播放此视频"。
  3. 在 `video_player_widget.dart` 顶部新增一个
     `ValueNotifier<int> currentPlaybackLevel` 供 Task 3 的上报
     逻辑读取当前实际的 PlayMethod。
- **验收标准对应**：AC-2、AC-3
- **测试要求**：
  - `programmatic`：在测试环境中通过 mock controller 触发
    hasError，验证 `_fallbackLevel` 递增并重新调用 `_initVideo`。
  - `human-judgment`：真机上播放一条 hevc/mkv 文件（默认 Direct Play
    会在部分设备失败），观察是否平滑降级到 Direct Stream / HLS。
- **备注**：降级过程中应避免 UI 白屏，优先保留最后一帧或封面图。

---

## [ ] Task 3：完整播放上报链 —— widget 层调用服务层 report* 方法

- **优先级**：P0
- **依赖**：Task 1（PlaySessionId / playbackLevel）、Task 2（可选，但两者需共享 playbackLevel）
- **描述**：
  1. 在 `video_page_item.dart` 中新增一个独立的 `PlaybackReporter`
     State 对象，持有：
     - `currentPlaySessionId`（从 Task 1 传入或自动生成）
     - `lastReportedPosition`（上次上报 position）
     - `Timer? _progressTimer`（每 5 秒触发一次 progress 上报）
  2. 生命周期绑定：
     - `initState` 中调用 `reportCapabilities` 一次
     - 视频进入 `onControllerReady` 回调时调用
       `reportPlaybackStart(itemId, mediaSourceId, playSessionId,
       playMethod: _methodForLevel(playbackLevel))`
     - 播放中 Timer 每 5 秒调用 `reportPlaybackPosition`（带
       完整字段：PositionTicks / IsPaused / IsMuted /
       VolumeLevel / PlayMethod / EventName / CanSeek /
       QueueableMediaTypes / MediaSourceId / PlaySessionId）
     - `dispose` / 切换到其它 item 时调用 `reportPlaybackStopped`
     - 用户按暂停键时额外调用一次 `reportPlaybackPosition`
       （`EventName: "Pause"`，`IsPaused: true`）
  3. 节流：距离上次上报不足 3 秒且进度变化 < 1% 时跳过本次上报。
  4. 失败处理：单次上报失败不重试，避免影响播放；但会在 Logger
     中记录一次 debug 信息（**不打印 token**）。
- **验收标准对应**：AC-4
- **测试要求**：
  - `programmatic`：用 mock `ApiClient`，断言在播放 12 秒后
    `reportPlaybackPosition` 被调用 ≥ 2 次；断言 payload 中
    `EventName` 非空。
- **备注**：所有 report* 调用都应使用 `unawaited(Future)` 以
  避免阻塞播放 UI。

---

## [ ] Task 4：跨设备续播云同步触发

- **优先级**：P1
- **依赖**：Task 1（saveCloudSync / checkCloudSync 已存在，
  需要正确的 userId 已通过 setupAuth 保存）
- **描述**：
  1. 在 `feed_view.dart` 中：
     - `initState` 或进入页面时调用 `checkCloudSync()` 一次；
       若返回 `{ lastId, libId, date, deviceName }` 且 `lastId`
       非当前设备播放的条目，则在顶部展示一条 SnackBar：
       "从 {deviceName} 续播？" + "继续" 按钮。
     - 用户点击"继续"时，定位到 `lastId` 对应条目并 seek 到
       `UserData.PlaybackPositionTicks`（若无则 seek 到 0）。
  2. 在视频切换（currentPlayingItemProvider 变化）时，对 **旧**
     条目调用 `saveCloudSync(lastId: oldItem.id, libId: currentLib.id,
     libType: currentLib.type)`。
  3. 冲突策略：以 `date` 时间戳最新者为准，远端数据更旧则不覆盖。
- **验收标准对应**：AC-5
- **测试要求**：
  - `human-judgment`：两设备 / 两个 App 安装包真机联调，观察
    续播信息是否在设备间同步。
- **备注**：云同步为"尽力而为"，失败不影响播放；仅打 debug log。

---

## [ ] Task 5：后端代理路径 Fields 补齐

- **优先级**：P2
- **依赖**：独立
- **描述**：修改 `backend/clients/emby_client.py`：
  1. `get_items()` 的 `Fields` 新增 `MediaSources,Path`。
  2. `get_item()` 的 `Fields` 同样补充 `MediaSources,Path`。
- **验收标准对应**：无独立 AC（与前端字段一致性要求）
- **测试要求**：
  - `programmatic`：后端 pytest fixture 断言 params 中包含
    `MediaSources` 字段。
- **备注**：与主路径无耦合，可随时提交。

---

## [ ] Task 6：收藏端点路径统一（可选）

- **优先级**：P2
- **依赖**：独立
- **描述**：
  1. `embbytok_service.dart` 中将 `toggleFavorite` 的端点从
     `/UserFavoriteItems/{itemId}` 改为
     `/Users/{userId}/FavoriteItems/{itemId}`（需要从
     `_defaultUserId` 取 userId）。
  2. `backend/clients/emby_client.py` 中同步修改路径。
- **验收标准对应**：无独立 AC（与 EmbyX 风格对齐）
- **测试要求**：
  - `programmatic`：断言 mock HTTP 调用路径为新格式。
- **备注**：两端点在 Emby 上行为一致，改动主要为代码风格统一，
  风险低；可与其它 PR 一起提交。

---

## 任务优先级总览

| Task | 优先级 | 与 EmbyX 对齐点 |
|------|--------|-----------------|
| 1 | P0 | PlaySessionId / PlayMethod / 收藏端点 |
| 2 | P0 | 运行时 error 降级 |
| 3 | P0 | 完整四连上报链 |
| 4 | P1 | DisplayPreferences 续播云同步 |
| 5 | P2 | 后端 Fields 对齐 |
| 6 | P2 | 收藏路径风格统一 |

