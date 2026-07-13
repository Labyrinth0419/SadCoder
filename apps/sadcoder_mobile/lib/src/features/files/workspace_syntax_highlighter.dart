import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../theme/sadcoder_theme.dart';

class WorkspaceSyntaxHighlighter extends SyntaxHighlighter {
  WorkspaceSyntaxHighlighter({
    required SadCoderThemeColors colors,
    this.language,
    TextStyle? baseStyle,
  }) : _baseStyle = (baseStyle ?? const TextStyle()).copyWith(
         fontFamily: sadCoderMonospaceFontFamily,
         color: colors.codeForeground,
       ),
       _keywordStyle = TextStyle(
         color: colors.codeKeyword,
         fontWeight: FontWeight.w600,
       ),
       _stringStyle = TextStyle(color: colors.codeString),
       _commentStyle = TextStyle(color: colors.codeComment);

  final String? language;
  final TextStyle _baseStyle;
  final TextStyle _keywordStyle;
  final TextStyle _stringStyle;
  final TextStyle _commentStyle;

  @override
  TextSpan format(String source) {
    return TextSpan(
      style: _baseStyle,
      children: _highlightSpans(
        source,
        language: language,
        keywordStyle: _keywordStyle,
        stringStyle: _stringStyle,
        commentStyle: _commentStyle,
      ),
    );
  }
}

List<TextSpan> _highlightSpans(
  String content, {
  required String? language,
  required TextStyle keywordStyle,
  required TextStyle stringStyle,
  required TextStyle commentStyle,
}) {
  final keywordPattern = _keywordPattern(language);
  final spans = <TextSpan>[];
  for (final line in content.split('\n')) {
    final commentIndex = _commentIndex(line);
    final code = commentIndex == -1 ? line : line.substring(0, commentIndex);
    final comment = commentIndex == -1 ? '' : line.substring(commentIndex);
    spans.addAll(
      _codeLineSpans(code, keywordPattern, keywordStyle, stringStyle),
    );
    if (comment.isNotEmpty) {
      spans.add(TextSpan(text: comment, style: commentStyle));
    }
    spans.add(const TextSpan(text: '\n'));
  }
  return spans;
}

List<TextSpan> _codeLineSpans(
  String code,
  RegExp keywordPattern,
  TextStyle keywordStyle,
  TextStyle stringStyle,
) {
  final spans = <TextSpan>[];
  final pattern = RegExp(
    '("(?:[^"\\\\]|\\\\.)*"|\'(?:[^\'\\\\]|\\\\.)*\'|${keywordPattern.pattern})',
  );
  var cursor = 0;
  for (final match in pattern.allMatches(code)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: code.substring(cursor, match.start)));
    }
    final text = match.group(0)!;
    final isString = text.startsWith('"') || text.startsWith("'");
    spans.add(
      TextSpan(text: text, style: isString ? stringStyle : keywordStyle),
    );
    cursor = match.end;
  }
  if (cursor < code.length) {
    spans.add(TextSpan(text: code.substring(cursor)));
  }
  return spans;
}

RegExp _keywordPattern(String? language) {
  final keywords = switch (language?.toLowerCase()) {
    'dart' => [
      'abstract',
      'async',
      'await',
      'class',
      'const',
      'else',
      'extends',
      'final',
      'for',
      'if',
      'implements',
      'import',
      'return',
      'switch',
      'void',
      'while',
      'yield',
    ],
    'rust' || 'rs' => [
      'async',
      'await',
      'enum',
      'fn',
      'impl',
      'let',
      'match',
      'mod',
      'mut',
      'pub',
      'return',
      'struct',
      'trait',
      'use',
    ],
    'javascript' || 'js' || 'typescript' || 'ts' => [
      'async',
      'await',
      'class',
      'const',
      'else',
      'export',
      'extends',
      'function',
      'if',
      'import',
      'interface',
      'let',
      'return',
      'type',
      'var',
    ],
    'json' => ['false', 'null', 'true'],
    'python' || 'py' => [
      'async',
      'await',
      'class',
      'def',
      'elif',
      'else',
      'False',
      'for',
      'from',
      'if',
      'import',
      'in',
      'None',
      'return',
      'True',
      'while',
      'yield',
    ],
    _ => [
      'async',
      'await',
      'class',
      'const',
      'else',
      'enum',
      'false',
      'final',
      'fn',
      'for',
      'if',
      'import',
      'let',
      'null',
      'return',
      'struct',
      'true',
      'while',
    ],
  };
  return RegExp('\\b(?:${keywords.join('|')})\\b');
}

int _commentIndex(String line) {
  var inSingleQuotedString = false;
  var inDoubleQuotedString = false;
  var escaped = false;
  for (var index = 0; index < line.length; index++) {
    final char = line[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (inSingleQuotedString || inDoubleQuotedString) {
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (char == "'" && inSingleQuotedString) {
        inSingleQuotedString = false;
      } else if (char == '"' && inDoubleQuotedString) {
        inDoubleQuotedString = false;
      }
      continue;
    }
    if (char == "'") {
      inSingleQuotedString = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuotedString = true;
      continue;
    }
    if (char == '/' && index + 1 < line.length && line[index + 1] == '/') {
      return index;
    }
  }

  final firstNonWhitespace = line.indexOf(RegExp(r'\S'));
  if (firstNonWhitespace != -1 && line[firstNonWhitespace] == '#') {
    return firstNonWhitespace;
  }
  return -1;
}
