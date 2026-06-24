# 设置持久化修复 - The Implementation Plan (Decomposed and Prioritized Task List)

## [x] Task 1: 扩展 AppPreferences 模型和服务，添加新设置项的存储支持
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 在 `AppPreferences` 模型中添加 `defaultPlaybackRate`、`defaultSubtitleLanguage`、`videoQuality`、`subtitleSize` 字段
  - 在 `AppPreferencesService` 中添加对应的读写方法和存储键常量
  - 更新 `load()` 和 `save()` 方法以包含新字段
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4, AC-5
- **Test Requirements**:
  - `programmatic` TR-1.1: AppPreferences 模型包含新的四个字段且有默认值
  - `programmatic` TR-1.2: AppPreferencesService 能正确读写新字段到 SharedPreferences
  - `programmatic` TR-1.3: 旧版本数据（没有新字段）能正常加载并使用默认值

## [x] Task 2: 修改 defaultPlaybackRateProvider 添加持久化
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 修改 `DefaultPlaybackRateNotifier`，在构造函数中从 AppPreferencesService 加载保存的值
  - 修改 `set` 方法，更新状态后同时保存到 AppPreferencesService
- **Acceptance Criteria Addressed**: AC-1, AC-6
- **Test Requirements**:
  - `programmatic` TR-2.1: 应用启动时从存储加载播放倍速设置
  - `programmatic` TR-2.2: 调用 set() 方法后状态更新且持久化

## [x] Task 3: 修改 defaultSubtitleLanguageProvider 添加持久化
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 修改 `DefaultSubtitleLanguageNotifier`，在构造函数中从 AppPreferencesService 加载保存的值
  - 修改 `set` 方法，更新状态后同时保存到 AppPreferencesService
- **Acceptance Criteria Addressed**: AC-2, AC-6
- **Test Requirements**:
  - `programmatic` TR-3.1: 应用启动时从存储加载字幕语言设置
  - `programmatic` TR-3.2: 调用 set() 方法后状态更新且持久化

## [x] Task 4: 创建 videoQualityProvider 并添加持久化
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 在 user_preferences_provider.dart 中创建 VideoQualityNotifier 和 videoQualityProvider
  - 在构造函数中从 AppPreferencesService 加载保存的值
  - 添加 set 方法，更新状态后同时保存到 AppPreferencesService
  - 在 settings_view.dart 中使用新的 Provider 替代硬编码的 'auto'
- **Acceptance Criteria Addressed**: AC-3, AC-6
- **Test Requirements**:
  - `programmatic` TR-4.1: 应用启动时从存储加载画质偏好设置
  - `programmatic` TR-4.2: 调用 set() 方法后状态更新且持久化
  - `human-judgement` TR-4.3: 设置页面正确显示当前画质偏好

## [x] Task 5: 创建 subtitleSizeProvider 并添加持久化
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 在 user_preferences_provider.dart 中创建 SubtitleSizeNotifier 和 subtitleSizeProvider
  - 在构造函数中从 AppPreferencesService 加载保存的值
  - 添加 set 方法，更新状态后同时保存到 AppPreferencesService
  - 在 settings_view.dart 中使用新的 Provider 替代硬编码的 'medium'
- **Acceptance Criteria Addressed**: AC-4, AC-6
- **Test Requirements**:
  - `programmatic` TR-5.1: 应用启动时从存储加载字幕大小设置
  - `programmatic` TR-5.2: 调用 set() 方法后状态更新且持久化
  - `human-judgement` TR-5.3: 设置页面正确显示当前字幕大小

## [x] Task 6: 更新 settings_view.dart 使用新的 Provider
- **Priority**: medium
- **Depends On**: Task 4, Task 5
- **Description**: 
  - 更新画质偏好设置项，使用 videoQualityProvider
  - 更新字幕大小设置项，使用 subtitleSizeProvider
  - 确保设置页面正确显示当前保存的值
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `human-judgement` TR-6.1: 设置页面正确显示当前画质偏好
  - `human-judgement` TR-6.2: 设置页面正确显示当前字幕大小
