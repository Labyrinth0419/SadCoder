import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/app/sadcoder_app.dart';

void main() {
  testWidgets('renders the SadCoder shell', (tester) async {
    await tester.pumpWidget(const SadCoderApp());

    expect(find.text('Hosts'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Approvals'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('SSH profile'), findsOneWidget);
  });

  testWidgets('renders Chinese localization', (tester) async {
    await tester.pumpWidget(const SadCoderApp(locale: Locale('zh')));

    expect(find.text('主机'), findsWidgets);
    expect(find.text('SSH 配置'), findsOneWidget);
    expect(find.text('对话'), findsWidgets);
    expect(find.text('审批'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
