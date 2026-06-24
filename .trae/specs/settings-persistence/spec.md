# 设置持久化修复 - Product Requirement Document

## Overview
- **Summary**: 修复应用设置重启后恢复默认值的问题，为所有用户可配置的设置项添加本地持久化支持，确保用户设置在应用重启后仍然生效。
- **Purpose**: 解决用户反馈的"设置一重启就恢复初始化"问题，提升用户体验，减少重复配置的麻烦。
- **Target Users**: 所有 EmbyTok 应用用户

## Goals
- 为默认播放倍速添加持久化
- 为默认字幕语言添加持久化
- 为画质偏好添加持久化
- 为字幕大小添加持久化
- 统一使用 AppPreferencesService 管理所有偏好设置

## Non-Goals (Out of Scope)
- 不修改已有的持久化设置（主题、自动播放、视频方向等）
- 不添加云同步功能
- 不修改设置页面的 UI 布局

## Background & Context
当前应用中部分设置项（如主题、自动播放、视频方向）已经实现了持久化，但仍有多个重要设置项仅在内存中保存状态，应用重启后就会丢失。用户反馈设置重启后恢复默认值，严重影响使用体验。

## Functional Requirements
- **FR-1**: 默认播放倍速设置持久化 - 用户设置的播放倍速在应用重启后仍然保留
- **FR-2**: 默认字幕语言设置持久化 - 用户设置的默认字幕语言在应用重启后仍然保留
- **FR-3**: 画质偏好设置持久化 - 用户设置的画质偏好（自动/1080p/720p/480p）在应用重启后仍然保留
- **FR-4**: 字幕大小设置持久化 - 用户设置的字幕大小（小/中/大）在应用重启后仍然保留
- **FR-5**: 统一持久化方案 - 所有设置项通过 AppPreferencesService 统一管理

## Non-Functional Requirements
- **NFR-1**: 性能 - 设置保存和读取应在 100ms 内完成
- **NFR-2**: 兼容性 - 保留原有存储键值，不影响已有的持久化数据
- **NFR-3**: 可靠性 - 持久化失败时不应导致应用崩溃

## Constraints
- **技术**: Flutter + Riverpod + SharedPreferences
- **依赖**: shared_preferences 包
- **兼容性**: 不破坏现有的存储数据结构

## Assumptions
- SharedPreferences 在目标平台上可用
- 用户设置数据量小，不需要数据库存储
- 所有设置都可以用简单的键值对存储

## Acceptance Criteria

### AC-1: 默认播放倍速持久化
- **Given**: 用户在设置中修改了默认播放倍速
- **When**: 用户关闭应用并重新打开
- **Then**: 默认播放倍速保持为用户上次设置的值
- **Verification**: `programmatic`

### AC-2: 默认字幕语言持久化
- **Given**: 用户在设置中修改了默认字幕语言
- **When**: 用户关闭应用并重新打开
- **Then**: 默认字幕语言保持为用户上次设置的值
- **Verification**: `programmatic`

### AC-3: 画质偏好持久化
- **Given**: 用户在设置中修改了画质偏好
- **When**: 用户关闭应用并重新打开
- **Then**: 画质偏好保持为用户上次设置的值
- **Verification**: `programmatic`

### AC-4: 字幕大小持久化
- **Given**: 用户在设置中修改了字幕大小
- **When**: 用户关闭应用并重新打开
- **Then**: 字幕大小保持为用户上次设置的值
- **Verification**: `programmatic`

### AC-5: 不影响已有持久化数据
- **Given**: 用户之前设置过主题、自动播放等已持久化的选项
- **When**: 应用升级到新版本
- **Then**: 已有的设置数据不会丢失
- **Verification**: `programmatic`

### AC-6: 设置页面正确显示当前值
- **Given**: 用户设置了各项偏好
- **When**: 打开设置页面
- **Then**: 所有设置项显示当前保存的值
- **Verification**: `human-judgment`

## Open Questions
- [ ] 画质偏好在播放时是否实际生效？（当前 UI 上显示但可能没有实际作用）
- [ ] 字幕大小在播放时是否实际生效？（当前 UI 上显示但可能没有实际作用）
