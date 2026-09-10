// 简单 HTML 富文本解析器
//
// 歌手简介功能 V1.1
// 用于渲染 Last.fm/Wikipedia 返回的 HTML 格式简介。
//
// 支持的标签：
// - <p> 段落
// - <br> 换行
// - <b> / <strong> 粗体
// - <i> / <em> 斜体
// - <a href="..."> 链接（显示为蓝色可点击文本）
// - <ul>/<ol>/<li> 列表
//
// 不支持的标签会被忽略（只保留文本内容）。
//
// 注意：这是一个轻量级解析器，不支持嵌套复杂标签，
// 适合渲染歌手简介这类简单的 HTML 内容。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// HTML 解析器
class SimpleHtmlParser {
  /// 将 HTML 字符串解析为 TextSpan 列表
  static List<TextSpan> parse(String html, {TextStyle? baseStyle}) {
    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var currentStyle = baseStyle ?? const TextStyle();
    var inBold = false;
    var inItalic = false;
    var inLink = false;
    String? currentHref;

    int i = 0;
    while (i < html.length) {
      if (html[i] == '<') {
        // 先输出缓冲区内容
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(
            text: buffer.toString(),
            style: currentStyle,
            recognizer: inLink && currentHref != null
                ? (TapGestureRecognizer()
                  ..onTap = () => _launchUrl(currentHref!))
                : null,
          ));
          buffer.clear();
        }

        // 查找标签结束位置
        final end = html.indexOf('>', i);
        if (end == -1) {
          buffer.write(html[i]);
          i++;
          continue;
        }

        final tag = html.substring(i + 1, end).trim().toLowerCase();
        i = end + 1;

        // 处理标签
        if (tag == 'br' || tag == 'br/') {
          spans.add(const TextSpan(text: '\n'));
        } else if (tag == 'p' || tag == 'p/') {
          spans.add(const TextSpan(text: '\n\n'));
        } else if (tag == 'b' || tag == 'strong') {
          inBold = true;
          currentStyle = currentStyle.copyWith(fontWeight: FontWeight.bold);
        } else if (tag == '/b' || tag == '/strong') {
          inBold = false;
          currentStyle = currentStyle.copyWith(fontWeight: FontWeight.normal);
        } else if (tag == 'i' || tag == 'em') {
          inItalic = true;
          currentStyle = currentStyle.copyWith(fontStyle: FontStyle.italic);
        } else if (tag == '/i' || tag == '/em') {
          inItalic = false;
          currentStyle = currentStyle.copyWith(fontStyle: FontStyle.normal);
        } else if (tag.startsWith('a ')) {
          // 提取 href
          final hrefMatch = RegExp(r'href="([^"]*)"').firstMatch(tag);
          if (hrefMatch != null) {
            inLink = true;
            currentHref = hrefMatch.group(1);
            currentStyle = currentStyle.copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            );
          }
        } else if (tag == '/a') {
          inLink = false;
          currentHref = null;
          currentStyle = currentStyle.copyWith(
            color: null,
            decoration: null,
          );
        } else if (tag == 'li') {
          spans.add(const TextSpan(text: '• '));
        } else if (tag == '/li') {
          spans.add(const TextSpan(text: '\n'));
        }
        // 其他标签忽略
      } else {
        buffer.write(html[i]);
        i++;
      }
    }

    // 输出剩余内容
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(
        text: buffer.toString(),
        style: currentStyle,
        recognizer: inLink && currentHref != null
            ? (TapGestureRecognizer()
              ..onTap = () => _launchUrl(currentHref!))
            : null,
      ));
    }

    return spans;
  }

  /// 去除 HTML 标签，返回纯文本
  static String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</p>'), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  /// 启动 URL
  static Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // 忽略启动失败
    }
  }
}

/// HTML 富文本 Widget
class HtmlText extends StatelessWidget {
  final String html;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const HtmlText(
    this.html, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final spans = SimpleHtmlParser.parse(html, baseStyle: style);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
