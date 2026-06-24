# 设置持久化修复 - Verification Checklist

- [x] Checkpoint 1: AppPreferences 模型包含 defaultPlaybackRate、defaultSubtitleLanguage、videoQuality、subtitleSize 四个新字段
- [x] Checkpoint 2: AppPreferencesService 能正确读写新字段到 SharedPreferences
- [x] Checkpoint 3: 旧版本数据（没有新字段）能正常加载并使用默认值，不破坏已有数据
- [x] Checkpoint 4: defaultPlaybackRateProvider 应用启动时从存储加载，set() 后持久化
- [x] Checkpoint 5: defaultSubtitleLanguageProvider 应用启动时从存储加载，set() 后持久化
- [x] Checkpoint 6: videoQualityProvider 应用启动时从存储加载，set() 后持久化
- [x] Checkpoint 7: subtitleSizeProvider 应用启动时从存储加载，set() 后持久化
- [x] Checkpoint 8: 设置页面正确显示当前保存的各项设置值
- [x] Checkpoint 9: 所有新存储键在 constants.dart 中统一定义
- [x] Checkpoint 10: 应用重启后，四个设置项保持用户上次设置的值
