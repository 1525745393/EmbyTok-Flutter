# 测试体系建设建议 - 验证清单

## 当前测试状况确认
- [x] Flutter 测试文件共 47 个
- [x] models 目录 12 个测试
- [x] providers 目录 12 个测试
- [x] services 目录 5 个测试
- [x] widgets 目录 6 个测试
- [x] views 目录 5 个测试
- [x] utils 目录 3 个测试
- [x] repositories 目录 1 个测试
- [x] theme 目录 1 个测试
- [x] Python 后端测试缺失（backend/tests 不存在）
- [x] pytest.ini 不存在
- [x] flutter analyze 已集成到 Makefile lint 目标

## 测试建议优先级验证
- [x] high 优先级 4 个：MediaItem 解析、字幕解析、VideoList 竞态、收藏并发
- [x] medium 优先级 2 个：Auth 持久化、手势 Widget
- [x] low 优先级 1 个：集成测试

## 测试范围验证
- [x] 覆盖模型层（MediaItem、SubtitleTrack）
- [x] 覆盖 Provider 层（VideoList、Favorites、Auth）
- [x] 覆盖 Widget 层（GestureOverlay）
- [x] 覆盖集成测试（完整流程）
- [x] 覆盖边界情况（空文件、损坏数据、并发、竞态）
