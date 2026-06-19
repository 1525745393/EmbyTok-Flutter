# 右侧操作区图标化显示 - Verification Checklist

## 视觉检查
- [ ] Checkpoint 1: "点赞"按钮（爱心图标）没有文字标签
- [ ] Checkpoint 2: "信息"按钮（ℹ图标）没有文字标签
- [ ] Checkpoint 3: "删除"按钮（🗑图标）没有文字标签
- [ ] Checkpoint 4: "全屏/退出"按钮没有文字标签
- [ ] Checkpoint 5: "下一集"按钮（⏭图标，如可见）没有文字标签
- [ ] Checkpoint 6: 倍速圆形按钮内没有 "1.0x" / "2.0x" 等数字文字
- [ ] Checkpoint 7: 倍速 >1.0 时按钮仍有橙色高亮状态
- [ ] Checkpoint 8: 播放模式圆形按钮内没有 "Direct" / "Transcode" / "Fbk" 文字
- [ ] Checkpoint 9: 三种播放模式可通过图标/颜色区分
- [ ] Checkpoint 10: 海报头像下方不显示演员名字
- [ ] Checkpoint 11: 顶部倍速徽章（_buildSpeedBadge）保持可见（显示 "x.x + 闪电图标"）

## 功能检查
- [ ] Checkpoint 12: 点赞按钮点击仍可切换收藏状态
- [ ] Checkpoint 13: 信息按钮点击仍可打开底部信息面板
- [ ] Checkpoint 14: 删除按钮点击仍可触发删除确认对话框
- [ ] Checkpoint 15: 倍速按钮点击仍可打开倍速设置面板
- [ ] Checkpoint 16: 播放模式按钮点击仍可循环切换 3 种模式
- [ ] Checkpoint 17: 字幕按钮点击仍可打开字幕选择
- [ ] Checkpoint 18: 唱片静音按钮点击仍可切换静音状态
- [ ] Checkpoint 19: 全屏按钮点击仍可切换全屏
- [ ] Checkpoint 20: 连播按钮点击仍可切换连播状态（SnackBar 提示正常显示）
- [ ] Checkpoint 21: 海报头像点击仍可跳转到演员详情页
- [ ] Checkpoint 22: 海报头像 "+" 收藏按钮点击仍可切换演员收藏

## 布局检查
- [ ] Checkpoint 23: 整体右侧操作区布局不拥挤也不过散
- [ ] Checkpoint 24: 响应式缩放（手机/平板/桌面）均正常工作
- [ ] Checkpoint 25: 按钮按下缩放动画（0.8x）仍然工作
- [ ] Checkpoint 26: TV 模式焦点高亮边框仍然工作

## 代码审查
- [ ] Checkpoint 27: `git diff --stat` 仅显示 `frontend/lib/widgets/video_page_item.dart` 的修改
- [ ] Checkpoint 28: 没有修改业务逻辑 / API 调用 / Provider 状态管理
- [ ] Checkpoint 29: 代码风格与项目现有代码一致
- [ ] Checkpoint 30: 代码编译无错误
