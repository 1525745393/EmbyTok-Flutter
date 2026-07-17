<!--
本模板依据 docs/code-review.md 制定。请如实填写，审查者将按第 7 节「合并准入清单」核对。
-->

## 变更说明
<!-- 改了什么 / 为什么 / 如何验证（必填） -->

## 变更类型
- [ ] feat（新功能）
- [ ] fix（Bug 修复）
- [ ] refactor（重构）
- [ ] perf（性能）
- [ ] docs（文档）
- [ ] test（测试）
- [ ] chore / ci / build（其他）
- scope（影响模块，如 `video-player` / `auth` / `backend`）：

## 自测验证（Author 勾选）
- [ ] `flutter analyze lib` 无 error
- [ ] `flutter test` 通过
- [ ] UI 改动已自测：暗色模式 / 手势 / 字幕（如适用）
- [ ] 后端改动已自测接口与统一错误格式（如适用）

## 作者自检（对照 docs/code-review.md 第 3 节）
- [ ] 颜色仅用 `ColorScheme`，无硬编码 hex
- [ ] 异步均 `try/catch`，错误以中文提示
- [ ] 空 / 错误 / 加载三态齐全
- [ ] 无散落魔法数字（使用设计令牌）
- [ ] 单文件 < 400 行，或已说明拆分理由

## 审查清单（Reviewer 勾选，合并前确认）
- [ ] 架构 / 状态管理合理（Riverpod 单一职责，未在 build 发起网络）
- [ ] 性能（资源释放、列表分页、交互防抖）
- [ ] 安全（CORS 非 `*`，密钥走 Secrets，输入已校验）
- [ ] 无障碍（点击目标 ≥44、对比度 WCAG AA）
- [ ] 严重级别：0 Blocker、0 未 waiver 的 Major
- [ ] 提交信息符合 COMMIT_CONVENTION.md，PR 描述完整

## 关联
<!-- Closes #issue 或 相关 PR -->
