// 硬编码颜色检测脚本（纯正则扫描，不依赖 package:analyzer）
//
// 为什么用正则而非 AST：
// - 颜色构造模式高度规则（Color(0x..) / Colors.xxx / Color.fromARGB / Color.fromRGBO），
//   正则可完全覆盖，无需引入 analyzer 重依赖，符合"不添加不必要依赖"原则。
// - CI 环境（GitHub Actions + Flutter SDK）可直接 `dart run` 运行本脚本；
//   本地无 Dart SDK 时，可用其他语言复现同样的正则逻辑做验证。
// - 精度限制：不做完整的字符串/注释语义分析，但通过对行内 `//` 做简单剥离，
//   已能正确处理绝大多数真实场景（含颜色示例的注释行不会被误报）。
//
// 用法：
//   dart run tool/lints/hardcoded_color_lint.dart            # 扫描默认 lib/
//   dart run tool/lints/hardcoded_color_lint.dart --path lib/ # 指定扫描路径
//
// 退出码：0 = 无违规；1 = 有违规

import 'dart:convert';
import 'dart:io';

/// 单条违规记录：文件路径、行号、列号、匹配到的文本
class Violation {
  final String filePath;
  final int line;
  final int column;
  final String matched;

  Violation(this.filePath, this.line, this.column, this.matched);
}

// ---- 正则模式 ----
// 为什么用 \b：要求 Color 是独立单词，避免误匹配 MyColor(0x..) / Colorful( 这类自定义标识符
// 为什么 0x 后只允许十六进制字符：Color(int) 构造器只接受 ARGB 整数字面量
final RegExp _colorHex = RegExp(r'\bColor\(0x[0-9A-Fa-f]+\)');
// Colors.xxx：捕获属性名，以便对 transparent 做白名单放行
final RegExp _colorsProp = RegExp(r'\bColors\.([A-Za-z_][A-Za-z0-9_]*)');
// Color.fromARGB(...)：匹配到第一个右括号；颜色参数均为字面量，不含嵌套括号
final RegExp _colorFromArgb = RegExp(r'\bColor\.fromARGB\([^)]*\)');
// Color.fromRGBO(...)
final RegExp _colorFromRgbo = RegExp(r'\bColor\.fromRGBO\([^)]*\)');

/// Colors.transparent 是合法的"无色"占位，不应视为硬编码颜色
const String _transparentAllowed = 'transparent';

void main(List<String> arguments) {
  final scanPath = _parseScanPath(arguments);
  exit(_run(scanPath));
}

/// 解析 --path 参数，未指定时默认扫描 lib/
String _parseScanPath(List<String> arguments) {
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--path' && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
  }
  return 'lib/';
}

/// 执行扫描，返回退出码（0=无违规，1=有违规）
int _run(String scanPath) {
  final dir = Directory(scanPath);
  if (!dir.existsSync()) {
    stderr.writeln('Error: scan path not found: $scanPath');
    return 1;
  }

  final allowlist = _loadAllowlist();
  // 显示路径统一用相对 CWD 的形式（如 lib/views/feed_view.dart），
  // 这样白名单的 lib/theme/ 前缀无论 scanPath 如何都能稳定匹配
  final cwd = Directory.current.absolute.path;
  final cwdRoot =
      cwd.endsWith(Platform.pathSeparator) ? cwd : '$cwd${Platform.pathSeparator}';

  final violations = <Violation>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;

    final absPath = entity.absolute.path;
    final displayPath = _relativeToCwd(absPath, cwdRoot);

    if (_isAllowlisted(displayPath, allowlist)) continue;

    violations.addAll(_scanFile(absPath, displayPath));
  }

  for (final v in violations) {
    print('HardcodedColor: ${v.filePath}:${v.line}:${v.column}  ${v.matched}');
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Found ${violations.length} hardcoded color(s).');
    return 1;
  }
  return 0;
}

/// 把绝对路径转成相对 CWD 的路径，便于阅读和白名单匹配
String _relativeToCwd(String absPath, String cwdRoot) {
  if (absPath.startsWith(cwdRoot)) return absPath.substring(cwdRoot.length);
  return absPath;
}

/// 加载白名单：优先读取脚本同目录的 hardcoded_color_allowlist.json；
/// 文件缺失或解析失败时回退到默认白名单 ["lib/theme/"]
List<String> _loadAllowlist() {
  const defaultAllowlist = ['lib/theme/'];
  try {
    final scriptDir = File(Platform.script.path).parent;
    final configFile = File('${scriptDir.path}/hardcoded_color_allowlist.json');
    if (!configFile.existsSync()) return defaultAllowlist;

    final raw = configFile.readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['allowlist'];
    if (list is! List) return defaultAllowlist;
    final typed = list.whereType<String>().toList();
    return typed.isEmpty ? defaultAllowlist : typed;
  } catch (_) {
    // 配置读取异常时不阻断流程，回退默认白名单
    return defaultAllowlist;
  }
}

/// 判断文件是否命中白名单（路径前缀匹配，如 "lib/theme/" 命中 lib/theme/ 下所有文件）
bool _isAllowlisted(String displayPath, List<String> allowlist) {
  for (final prefix in allowlist) {
    if (displayPath.startsWith(prefix)) return true;
  }
  return false;
}

/// 扫描单个文件，返回所有违规
List<Violation> _scanFile(String absPath, String displayPath) {
  final lines = File(absPath).readAsLinesSync();
  final result = <Violation>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // 简单剥离行内注释：只扫描 `//` 之前的部分。
    // 为什么不做完整字符串/注释解析：颜色场景下足够准确，避免引入 AST；
    // 极少数字符串字面量含 `//` 的情况可接受（颜色构造几乎不出现在 URL 字符串同行）。
    final codePart = line.split('//').first;

    if (codePart.isEmpty) continue;

    final lineNo = i + 1;
    result.addAll(_matchAll(_colorHex, codePart, displayPath, lineNo));
    result.addAll(_matchAll(_colorFromArgb, codePart, displayPath, lineNo));
    result.addAll(_matchAll(_colorFromRgbo, codePart, displayPath, lineNo));
    // Colors.xxx 需单独处理：transparent 放行
    for (final m in _colorsProp.allMatches(codePart)) {
      final propName = m.group(1)!;
      if (propName == _transparentAllowed) continue;
      result.add(Violation(displayPath, lineNo, m.start + 1, m.group(0)!));
    }
  }
  return result;
}

/// 对一条正则收集所有匹配，转为 Violation 列表
List<Violation> _matchAll(
  RegExp pattern,
  String code,
  String displayPath,
  int lineNo,
) {
  return pattern
      .allMatches(code)
      .map((m) => Violation(displayPath, lineNo, m.start + 1, m.group(0)!))
      .toList();
}
