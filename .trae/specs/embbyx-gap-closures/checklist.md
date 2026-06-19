# EmbyTok Flutter - 验证清单（Checklist）

## 基础编译与静态分析
- [ ] `flutter pub get` 无错误
- [ ] `flutter analyze --no-pub lib` 0 errors / 0 warnings（相对之前不新增）
- [ ] `flutter build apk --debug` 能编译通过
- [ ] `flutter format lib` 检查格式一致

## 功能验证：Feed Type（Task 1）
- [ ] latest 模式正常拉取视频列表
- [ ] random 模式显示 80 条随机视频，每次刷新顺序不同
- [ ] favorites 模式显示用户收藏条目（影片/合集/人物混合）
- [ ] resume 模式调用 `getResumeItems()` 拉取"继续观看"列表
- [ ] `FeedType` 枚举包含 `resume` 值，`fromString`/`toStorageString`/`zhLabel` 全部支持
- [ ] `constants.dart` 新增 `kFeedTypeResume = 'resume'`
- [ ] 快捷键 R 在四种模式间循环切换（latest → random → favorites → resume → latest）
- [ ] 切换后 2 秒内列表刷新完成
- [ ] 空状态友好（favorites / resume 为空时展示提示）
- [ ] resume 列表项底部有细进度条（粉色 2px），显示播放进度
- [ ] video_list_provider 不再有 `favResp.items` 这类错误（需为 `List<MediaItem>`）

## 功能验证：视频预加载（Task 2）
- [ ] PageView.builder 的当前页 +1 条视频 `initialize()` 完成
- [ ] 当前页 -1 条视频 controller 保留在缓存中
- [ ] 超出 ±2 条以外的 controller 已 dispose，无内存泄漏
- [ ] 滑到下一条时优先使用 preloaded controller，300ms 内显示画面
- [ ] 滑动 50 条不崩溃，内存不线性增长

## 功能验证：自动连播下一集（Task 3）
- [ ] isAutoPlay=true 时，视频结束后自动切换下一页
- [ ] 切换前调用 `reportPlaybackStopped` 上报结束位置
- [ ] 最后一条视频结束时不自动跳转，显示"全部播放完毕"提示
- [ ] 最后 1 秒显示"即将播放下一集"提示条
- [ ] isAutoPlay=false 时不自动切换（用户手动切换正常）

## 功能验证：图片缓存优化（Task 4）
- [ ] 所有 `Image.network` 替换为 `CachedNetworkImage`
- [ ] placeholder 显示骨架色 / 加载动画
- [ ] errorWidget 显示渐变背景 + 图标（而非空白）
- [ ] 设置了 `memCacheWidth` / `memCacheHeight` 限制解码大小
- [ ] 回滑到已看过的条目时图片不重复加载（无 spinner）

## 功能验证：键盘/遥控器快捷键（Task 5）
- [ ] A / ArrowLeft → 向后 seek 15 秒（实际生效，非占位）
- [ ] D / ArrowRight → 向前 seek 15 秒
- [ ] W / ArrowUp → 上一条视频
- [ ] S / ArrowDown → 下一条视频
- [ ] Space → 播放/暂停
- [ ] U → 切换收藏
- [ ] R → 切换浏览模式
- [ ] E → 切换视图/网格
- [ ] G → 打开媒体库选择器
- [ ] F → 切换全屏
- [ ] M → 切换静音
- [ ] `/` → 显示快捷键帮助面板

## 功能验证：子标题渲染（Task 6）
- [ ] 视频支持字幕时控制条有"字幕按钮"
- [ ] 字幕选择器能列出可用语言
- [ ] 选中某语言后字幕正确显示（黑底白字）
- [ ] 选择"关闭"后字幕消失
- [ ] 横竖屏字体大小正确（16sp / 22sp）
- [ ] VTT 解析正确，按时间戳显示文本

## 功能验证：Continue Watching（Task 7）
- [ ] feed 页顶部或单独 tab 展示"继续观看"列表
- [ ] 调用 `getResumeItems()` 返回的条目与 UI 一致
- [ ] 每个条目显示缩略图、标题和播放进度条
- [ ] 点击后从 `playbackPositionTicks` 位置开始播放
- [ ] 播放完毕后从"继续观看"列表移除

## 功能验证：NextUp（Task 8）
- [ ] 剧集 S1E5 播放结束时查询 `getNextUp()`
- [ ] 若有 S1E6，显示 5 秒倒计时提示条
- [ ] 提示条显示"即将播放：S1E6 标题"
- [ ] 点击提示条立即播放下一集
- [ ] 5 秒后自动播放下一集
- [ ] 若无下一集，则回退默认逻辑（跳 feed 下一条）

## 功能验证：Item Detail View（Task 9）
- [ ] 详情页能正常打开（点击条目或路由 `/item/:itemId`）
- [ ] 显示横屏海报大图
- [ ] 显示标题、年份、类型标签
- [ ] 显示社区评分（⭐ 数字）
- [ ] 显示简介（可展开/折叠）
- [ ] 显示演员头像横滑列表（有名称）
- [ ] 显示集数列表（Series），点击可直接播放
- [ ] "立即播放"按钮调用播放器并从开头播放
- [ ] "收藏"按钮调用 favoritesProvider，状态与 feed 页同步

## 功能验证：TV Mode 遥控器导航（Task 10）
- [ ] 顶部 Library Chips 能通过左右方向键切换焦点
- [ ] 选中的 chip 有粉色边框 + 缩放 1.05 高亮
- [ ] 视频流 PageView 能用 Up/Down 切换条目
- [ ] 右操作栏（点赞/收藏/分享/全屏）能获取焦点
- [ ] 网格视图中卡片支持 D-pad 移动
- [ ] 焦点超出可视区域时自动 `ensureVisible` 滚动

## 功能验证：错误状态与空状态（Task 11）
- [ ] 断网 → 显示"网络不稳定，点击重试"卡片 + 刷新按钮
- [ ] API 返回空列表（如 favorites 为空）→ 显示"暂无内容"友好提示
- [ ] 未登录 → 显示"请先登录"引导（非空白页）
- [ ] 服务器地址错误 → 提示"无法连接服务器"，提供跳转设置页按钮
- [ ] 错误页面对比度/可读性通过人工检查

## 性能（Task 12）
- [ ] feed 页滑动帧率稳定 55+ FPS（在目标机型）
- [ ] PageView 上下切换无明显卡顿（<300ms 出画面）
- [ ] 列表项使用 `Key(key: item.id)` 稳定 key
- [ ] 公共 API/Provider 都有 `///` doc 注释
- [ ] 函数不超过 80 行（大函数拆分）
- [ ] 移除未使用的 import
- [ ] flutter format 自动格式化

## CI 与发布相关
- [ ] 所有 commit 通过 CI（`flutter analyze` 必须通过）
- [ ] 不引入 Android/iOS 原生插件
- [ ] 不新增敏感权限
- [ ] `pubspec.yaml` 版本号按语义化正确管理
- [ ] CHANGELOG.md 在 release 分支正确更新

## 回归测试（修改可能影响的既有功能）
- [ ] 登录/登出流程正常（authProvider 未破坏）
- [ ] 收藏切换（toggleFavorite）正常，乐观更新正确
- [ ] 播放上报链（Capabilities → Start → Position → Stopped）完整
- [ ] 横屏/竖屏切换不崩溃，控制条正常
- [ ] 搜索功能正常
- [ ] Favorites view 正常展示三栏（movies/boxsets/people）
- [ ] History view 正常记录和展示观看历史
- [ ] Settings 页正常（主题切换等）

## 代码 Review 检查
- [ ] 变量命名有意义（避免单字母变量）
- [ ] 函数单一职责
- [ ] 避免不必要的对象复制（避免 `.toList().toList()` 等）
- [ ] 避免深层嵌套（3 层以上需考虑提前返回）
- [ ] 使用 `async/await` 而非 `.then()` 链式调用
- [ ] 错误处理完善（try/catch 覆盖所有异步操作）
- [ ] 日志使用 AppLogger，不使用裸 `print`
- [ ] 资源释放完善（`dispose()` 中取消 Timer/Listener/Controller）
