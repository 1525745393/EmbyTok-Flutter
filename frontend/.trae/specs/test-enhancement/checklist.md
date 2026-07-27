# 测试体系建设建议 - 验证清单

## 当前测试状况确认
- [x] Flutter 测试文件共 47 个（原）→ 现在 54+ 个（新增 7+）
- [x] models 目录 12 个测试 → 12 个（增强内容）
- [x] providers 目录 12 个测试 → 14 个（新增 video_list_race_test，增强 favorites、auth）
- [x] services 目录 5 个测试
- [x] widgets 目录 6 个测试 → 7 个（新增 gesture_overlay_test）
- [x] views 目录 5 个测试
- [x] utils 目录 3 个测试
- [x] repositories 目录 1 个测试
- [x] theme 目录 1 个测试
- [x] integration 目录 0 个 → 1 个（新增 full_flow_test）
- [x] Python 后端测试缺失（backend/tests 不存在）
- [x] pytest.ini 不存在
- [x] flutter analyze 已集成到 Makefile lint 目标

## Task 1: MediaItem.fromJson 解析测试增强
- [x] PascalCase 格式解析正确（Emby 原生格式）
- [x] snake_case 格式解析正确
- [x] 混合格式解析正确
- [x] UserData 嵌套对象解析正确
- [x] 类型不匹配时优雅降级
- [x] 边界情况：空 JSON、空字符串、null 值
- [x] 图片 URL 生成方法测试

## Task 2: 字幕解析测试增强
- [x] parseSrt 空文件返回空列表
- [x] parseSrt 单个字幕 block 解析正确
- [x] parseSrt 多个连续空行分隔解析正确
- [x] parseSrt 特殊字符（中文、emoji、HTML 标签）解析正确
- [x] parseSrt 超长文本解析正确
- [x] parseSrt 损坏格式不崩溃
- [x] parseVtt 格式解析正确
- [x] parseAss 格式解析正确
- [x] parseSubtitle 统一入口测试
- [x] findCueAtPosition 二分查找测试

## Task 3: VideoListNotifier 竞态测试
- [x] 快速连续调用 refresh 只保留最后一次结果
- [x] 快速连续调用 loadMore 不会重复加载
- [x] dispose 后请求完成不会抛出异常
- [x] loadMore 进行中调用 refresh，最终状态是 refresh 的结果
- [x] isLoading 状态正确性（初始、请求中、完成、失败）

## Task 4: FavoritesNotifier 并发测试
- [x] 快速连续 toggleFavorite 只执行一次网络请求
- [x] 网络失败时回滚到正确的前一状态
- [x] 同时对不同 item 操作互不干扰
- [x] 请求进行中再次调用同一 item 被忽略
- [x] 多个 item 批量切换收藏并发操作

## Task 5: AuthProvider 持久化测试
- [x] 损坏 JSON 数据不崩溃，进入未登录状态
- [x] 缺少 token 字段时进入未登录状态
- [x] 旧格式数据能正确迁移到新格式
- [x] secure_storage 读取失败时降级处理
- [x] 登出时清除所有存储数据
- [x] 部分数据损坏（user 损坏）时仍可正常登录

## Task 6: GestureOverlay 手势测试
- [x] 单击触发 onTap 回调
- [x] 双击不触发单击回调（手势冲突正确处理）
- [x] 长按触发倍速切换
- [x] 水平滑动触发 seek
- [x] 垂直滑动触发音量调节
- [x] 滑动距离小于阈值不触发
- [x] enableGestures=false 时正确禁用

## Task 7: 集成测试 - 完整流程
- [x] 登录成功后进入首页
- [x] 首页能看到视频列表
- [x] 点击视频进入详情页
- [x] 收藏功能正常工作
- [x] 退出登录回到登录页
