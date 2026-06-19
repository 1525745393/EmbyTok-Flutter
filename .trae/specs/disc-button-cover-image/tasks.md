# 唱片静音按钮添加视频封面图 - Implementation Plan

## [x] Task 1: 修改唱片静音按钮实现
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 修改 `_buildDiscMuteButton()` 方法
  - 中间显示视频封面图（使用 `widget.item.imageUrl('Primary', embyServerUrl, token)`）
  - 使用 `BoxDecoration.shape` 自动裁剪封面图为圆形
  - 封面图随唱片一起旋转
  - 加载失败时显示默认图标
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4
- **Test Requirements**:
  - `human-judgment` TR-1.1: 唱片按钮中间显示视频封面图
  - `human-judgment` TR-1.2: 封面图随唱片旋转
  - `human-judgment` TR-1.3: 静音时边框变红
  - `human-judgment` TR-1.4: 封面图加载失败显示默认图标
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 需要获取 auth 状态来构造带认证的封面图 URL

## [x] Task 2: 验证实现
- **Priority**: P1
- **Depends On**: Task 1
- **Description**: 
  - 检查代码语法正确
  - 确认封面图 URL 构造正确
  - 确认旋转动画正常工作
- **Test Requirements**:
  - `human-judgment` TR-2.1: 代码编译无错误
  - `human-judgment` TR-2.2: 运行时无崩溃

## [ ] Task 3: 提交代码
- **Priority**: P1
- **Depends On**: Task 2
- **Description**: 
  - Git 提交修改
  - 推送到远程仓库
- **Test Requirements**:
  - `human-judgment` TR-3.1: 提交成功
  - `human-judgment` TR-3.2: 推送成功
