# 演员头像按钮（TikTok 风格） - Verification Checklist

## Task 1: 重构 `_buildPosterAvatar()` 为演员头像
- [x] 从 `widget.item.people` 获取第一个 Actor 类型人员
- [x] 有演员时显示演员头像（56x56px 圆形）
- [x] 无演员时回退显示视频封面图
- [x] 演员头像下方显示名字（可选短名）
- [x] 获取认证信息用于构造图片 URL

## Task 2: 添加 TikTok 风格的 "+" 收藏按钮
- [x] "+"按钮位于头像右下角（20-24px）
- [x] 青色圆形背景（`Color(0xFF00D9FF)`）
- [x] 点击调用 `toggleFavorite()` 切换收藏状态
- [x] 已收藏时显示"✓"
- [x] 未收藏时显示"+"
- [x] "+"按钮的点击与头像点击分离（不冲突）

## Task 3: 点击头像跳转到演员详情页
- [x] 点击演员头像调用 `Navigator.push` 到 `PersonDetailView`
- [x] `Person` 正确转换为 `MediaItem`（type='Person'）
- [x] 详情页正确显示演员姓名
- [x] 详情页正确加载演员作品列表
- [x] 返回按钮工作正常

## Task 4: 与现有收藏系统兼容
- [x] 收藏后 `favoriteIds` 包含演员 ID
- [x] 收藏页"人物"标签能看到新收藏的演员
- [x] 取消收藏后状态正确更新
- [x] 收藏状态在页面刷新后保持

## Task 5: 验证并提交
- [x] 代码编译无错误
- [x] 运行时无崩溃
- [x] Git 提交成功
- [x] 推送到远程仓库成功
