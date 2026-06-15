# 修复计划：错误信息 HTML 解码

## 问题分析
截图显示的错误信息经过了 HTML 编码：
- 原始错误：`服务器错误：Exception of type 'SQLitePCL.pretty.SQLiteException' was thrown.`
- 显示错误：`服务器错误：Exception of type &#39;SQLitePCL.pretty.SQLiteException&#39; was thrown.`

`&#39;` 是 HTML 实体编码的单引号，客户端需要解码才能正确显示。

## 修复方案
1. 添加 HTML 实体解码工具函数
2. 在错误显示前对错误信息进行解码

## 修改文件
1. `lib/utils/formatters.dart` - 添加 HTML 解码函数
2. `lib/services/api_client.dart` - 在错误处理中解码 HTML 实体

## 实施步骤
1. 在 `formatters.dart` 中添加 `htmlDecode` 函数
2. 在 `api_client.dart` 的 `_handleError` 方法中使用解码函数
3. 测试确保错误信息正确显示

## 风险评估
- 低风险：仅添加工具函数和解码逻辑，不影响核心业务

## 优先级
高 - 影响用户体验，错误信息不可读