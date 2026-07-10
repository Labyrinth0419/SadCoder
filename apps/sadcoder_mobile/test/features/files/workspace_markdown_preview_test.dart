import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/files/workspace_markdown_preview.dart';
import 'package:sadcoder_mobile/src/features/files/workspace_syntax_highlighter.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('renders common GFM elements without loading remote images', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sadCoderThemeData(
          colorPalette: AppColorPalette.sadcoder,
          brightness: Brightness.light,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: WorkspaceMarkdownPreview(
              content: '''
# Guide

**Important** and [documentation](https://example.com/docs).

> quoted text

- [x] complete
- [ ] pending

| Name | Value |
| --- | --- |
| Mode | Safe |

```dart
final message = "ok"; // note
```

![Remote image](https://example.com/image.png)
''',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workspace-markdown-preview')),
      findsOneWidget,
    );
    expect(find.text('Guide'), findsOneWidget);
    expect(find.textContaining('quoted text'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-markdown-image-placeholder')),
      findsOneWidget,
    );
    expect(
      find.textContaining('https://example.com/image.png'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
  });

  test('uses semantic colors for code tokens', () {
    final span = WorkspaceSyntaxHighlighter(
      colors: SadCoderThemeColors.light,
      language: 'dart',
    ).format('final message = "ok"; // note');
    final leaves = _leafSpans(span);

    expect(
      leaves.singleWhere((span) => span.text == 'final').style?.color,
      SadCoderThemeColors.light.codeKeyword,
    );
    expect(
      leaves.singleWhere((span) => span.text == '"ok"').style?.color,
      SadCoderThemeColors.light.codeString,
    );
    expect(
      leaves.singleWhere((span) => span.text == '// note').style?.color,
      SadCoderThemeColors.light.codeComment,
    );
  });
}

List<TextSpan> _leafSpans(TextSpan root) {
  final leaves = <TextSpan>[];

  void visit(InlineSpan span) {
    if (span is! TextSpan) {
      return;
    }
    if (span.text != null) {
      leaves.add(span);
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child);
    }
  }

  visit(root);
  return leaves;
}
