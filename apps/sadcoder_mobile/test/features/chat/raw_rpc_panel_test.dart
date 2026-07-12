import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/raw_rpc_panel.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  testWidgets('requires confirmation before sending raw RPC', (tester) async {
    final calls = <({String method, Map<String, Object?>? params})>[];
    await _pumpPanel(
      tester,
      onSend: ({required method, params}) async {
        calls.add((method: method, params: params));
        return {'ok': true, 'method': method};
      },
    );

    await tester.tap(find.text('Raw RPC'));
    await tester.pumpAndSettle();

    FilledButton sendButton() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('chat-raw-rpc-send')),
    );

    expect(sendButton().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('chat-raw-rpc-method-field')),
      ' thread/custom ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-raw-rpc-params-field')),
      '{"threadId":"thr_1","limit":2}',
    );
    await tester.pump();

    expect(sendButton().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('chat-raw-rpc-confirm')));
    await tester.pump();
    expect(sendButton().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('chat-raw-rpc-send')));
    await tester.pumpAndSettle();

    expect(calls.single.method, 'thread/custom');
    expect(calls.single.params, {'threadId': 'thr_1', 'limit': 2});
    expect(find.byKey(const ValueKey('chat-raw-rpc-result')), findsOneWidget);
    expect(find.textContaining('"ok": true'), findsOneWidget);
  });

  testWidgets('rejects non-object params before sending', (tester) async {
    var calls = 0;
    await _pumpPanel(
      tester,
      onSend: ({required method, params}) async {
        calls++;
        return {'ok': true};
      },
    );

    await tester.tap(find.text('Raw RPC'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-raw-rpc-method-field')),
      'thread/custom',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-raw-rpc-params-field')),
      '[]',
    );
    await tester.tap(find.byKey(const ValueKey('chat-raw-rpc-confirm')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-raw-rpc-send')));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byKey(const ValueKey('chat-raw-rpc-error')), findsOneWidget);
    expect(find.text('Params must be a JSON object'), findsOneWidget);
  });

  testWidgets('is disabled while disconnected', (tester) async {
    await _pumpPanel(tester, onSend: null);

    await tester.tap(find.text('Raw RPC'));
    await tester.pumpAndSettle();

    expect(
      find.text('Connect to a host before sending raw RPC.'),
      findsOneWidget,
    );
    final sendButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('chat-raw-rpc-send')),
    );
    expect(sendButton.onPressed, isNull);
  });
}

Future<void> _pumpPanel(WidgetTester tester, {required RawRpcSender? onSend}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: RawRpcPanel(onSend: onSend)),
    ),
  );
}
