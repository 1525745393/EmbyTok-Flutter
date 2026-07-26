# 服务层抽象与依赖注入 - Verification Checklist

## 接口定义验证
- [ ] MediaServerApi 接口已创建且方法完整覆盖 EmbytokService 所有公共 API 方法
- [ ] 接口每个方法都有中文文档注释，说明用途、参数和返回值
- [ ] ServerType 枚举已定义，包含 emby、jellyfin、plex 三个值
- [ ] 接口方法按功能逻辑分组（认证、媒体库、播放、收藏、搜索等）

## Emby 适配层验证
- [ ] EmbyServerApi 类完整实现了 MediaServerApi 接口的所有方法
- [ ] EmbyServerApi 内部使用 ApiClient 进行 HTTP 请求，不直接依赖 Dio
- [ ] 登录方法：login 请求的 URL、参数、Header 与原实现一致
- [ ] 媒体库方法：getLibraries、getUserViews 请求格式正确
- [ ] 列表方法：getLibraryItems 分页、排序、过滤参数传递正确
- [ ] 详情方法：getItemDetail 返回的 MediaItem 字段完整
- [ ] 推荐方法：getRecommendations、getSuggestions、getNextUp 参数正确
- [ ] 剧集方法：getSeasons、getEpisodes 返回值解析正确
- [ ] 人员方法：getPeople、getPersonItems、getPersonDetail 行为一致
- [ ] 分类方法：getGenres、getItemsByGenre、getStudios、getItemsByStudio 正确
- [ ] 收藏方法：getFavoriteMovies、getFavoriteBoxSets、getFavoritePeople 解析正确
- [ ] toggleFavorite 方法：POST/DELETE 方法和 URL 与原实现一致
- [ ] 播放信息：getPlaybackInfo 返回 MediaSource 列表解析正确
- [ ] 字幕方法：getSubtitleCues、getSubtitleCuesFromFile 行为一致
- [ ] 搜索方法：searchHints、searchItems、searchPersons 参数正确
- [ ] 播放上报：reportCapabilities、reportPlaybackStart、reportPlaybackPosition、reportPlaybackStopped 参数正确
- [ ] 其他方法：getWatchHistory、getChildren、deleteItem、getSimilarItems 等行为一致

## EmbytokService 重构验证
- [ ] EmbytokService 持有 MediaServerApi 接口实例，而非直接调用 ApiClient
- [ ] EmbytokService 构造函数支持注入自定义 MediaServerApi 实现
- [ ] EmbytokService 默认构造函数使用 EmbyServerApi 实现，向后兼容
- [ ] EmbytokService 保留所有公共方法，签名与之前完全一致
- [ ] EmbytokService 中的业务逻辑（字幕缓存、播放重试等）保留完整
- [ ] EmbytokService 中不再有直接的 Dio 或 ApiClient 调用（除构造注入外）

## Provider 体系验证
- [ ] mediaServerApiProvider 已创建，默认返回 EmbyServerApi 实例
- [ ] embytokServiceProvider 从 mediaServerApiProvider 获取适配层实例
- [ ] providers.dart 导出了新增的 Provider
- [ ] 通过 ProviderScope.overrides 可替换 mediaServerApiProvider 为 Mock 实现
- [ ] 替换后 EmbytokService 正确使用 Mock 实例

## 向后兼容验证
- [ ] 所有现有单元测试无需修改即可通过
- [ ] 所有现有集成测试无需修改即可通过
- [ ] 上层调用代码（Provider、Widget、Repository）无需修改
- [ ] EmbyRepository 中的 EmbytokService 使用方式不受影响
- [ ] 登录流程、播放流程、收藏流程等核心功能行为完全一致

## 代码质量验证
- [ ] 所有新文件遵循项目代码规范
- [ ] 关键逻辑有中文注释
- [ ] 单个文件不超过 500 行
- [ ] flutter analyze 无错误、无警告
- [ ] 接口与实现分离清晰，依赖方向正确（上层依赖抽象，不依赖具体实现）
- [ ] 命名一致，符合 Dart/Flutter 命名规范

## 测试覆盖验证
- [ ] MediaServerApi 接口的每个方法都有对应的单元测试（在 EmbyServerApi 测试中）
- [ ] EmbyServerApi 的单元测试覆盖了正常路径和错误路径
- [ ] EmbytokService 可通过 Mock MediaServerApi 进行独立测试
- [ ] Provider 依赖注入机制有对应的测试用例
