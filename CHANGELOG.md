## [1.140.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.140.1...v1.140.2) (2026-07-17)


### Performance Improvements

* **ui:** 退出全屏后保持 feed 沉浸式系统栏 ([60a4767](https://github.com/1525745393/EmbyTok-Flutter/commit/60a4767d48342e037915202ebc4bc3b0cad911af))

## [1.140.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.140.0...v1.140.1) (2026-07-17)


### Performance Improvements

* **ui:** UI/UX 增强——滑动性能+沉浸式+手势反馈优化 ([e53e047](https://github.com/1525745393/EmbyTok-Flutter/commit/e53e047ac30a25793d18bda26c47e30700fe7cc1))

# [1.140.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.139.3...v1.140.0) (2026-07-17)


### Features

* EmbyX 媒体库网格视图实现 ([129f331](https://github.com/1525745393/EmbyTok-Flutter/commit/129f33169b99a76a9d38e52942dad2c4a9a1fa49))


### Performance Improvements

* **memory:** actors_view 补充 memCacheWidth + video_player 延迟释放缩短到2秒 ([2f5fb23](https://github.com/1525745393/EmbyTok-Flutter/commit/2f5fb2367569c6754c6022d9840df3ef0f4dfc4f))
* **memory:** recommend_view 补充 memCacheWidth: 300 ([7af2d78](https://github.com/1525745393/EmbyTok-Flutter/commit/7af2d78d6d4ed610244e038d9026d0240525a0df))
* **memory:** 内存管理优化——延迟释放缩短+内存压力监听+图片缓存补全 ([3915e9b](https://github.com/1525745393/EmbyTok-Flutter/commit/3915e9bda3ec7246a10e76786d1fa30f05de3d8e))
* **memory:** 添加内存压力监听到 app.dart ([a45b37f](https://github.com/1525745393/EmbyTok-Flutter/commit/a45b37f592b9010943a1b5b290befd2300eb5fb8))

## [1.139.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.139.2...v1.139.3) (2026-07-17)


### Bug Fixes

* **watch-stats:** 补全观看统计功能的数据采集环节 ([4b2d481](https://github.com/1525745393/EmbyTok-Flutter/commit/4b2d481704a059f9481aeb7fa3fe2495f269fed3))

## [1.139.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.139.1...v1.139.2) (2026-07-16)


### Bug Fixes

* **person-detail:** 修复演员详情页视频加载缓慢 + 简介空态提示 ([203c920](https://github.com/1525745393/EmbyTok-Flutter/commit/203c920c46844345d10f88d194a01ed0c546c2cc))
* **person-detail:** 修复演员详情页简介不显示的问题 ([f55be48](https://github.com/1525745393/EmbyTok-Flutter/commit/f55be48f43d68e16e505c18072db7ece562bc7fc))

## [1.139.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.139.0...v1.139.1) (2026-07-16)


### Bug Fixes

* **person-detail:** 回退 getPersonDetail 路径改动，恢复 /Items/{id} 避免破坏作品列表 ([adc6c82](https://github.com/1525745393/EmbyTok-Flutter/commit/adc6c8228ec84265da49dd5387dcff5bfb37eeb7))

# [1.139.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.138.0...v1.139.0) (2026-07-16)


### Features

* **settings:** 新增打赏支持功能 ([9f8d46e](https://github.com/1525745393/EmbyTok-Flutter/commit/9f8d46ec2f20e7fdb15d44284739b9d125f7f7d4))

# [1.138.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.137.0...v1.138.0) (2026-07-16)


### Features

* **about:** 关于对话框新增 GitHub 仓库跳转入口 ([580d11e](https://github.com/1525745393/EmbyTok-Flutter/commit/580d11e62cb15f81dcf59a0ca352dc812cfdcaa1))

# [1.137.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.136.2...v1.137.0) (2026-07-16)


### Features

* **update:** 检查更新支持应用内下载 APK 并安装 ([dfa6072](https://github.com/1525745393/EmbyTok-Flutter/commit/dfa6072de86a2c846edd2a34db002d5196dc5e9c))

## [1.136.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.136.1...v1.136.2) (2026-07-16)


### Bug Fixes

* **person-detail:** 修复演员详情页简介不显示的问题 ([08add2a](https://github.com/1525745393/EmbyTok-Flutter/commit/08add2a765c9ffc377eed872883e434d702f2659))

## [1.136.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.136.0...v1.136.1) (2026-07-16)


### Bug Fixes

* **actors:** 修复已关注/未关注 Tab 内容不显示的问题 ([09646f9](https://github.com/1525745393/EmbyTok-Flutter/commit/09646f9176e305b02f4052466a95321519d21ac3))

# [1.136.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.135.0...v1.136.0) (2026-07-16)


### Bug Fixes

* **settings:** 显式导入 LicenseRegistry 修复 undefined_identifier 错误 ([b7511bb](https://github.com/1525745393/EmbyTok-Flutter/commit/b7511bb83afc3dd60da75d748b6f9886440d5931))


### Features

* **settings:** 自定义中文许可证页面替代英文 showLicensePage ([a3aa92d](https://github.com/1525745393/EmbyTok-Flutter/commit/a3aa92d2dbf8490502713a35d8162c5ba227ad07))

# [1.135.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.134.0...v1.135.0) (2026-07-16)


### Features

* **settings:** 添加检查更新功能 ([b9cd252](https://github.com/1525745393/EmbyTok-Flutter/commit/b9cd252ca848a1868682eb5ccaefe9ee55da0071))

# [1.134.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.133.0...v1.134.0) (2026-07-16)


### Features

* **settings:** 关于对话框中文化优化 ([d63de9e](https://github.com/1525745393/EmbyTok-Flutter/commit/d63de9e34ecf1b4c57f5a286344d5e29da0711c1))

# [1.133.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.132.0...v1.133.0) (2026-07-16)


### Features

* **favorites:** 收藏分页加载 + 本地缓存 ([f53e9e8](https://github.com/1525745393/EmbyTok-Flutter/commit/f53e9e81c3ba102e586d0aa648ba03a419201392))
* **favorites:** 横向卡片添加心形角标 ([f75d535](https://github.com/1525745393/EmbyTok-Flutter/commit/f75d5357f157134306be5ad522fa3d6e20faf22e))

# [1.132.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.131.0...v1.132.0) (2026-07-16)


### Features

* **favorites:** 收藏页优化（搜索/排序/空状态引导/内存优化/副标题增强） ([23f572e](https://github.com/1525745393/EmbyTok-Flutter/commit/23f572e0f35489b2919b4a50c5cbe0699679d1a8))

# [1.131.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.130.0...v1.131.0) (2026-07-16)


### Features

* **favorites:** 收藏页优化（部分失败/长按菜单/撤销/查看全部/类型统一） ([a56fda8](https://github.com/1525745393/EmbyTok-Flutter/commit/a56fda81537e59352152778949308aa03bde970a))

# [1.130.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.129.1...v1.130.0) (2026-07-16)


### Bug Fixes

* **ci:** 修复 AppLogger.warn/debug error 参数不存在（改为 data 参数） ([3bd9c54](https://github.com/1525745393/EmbyTok-Flutter/commit/3bd9c540d3d75a3727a4b28804db457a5de1984d))


### Features

* **feed:** 视频流优化（分页修复/去重/上报重试/删除同步） ([5ac3698](https://github.com/1525745393/EmbyTok-Flutter/commit/5ac36985025736fe8c83c59a65a447d59b5257b7))

## [1.129.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.129.0...v1.129.1) (2026-07-16)


### Bug Fixes

* **pure-mode:** 修复纯净模式工具栏不隐藏问题 ([d43c548](https://github.com/1525745393/EmbyTok-Flutter/commit/d43c548148c2efb1f627b941bc0f4d83e6a04bbf))

# [1.129.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.128.1...v1.129.0) (2026-07-16)


### Features

* **settings:** 设置页优化（版本号动态/手势说明/高级折叠/搜索/重置） ([eb0d279](https://github.com/1525745393/EmbyTok-Flutter/commit/eb0d279322298af0ac8470b3bc904aef82d9b473))

## [1.128.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.128.0...v1.128.1) (2026-07-16)


### Bug Fixes

* **nav:** NavigationBar 移除不支持的 selectedItemColor/unselectedItemColor ([2526697](https://github.com/1525745393/EmbyTok-Flutter/commit/252669748f0720348bb633a05a898e67544a86f2))

# [1.128.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.127.0...v1.128.0) (2026-07-16)


### Bug Fixes

* **login:** ActionChip 改为 InputChip 修复 onDeleted 编译错误 ([69ba93e](https://github.com/1525745393/EmbyTok-Flutter/commit/69ba93e78fa3383875b3acd870780b8f376cf666))


### Features

* **login:** 优化登录界面，提升用户体验 ([ce225ce](https://github.com/1525745393/EmbyTok-Flutter/commit/ce225ce375e748b61b5774f3618993c48b95e296))

# [1.127.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.126.7...v1.127.0) (2026-07-16)


### Bug Fixes

* **search:** 修复 apiClient 未定义错误 ([75fc725](https://github.com/1525745393/EmbyTok-Flutter/commit/75fc72596a65cdcc6f9af640f899e172d63fddcd))


### Features

* **search:** 添加分组搜索功能，支持人物搜索 ([c7012d3](https://github.com/1525745393/EmbyTok-Flutter/commit/c7012d32f5852f61822853106ea749383c5c5856))

## [1.126.7](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.126.6...v1.126.7) (2026-07-14)


### Bug Fixes

* **search:** 修复搜索页面8项问题 ([d3cb1f5](https://github.com/1525745393/EmbyTok-Flutter/commit/d3cb1f5932de6a422183d683c13d4b095fc41bbe))

## [1.126.6](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.126.5...v1.126.6) (2026-07-14)


### Bug Fixes

* 回退全屏播放页到 v1.125.3 正常版本 ([215754d](https://github.com/1525745393/EmbyTok-Flutter/commit/215754dc06778bd9b435652a51985e8c37ae4a90))

## [1.126.5](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.126.4...v1.126.5) (2026-07-14)


### Bug Fixes

* 修复全屏播放黑屏 - 移除视频层 RepaintBoundary ([ad017a5](https://github.com/1525745393/EmbyTok-Flutter/commit/ad017a5efec9c76232b011b8731679ed6d4729d5))

## [1.126.4](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.126.3...v1.126.4) (2026-07-14)


### Bug Fixes

* 修复全屏播放黑屏问题（完整方案） ([7a35cc0](https://github.com/1525745393/EmbyTok-Flutter/commit/7a35cc01418e8197e11d19454a85488e790e3217))


### Reverts

* 回退全屏播放相关文件到 v1.126.0 正常状态 ([29c96ef](https://github.com/1525745393/EmbyTok-Flutter/commit/29c96efe965b50fa3ef2b1ce64a08d7747b5f36b))

## [1.126.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.126.2...v1.126.3) (2026-07-14)


### Bug Fixes

* 修复全屏播放黑屏问题 ([41a472c](https://github.com/1525745393/EmbyTok-Flutter/commit/41a472ca4a650c99b4205e9f0bc9035417efc618))

## [1.126.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.126.1...v1.126.2) (2026-07-14)


### Bug Fixes

* 修复演员界面三个问题 ([cdddd1f](https://github.com/1525745393/EmbyTok-Flutter/commit/cdddd1fa625d7a91f47dba1c6d6a161882ea6083))

## [1.126.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.126.0...v1.126.1) (2026-07-14)


### Bug Fixes

* 修复全屏播放黑屏问题 ([2ef6e39](https://github.com/1525745393/EmbyTok-Flutter/commit/2ef6e39b4d6778f9616d659b53fd902580b3abdd))

# [1.126.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.125.4...v1.126.0) (2026-07-14)


### Features

* EmbyX 媒体库网格视图实现 ([b9039cf](https://github.com/1525745393/EmbyTok-Flutter/commit/b9039cfeb0c3daa016dd4accfdf5d8baf8e67955))

## [1.125.4](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.125.3...v1.125.4) (2026-07-14)


### Bug Fixes

* **fullscreen:** 修复双击白屏问题 ([57478ba](https://github.com/1525745393/EmbyTok-Flutter/commit/57478ba681edfd06327efaeef245f45d9adb131e))
* 移除重复定义 _showSpeedBadge ([7da4984](https://github.com/1525745393/EmbyTok-Flutter/commit/7da4984a98d0cfd796c2de65e4c3f20d849386ff))

## [1.125.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.125.2...v1.125.3) (2026-07-14)


### Bug Fixes

* **fullscreen:** 修复手势功能丢失 ([54780a5](https://github.com/1525745393/EmbyTok-Flutter/commit/54780a584e7d34df793639d6c74318f5e504ee4c))

## [1.125.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.125.1...v1.125.2) (2026-07-14)


### Bug Fixes

* **fullscreen:** 修复画面比例切换逻辑 ([c3ef9f5](https://github.com/1525745393/EmbyTok-Flutter/commit/c3ef9f5eabf78618b60cc5ab1677076fad663edc))

## [1.125.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.125.0...v1.125.1) (2026-07-14)


### Bug Fixes

* **fullscreen:** 修复全屏播放器缺失功能 ([c217b07](https://github.com/1525745393/EmbyTok-Flutter/commit/c217b07686841191918730f84e89fe93583bd6b7))

# [1.125.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.124.3...v1.125.0) (2026-07-14)


### Bug Fixes

* 修复 connectivity_plus 类型不匹配 ([bdf0c73](https://github.com/1525745393/EmbyTok-Flutter/commit/bdf0c7303ae5a8486b0b1b950c898070a467e5c8))


### Features

* **fullscreen:** 补全全屏播放器完整功能 ([5e99a9a](https://github.com/1525745393/EmbyTok-Flutter/commit/5e99a9a66b54440b9484fff3b121e102df2c5a91))

## [1.124.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.124.2...v1.124.3) (2026-07-05)


### Bug Fixes

* 修复 CI 编译错误 ([88c510f](https://github.com/1525745393/EmbyTok-Flutter/commit/88c510f4106bcc63b09a587b68da26cbcda8c465))


### Performance Improvements

* **fullscreen:** 全屏播放功耗优化 ([e99edcf](https://github.com/1525745393/EmbyTok-Flutter/commit/e99edcfa40d383bbbd7765520373382812485a42))

## [1.124.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.124.1...v1.124.2) (2026-07-05)


### Bug Fixes

* **ci:** 删除v1.123.0新增的3个文件以彻底完成回退 ([c2237a3](https://github.com/1525745393/EmbyTok-Flutter/commit/c2237a3b4850f667bed12f58c531cd334b874fa2))


### Reverts

* 回退到v1.122.1代码状态（发布为v1.125.0） ([b3028ce](https://github.com/1525745393/EmbyTok-Flutter/commit/b3028ce40b575e52efbbb1a6a4e43080b4201a69))

## [1.122.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.122.0...v1.122.1) (2026-07-02)


### Bug Fixes

* **ui:** 完善全屏播放页交互完整性 ([5796a28](https://github.com/1525745393/EmbyTok-Flutter/commit/5796a28b73d68b7e7192ad704a553b841b35ca15))

# [1.122.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.121.0...v1.122.0) (2026-07-02)


### Bug Fixes

* import dart:async for unawaited() in home_scaffold ([31fc152](https://github.com/1525745393/EmbyTok-Flutter/commit/31fc1528231097fd8baf159d00fc6fbcd794059d))


### Features

* EmbyX 媒体库网格视图实现 ([779eb0a](https://github.com/1525745393/EmbyTok-Flutter/commit/779eb0ab91553285ba512bba2bfb21b9c024c837))

# [1.121.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.120.0...v1.121.0) (2026-07-02)


### Features

* EmbyX 媒体库网格视图实现 ([69d72f0](https://github.com/1525745393/EmbyTok-Flutter/commit/69d72f0f7cbe074de0c9d32d561aa79a8f0e3c9b))

# [1.120.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.119.1...v1.120.0) (2026-07-02)


### Features

* EmbyX 媒体库网格视图实现 ([be24d44](https://github.com/1525745393/EmbyTok-Flutter/commit/be24d44f87162753b1eab69e5cc0adac67b6b1bd))
* EmbyX 媒体库网格视图实现 ([b783dee](https://github.com/1525745393/EmbyTok-Flutter/commit/b783dee4f7bc14e49de1da6aca589685679f8d6a))

## [1.119.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.119.0...v1.119.1) (2026-07-01)


### Performance Improvements

* 播放器性能优化 - 渲染降频/预加载静音/封面图自适应 ([a66dbe1](https://github.com/1525745393/EmbyTok-Flutter/commit/a66dbe1849e4541690010c3c51e19d20a917ce14))
* 播放器深度优化 - 轻量预加载/池化统一/并发限流 ([d557522](https://github.com/1525745393/EmbyTok-Flutter/commit/d5575229c2c1966f3954c6a8b035efee85c36e0d))

# [1.119.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.118.6...v1.119.0) (2026-07-01)


### Bug Fixes

* 修复 CI 空安全编译错误 ([20beb3b](https://github.com/1525745393/EmbyTok-Flutter/commit/20beb3bf52ba856afb470f89891d9c5bcea0d568))
* 修复 CI 编译错误 ([afbd245](https://github.com/1525745393/EmbyTok-Flutter/commit/afbd245bda566b7bddbef0ef34aadcfb12f2229b))
* 修复 Person.id 可空字段在 else-if 条件中未判空 ([9a127d1](https://github.com/1525745393/EmbyTok-Flutter/commit/9a127d140806c35d54bafeecf44cb9e4fdb0db77))
* 修复 video_player_widget 路径1 类型提升问题 ([75874cb](https://github.com/1525745393/EmbyTok-Flutter/commit/75874cb9d153f0dc128a903e5f7c2d51ecdedea2))


### Features

* EmbyX 媒体库网格视图实现 ([2d30f0e](https://github.com/1525745393/EmbyTok-Flutter/commit/2d30f0e80decb3cd10009e13592840d22aa61bd7))

## [1.118.6](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.118.5...v1.118.6) (2026-07-01)


### Performance Improvements

* build 方法性能优化（预计算 + compute + memCacheWidth） ([#97](https://github.com/1525745393/EmbyTok-Flutter/issues/97)) ([6a7eb4e](https://github.com/1525745393/EmbyTok-Flutter/commit/6a7eb4eee61910503a944f20bb0aa7c4c0720080))

## [1.118.5](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.118.4...v1.118.5) (2026-07-01)


### Bug Fixes

* **memory:** 修复中危内存泄漏隐患 ([#96](https://github.com/1525745393/EmbyTok-Flutter/issues/96)) ([5dcf207](https://github.com/1525745393/EmbyTok-Flutter/commit/5dcf20793e6668ee0ec37bb4ace8f9d868c3212b))

## [1.118.4](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.118.3...v1.118.4) (2026-07-01)


### Bug Fixes

* **memory:** VideoListNotifier dispose 时 cancel Timer 防止内存泄漏 ([#95](https://github.com/1525745393/EmbyTok-Flutter/issues/95)) ([5e56d7f](https://github.com/1525745393/EmbyTok-Flutter/commit/5e56d7fe1a218f2d62b43c59a87e32962999c79f))

## [1.118.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.118.2...v1.118.3) (2026-06-30)


### Bug Fixes

* **lifecycle:** App 切后台时自动暂停 Feed 视频播放 ([#94](https://github.com/1525745393/EmbyTok-Flutter/issues/94)) ([b8f5078](https://github.com/1525745393/EmbyTok-Flutter/commit/b8f507845e0e0b844347194317a5dcb4c5dadc23)), closes [#93](https://github.com/1525745393/EmbyTok-Flutter/issues/93) [#93](https://github.com/1525745393/EmbyTok-Flutter/issues/93)

## [1.118.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.118.1...v1.118.2) (2026-06-30)


### Bug Fixes

* **feed:** 切到其他 Tab 时自动暂停 Feed 视频播放 ([#93](https://github.com/1525745393/EmbyTok-Flutter/issues/93)) ([9813072](https://github.com/1525745393/EmbyTok-Flutter/commit/98130729e3c9269b58eebac13281ac4d183703bb))

## [1.118.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.118.0...v1.118.1) (2026-06-29)


### Bug Fixes

* **android:** 修复 MainActivity 编译错误 (PR [#91](https://github.com/1525745393/EmbyTok-Flutter/issues/91) 回归) ([#92](https://github.com/1525745393/EmbyTok-Flutter/issues/92)) ([17112f8](https://github.com/1525745393/EmbyTok-Flutter/commit/17112f880a92617ff5e8a1c09b3386fd9db35acd))

# [1.118.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.117.1...v1.118.0) (2026-06-29)


### Features

* **android:** 适配全面屏手势导航 (edge-to-edge) ([#91](https://github.com/1525745393/EmbyTok-Flutter/issues/91)) ([e1b7296](https://github.com/1525745393/EmbyTok-Flutter/commit/e1b7296fd131dda08b457119ec95727b8168141e))

## [1.117.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.117.0...v1.117.1) (2026-06-29)


### Bug Fixes

* **feed:** 修复首页 (Feed Tab) 按返回键不弹退出确认 ([#90](https://github.com/1525745393/EmbyTok-Flutter/issues/90)) ([b09c220](https://github.com/1525745393/EmbyTok-Flutter/commit/b09c22000c883f692e66929ec650db4f650f170d))

# [1.117.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.116.0...v1.117.0) (2026-06-29)


### Bug Fixes

* **recommend:** 修复 PR [#89](https://github.com/1525745393/EmbyTok-Flutter/issues/89) loadMore 缺失 userRating 变量 ([09af49f](https://github.com/1525745393/EmbyTok-Flutter/commit/09af49fca29343364c414322daf5a16b851d4b82))


### Features

* **recommend:** 用户评分加权（Emby UserData.Rating） ([#89](https://github.com/1525745393/EmbyTok-Flutter/issues/89)) ([86b13b3](https://github.com/1525745393/EmbyTok-Flutter/commit/86b13b39e0f8574b68d1378ebc5bb2cd7cef7b4d))
* **recommend:** 用户评分加权（Emby UserData.Rating） (PR [#89](https://github.com/1525745393/EmbyTok-Flutter/issues/89)) ([8a6a1ed](https://github.com/1525745393/EmbyTok-Flutter/commit/8a6a1edea0af279921fc966ec7007fccbe6d61e9))

# [1.116.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.115.0...v1.116.0) (2026-06-29)


### Bug Fixes

* **recommend:** 修复 PR [#88](https://github.com/1525745393/EmbyTok-Flutter/issues/88) 编译错误 ([e67c1f4](https://github.com/1525745393/EmbyTok-Flutter/commit/e67c1f4dcd0cc8c48f11042ecf6de0c2c0e22fff))


### Features

* **recommend:** 反推荐疲劳（X 天内不重推） ([#88](https://github.com/1525745393/EmbyTok-Flutter/issues/88)) ([014840c](https://github.com/1525745393/EmbyTok-Flutter/commit/014840c5ea85a8c56126eb94e18b3baa21a37f6a))
* **recommend:** 反推荐疲劳（X 天内不重推） (PR [#88](https://github.com/1525745393/EmbyTok-Flutter/issues/88)) ([e1d04ec](https://github.com/1525745393/EmbyTok-Flutter/commit/e1d04ec270281e089edc80d0759591dfa6289f6e))

# [1.115.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.114.0...v1.115.0) (2026-06-29)


### Features

* **recommend:** 系列追剧优先 (PR [#87](https://github.com/1525745393/EmbyTok-Flutter/issues/87)) ([822bf4c](https://github.com/1525745393/EmbyTok-Flutter/commit/822bf4c28d345329d9ab71220cd68e103bd2defc))

# [1.114.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.113.0...v1.114.0) (2026-06-29)


### Features

* **recommend:** 收藏加权 (PR [#86](https://github.com/1525745393/EmbyTok-Flutter/issues/86)) ([f83c00c](https://github.com/1525745393/EmbyTok-Flutter/commit/f83c00cbb9d82de798f59f89d6227dc75c80807d))

# [1.113.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.112.0...v1.113.0) (2026-06-29)


### Features

* **recommend:** 用户控制 - 完播率门控开关 + 时间衰减半衰期 (PR [#85](https://github.com/1525745393/EmbyTok-Flutter/issues/85)) ([d4b65f2](https://github.com/1525745393/EmbyTok-Flutter/commit/d4b65f24de038ab719c0c1e7457607cad91b82e6))

# [1.112.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.111.0...v1.112.0) (2026-06-29)


### Features

* **recommend:** 完播率时间衰减（半衰期 14 天） (PR [#84](https://github.com/1525745393/EmbyTok-Flutter/issues/84)) ([4a78c9b](https://github.com/1525745393/EmbyTok-Flutter/commit/4a78c9bc247d1bcbad895f172317e183e249da87))

# [1.111.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.110.0...v1.111.0) (2026-06-29)


### Features

* **recommend:** 完播率接入门控 (PR [#83](https://github.com/1525745393/EmbyTok-Flutter/issues/83)) ([#83](https://github.com/1525745393/EmbyTok-Flutter/issues/83)) ([3eb1214](https://github.com/1525745393/EmbyTok-Flutter/commit/3eb12145762956611664f2e90c7bc4cae4e4b1f5)), closes [#81](https://github.com/1525745393/EmbyTok-Flutter/issues/81)

# [1.110.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.109.0...v1.110.0) (2026-06-29)


### Bug Fixes

* **preferences:** 补回 logger 导入 (PR [#82](https://github.com/1525745393/EmbyTok-Flutter/issues/82)) ([#82](https://github.com/1525745393/EmbyTok-Flutter/issues/82)) ([8e4e69b](https://github.com/1525745393/EmbyTok-Flutter/commit/8e4e69bde5419f9629d4ddbd262f228ff60a871a)), closes [#79](https://github.com/1525745393/EmbyTok-Flutter/issues/79)


### Features

* **recommend:** 冷启动 Banner + 类型偏好 + 分页 loadMore (PR [#79](https://github.com/1525745393/EmbyTok-Flutter/issues/79)) ([#79](https://github.com/1525745393/EmbyTok-Flutter/issues/79)) ([2bb7700](https://github.com/1525745393/EmbyTok-Flutter/commit/2bb770093790d827f12516e5526035ee4dd937db))
* **recommend:** 标签分类 UI - 追剧/续看/为你推荐/相似/高分 (PR [#80](https://github.com/1525745393/EmbyTok-Flutter/issues/80)) ([#80](https://github.com/1525745393/EmbyTok-Flutter/issues/80)) ([96a367e](https://github.com/1525745393/EmbyTok-Flutter/commit/96a367efe9fb8938eb3828c012a9133a372e147f)), closes [#79](https://github.com/1525745393/EmbyTok-Flutter/issues/79)
* **stats:** 完播率统计 Provider + 设置页 (PR [#81](https://github.com/1525745393/EmbyTok-Flutter/issues/81)) ([#81](https://github.com/1525745393/EmbyTok-Flutter/issues/81)) ([7a792fa](https://github.com/1525745393/EmbyTok-Flutter/commit/7a792fa4e5932a90a9231ba1a4afe2fdca23f543))

# [1.109.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.108.0...v1.109.0) (2026-06-28)


### Features

* **recommend:** 推荐规则全面优化 (PR [#78](https://github.com/1525745393/EmbyTok-Flutter/issues/78)) ([#78](https://github.com/1525745393/EmbyTok-Flutter/issues/78)) ([a82493b](https://github.com/1525745393/EmbyTok-Flutter/commit/a82493b81b83b7b34cc1fe1e6217baa6da6bd2c6))

# [1.108.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.8...v1.108.0) (2026-06-28)


### Features

* **feed/topbar:** 顶部栏添加视频流按钮 + 推荐中文 + 横向可滚动 (PR [#77](https://github.com/1525745393/EmbyTok-Flutter/issues/77)) ([#77](https://github.com/1525745393/EmbyTok-Flutter/issues/77)) ([c84e3e4](https://github.com/1525745393/EmbyTok-Flutter/commit/c84e3e48c9a0f2597a1f7601b83f27bd524fa3c6))

## [1.107.8](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.7...v1.107.8) (2026-06-28)


### Bug Fixes

* **feed/grid:** grid 跳 feed 时显式跳页（PR [#76](https://github.com/1525745393/EmbyTok-Flutter/issues/76)） ([#76](https://github.com/1525745393/EmbyTok-Flutter/issues/76)) ([a057ac7](https://github.com/1525745393/EmbyTok-Flutter/commit/a057ac7b00611916e2915a1a9b40e85a8b7f4791))

## [1.107.7](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.6...v1.107.7) (2026-06-28)


### Bug Fixes

* **clean-mode:** 修双指按压显示按钮（补 PR [#74](https://github.com/1525745393/EmbyTok-Flutter/issues/74)） ([#75](https://github.com/1525745393/EmbyTok-Flutter/issues/75)) ([fe0e9b9](https://github.com/1525745393/EmbyTok-Flutter/commit/fe0e9b96b512d944b66056451ef9e0391aac6e66))

## [1.107.6](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.5...v1.107.6) (2026-06-28)


### Bug Fixes

* **clean-mode:** 纯净模式下按钮持续隐藏（PR [#74](https://github.com/1525745393/EmbyTok-Flutter/issues/74)） ([#74](https://github.com/1525745393/EmbyTok-Flutter/issues/74)) ([3c4c5cd](https://github.com/1525745393/EmbyTok-Flutter/commit/3c4c5cd2dc8fe27679dd396ecd7454e69e96e146)), closes [#71](https://github.com/1525745393/EmbyTok-Flutter/issues/71)

## [1.107.5](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.4...v1.107.5) (2026-06-28)


### Bug Fixes

* **recommend/grid:** 修两个 bug ([#73](https://github.com/1525745393/EmbyTok-Flutter/issues/73)) ([f2ac7d5](https://github.com/1525745393/EmbyTok-Flutter/commit/f2ac7d5fbba64d3a2879c7cf4db4e6cf8308db02))

## [1.107.4](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.3...v1.107.4) (2026-06-28)


### Bug Fixes

* **clean-mode:** 纯净模式下隐藏顶部栏 + 底部导航栏（PR [#72](https://github.com/1525745393/EmbyTok-Flutter/issues/72)） ([9186927](https://github.com/1525745393/EmbyTok-Flutter/commit/91869274057ff42394ef96fcf1cb39b86b6df1ca))

## [1.107.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.2...v1.107.3) (2026-06-28)


### Bug Fixes

* **clean-mode:** 纯净模式下按钮组自动隐藏（PR [#71](https://github.com/1525745393/EmbyTok-Flutter/issues/71)） ([55789c1](https://github.com/1525745393/EmbyTok-Flutter/commit/55789c112259fe8bf3b4540eee2c114fbb4c1ed7))

## [1.107.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.1...v1.107.2) (2026-06-28)


### Bug Fixes

* **library:** 媒体库选择不持久化（PR [#70](https://github.com/1525745393/EmbyTok-Flutter/issues/70)） ([9f7dcad](https://github.com/1525745393/EmbyTok-Flutter/commit/9f7dcadf29a739931ca55582a7355e088ecba138))

## [1.107.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.107.0...v1.107.1) (2026-06-28)


### Bug Fixes

* **library-selector:** 打开弹窗强制重载 + 加载失败加重试按钮 ([#67](https://github.com/1525745393/EmbyTok-Flutter/issues/67)) ([3c31681](https://github.com/1525745393/EmbyTok-Flutter/commit/3c3168151422649afaf081428c71063a0f4bd9bc))

# [1.107.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.13...v1.107.0) (2026-06-28)


### Features

* **library:** 视频流和推荐可分别设置媒体库 ([#66](https://github.com/1525745393/EmbyTok-Flutter/issues/66)) ([4ac80b0](https://github.com/1525745393/EmbyTok-Flutter/commit/4ac80b0d1f33eab2c2fcc5cd3699a30292f76df1))

## [1.106.13](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.12...v1.106.13) (2026-06-28)


### Bug Fixes

* **fullscreen:** 修复 PR [#64](https://github.com/1525745393/EmbyTok-Flutter/issues/64) merge 后多余的右括号导致编译错误 ([#65](https://github.com/1525745393/EmbyTok-Flutter/issues/65)) ([3b5b6f3](https://github.com/1525745393/EmbyTok-Flutter/commit/3b5b6f342f258d33e452f404d794f713fbbbf8c4))
* **fullscreen:** 全屏页补全手势（长按倍速 / 滑动拖动 / 双击 ±10s） ([#64](https://github.com/1525745393/EmbyTok-Flutter/issues/64)) ([4602f46](https://github.com/1525745393/EmbyTok-Flutter/commit/4602f469b08346140ce1e63b2570cb487cb067b1))

## [1.106.12](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.11...v1.106.12) (2026-06-28)


### Bug Fixes

* **recommend:** 推荐页点 video 改用独立播放页 ([#63](https://github.com/1525745393/EmbyTok-Flutter/issues/63)) ([7c36a79](https://github.com/1525745393/EmbyTok-Flutter/commit/7c36a7932f409aa1e19b000067b6d635396b40cb))

## [1.106.11](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.10...v1.106.11) (2026-06-28)


### Bug Fixes

* **fullscreen:** 全屏页补全播放控制 ([#62](https://github.com/1525745393/EmbyTok-Flutter/issues/62)) ([bbc431a](https://github.com/1525745393/EmbyTok-Flutter/commit/bbc431a373f9a4ca10544db7e6052be6527ebf98))

## [1.106.10](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.9...v1.106.10) (2026-06-28)


### Bug Fixes

* **playback:** 换媒体库时清除上一个媒体库的 playingItem ([#61](https://github.com/1525745393/EmbyTok-Flutter/issues/61)) ([be0e3dc](https://github.com/1525745393/EmbyTok-Flutter/commit/be0e3dcb22156055919e56c5cddab0ea366fe686))

## [1.106.9](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.8...v1.106.9) (2026-06-28)


### Bug Fixes

* **grid/feed:** 换一批同步 items + 移除换库重复 refresh ([#60](https://github.com/1525745393/EmbyTok-Flutter/issues/60)) ([9e5b5a2](https://github.com/1525745393/EmbyTok-Flutter/commit/9e5b5a2aacfb0f65cf56008b8988ad9248818859))

## [1.106.8](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.7...v1.106.8) (2026-06-28)


### Bug Fixes

* **grid:** 网格视图 hidden→visible 切换时重置去重并重试滚动 ([#59](https://github.com/1525745393/EmbyTok-Flutter/issues/59)) ([8f58e9c](https://github.com/1525745393/EmbyTok-Flutter/commit/8f58e9cf1ff117ba30bd578465d4de92517972e2))

## [1.106.7](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.6...v1.106.7) (2026-06-28)


### Bug Fixes

* **build:** recommend_view 误用 AppImageCacheManager.instance ([#58](https://github.com/1525745393/EmbyTok-Flutter/issues/58)) ([d4689d5](https://github.com/1525745393/EmbyTok-Flutter/commit/d4689d55ca4939686a5aa0ee9f1a22fe26959804))

## [1.106.6](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.5...v1.106.6) (2026-06-27)


### Bug Fixes

* **build:** AppLogger.warn 误用 error 参数 ([#56](https://github.com/1525745393/EmbyTok-Flutter/issues/56)) ([c44bfd1](https://github.com/1525745393/EmbyTok-Flutter/commit/c44bfd1240cec42c3e8002a8b96428b1ff366b0a))
* **build:** 修复 PR [#54](https://github.com/1525745393/EmbyTok-Flutter/issues/54) + [#52](https://github.com/1525745393/EmbyTok-Flutter/issues/52) 引入的编译错误 ([#55](https://github.com/1525745393/EmbyTok-Flutter/issues/55)) ([6346575](https://github.com/1525745393/EmbyTok-Flutter/commit/634657560cac05ed15c2d323a7023c747377f857))
* **feed-grid:** 推荐模式与视频流冲突根治（C 方案） ([#54](https://github.com/1525745393/EmbyTok-Flutter/issues/54)) ([ad8bb14](https://github.com/1525745393/EmbyTok-Flutter/commit/ad8bb147d306bf123bf2c74b5bdeb508fc116958))
* **feed-grid:** 网格"换一批"后切回 grid 仍能定位当前在播 ([#53](https://github.com/1525745393/EmbyTok-Flutter/issues/53)) ([f375b9f](https://github.com/1525745393/EmbyTok-Flutter/commit/f375b9fa08d0b00e707509923f01fc04fe4072d3))
* **fullscreen:** 全屏页复用全局 controller，进度 100% 不丢 ([#52](https://github.com/1525745393/EmbyTok-Flutter/issues/52)) ([a9aa7bd](https://github.com/1525745393/EmbyTok-Flutter/commit/a9aa7bd987226ee2806226587b32be5cebffeb2f))

## [1.106.5](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.4...v1.106.5) (2026-06-27)


### Bug Fixes

* **feed-grid:** 补全 poster_grid_view 的 go_router/logger import ([#51](https://github.com/1525745393/EmbyTok-Flutter/issues/51)) ([b9fb586](https://github.com/1525745393/EmbyTok-Flutter/commit/b9fb58683e5a6b1b33ecc0764a0ec342ff1863fe))

## [1.106.4](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.3...v1.106.4) (2026-06-27)


### Bug Fixes

* 修复全屏切换导致视频从头播放的问题 ([9e50822](https://github.com/1525745393/EmbyTok-Flutter/commit/9e5082282bc4645f3a7da5b1f2c9b2a04b00dd07))
* 重构网格/视频流索引管理，实现视频流自管播放索引 ([d07fa0a](https://github.com/1525745393/EmbyTok-Flutter/commit/d07fa0a0ca4b238ca83b5e214906fc9f46732646))
* 重构网格/视频流索引管理，实现视频流自管播放索引 ([#48](https://github.com/1525745393/EmbyTok-Flutter/issues/48)) ([7843b88](https://github.com/1525745393/EmbyTok-Flutter/commit/7843b889983c306215ccd6d3a40be4e5ba37555b))

## [1.106.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.2...v1.106.3) (2026-06-27)


### Bug Fixes

* 修复网格与视频流切换跳转问题 ([e5863f2](https://github.com/1525745393/EmbyTok-Flutter/commit/e5863f22339342ce29a0391bec314def3e2913ba))
* 用 ref.watch 替代 ref.listen 彻底解决网格↔视频流跳转竞态 ([485a6ce](https://github.com/1525745393/EmbyTok-Flutter/commit/485a6cef864819ae7c20742fc02c97c5f6a49d02))

## [1.106.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.1...v1.106.2) (2026-06-27)


### Bug Fixes

* 帧轮询机制彻底解决网格↔视频流跳转竞态问题 ([#46](https://github.com/1525745393/EmbyTok-Flutter/issues/46)) ([e7d64c9](https://github.com/1525745393/EmbyTok-Flutter/commit/e7d64c9d0eb76b74e742ceafe60e469b05942c91))

## [1.106.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.106.0...v1.106.1) (2026-06-27)


### Bug Fixes

* 修复网格↔视频流切换跳转与位置同步 ([#45](https://github.com/1525745393/EmbyTok-Flutter/issues/45)) ([eff9da5](https://github.com/1525745393/EmbyTok-Flutter/commit/eff9da5f8d3f62b58a114e0a101bd3ee3eff0896))

# [1.106.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.105.6...v1.106.0) (2026-06-27)


### Features

* EmbyX 媒体库网格视图实现 ([6981d3f](https://github.com/1525745393/EmbyTok-Flutter/commit/6981d3f858a50e4df75b91d5c4e5a009e810351c))
* EmbyX 媒体库网格视图实现 ([dba02d0](https://github.com/1525745393/EmbyTok-Flutter/commit/dba02d02b5f505928eeeaa2fc23e43602c8ccd5f))
* EmbyX 媒体库网格视图实现 ([995c4c7](https://github.com/1525745393/EmbyTok-Flutter/commit/995c4c7b8fcaa104b66e1bd982536a75fc93b24a))

## [1.105.6](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.105.5...v1.105.6) (2026-06-27)


### Bug Fixes

* 修复网格顶部栏与 PosterGridView header 重叠问题 ([0a39d2f](https://github.com/1525745393/EmbyTok-Flutter/commit/0a39d2f9757b85e6872259b7276b5d81bf585a0e))

## [1.105.5](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.105.4...v1.105.5) (2026-06-27)


### Bug Fixes

* 将 ref.listen 从 addPostFrameCallback 移到 initState 直接注册 ([27f5fcb](https://github.com/1525745393/EmbyTok-Flutter/commit/27f5fcb973e11d1e316b341c7e88f78b30b184b3))

## [1.105.4](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.105.3...v1.105.4) (2026-06-27)


### Bug Fixes

* 删除网格顶部栏搜索框 ([0e4b5d1](https://github.com/1525745393/EmbyTok-Flutter/commit/0e4b5d15c860698fa85a0b8aab5e0ca40c0cb343))

## [1.105.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.105.2...v1.105.3) (2026-06-27)


### Bug Fixes

* 移除未定义的 gridSortOptionProvider/GridSortOption 引用 ([37640ef](https://github.com/1525745393/EmbyTok-Flutter/commit/37640ef9f1bfaf150a9c42be8b24011e3b2a73ca))
* 网格↔视频流切换 v2 - 彻底消除三套跳转逻辑的竞态条件 ([b71388a](https://github.com/1525745393/EmbyTok-Flutter/commit/b71388ae26880d6c3b307c553de0dd2f8b68e42a))

## [1.105.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.105.1...v1.105.2) (2026-06-27)


### Bug Fixes

* 修复网格↔视频流双向跳转的两个竞态条件 ([527fb77](https://github.com/1525745393/EmbyTok-Flutter/commit/527fb776016ebc3114a45240c3a31ab038bc432d))

## [1.105.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.105.0...v1.105.1) (2026-06-27)


### Bug Fixes

* 修复网格点击视频跳转被 SharedPreferences 恢复覆盖的竞态条件 ([67f674a](https://github.com/1525745393/EmbyTok-Flutter/commit/67f674a6f51a451b6cdcdd7377644b0cf3fb9ccc))

# [1.105.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.104.2...v1.105.0) (2026-06-27)


### Features

* EmbyX 媒体库网格视图实现 ([d6148f8](https://github.com/1525745393/EmbyTok-Flutter/commit/d6148f8074dba1e79f64a8903a14090035ef1274))

## [1.104.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.104.1...v1.104.2) (2026-06-27)


### Bug Fixes

* controller.dispose() 加空安全检查 ([a928e40](https://github.com/1525745393/EmbyTok-Flutter/commit/a928e40aa0ee8fc3cf5de7726dd2dbcad5d4e475))
* 修复 _restoreVideoIndex async 延迟覆盖网格点击跳转 ([7fc733e](https://github.com/1525745393/EmbyTok-Flutter/commit/7fc733e654fc2bb099317b5b1cfc55f4813c1c3c))
* 随机模式删除 150 条限制，加载全部视频 ([493ac7a](https://github.com/1525745393/EmbyTok-Flutter/commit/493ac7a4ea061bd6967075983794f6983ff73e26))


### Performance Improvements

* 修复播放器 4 个高优性能问题 ([fcc4bee](https://github.com/1525745393/EmbyTok-Flutter/commit/fcc4bee23edf835c8664e12cd2d0e31be03a73a0))

## [1.104.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.104.0...v1.104.1) (2026-06-27)


### Bug Fixes

* 恢复退出后视频位置和媒体库选择的状态持久化 ([208dfd8](https://github.com/1525745393/EmbyTok-Flutter/commit/208dfd8b48ca24bbec40ce08b9ce81e1a762f79a))

# [1.104.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.103.0...v1.104.0) (2026-06-27)


### Bug Fixes

* 修复网格→视频流跳转被 SharedPreferences 恢复覆盖 ([7cefd66](https://github.com/1525745393/EmbyTok-Flutter/commit/7cefd66f84682c50470d6e5d801123428ce4dfd4))


### Features

* EmbyX 媒体库网格视图实现 ([d0451bb](https://github.com/1525745393/EmbyTok-Flutter/commit/d0451bb1024b0cc3f06601b182629887b69154b6))

# [1.103.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.102.0...v1.103.0) (2026-06-27)


### Features

* EmbyX 媒体库网格视图实现 ([cd8c7d4](https://github.com/1525745393/EmbyTok-Flutter/commit/cd8c7d4fd806182d354084f63ff4a9fb5be68f3c))
* 详情页增加相关推荐+元信息，优化封面图预加载 ([bb31f20](https://github.com/1525745393/EmbyTok-Flutter/commit/bb31f208d0018a1437935d456660230abb145bf3))

# [1.102.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.101.1...v1.102.0) (2026-06-27)


### Bug Fixes

* 修复媒体库选择器单选模式，初始只选中第一个库，对齐 EmbyX ([2b0f0e1](https://github.com/1525745393/EmbyTok-Flutter/commit/2b0f0e1dbf92a40291a256e10f7c76ddbbdf233e))


### Features

* EmbyX 媒体库网格视图实现 ([e56443f](https://github.com/1525745393/EmbyTok-Flutter/commit/e56443facbcedd62bf27296f5fd64c37f3962fea))

## [1.101.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.101.0...v1.101.1) (2026-06-27)


### Performance Improvements

* 优化网格滚动到当前视频为垂直居中，对齐 EmbyX 实现 ([772eb52](https://github.com/1525745393/EmbyTok-Flutter/commit/772eb52177d5fa4a4b5ea4626257a577c209d1c5))

# [1.101.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.100.0...v1.101.0) (2026-06-25)


### Features

* EmbyX 媒体库网格视图实现 ([43dfbf3](https://github.com/1525745393/EmbyTok-Flutter/commit/43dfbf359359380192fa6cf8994ef30db221eb54))

# [1.100.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.99.2...v1.100.0) (2026-06-25)


### Features

* EmbyX 媒体库网格视图实现 ([8b978c1](https://github.com/1525745393/EmbyTok-Flutter/commit/8b978c18ff6ddb7e4c18d0642794696e75596f1e))

## [1.99.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.99.1...v1.99.2) (2026-06-25)


### Bug Fixes

* 修复 grid→feed 跳转判断条件错误（maxScrollExtent 是像素值不是页数） ([1b3ab92](https://github.com/1525745393/EmbyTok-Flutter/commit/1b3ab9259af38226de435d2e942aaa9724a049c8))

## [1.99.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.99.0...v1.99.1) (2026-06-25)


### Bug Fixes

* 移除 _seekToItem 中已删除的 _isGridToFeedTransition 引用，修复编译错误 ([39906fd](https://github.com/1525745393/EmbyTok-Flutter/commit/39906fd39e0df1d1cde973c19f4aa852edbeab22))
* 简化网格与视频流切换逻辑，直接在 transition 中处理跳转 ([9648660](https://github.com/1525745393/EmbyTok-Flutter/commit/964866094bec7ab630a63a41a5147aa0df70fc61))

# [1.99.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.98.0...v1.99.0) (2026-06-25)


### Features

* EmbyX 媒体库网格视图实现 ([4f49e87](https://github.com/1525745393/EmbyTok-Flutter/commit/4f49e87669fd4a663e9a544f3d6af50052758ac8))

# [1.98.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.97.0...v1.98.0) (2026-06-25)


### Bug Fixes

* 修复 library_selector.dart 语法错误（缺少 children 闭合括号） ([122dcb7](https://github.com/1525745393/EmbyTok-Flutter/commit/122dcb76e8dd482360e8c1821cab637f4e573a18))
* 修复网格与视频流切换时的跳转和滚动问题 ([af62c4e](https://github.com/1525745393/EmbyTok-Flutter/commit/af62c4e0d9bb8fe72a81c051ed6c50c1d4369d25))


### Features

* EmbyX 媒体库网格视图实现 ([c52d633](https://github.com/1525745393/EmbyTok-Flutter/commit/c52d6333d59064b55e5c62f5e0f387f090d87e2d))
* 媒体库选择器支持多选模式 ([c3b77bf](https://github.com/1525745393/EmbyTok-Flutter/commit/c3b77bfee12caf34f193a6c900c8d11ecd02d001))

# [1.97.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.96.0...v1.97.0) (2026-06-25)


### Features

* 从视频流切回网格时滚动到当前视频位置 ([2966ada](https://github.com/1525745393/EmbyTok-Flutter/commit/2966adaa07e5832700c52a8312dba3cd977c5f91))

# [1.96.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.95.2...v1.96.0) (2026-06-25)


### Bug Fixes

* 修复网格点击跳转视频流失效的问题 ([aa8cff7](https://github.com/1525745393/EmbyTok-Flutter/commit/aa8cff70a6a0f944de3896b808085f25d2cd9df6))


### Features

* EmbyX 媒体库网格视图实现 ([03ce155](https://github.com/1525745393/EmbyTok-Flutter/commit/03ce155c952f3dcb6fd3378eec32839d456a4ee6))

## [1.95.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.95.1...v1.95.2) (2026-06-25)


### Bug Fixes

* 修复网格视图点击后视频流跳转到第一个视频的问题 ([db0b0a1](https://github.com/1525745393/EmbyTok-Flutter/commit/db0b0a14a055fd1e08f2b10ca01d44585b2704f5))

## [1.95.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.95.0...v1.95.1) (2026-06-25)


### Bug Fixes

* 修复 AppLogger.debug error 参数错误 ([24738c4](https://github.com/1525745393/EmbyTok-Flutter/commit/24738c43e90b7408bbc2c4e48312d1f9c310b608))
* 媒体库视频数量单独请求，确保能正常显示 ([a9a7ad5](https://github.com/1525745393/EmbyTok-Flutter/commit/a9a7ad5b49539dcafc581844299566f29b304074))

# [1.95.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.94.1...v1.95.0) (2026-06-25)


### Bug Fixes

* 删除网格排序功能，修复顶部栏重叠和滚动加载更多 ([bd7a98a](https://github.com/1525745393/EmbyTok-Flutter/commit/bd7a98a7367d45cd4fbf6c664facdcf44b2772d9))


### Features

* EmbyX 媒体库网格视图实现 ([ba10f39](https://github.com/1525745393/EmbyTok-Flutter/commit/ba10f3904cbe952df06d0c631816662de1664d49))

## [1.94.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.94.0...v1.94.1) (2026-06-25)


### Bug Fixes

* 网格模式顶部栏删除搜索框，避免重叠 ([9fdfd6f](https://github.com/1525745393/EmbyTok-Flutter/commit/9fdfd6fb6199587286da08416eec85f9c6b0fabc))

# [1.94.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.93.1...v1.94.0) (2026-06-25)


### Bug Fixes

* **app-exit:** batch-dispose video controllers to prevent OOM on exit ([c585a56](https://github.com/1525745393/EmbyTok-Flutter/commit/c585a561f6cd228afb069b01c3fd09c0250a01bb))
* 修复编译错误 - 缺少导入和错误参数 ([f17b2c1](https://github.com/1525745393/EmbyTok-Flutter/commit/f17b2c16d9399e08763afd437e01d7db1f259bd0))


### Features

* EmbyX 媒体库网格视图实现 ([d7e0fc7](https://github.com/1525745393/EmbyTok-Flutter/commit/d7e0fc70ab1bd7448f8b54cda440b35c0c2afe81))
* EmbyX 媒体库网格视图实现 ([d3e8792](https://github.com/1525745393/EmbyTok-Flutter/commit/d3e8792ebc823ca2c77aeb7400930220b5c185ee))
* EmbyX 媒体库网格视图实现 ([0d3009d](https://github.com/1525745393/EmbyTok-Flutter/commit/0d3009d2980bd51b08ad44c08ce74c17108ae5c2))
* EmbyX 媒体库网格视图实现 ([8488dad](https://github.com/1525745393/EmbyTok-Flutter/commit/8488dadb5f02bd3743e01d7f67dd7239b88c412c))
* EmbyX 媒体库网格视图实现 ([5db88ff](https://github.com/1525745393/EmbyTok-Flutter/commit/5db88ff1f752efcdb8fbd7558bfa3ccca2bc439c))
* EmbyX 媒体库网格视图实现 ([7c6cb45](https://github.com/1525745393/EmbyTok-Flutter/commit/7c6cb4580130ec4f0db55cbbb632360a5de82e39))

## [1.93.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.93.0...v1.93.1) (2026-06-25)


### Bug Fixes

* **video_grid_view:** persist tapped index when switching to feed mode for grid-feed sync ([22acaf3](https://github.com/1525745393/EmbyTok-Flutter/commit/22acaf33e45af74cb3de4aa381a52e3c743e4c02))

# [1.93.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.92.0...v1.93.0) (2026-06-24)


### Features

* 演员页面状态持久化（类型/Tab/搜索/滚动位置） ([#43](https://github.com/1525745393/EmbyTok-Flutter/issues/43)) ([1774028](https://github.com/1525745393/EmbyTok-Flutter/commit/17740281606f426c29df7edb0a31ece79203a94e))

# [1.92.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.91.0...v1.92.0) (2026-06-24)


### Features

* 网格模式点击视频切换到视频流并从该视频播放 ([#41](https://github.com/1525745393/EmbyTok-Flutter/issues/41)) ([9ff860a](https://github.com/1525745393/EmbyTok-Flutter/commit/9ff860a0ef4c16fe84912261e3f5f65e295e587f))

# [1.91.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.90.1...v1.91.0) (2026-06-24)


### Features

* 演员页面支持按类型缓存 ([#40](https://github.com/1525745393/EmbyTok-Flutter/issues/40)) ([d059c2c](https://github.com/1525745393/EmbyTok-Flutter/commit/d059c2ccbb54b9d342c882f5e8ab2c96665fdba5))

## [1.90.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.90.0...v1.90.1) (2026-06-24)


### Bug Fixes

* 修复网格模式排序没有实际效果的问题 ([8f10b8e](https://github.com/1525745393/EmbyTok-Flutter/commit/8f10b8e95c734072ebbe80551ed2eead887b37dd))

# [1.90.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.89.0...v1.90.0) (2026-06-24)


### Features

* 列表滚动位置持久化，重启后恢复上次浏览位置 ([cb264d4](https://github.com/1525745393/EmbyTok-Flutter/commit/cb264d4ed8c6dd338e12d0830859067982d6e563))
* 添加推荐按钮 ([2a5d163](https://github.com/1525745393/EmbyTok-Flutter/commit/2a5d163407d4ed104a90bd254306518766439891))

# [1.89.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.88.1...v1.89.0) (2026-06-24)


### Features

* 添加推荐按钮 ([28d0806](https://github.com/1525745393/EmbyTok-Flutter/commit/28d08066b5af1bd6ddd118920422e09706a3be1b))
* 添加推荐按钮 ([ad2e875](https://github.com/1525745393/EmbyTok-Flutter/commit/ad2e8758774a28c5f5bf3d30be399c064a68eed8))
* 页面导航状态持久化，重启后恢复上次页面 ([f827de5](https://github.com/1525745393/EmbyTok-Flutter/commit/f827de5cd37085829eab145ee7fb7ebc4f4174d7))

## [1.88.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.88.0...v1.88.1) (2026-06-24)


### Bug Fixes

* 修复设置重启后恢复默认值的问题 ([ac612b8](https://github.com/1525745393/EmbyTok-Flutter/commit/ac612b8df18f8c5371b364c2191760919d11791d))

# [1.88.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.87.1...v1.88.0) (2026-06-24)


### Bug Fixes

* 修复演员列表重复加载问题 ([d27ce53](https://github.com/1525745393/EmbyTok-Flutter/commit/d27ce53d28cdf4dce98fb6e4a361865361a41946))


### Features

* 添加推荐按钮 ([d147f58](https://github.com/1525745393/EmbyTok-Flutter/commit/d147f58b8d85fec93d14a8201d3d479c441c0bd1))

## [1.87.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.87.0...v1.87.1) (2026-06-24)


### Bug Fixes

* 修复演员界面问题 ([486c373](https://github.com/1525745393/EmbyTok-Flutter/commit/486c373eab80cfe5c0a4e22c4ca5d6e1f3f2763b))

# [1.87.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.86.0...v1.87.0) (2026-06-24)


### Bug Fixes

* 修复 searchHintsProvider 命名冲突 ([9f30b95](https://github.com/1525745393/EmbyTok-Flutter/commit/9f30b9552fab75b84d4fff61b5531d95615e0494))


### Features

* 搜索页面增强，接近 Emby 官方体验 ([df486c1](https://github.com/1525745393/EmbyTok-Flutter/commit/df486c14abfbb6807045d1fdc4c4d43bc6e2eb4a))

# [1.86.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.85.0...v1.86.0) (2026-06-24)


### Bug Fixes

* 添加 MediaSource 缺失的 size 和 bitrate 字段 ([107b406](https://github.com/1525745393/EmbyTok-Flutter/commit/107b406698b45d186f29882864fbb03d1789d8ae))


### Features

* 基于 Emby 服务端实现网格模式排序和搜索 ([fdba37f](https://github.com/1525745393/EmbyTok-Flutter/commit/fdba37ff2927f3aed5979438c0c9ce13474aa380))
* 实现网格模式搜索和排序的实际功能 ([f62a0dc](https://github.com/1525745393/EmbyTok-Flutter/commit/f62a0dc9a3f5c41a881e6565e1088041918bc79c))
* 添加推荐按钮 ([d682724](https://github.com/1525745393/EmbyTok-Flutter/commit/d6827248353e0c01668fa330eab92f9b0ca7bcaf))

# [1.85.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.84.0...v1.85.0) (2026-06-24)


### Bug Fixes

* 修复设置页面编译错误 ([610b565](https://github.com/1525745393/EmbyTok-Flutter/commit/610b565b13e92a2ff7dc0617ea2a5ca245c73fc2))


### Features

* 恢复网格模式顶部栏搜索和排序功能 ([17fa60f](https://github.com/1525745393/EmbyTok-Flutter/commit/17fa60f05aad8199009246583f66d57b46aedb99))

# [1.84.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.83.0...v1.84.0) (2026-06-24)


### Bug Fixes

* 修复设置页面编译错误 ([#28](https://github.com/1525745393/EmbyTok-Flutter/issues/28)) ([251a6e3](https://github.com/1525745393/EmbyTok-Flutter/commit/251a6e3e7e73dbd9013ac1ce476d0d484bb07174))


### Features

* 设置页面全面优化 ([c607ebc](https://github.com/1525745393/EmbyTok-Flutter/commit/c607ebc040b6c3bc06b8e8ca81adc823b8c823e2))

# [1.83.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.82.0...v1.83.0) (2026-06-24)


### Features

* 添加推荐按钮 ([b1af2af](https://github.com/1525745393/EmbyTok-Flutter/commit/b1af2af6f7350b88e679020968d71fc42febfe1b))


### Reverts

* 回退测试文件以确保 CI 通过 ([f1adc5e](https://github.com/1525745393/EmbyTok-Flutter/commit/f1adc5e9834f44d6ca4b1c96d9de1edbab8669fb))

# [1.82.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.81.0...v1.82.0) (2026-06-24)


### Features

* 自动化测试缺口分析与补充 ([16407f5](https://github.com/1525745393/EmbyTok-Flutter/commit/16407f51c977a78bffd5600fbf52f602a5029b5b))
* 自动化测试缺口分析与补充 ([b745f53](https://github.com/1525745393/EmbyTok-Flutter/commit/b745f538ca24ab85fa17dc37a93ac8ee0750a3b3))

# [1.81.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.80.0...v1.81.0) (2026-06-24)


### Features

* 添加演员按钮与演员页面 ([5a52b86](https://github.com/1525745393/EmbyTok-Flutter/commit/5a52b867b643eb4ba21ef0cf49fd49507c446a3d))

# [1.80.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.79.1...v1.80.0) (2026-06-24)


### Bug Fixes

* 修复 TvFocusable 边框遮挡内容问题 ([e313094](https://github.com/1525745393/EmbyTok-Flutter/commit/e31309453f3112b105b0905109ba8300962c414f))


### Features

* 添加演员按钮与演员页面 ([f076d6f](https://github.com/1525745393/EmbyTok-Flutter/commit/f076d6f6abdbe8a368415699a71883a1b3587229))

## [1.74.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.74.0...v1.74.1) (2026-06-22)


### Bug Fixes

* 修复演员列表显示问题 ([bfaabac](https://github.com/1525745393/EmbyTok-Flutter/commit/bfaabac9ae2c3a0bfd3ebc9cadaabe61e163ce44))

# [1.74.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.73.3...v1.74.0) (2026-06-22)


### Bug Fixes

* 修复演员详情页编译错误 ([4e768ca](https://github.com/1525745393/EmbyTok-Flutter/commit/4e768ca4c4066bdc52464f46dcefe3d16ce42c69))


### Features

* 演员简介支持折叠/展开 ([ec530cc](https://github.com/1525745393/EmbyTok-Flutter/commit/ec530ccd66f6f5297669996335e152925537417f))
* 演员详情页显示简介 ([0ac3b06](https://github.com/1525745393/EmbyTok-Flutter/commit/0ac3b06ab6b9cb7efc58698f857dc0ee4c6f87e2))

## [1.73.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.73.2...v1.73.3) (2026-06-22)


### Bug Fixes

* 修复已关注演员列表不显示问题 ([9ed4e26](https://github.com/1525745393/EmbyTok-Flutter/commit/9ed4e266cee3d668aaf79b1510c182cdf38f14c5))

## [1.73.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.73.1...v1.73.2) (2026-06-22)


### Bug Fixes

* 演员收藏功能缺少 userId 参数 ([995494f](https://github.com/1525745393/EmbyTok-Flutter/commit/995494f01eecd8f942da1511ecf79e92c779fb94))

## [1.73.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.73.0...v1.73.1) (2026-06-22)


### Bug Fixes

* 修复演员详情页图片加载问题 ([fae715b](https://github.com/1525745393/EmbyTok-Flutter/commit/fae715b1a2160e13d625be0f8ffb191e249e4ecb))

# [1.73.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.72.1...v1.73.0) (2026-06-22)


### Bug Fixes

* 演员列表卡片添加图片认证头，解决图片加载失败问题 ([a7da069](https://github.com/1525745393/EmbyTok-Flutter/commit/a7da06994ec60358c59120bbbea6f1222c194241))


### Features

* 添加演员按钮与演员页面 ([02c266a](https://github.com/1525745393/EmbyTok-Flutter/commit/02c266a98d381ea62011820543a1a903d59cf63d))
* 添加演员按钮与演员页面 ([bf3a06b](https://github.com/1525745393/EmbyTok-Flutter/commit/bf3a06b8c8448b8f3e0d1e5db7b41f049d6965cd))

## [1.72.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.72.0...v1.72.1) (2026-06-22)


### Bug Fixes

* 清理代码警告 - 删除未使用导入和修复非空断言 ([4d420cf](https://github.com/1525745393/EmbyTok-Flutter/commit/4d420cf625a95b770d69997c2bd9d26a34bc4cc8))

# [1.72.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.71.1...v1.72.0) (2026-06-22)


### Bug Fixes

* **ci:** 优化 flutter analyze 日志显示，按 error/warning/info 分开显示 ([b348a79](https://github.com/1525745393/EmbyTok-Flutter/commit/b348a79a9bb891051c8dc8ff106a105ca8041e2e))
* 修复演员页面分页加载逻辑错误 ([4fce088](https://github.com/1525745393/EmbyTok-Flutter/commit/4fce088b8321c7b6cc50f61fe2062aec106b47da))
* 修复编译错误 - getPeople返回类型和TickerProvider ([966987a](https://github.com/1525745393/EmbyTok-Flutter/commit/966987a933b83756cc2cb5c70bd30245eba83bc6))
* 清理未使用的代码变量和方法 ([d4ab9ff](https://github.com/1525745393/EmbyTok-Flutter/commit/d4ab9ffaacf519544baa016a0163a8916e9182a3))


### Features

* 演员界面优化 - Tab分类显示、搜索、分页加载、类型筛选、卡片优化 ([5feab37](https://github.com/1525745393/EmbyTok-Flutter/commit/5feab37aa26ab58e5c1690d704f61f15e47d51c9))

## [1.71.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.71.0...v1.71.1) (2026-06-22)


### Bug Fixes

* 修复演员页面缺少userId参数导致API调用失败的问题 ([dae9308](https://github.com/1525745393/EmbyTok-Flutter/commit/dae93087d3f76ab432db3e017f2c66e3e6320368))

# [1.71.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.70.1...v1.71.0) (2026-06-22)


### Bug Fixes

* 修复演员页面图片URL缺少认证token的问题 ([c91f478](https://github.com/1525745393/EmbyTok-Flutter/commit/c91f47899b52b1282f09dc4ef1bc2c1504836462))


### Features

* 添加演员按钮与演员页面 ([93bad2e](https://github.com/1525745393/EmbyTok-Flutter/commit/93bad2ec99d7556542f513ab882cbeb203d25b36))

## [1.70.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.70.0...v1.70.1) (2026-06-22)


### Bug Fixes

* 优化演员页面错误提示信息 ([eab1656](https://github.com/1525745393/EmbyTok-Flutter/commit/eab1656174b9a79120b9fe7e597ff1fcbc6d6ddc))

# [1.70.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.69.0...v1.70.0) (2026-06-22)


### Features

* 添加演员按钮与演员页面 ([d356ee4](https://github.com/1525745393/EmbyTok-Flutter/commit/d356ee47c5ea466d5ad28347b1243a53cf02480c))

# [1.69.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.68.1...v1.69.0) (2026-06-22)


### Features

* 检查历史和Emby服务器对接 ([8203887](https://github.com/1525745393/EmbyTok-Flutter/commit/82038870ba16f0c8c74662beba0049251155a8b1))


### Reverts

* 回退到 fec7265 (对应 Actions run [#27913920086](https://github.com/1525745393/EmbyTok-Flutter/issues/27913920086)) ([b336e0d](https://github.com/1525745393/EmbyTok-Flutter/commit/b336e0d48a601aa29badfebfa138f92a7ec53a85))

# [1.65.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.64.0...v1.65.0) (2026-06-21)


### Features

* 检查历史和Emby服务器对接 ([d01c0c7](https://github.com/1525745393/EmbyTok-Flutter/commit/d01c0c7b48b0aab66fc6ae9c1f3cd02ec9754e51))

# [1.64.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.63.0...v1.64.0) (2026-06-21)


### Features

* 检查历史和Emby服务器对接 ([fb26958](https://github.com/1525745393/EmbyTok-Flutter/commit/fb26958741561cbebdd8f6186ab5624455b58780))

# [1.63.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.62.3...v1.63.0) (2026-06-21)


### Bug Fixes

* catch (e) 改为 catch (Object e, StackTrace _) 通过 strict-raw-types 检查 ([96a04c2](https://github.com/1525745393/EmbyTok-Flutter/commit/96a04c21b561db45f947b4b6dbf020e872b3c717))
* 修复 FeedType.latest 分支缺少 merged 变量声明导致的 CI 错误 ([503a0b7](https://github.com/1525745393/EmbyTok-Flutter/commit/503a0b762f5699cc5e1ba383e3c79d2c09ca13b1))
* 视图状态管理五项优化 ([3a79f6f](https://github.com/1525745393/EmbyTok-Flutter/commit/3a79f6f96e94134557c90069b0eef5406735fb0c))


### Features

* 检查历史和Emby服务器对接 ([ad8986b](https://github.com/1525745393/EmbyTok-Flutter/commit/ad8986bccf709e268d2ceda73bc68251d0018d68))

## [1.62.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.62.2...v1.62.3) (2026-06-21)


### Bug Fixes

* 播放会话ID碰撞/搜索参数校验/进度计算重复 ([426cd8b](https://github.com/1525745393/EmbyTok-Flutter/commit/426cd8b0db3c6dbc29b8f7fa69f705d5d6d33f9d))

## [1.62.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.62.1...v1.62.2) (2026-06-21)


### Bug Fixes

* 非"继续观看"Tab 下视频不续播的问题 ([81e0241](https://github.com/1525745393/EmbyTok-Flutter/commit/81e024161f0f06121ba8caa855aa3413e3d0af43))

## [1.62.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.62.0...v1.62.1) (2026-06-21)


### Bug Fixes

* getResumeItems/getNextUp 缺少 IncludeItemTypes 过滤 ([67dbae5](https://github.com/1525745393/EmbyTok-Flutter/commit/67dbae54618456617201236ad6569785fc3c8032))

# [1.62.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.61.0...v1.62.0) (2026-06-21)


### Features

* 检查历史和Emby服务器对接 ([e0e6dd2](https://github.com/1525745393/EmbyTok-Flutter/commit/e0e6dd28214616d957d56288011d93e9476560a1))
* 检查历史和Emby服务器对接 ([d08f607](https://github.com/1525745393/EmbyTok-Flutter/commit/d08f607fc4a82efe7c2892228a04588b7d603995))

# [1.61.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.60.0...v1.61.0) (2026-06-21)


### Features

* 视频播放页返回键异常退出 ([e16f4ab](https://github.com/1525745393/EmbyTok-Flutter/commit/e16f4ab9ad3319d96646eec463a35743fc7323be))

# [1.60.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.59.0...v1.60.0) (2026-06-21)


### Features

* 视频播放页返回键异常退出 ([58e17d9](https://github.com/1525745393/EmbyTok-Flutter/commit/58e17d94eda192a9186e642e14a19c2b20899172))

# [1.59.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.58.4...v1.59.0) (2026-06-21)


### Features

* 视频播放页返回键异常退出 ([afc4116](https://github.com/1525745393/EmbyTok-Flutter/commit/afc4116366c7848dfd2fbfd894fee78fe0599945))

## [1.58.4](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.58.3...v1.58.4) (2026-06-21)


### Bug Fixes

* Android 13+ 系统返回键直接退出 App ([6f4189c](https://github.com/1525745393/EmbyTok-Flutter/commit/6f4189c5708b96727a723759ffffe0077c502662))

## [1.58.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.58.2...v1.58.3) (2026-06-21)


### Bug Fixes

* 返回键逐级返回直到首页后显示退出确认 ([ee82e8b](https://github.com/1525745393/EmbyTok-Flutter/commit/ee82e8bcac3dbf60b7201f7bf545d558bb61022f))

## [1.58.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.58.1...v1.58.2) (2026-06-21)


### Bug Fixes

* 退出应用改为两次确认弹窗 ([62c5db2](https://github.com/1525745393/EmbyTok-Flutter/commit/62c5db2063818fba0ceefce2c8e7c957bf9144fe))
* 退出确认改回一次弹窗 ([9cb9bfc](https://github.com/1525745393/EmbyTok-Flutter/commit/9cb9bfc1e13cb893a007e3eeadfbf2927a221809))

## [1.58.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.58.0...v1.58.1) (2026-06-21)


### Bug Fixes

* 详情页导航改用push保留返回栈 ([f56f616](https://github.com/1525745393/EmbyTok-Flutter/commit/f56f6164de6d041540f9e5c032260d601d9ae243))

# [1.58.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.57.0...v1.58.0) (2026-06-21)


### Features

* 视频播放页返回键异常退出 ([aa960e2](https://github.com/1525745393/EmbyTok-Flutter/commit/aa960e29a3b388fb850df14ff8ffffead645bb51))

# [1.57.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.56.2...v1.57.0) (2026-06-20)


### Bug Fixes

* missing flutter_riverpod import and stale _preloadCache references ([28a0c3f](https://github.com/1525745393/EmbyTok-Flutter/commit/28a0c3f89552b1f7b4db4e6a7ced28dd75b2468d))


### Features

* implement VideoPoolService for Emby-aware video preloading ([14b6634](https://github.com/1525745393/EmbyTok-Flutter/commit/14b66341c09827efdffa0b3e98abbd5cb2199c39))

## [1.56.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.56.1...v1.56.2) (2026-06-20)


### Bug Fixes

* **memory:** reduce image cache and optimize Android build to prevent OOM ([d030aa9](https://github.com/1525745393/EmbyTok-Flutter/commit/d030aa9264aba2c95e63137f1f370faebcc6d641))

## [1.56.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.56.0...v1.56.1) (2026-06-20)


### Bug Fixes

* **app:** replace WillPopScope with PopScope for proper back navigation ([ecadeed](https://github.com/1525745393/EmbyTok-Flutter/commit/ecadeed9b20d0c09b263473c2707a859c214c9d1))

# [1.56.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.55.2...v1.56.0) (2026-06-20)


### Bug Fixes

* add exit confirmation dialog and fullscreen back key handling ([a61682e](https://github.com/1525745393/EmbyTok-Flutter/commit/a61682e42be9c06be4b8a8f819cf18002fbb77e4))
* resolve flutter analyze errors ([9352cbe](https://github.com/1525745393/EmbyTok-Flutter/commit/9352cbe3e4c702de567eb78a6cd221b74d51acd1))


### Features

* save progress ([5150787](https://github.com/1525745393/EmbyTok-Flutter/commit/51507879880dd75287fe3e354e2a0b525750fced))

## [1.55.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.55.1...v1.55.2) (2026-06-20)


### Bug Fixes

* remove library chips, keep only icon buttons in feed view top bar ([9b46ace](https://github.com/1525745393/EmbyTok-Flutter/commit/9b46acef719600890a7d5262a1f40f5cbb65272d))

## [1.55.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.55.0...v1.55.1) (2026-06-20)


### Bug Fixes

* restore library selector button in feed view and grid view top bar ([6a3fa38](https://github.com/1525745393/EmbyTok-Flutter/commit/6a3fa38a1d93a0fb1f2d2ff1816777d59812ab1d))

# [1.55.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.54.0...v1.55.0) (2026-06-20)


### Bug Fixes

* add missing selectedLibraryProvider and clean up unused variable ([c3db9fd](https://github.com/1525745393/EmbyTok-Flutter/commit/c3db9fdf63eba36588a704389f247d930063442f))


### Features

* save progress ([366a90b](https://github.com/1525745393/EmbyTok-Flutter/commit/366a90b62d9a09d7829feeee3716460c7bca566d))

# [1.54.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.53.0...v1.54.0) (2026-06-20)


### Features

* apply changes ([e84e44b](https://github.com/1525745393/EmbyTok-Flutter/commit/e84e44b4473938584f6c809ee1e66e4d611c12a1))
* sync latest updates ([6bdcbe4](https://github.com/1525745393/EmbyTok-Flutter/commit/6bdcbe4b7b97b0cd52a5a0596bb5993504bb1f8a))

# [1.53.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.52.0...v1.53.0) (2026-06-20)


### Features

* save progress ([b04e7ae](https://github.com/1525745393/EmbyTok-Flutter/commit/b04e7aed9c380efe27a03d7f60c414603c03a455))

# [1.52.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.51.0...v1.52.0) (2026-06-20)


### Features

* apply changes ([1cd1778](https://github.com/1525745393/EmbyTok-Flutter/commit/1cd177891910743d2359a7110d9d2a58f9f72d7c))
* save progress ([c41f8e4](https://github.com/1525745393/EmbyTok-Flutter/commit/c41f8e4a9e458acf87186a99dd9c9ffbdf43e2aa))

# [1.51.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.50.0...v1.51.0) (2026-06-20)


### Features

* update workspace ([7795c9f](https://github.com/1525745393/EmbyTok-Flutter/commit/7795c9fbad7bc0720aa3c1a06dd05cc7db37e9f8))

# [1.50.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.49.0...v1.50.0) (2026-06-20)


### Features

* apply changes ([2f0032f](https://github.com/1525745393/EmbyTok-Flutter/commit/2f0032f4315b08a2d1445f5c64e7717f6d528eff))

# [1.49.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.48.0...v1.49.0) (2026-06-20)


### Features

* update workspace ([5789d6e](https://github.com/1525745393/EmbyTok-Flutter/commit/5789d6ede02202928b616b3519ec571f137196c2))

# [1.48.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.47.0...v1.48.0) (2026-06-20)


### Features

* apply changes ([e55b656](https://github.com/1525745393/EmbyTok-Flutter/commit/e55b656fd11b92edeba0ccd8f24d5565a1439aae))

# [1.47.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.46.0...v1.47.0) (2026-06-20)


### Features

* update workspace ([15565a6](https://github.com/1525745393/EmbyTok-Flutter/commit/15565a650b04dcecc3eb7f14197862301d9d740d))

# [1.46.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.45.0...v1.46.0) (2026-06-20)


### Features

* sync latest updates ([0b3038a](https://github.com/1525745393/EmbyTok-Flutter/commit/0b3038a35c76e9819a9a5661329cb957fb884035))

# [1.45.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.44.0...v1.45.0) (2026-06-20)


### Features

* save progress ([e1ee34f](https://github.com/1525745393/EmbyTok-Flutter/commit/e1ee34f61a914756cc136ac45d8c06a630860016))

# [1.44.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.43.1...v1.44.0) (2026-06-20)


### Bug Fixes

* remove undefined 'name' parameter from MediaItem constructor in app.dart ([03fbaa8](https://github.com/1525745393/EmbyTok-Flutter/commit/03fbaa871258ab83aa210bd112d9e6657db8ad01))
* remove vc. prefix for responsiveSize in video_page_item.dart ([2024cce](https://github.com/1525745393/EmbyTok-Flutter/commit/2024cce61955e16a8327a1e1cf26bd2caeda3f8c))
* resolve widget import aliases and null safety in video_page_item.dart ([75ac966](https://github.com/1525745393/EmbyTok-Flutter/commit/75ac966512574eed69c30dfa66d7f50536be2184))


### Features

* apply changes ([72dbf64](https://github.com/1525745393/EmbyTok-Flutter/commit/72dbf641e59901ef605ab8ef86675273cfd94ca5))

## [1.43.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.43.0...v1.43.1) (2026-06-20)


### Bug Fixes

* resolve compile errors in search_view and heart_animation ([fdbd6b3](https://github.com/1525745393/EmbyTok-Flutter/commit/fdbd6b345ac37fbe926cde7c60cc0e955888022b))

# [1.43.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.42.0...v1.43.0) (2026-06-20)


### Features

* subtitle_selector / video_player_widget / poster_grid_view 主题化迁移 ([9c3c02e](https://github.com/1525745393/EmbyTok-Flutter/commit/9c3c02ec1d54d23c0974442b3026c0b31fc461c3))

# [1.42.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.41.0...v1.42.0) (2026-06-20)


### Bug Fixes

* _SectionLabel 添加 color 命名参数，修复编译错误 ([651c328](https://github.com/1525745393/EmbyTok-Flutter/commit/651c32874b011887b11dda6e426cc34fc4eb5f20))


### Features

* save progress ([0885f73](https://github.com/1525745393/EmbyTok-Flutter/commit/0885f73673bc353463485f3e89c3461e56109439))
* update workspace ([4bdb031](https://github.com/1525745393/EmbyTok-Flutter/commit/4bdb031a7b3e46ad101cb26ffa2bdb6d872ba5f5))

# [1.41.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.40.2...v1.41.0) (2026-06-20)


### Features

* 引入 Material Design 3 动态色彩系统（阶段1：主题框架搭建） ([aacb218](https://github.com/1525745393/EmbyTok-Flutter/commit/aacb2185cdc280fa1ac0af4488a3e380dd7640d7))

## [1.40.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.40.1...v1.40.2) (2026-06-20)


### Bug Fixes

* 代码清理 - 移除多余断言操作符，修正 Riverpod read/watch 用法 ([b6ca2e8](https://github.com/1525745393/EmbyTok-Flutter/commit/b6ca2e848de67c96b9f90ceecba66d374c299928))


### Reverts

* 回退到 CI 成功状态（80648fa），回退期间引入编译错误的变更 ([99def38](https://github.com/1525745393/EmbyTok-Flutter/commit/99def3865549c7f924a4f73886fb959eaef5cf46))

# [1.39.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.38.0...v1.39.0) (2026-06-19)


### Features

* **clean-mode:** 连播模式浮层按钮移至屏幕右下角 ([4f3a9b5](https://github.com/1525745393/EmbyTok-Flutter/commit/4f3a9b53283b244712d6aacd56583dbf39637138))

# [1.38.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.37.0...v1.38.0) (2026-06-19)


### Features

* **player:** 完善播放控制与底部信息条 + 右侧操作区整理 ([d440a10](https://github.com/1525745393/EmbyTok-Flutter/commit/d440a106987bd353b205f088a02e3b52eaaf916a))
* sync latest updates ([567a81b](https://github.com/1525745393/EmbyTok-Flutter/commit/567a81beb0b4a1b836215bf1097ca8de3ed44037))

# [1.37.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.36.0...v1.37.0) (2026-06-19)


### Features

* **ui:** 底部信息条添加可拖拽进度条，支持点击和滑动跳转 ([f0b66e7](https://github.com/1525745393/EmbyTok-Flutter/commit/f0b66e76c1b77efb2af4926cd98745388c43e096))

# [1.36.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.35.0...v1.36.0) (2026-06-19)


### Features

* apply changes ([e7a4d01](https://github.com/1525745393/EmbyTok-Flutter/commit/e7a4d0175cdd09c91d066b28e08e856cc3785217))

# [1.35.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.34.0...v1.35.0) (2026-06-19)


### Features

* save progress ([cae7103](https://github.com/1525745393/EmbyTok-Flutter/commit/cae7103276a1c29949dba3b8e40462e261803244))

# [1.34.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.33.0...v1.34.0) (2026-06-19)


### Features

* sync latest updates ([d2905bb](https://github.com/1525745393/EmbyTok-Flutter/commit/d2905bbf3d6d4835e30e30ab26a33a3cda51dee3))
* **ui:** 右侧操作区按钮图标化，移除文字标签 ([ff46c2e](https://github.com/1525745393/EmbyTok-Flutter/commit/ff46c2ec83b3f6d27c41b09a7183bd36b0c0507c))

# [1.33.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.32.0...v1.33.0) (2026-06-19)


### Features

* update workspace ([a29caff](https://github.com/1525745393/EmbyTok-Flutter/commit/a29caffd12f13bef1ee4cca5aea81624ad5038d0))

# [1.32.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.31.0...v1.32.0) (2026-06-19)


### Features

* update workspace ([7edfc09](https://github.com/1525745393/EmbyTok-Flutter/commit/7edfc09a1e5496f031221a17fd2e96d534ccd579))
* 右侧操作区响应式布局，适配移动端和桌面端 ([fcd97b2](https://github.com/1525745393/EmbyTok-Flutter/commit/fcd97b22a27b7af811a06bb7b8da8e07240f857a))

# [1.31.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.30.0...v1.31.0) (2026-06-19)


### Features

* **video:** 底部信息条显示评分 ([023d429](https://github.com/1525745393/EmbyTok-Flutter/commit/023d42920cc5688b338f5160eccff091acf96964))

# [1.30.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.29.0...v1.30.0) (2026-06-19)


### Features

* sync latest updates ([628c597](https://github.com/1525745393/EmbyTok-Flutter/commit/628c597a1daef81986c791b03d1cb7cdca0b521b))

# [1.29.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.28.5...v1.29.0) (2026-06-19)


### Bug Fixes

* **ci:** 替换 withValues() 为 withOpacity() 以兼容 Flutter 3.10+ ([22348bc](https://github.com/1525745393/EmbyTok-Flutter/commit/22348bc64a214b8aafc0cd1bb8c49ec4112eccf1))


### Features

* sync latest updates ([2e0b9e5](https://github.com/1525745393/EmbyTok-Flutter/commit/2e0b9e54f70e97bb577ace0a44de184b93ecfeb3))

## [1.28.5](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.28.4...v1.28.5) (2026-06-19)


### Bug Fixes

* **memory:** 修复 OOM 内存溢出问题 - 优化图片缓存限制、controller 生命周期管理和预加载策略 ([793c2e7](https://github.com/1525745393/EmbyTok-Flutter/commit/793c2e7e1161f8b718ae6f81d30436b17be97771))

## [1.28.4](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.28.3...v1.28.4) (2026-06-19)


### Bug Fixes

* **ci:** flutter analyze 只要有 info/warning 就会返回 exit code 1，改用 grep 检查 error • 级别问题来判断是否阻断发布 ([03af6d7](https://github.com/1525745393/EmbyTok-Flutter/commit/03af6d74c4abb034601b4b838e276037153fcb71))
* **ci:** verifyConditionsCmd 仅检查 lib/ 目录，测试文件错误不影响 Android 发布 ([fde1800](https://github.com/1525745393/EmbyTok-Flutter/commit/fde1800ec4be7512dcbef8e44293e55fdf0c5d6a))
* **ci:** 修复 flutter analyze 错误检测失效，移除无效的 grep 过滤，直接依赖 flutter analyze 退出码 ([0dde09b](https://github.com/1525745393/EmbyTok-Flutter/commit/0dde09b78435da8febe14ab664cfbfc6dfd94d80))

## [1.28.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.28.2...v1.28.3) (2026-06-19)


### Bug Fixes

* **ci:** 修复 video_page_item.dart 第 1248 行 imageUrl 调用语法错误，将位置参数改为命名参数 primaryUrl ([b34d7f1](https://github.com/1525745393/EmbyTok-Flutter/commit/b34d7f1f8039c8da1a908a68fcb78034a10e2e38))

## [1.28.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.28.1...v1.28.2) (2026-06-19)


### Bug Fixes

* **ci:** 简化 Android 构建命令，移除 universal APK 构建和多余的文件验证步骤，恢复到 v1.25.1 的稳定工作流程 ([172466e](https://github.com/1525745393/EmbyTok-Flutter/commit/172466e0b82c3714c41be6f782b3bf29850f1762))

## [1.28.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.28.0...v1.28.1) (2026-06-19)


### Bug Fixes

* **ci:** 修复 Android 发布脚本，移除 -u 选项避免未定义变量报错 ([f3a6e1d](https://github.com/1525745393/EmbyTok-Flutter/commit/f3a6e1dc3b33e1d7a97975895fd5a38393adab06))

# [1.28.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.27.2...v1.28.0) (2026-06-19)


### Features

* update workspace ([bb00cfb](https://github.com/1525745393/EmbyTok-Flutter/commit/bb00cfb85129ba80510854c0d9a184b1a10bf602))

## [1.27.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.27.1...v1.27.2) (2026-06-19)


### Bug Fixes

* **ci:** 简化 Android 发布脚本，修复 Release [#124](https://github.com/1525745393/EmbyTok-Flutter/issues/124) 失败 ([c4c9d20](https://github.com/1525745393/EmbyTok-Flutter/commit/c4c9d2075c62afb156016233218009f9457eabd8))

## [1.27.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.27.0...v1.27.1) (2026-06-19)


### Bug Fixes

* **ci:** 修复 Android 自动发布缺少通用 APK 的问题 ([bffc827](https://github.com/1525745393/EmbyTok-Flutter/commit/bffc827c1273281b821d4d737d66add8165e5472))

# [1.27.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.26.0...v1.27.0) (2026-06-19)


### Features

* 演员头像按钮（TikTok 风格） ([a23e14f](https://github.com/1525745393/EmbyTok-Flutter/commit/a23e14fce72df43d8ab0b9f5c0a07d8144387c83))

# [1.26.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.25.1...v1.26.0) (2026-06-19)


### Features

* 唱片静音按钮添加视频封面图 ([fb0159b](https://github.com/1525745393/EmbyTok-Flutter/commit/fb0159ba4bfbeecdbc136058c2989490a99db014))
* 检查 EmbyX 对接 Emby 服务器 ([4a579a9](https://github.com/1525745393/EmbyTok-Flutter/commit/4a579a90f8aff7ebec6c9dcfbaa4a6fbcce6a2b9))

## [1.25.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.25.0...v1.25.1) (2026-06-19)


### Bug Fixes

* 播放模式切换和唱片按钮功能修复 ([bb73485](https://github.com/1525745393/EmbyTok-Flutter/commit/bb73485f624b7624ef087608fc256ecabfdd3671))

# [1.25.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.24.0...v1.25.0) (2026-06-19)


### Features

* 右侧操作栏与 React 版 EmbyTok 对齐 ([28d5601](https://github.com/1525745393/EmbyTok-Flutter/commit/28d5601fc29d81a0cac5242422d874bfa3ce8c22))

# [1.24.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.23.1...v1.24.0) (2026-06-19)


### Features

* 纯净模式下连播开关和倍速按钮支持拖动调整位置 ([bf935a4](https://github.com/1525745393/EmbyTok-Flutter/commit/bf935a4be616f4254a6ceff842bb60a8a313a560))

## [1.23.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.23.0...v1.23.1) (2026-06-19)


### Bug Fixes

* 纯净模式下保留连播开关和倍速按钮，确保用户可关闭连播模式 ([a2b6499](https://github.com/1525745393/EmbyTok-Flutter/commit/a2b64991528bf469300583f670777e72059756a9))

# [1.23.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.22.0...v1.23.0) (2026-06-19)


### Features

* 检查 EmbyX 对接 Emby 服务器 ([b6c677f](https://github.com/1525745393/EmbyTok-Flutter/commit/b6c677f4cdea0aed2564e4efaf461665b3bd1e61))

# [1.22.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.21.1...v1.22.0) (2026-06-19)


### Features

* 检查 EmbyX 对接 Emby 服务器 ([280df9f](https://github.com/1525745393/EmbyTok-Flutter/commit/280df9f78572e6ef10399a1aba33f5b8ccdbe5c1))

## [1.21.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.21.0...v1.21.1) (2026-06-19)


### Bug Fixes

* 修复 embbytok_service.dart 空安全错误 ([854738a](https://github.com/1525745393/EmbyTok-Flutter/commit/854738a380f9ea807fe05397eb37e16dcae92e9a))

# [1.21.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.20.3...v1.21.0) (2026-06-19)


### Features

* 检查 EmbyX 对接 Emby 服务器 ([c7cda25](https://github.com/1525745393/EmbyTok-Flutter/commit/c7cda2551fe1aa0b3a0371c2a48d00e63c0cbaff))

## [1.20.3](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.20.2...v1.20.3) (2026-06-19)


### Bug Fixes

* **embyx:** 修复媒体库和点赞功能的多用户数据隔离问题 ([85bf33b](https://github.com/1525745393/EmbyTok-Flutter/commit/85bf33bea1ebd6708b92fc5ca775fa24ca8dafde))

## [1.20.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.20.1...v1.20.2) (2026-06-19)


### Bug Fixes

* **ci:** 统一 flutter analyze 过滤规则与 semantic-release 保持一致 ([2cd172f](https://github.com/1525745393/EmbyTok-Flutter/commit/2cd172fd1ae95569a2a1b61b8844d5ef8265d268))

## [1.20.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.20.0...v1.20.1) (2026-06-19)


### Bug Fixes

* **flutter:** 移除 item_detail_provider.dart 中 getNextUp 的错误 userId 参数 ([a753d40](https://github.com/1525745393/EmbyTok-Flutter/commit/a753d40104a98393c65c6fbcc83b5b063670b5fa))

# [1.20.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.19.0...v1.20.0) (2026-06-19)


### Features

* 检查 EmbyX 对接 Emby 服务器 ([5e6cee7](https://github.com/1525745393/EmbyTok-Flutter/commit/5e6cee724f423d6d3d9ed77d478c57e3fa4ae280))
* 检查 EmbyX 对接 Emby 服务器 ([cfe8143](https://github.com/1525745393/EmbyTok-Flutter/commit/cfe8143ac6ddadd32d2f1766f3bb5aa1e28eced0))

# [1.19.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.18.0...v1.19.0) (2026-06-19)


### Bug Fixes

* **flutter:** 修复 CI 构建错误 ([515bff6](https://github.com/1525745393/EmbyTok-Flutter/commit/515bff62a9676732d6dd7e159409027a72717c79))
* **flutter:** 添加 subtitle_widget.dart 的 SubtitleCue 导入 ([94c250a](https://github.com/1525745393/EmbyTok-Flutter/commit/94c250a157877151a19971fd628b59160f039105))
* **release:** 修复 semantic-release verifyConditions 对 flutter analyze warning 的误判 ([6e186a3](https://github.com/1525745393/EmbyTok-Flutter/commit/6e186a327eeac2da8cd05a821458a757b5565624))


### Features

* 检查 EmbyX 对接 Emby 服务器 ([1bc2421](https://github.com/1525745393/EmbyTok-Flutter/commit/1bc24210569a22f2a0d2195cdc1cd9e976388dd1))
* 检查 EmbyX 对接 Emby 服务器 ([c365187](https://github.com/1525745393/EmbyTok-Flutter/commit/c365187823a551f2a06c120897d29b63171f935e))
* 检查 EmbyX 对接 Emby 服务器 ([7f34da7](https://github.com/1525745393/EmbyTok-Flutter/commit/7f34da735c0d5bed2ec5c4f52518ebeb80ba862c))
* 检查 EmbyX 对接 Emby 服务器 ([b03e86a](https://github.com/1525745393/EmbyTok-Flutter/commit/b03e86a2648b40f3cbb1ecf06ab6c594524d4a0e))
* 检查 EmbyX 对接 Emby 服务器 ([c68c0d2](https://github.com/1525745393/EmbyTok-Flutter/commit/c68c0d2268791813b9ad7c18241b8b45896269af))
* 检查 EmbyX 对接 Emby 服务器 ([7793016](https://github.com/1525745393/EmbyTok-Flutter/commit/7793016be791327dfb383ae9f4cfb67b492db3fc))
* 检查 EmbyX 对接 Emby 服务器 ([b89b4b2](https://github.com/1525745393/EmbyTok-Flutter/commit/b89b4b24fb4d098cb6f719e14944ba1e6b20384b))
* 检查 EmbyX 对接 Emby 服务器 ([fde2a33](https://github.com/1525745393/EmbyTok-Flutter/commit/fde2a3397d319b88379f1f5351a77fa16621fee2))
* 检查 EmbyX 对接 Emby 服务器 ([b95d706](https://github.com/1525745393/EmbyTok-Flutter/commit/b95d70650229fb986ccad3cf862343dd5ee4d5c0))
* 检查 EmbyX 对接 Emby 服务器 ([6aaadfd](https://github.com/1525745393/EmbyTok-Flutter/commit/6aaadfd7f377360fddfb999fe9dbc61332e3d70c))
* 检查 EmbyX 对接 Emby 服务器 ([d0ac681](https://github.com/1525745393/EmbyTok-Flutter/commit/d0ac681c7f78e58fdd99fcf7c010eef1d35ce42b))
* 检查 EmbyX 对接 Emby 服务器 ([d582cd1](https://github.com/1525745393/EmbyTok-Flutter/commit/d582cd14a273e231366659d51679bcce7f9dc22a))
* 检查 EmbyX 对接 Emby 服务器 ([c84bac2](https://github.com/1525745393/EmbyTok-Flutter/commit/c84bac20a3e4e0b05e5ad2325cdf83fd8ce2f9ef))

# [1.13.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.12.0...v1.13.0) (2026-06-18)


### Features

* 生成项目仓库Code Wiki文档 ([69bf86a](https://github.com/1525745393/EmbyTok-Flutter/commit/69bf86aea1564ee3d3de2a08b0da2eb896ee1c37))
* 生成项目仓库Code Wiki文档 ([bcb1fe9](https://github.com/1525745393/EmbyTok-Flutter/commit/bcb1fe9fc8975d8050b611690e2096e7237acb40))

# [1.13.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.12.0...v1.13.0) (2026-06-18)


### Features

* 生成项目仓库Code Wiki文档 ([69bf86a](https://github.com/1525745393/EmbyTok-Flutter/commit/69bf86aea1564ee3d3de2a08b0da2eb896ee1c37))
* 生成项目仓库Code Wiki文档 ([bcb1fe9](https://github.com/1525745393/EmbyTok-Flutter/commit/bcb1fe9fc8975d8050b611690e2096e7237acb40))

# [1.12.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.11.0...v1.12.0) (2026-06-17)


### Bug Fixes

* 修复 AppLogger.debug 调用使用未定义的 error 参数 ([e6b243f](https://github.com/1525745393/EmbyTok-Flutter/commit/e6b243fa092ef5b1abc6f3de28dd5c31d3317778))


### Features

* 生成项目仓库Code Wiki文档 ([17e877a](https://github.com/1525745393/EmbyTok-Flutter/commit/17e877aa0c371aa691763d106987d74b4772fbad))
* 生成项目仓库Code Wiki文档 ([1b3dbb4](https://github.com/1525745393/EmbyTok-Flutter/commit/1b3dbb479b0a12cd132b8eaef95f13963f1a637b))

# [1.11.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.10.0...v1.11.0) (2026-06-17)


### Features

* 生成项目仓库Code Wiki文档 ([2edd4b1](https://github.com/1525745393/EmbyTok-Flutter/commit/2edd4b184ddabe70cee2684ec003d9ca3d859b01))

# [1.10.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.9.0...v1.10.0) (2026-06-17)


### Features

* 生成项目仓库Code Wiki文档 ([353286c](https://github.com/1525745393/EmbyTok-Flutter/commit/353286c0e0b6ed89abfd81790005cfef4dba6033))

# [1.9.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.8.2...v1.9.0) (2026-06-17)


### Bug Fixes

* 修复 ViewMode 命名冲突和缺失 provider 导出问题 ([c794a37](https://github.com/1525745393/EmbyTok-Flutter/commit/c794a376166cf94a0f8314481d6dcd8ab8d103ea))
* 恢复 video_grid_view 和 top_tool_bar 的 ViewMode 显式 import ([901b701](https://github.com/1525745393/EmbyTok-Flutter/commit/901b701ced972a90f496f2d1168e1cf8e8e7b74e))


### Features

* 添加键盘快捷键系统、视图切换、媒体库选择器和 PWA 优化 ([81f2c61](https://github.com/1525745393/EmbyTok-Flutter/commit/81f2c610082f838c3f069f48fcb29aa59d5f15da))

## [1.8.2](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.8.1...v1.8.2) (2026-06-16)


### Bug Fixes

* VideoPlayerWidget 添加 preloadedController 参数支持，修复 CI 静态分析错误 ([1f94a13](https://github.com/1525745393/EmbyTok-Flutter/commit/1f94a136ed31e499e7856154e84f8347de760545))
* 拖动进度条闪退修复 - 仅在松手后调用 seekTo，避免高频调用 MediaCodec 崩溃 ([3678a9f](https://github.com/1525745393/EmbyTok-Flutter/commit/3678a9fdc3cb0c8c2e9899e5291f3b406c1fbc5c))

## [1.8.1](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.8.0...v1.8.1) (2026-06-16)


### Bug Fixes

* build.gradle 显式从 pubspec.yaml 解析 versionCode/versionName，不依赖 Flutter Gradle 插件的自动注入 ([7076b12](https://github.com/1525745393/EmbyTok-Flutter/commit/7076b12ee53e4bce817e911f99aa044f0ed75b28))

# [1.8.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.7.0...v1.8.0) (2026-06-16)


### Bug Fixes

* lodash 模板解析错误，$BUILD_NUM 改为不带大括号避免与 ${...} 模板冲突 ([ce0ce71](https://github.com/1525745393/EmbyTok-Flutter/commit/ce0ce713689eb1550832c44e5a2f8c5355c4185e))


### Features

* 生成项目仓库Code Wiki文档 ([73ed4b7](https://github.com/1525745393/EmbyTok-Flutter/commit/73ed4b7b9ff334b331b95c95f1f02d5943cacf01))

# [1.7.0](https://github.com/1525745393/EmbyTok-Flutter/compare/v1.6.0...v1.7.0) (2026-06-16)


### Features

* 生成项目仓库Code Wiki文档 ([030fdc8](https://github.com/1525745393/EmbyTok-Flutter/commit/030fdc825bd5699a945f5c81adc452c5bb09cb89))
* 生成项目仓库Code Wiki文档 ([4bf0ca1](https://github.com/1525745393/EmbyTok-Flutter/commit/4bf0ca144c9441a7c7d69fd0a069202ed9eb0732))

# Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 语义化版本规范。

---

## [1.6.0] - 2026-06-17

### 新增

- **沉浸式交互设计**：在视频流播放模式下，顶部工具栏和底部导航栏跟随手势平滑折叠/展开，滑动切换视频时 200ms `AnimatedContainer` 动画自动隐藏，下滑或点击画面重新显示；全局 `toolbarVisibilityProvider` 统一管理状态，跨组件动画同步
- **沉浸式系统 UI 模式**：横屏全屏播放时，系统状态栏和导航栏自动隐藏（`SystemUiMode.immersiveSticky`），应用页面延伸到屏幕边缘，与 `SafeArea` 动态适配 notch 和手势条；退出全屏恢复 `edgeToEdge` 模式
- **响应式设计（半透明叠加）**：手机竖屏模式下视频内容 `Positioned.fill` 全屏展示，工具栏和导航栏用 `LinearGradient`（`overlayBlack` → 透明）半透明叠加，不再"推挤"视频区；操作按钮和标题 padding 与工具栏可见性联动，隐藏时释放空间，展开时自适应
- **滑动进度控制**：水平拖动调整视频播放进度时，屏幕中上方显示半透明进度条浮层，包含方向图标（`⏩` 快进 / `⏪` 快退）、偏移量（`+12s` / `-45s`）、当前时间 / 总时长（`HH:MM:SS` / `MM:SS`）、可视化进度条（粉色填充 + 圆形发光指示器）；150ms 淡入，300ms 淡出，填充动画 `easeOut`，实时跟随手指移动
- **增强触觉反馈**：滑动进度控制起始 `selectionClick`，每跨越 5 秒再次 `selectionClick`，结束 `lightImpact`，形成完整的"操作—反馈"闭环
- **时间格式化工具**：新增 `_formatDuration(Duration)` 处理 `HH:MM:SS` 和 `MM:SS` 两种格式，< 1 小时自动省略小时位，零时长和负时长有安全处理
- **动画与尺寸常量**：`constants.dart` 新增 `kToolbarAnimMs` (200)、`kToolbarHeight` (56)、`kBottomNavHeight` (56)、`kProgressBarFadeInMs` (150)、`kProgressBarFadeOutMs` (300)、`kProgressBarAnimMs` (80)，统一动画参数，便于后续调参
- **颜色与样式常量**：`colors.dart` 新增 `overlayBlack = Color(0xAA000000)`（67% 不透明黑）和 `overlayBlackDeep = Color(0xCC000000)`（80% 不透明黑），用于半透明浮层

### 改进

- `toolbar_visibility_provider.dart`：新增 `StateNotifier<bool>` 全局管理工具栏/导航栏可见性，`show()` / `hide()` / `toggle()` 方法统一接口，避免多处直接操作 `setState`
- `feed_view.dart`：重构 Stack 布局为视频内容 `Positioned.fill` + 工具栏 `Positioned(top: 0)`，替代原先的列堆叠；新增 `_buildAnimatedToolBar()` 负责工具栏的渐变背景 + 折叠动画；`_onScroll()` 监听驱动工具栏状态切换；grid 视图通过 padding 避开工具栏保持可读性
- `home_scaffold.dart`：从 `Scaffold(bottomNavigationBar:)` 改为 `body: Stack(IndexedStack + Positioned)`，导航栏改为 `AnimatedContainer` + `AnimatedOpacity` 联动，非 feed 页面的 `Padding` 预留导航栏高度避免内容被遮挡
- `gesture_overlay.dart`：水平拖动处理完整重写，`_onHorizontalDragStart` 记录起始位置并触发 UI 状态更新，`_onHorizontalDragUpdate` 实时更新进度条，`_onHorizontalDragEnd` 淡出动画 + 延迟状态清理；新增私有 `_ProgressBarOverlay` 组件封装进度条 UI
- `video_page_item.dart`：底部标题区和右侧操作按钮的 `EdgeInsets` 改为条件式，根据 `toolbarVisibilityProvider` 状态动态调整，工具栏隐藏时释放 56px 竖向空间

### 设计原则

- 统一使用 Riverpod 管理动画状态，`toolbarVisibilityProvider` 单一数据源
- Flutter 原生动画（`AnimatedContainer` + `AnimatedOpacity` + `AnimatedContainer` 伸缩），无第三方依赖
- Stack 绝对定位布局让内容自然延伸到屏幕边缘，配合 `MediaQuery.padding` 适配 notch/动态岛/手势条
- 进度条浮层用 `IgnorePointer` 包裹，不影响手势识别
- 所有文字和图标样式与 `_SpeedBadge` 保持视觉一致性

---

## [1.5.0] - 2026-06-17

### 新增

- **视频切换过渡动画**：竖屏滑动切换视频时，新视频通过 `AnimatedOpacity` 200ms 渐入，消除"硬切"突兀感；冷启动第一条视频也有淡入效果
- **智能预加载**：当前视频播放进度达到 60% 时，自动预取下一条视频的 `VideoPlayerController`，切换后首帧时间 < 300ms；最多同时缓存 2 个预加载控制器，超出自动 dispose
- **错误边界与重试**：视频加载 8 秒超时自动触发重试机制，最多重试 3 次（间隔 1s/2s/3s）；失败时显示带重试按钮的错误卡片；空媒体库显示引导卡片
- **手势触觉反馈**：双击点赞触发 `HapticFeedback.lightImpact()`，长按倍速触发 `mediumImpact()`，水平拖动进度每跨越 5 秒触发 `selectionClick()`，提升交互手感
- **首次使用引导**：首次进入视频流页面时显示"上滑看下一条"文字 + 半透明箭头动画，滑动 3 次后自动淡出消失
- **颜色常量体系**：`colors.dart` 新增 `black54`、`black87`、`amberColor`，统一替换 `Colors.black54`/`Colors.grey[900]`/`Colors.amber` 等硬编码引用

### 改进

- `video_playback_controller.dart`：新增 `videoReadyProvider` 跟踪每个视频的初始化就绪状态，精确驱动渐入动画
- `preload_controller.dart`：新增 `PreloadNotifier` 管理预加载缓存，通过 `currentPlayingIndexProvider` 与 `preloadThresholdProvider` 解耦预加载逻辑
- `feed_view.dart`：接入 `_onPositionUpdate` 播放进度监听、预加载缓存 consume、onPageChanged 引导计数，完整打通视频流体验链路
- `gesture_overlay.dart`：整合 haptic 反馈调用 + 300ms 单/双击区分 + 400ms 双击防抖，手势响应即时且有触感

### 性能优化

- 视频切换的 Flutter 重建开销 < 16ms（60fps 单帧），中低端安卓机型无明显卡顿
- 预加载缓存限制在 2 个控制器，避免内存无限增长
- 颜色值统一使用常量引用，减少 Flutter 颜色对象重建

---

## [1.4.0] - 2026-06-15

### 新增

- **三栏收藏页面**：按类型展示「收藏影片」「收藏合集」「收藏人物」三个横向滚动卡片列表，与 Emby 官方 App 风格一致
- **合集详情页**：海报 + 简介 + 包含的影片列表，点击跳转到播放页
- **人员作品页**：头像 + 简介 + 出演作品列表，点击跳转到播放页

### 改进

- `EmbytokService` 新增 `getFavoriteMovies` / `getFavoriteBoxSets` / `getFavoritePeople` 三个方法，按 `IncludeItemTypes` 精准过滤收藏数据
- `favorites_provider.dart` 重构：`FavoritesState` 支持三组独立列表，`Future.wait` 并行加载；合并的 `favoriteIds` Set 供视频页快速判断收藏状态
- 保留双击切换收藏 + 红心动画交互，乐观更新 UI + 失败回滚

### 修复

- 收藏状态跨账号隔离：登出时清空缓存，新账号登录后自动拉取自己的收藏数据

---

## [1.3.3] - 2026-06-15

### 新增

- **收藏功能**：双击视频画面即可收藏/取消收藏，伴随红心动画（放大淡出 700ms）
- **我的收藏页**：独立的收藏列表视图，显示收藏的视频卡片、类型标签、时长、简介
- **右侧操作按钮**：点赞（心形图标）+ 收藏（星形图标）按钮，点击有缩放动画，状态与 `favoritesProvider` 响应式同步
- **手势交互层**：单击播放/暂停、双击收藏、长按 2x 倍速、水平拖动快进/快退（300ms 区分单/双击，400ms 双击防抖防重复请求）

### 改进

- `favorites_provider.dart`：重构为完整的 `StateNotifier` 状态管理器
  - 自动监听 `authProvider`：登录后自动拉取收藏，登出/切换账号自动清理缓存
  - `_pendingToggles` 去重：同一 item 并发点击只发送一次网络请求
  - 乐观更新 + 失败回滚：UI 即时反馈 + 数据最终一致
  - `ensureLoaded()` / `reset()` 幂等辅助方法
- `video_page_item.dart`：`favorited` 状态改为 `ref.watch(favoritesProvider)` 响应式读取，任何来源的状态变化都立即反映到 UI

### 修复

- **CI - 导入路径错误**：`favorites_view.dart` 中 `import 'video_page_item.dart'` → `import '../widgets/video_page_item.dart'`（`uri_does_not_exist` / `undefined_method: VideoPageItem`）
- **CI - API 名称**：`gesture_overlay.dart` 中 `setPlaybackRate` 改为 `video_player` 包正确方法 `setPlaybackSpeed`（2 处 `undefined_method`）

---

## [1.3.2] - 2026-06-15

### 修复

- `Color.withValues` 兼容性问题：Flutter 3.22+ 特有 API 在 CI 环境中导致 `undefined_method` 编译错误，已替换为稳定的 `Color.withOpacity()` API
- `_parsePaginatedResponse` 方法类型安全增强：空列表字面量 `const []` 改为 `const <MediaItem>[]`，明确泛型类型避免类型推断歧义
- `library_provider.dart` Provider 声明顺序优化：将 `libraryListProvider` 移到文件顶部，`selectedLibraryIdProvider` / `selectedLibraryProvider` 放在底部，使依赖声明顺序更清晰

### 改进

- `top_tool_bar.dart` 移除未使用的 `import 'package:flutter_riverpod/flutter_riverpod.dart'`（如适用）
- `embbytok_service.dart` 添加显式泛型类型参数，提升强类型一致性

---

## [1.3.1] - 2026-06-15

### 修复

- Flutter 静态分析错误：`VideoPlayerWidget.createState` 返回类型改为 `ConsumerState<VideoPlayerWidget>`
- `providers.dart` 添加 `app_preferences_providers` 导出，修复 `viewModeProvider` / `feedTypeProvider` / `orientationModeProvider` 未定义问题
- `FullscreenCallback` 类型匹配修复
- 移除 `feed_view.dart` 中未使用的 `_selectLibrary` 方法和 `_buildLibraryChips` 元素
- 移除 `top_tool_bar.dart` 中未使用的 `FeedType` 导入

---

## [1.3.0] - 2026-06-15

### 新增

- **视频流 / 网格视图切换**：顶部工具栏一键切换视频流与网格浏览模式
- **方向过滤**：支持只看竖屏 / 只看横屏 / 全部三种过滤模式
- **全屏播放模式**：横屏旋转 + 隐藏系统 UI 的沉浸式观看体验
- **视频方向自适应**：横屏视频以 `BoxFit.contain` + 海报背景显示，竖屏视频以 `BoxFit.cover` 全屏填充
- **网格视图卡片**：显示封面图、标题、时长和播放进度条

### 修改

- `TopToolBar` 顶部工具栏新增方向过滤、视图切换、全屏、静音按钮
- `VideoGridView` 网格视图支持 2 列（竖屏）/ 4 列（横屏）自适应布局
- `FeedView` 添加视图模式切换和 `filteredVideoListProvider` 过滤列表支持
- `MediaItem` / `MediaSource` 模型添加 `isLandscape` / `isPortrait` 方向判断属性
- `video_list_provider.dart` 新增 `filteredVideoListProvider` 派生 provider，基于 `OrientationMode` 对视频列表进行实时过滤
- `video_player_widget.dart` 实现 `_buildVideoWithAdaptiveFit()` 方向自适应显示逻辑

### 关联文件

- `frontend/lib/views/video_grid_view.dart`
- `frontend/lib/widgets/video_grid_card.dart`
- `frontend/lib/widgets/top_tool_bar.dart`
- `frontend/lib/views/feed_view.dart`
- `frontend/lib/providers/video_list_provider.dart`
- `frontend/lib/widgets/video_player_widget.dart`
- `frontend/lib/models/media_item.dart`
- `frontend/lib/models/media_source.dart`

---

## [1.2.8] - 2026-06-15

### 新增
- 结构化日志系统（AppLogger）：支持 INFO/DEBUG/WARN/ERROR 四个日志级别
- 视频流降级策略：主 URL 失败时自动切换到 Emby 原生 API
- 敏感信息过滤：日志自动过滤 token、password、secret 等敏感字段

### 功能
- 认证流程日志：登录/登出/Token 恢复全程可追踪
- 媒体库日志：视频列表加载状态实时记录
- 视频播放器日志：播放初始化、状态变化、错误信息完整记录
- 搜索收藏日志：搜索请求、收藏操作状态记录
- EmbytokService 日志：HTTP 请求/响应完整记录

---

## [1.2.7] - 2026-06-15

### 修复
- 视频播放认证问题：Emby API 不返回 playbackUrl，添加 `computePlaybackUrl()` 动态构造播放 URL
- 图片加载认证问题：所有图片加载组件添加 `api_key` 认证参数
- UI 缩略图修复：修复搜索/收藏/历史页面的缩略图加载问题

### 新增
- `VideoPlayerWidget` 支持 `embyServerUrl` 和 `token` 参数
- `MediaItem` 新增 `authHeaders()` 和 `thumbnailUrlWithAuth()` 方法

---

## [1.2.5] - 2026-06-15

### 新增
- 发布流程脚本系统（release.sh / verify-release.sh / rollback-release.sh）
- 版本号统一管理文件（version.dart / version.py）
- CI 构建安全增强（keystore 文件权限设置）

### 修复
- 发布脚本跨平台兼容性（macOS/Linux sed 语法差异）
- Git 提交安全性（精确文件列表替代 `git add -A`）
- 回滚脚本错误消息语义清晰化
- 后端 API 版本号动态导入（从 version.py 读取，而非硬编码）

---

## [1.1.7] - 2026-06-15

### 新增
- 发布流程脚本系统（release.sh / verify-release.sh / rollback-release.sh）
- 版本号统一管理文件（version.dart / version.py）
- CI 构建安全增强（keystore 文件权限设置）

### 修复
- 发布脚本跨平台兼容性（macOS/Linux sed 语法差异）
- Git 提交安全性（精确文件列表替代 `git add -A`）
- 回滚脚本错误消息语义清晰化

---

## [1.1.3] - 2025-06-14

### 新增
- `scripts/release.sh` - 自动化版本发布脚本，支持 patch/minor/major 三种发布类型
- `scripts/rollback-release.sh` - 发布回滚脚本，支持 dry-run 预览模式
- `scripts/verify-release.sh` - 发布前版本一致性验证脚本
- `frontend/lib/utils/version.dart` - Flutter 版本信息常量文件
- `backend/core/version.py` - Python 后端版本信息常量文件

### 修复
- **跨平台兼容性**: `release.sh` 中实现 `sed_inplace()` 函数，根据 `uname -s` 自动检测操作系统，在 macOS (BSD sed) 和 Linux (GNU sed) 上正确执行就地编辑，之前硬编码的 `sed -i` 在 macOS 上会产生临时文件或错误
- **发布安全性**: `release.sh` 中将 `git add -A` 替换为精确文件列表 `git add frontend/pubspec.yaml frontend/android/app/build.gradle frontend/lib/utils/version.dart backend/core/version.py CHANGELOG.md`，防止意外提交未跟踪的敏感文件（如密钥、本地配置等）
- **命令健壮性**: `release.sh` 开头增加 `git`/`sed`/`grep`/`awk` 命令存在性预检查，缺失时输出中文错误消息并优雅退出，避免因命令不存在导致脚本中途失败
- **CI 构建安全**: GitHub Actions workflow 中 keystore 文件解码后立即设置 `chmod 600` 权限，仅允许拥有者读写，并在日志中输出权限验证结果
- **回滚消息修复**: `rollback-release.sh` 中将矛盾的"已存在或不存在"消息修正为清晰的"远程 tag 不存在，跳过"，使错误信息与实际分支判断逻辑一致

### 改进
- 同步 `frontend/android/app/build.gradle` 版本号（`versionName` 1.0.7 → 1.1.3，`versionCode` 7 → 13），与 `frontend/pubspec.yaml` 保持一致
- 所有发布脚本使用统一的颜色输出风格，增强可读性
- `release.sh` 支持 `--dry-run` 参数，在不实际修改任何文件的情况下预览发布流程
- `verify-release.sh` 检查项目中 4 个版本号位置（pubspec/build.gradle/version.dart/version.py）的一致性

---

## [1.1.2] - 历史版本

- EmbyTok Flutter 客户端基础架构
- 视频浏览、搜索、收藏功能实现

---

## [1.1.0] - 初始版本

- EmbyTok Flutter 应用首次发布
- 竖屏视频浏览体验
- 媒体库管理
- 用户偏好设置

---

## 版本号说明

- **MAJOR** 版本：API 不兼容的变更（在 commit message 中使用 `!` 标记，如 `feat!: 重构 API`）
- **MINOR** 版本：向下兼容的功能性新增（commit type 为 `feat`）
- **PATCH** 版本：向下兼容的问题修正（commit type 为 `fix`）

## 自动化发布流程

自 v1.7.0 起，发布流程完全自动化（GitHub Actions + Semantic Release）：

1. 开发者按 Conventional Commits 规范提交代码并 push 到 main 分支
2. GitHub Actions 自动触发 `android-release.yml` 工作流
3. Semantic Release 分析自上次发布以来的所有 commit，决定新版本号
4. 自动执行：`flutter analyze` → 更新 `pubspec.yaml` → 更新 `CHANGELOG.md` → 构建签名 APK/AAB → 提交版本变更 → 创建 Git Tag → 创建 GitHub Release 并上传 APK/AAB

### 提交规范示例

```
feat: 增加全屏播放模式        # 触发 minor 版本升级
fix: 解决滑动时的动画抖动       # 触发 patch 版本升级
feat!: 重构媒体库 API（破坏性）  # 触发 major 版本升级
docs: 更新 README               # 不触发版本升级
```

### 手动触发

如需立即触发一次发布检查：
- 打开 GitHub 仓库 → Actions → `Android Release` → `Run workflow`

### 发布失败排查

- **静态分析失败**：检查 `flutter analyze lib` 输出，修复后重新 push
- **无符合规范的 commit**：Semantic Release 找不到 `feat` 或 `fix` 类型的 commit 时不创建新版本（正常现象）
- **keystore 问题**：检查 GitHub Secrets 中 ANDROID_KEYSTORE 及密码是否配置正确
- **构建失败**：查看 Actions 的详细日志，定位到具体的 Gradle/Flutter 错误
