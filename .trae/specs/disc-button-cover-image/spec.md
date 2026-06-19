# 唱片静音按钮添加视频封面图 - Product Requirement Document

## Overview

- **Summary**: 将唱片式静音按钮优化为黑胶唱片风格，中间显示当前视频的封面图，播放时唱片持续旋转，静音时边框变红。
- **Purpose**: 增强 UI 视觉效果，使唱片静音按钮更加美观，与音乐 App 的唱片效果类似，提供更好的沉浸式体验。
- **Target Users**: EmbyTok Flutter 版用户，尤其是追求精美 UI 的用户。

## Why

当前唱片式静音按钮只是一个简单的圆形 + 图标，视觉上较为单调。React 版 EmbyTok 的唱片按钮中间显示视频封面图，播放时旋转，提供更好的视觉反馈和沉浸感。

## What Changes

- 唱片静音按钮中间显示视频封面图
- 封面图使用圆形裁剪（ClipOval）
- 播放时整个唱片（包含封面图）持续旋转
- 静音时边框变为红色，提供状态反馈

## Impact

- **Affected specs**: `right-actions-bar-enhancement` - 扩展 Goal 5（唱片式静音按钮）
- **Affected code**: 
  - `frontend/lib/widgets/video_page_item.dart` - 修改 `_buildDiscMuteButton()` 方法
  - 依赖 `widget.item.imageUrl()` 获取视频封面图

## ADDED Requirements

### Requirement: 唱片封面显示
系统 SHALL 在唱片静音按钮中间显示当前视频的封面图。

#### Scenario: 正常播放状态
- **WHEN** 视频正在播放且未静音
- **THEN** 唱片按钮显示视频封面图，唱片持续旋转

#### Scenario: 静音状态
- **WHEN** 用户点击静音按钮
- **THEN** 视频静音，唱片边框变为红色

### Requirement: 封面图加载
系统 SHALL 正确获取并显示视频封面图。

#### Scenario: 封面图加载成功
- **WHEN** 视频封面图 URL 有效
- **THEN** 显示封面图

#### Scenario: 封面图加载失败
- **WHEN** 视频封面图 URL 无效或加载失败
- **THEN** 显示默认图标（music_note 或 volume_off）

## MODIFIED Requirements

### Requirement: 唱片式静音按钮（扩展）
**原要求**: 优化静音按钮视觉，改为圆形"唱片"样式，播放时缓慢旋转动画，静音时边框变为红色。

**新要求**: 在唱片样式基础上，中间显示视频封面图（优先使用 Primary 尺寸），播放时整个唱片持续旋转，静音时边框变为红色，封面图随唱片一起旋转。

## REMOVED Requirements

- 无

## Non-Goals (Out of Scope)

- 不修改唱片按钮的尺寸（保持 48x48）
- 不添加额外的动画效果
- 不修改静音功能逻辑

## Acceptance Criteria

### AC-1: 封面图显示
- **Given**: 用户正在观看有封面图的视频
- **When**: 页面加载完成
- **Then**: 唱片静音按钮中间显示视频封面图
- **Verification**: `human-judgment`

### AC-2: 封面图旋转
- **Given**: 视频正在播放
- **When**: 唱片按钮显示封面图
- **Then**: 封面图随唱片一起持续旋转
- **Verification**: `human-judgment`

### AC-3: 静音状态反馈
- **Given**: 用户点击静音按钮
- **When**: 视频静音
- **Then**: 唱片边框变为红色，封面图继续旋转
- **Verification**: `human-judgment`

### AC-4: 降级处理
- **Given**: 视频封面图加载失败
- **Then**: 显示默认图标（music_note/volume_off）
- **Verification**: `human-judgment`

## Technical Notes

- 封面图 URL: `widget.item.imageUrl('Primary', embyServerUrl, token)`
- 使用 `ClipOval` 裁剪封面图为圆形
- 封面图容器使用 `DecorationImage`
- 旋转动画使用现有的 `AnimationController` + `RotationTransition`
