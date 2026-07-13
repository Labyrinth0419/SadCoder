import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_test_approval_command.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));
  final now = DateTime.utc(2026, 7, 14, 12, 30, 0, 1, 2);

  test('test approval command queues a file-change approval', () async {
    final controller = ApprovalStateController();
    addTearDown(controller.dispose);

    final summary = await queueTestApprovalFromCommand(
      l10n: l10n,
      approvalController: controller,
      threadId: 'thr_1',
      activeTurnId: 'turn_1',
      now: now,
      arguments: '',
    );

    expect(summary, 'Test approval request queued.');
    expect(controller.approvals, hasLength(1));
    final approval = controller.approvals.single;
    expect(
      approval.requestId,
      'debug-test-approval-${now.microsecondsSinceEpoch}',
    );
    expect(approval.method, fileChangeApprovalMethod);
    expect(approval.kind, PendingApprovalKind.fileChange);
    expect(approval.threadId, 'thr_1');
    expect(approval.turnId, 'turn_1');
    expect(approval.startedAtMs, now.millisecondsSinceEpoch);
    expect(approval.reason, 'SadCoder test approval request');
    expect(approval.grantRoot, '/tmp');
    expect(approval.title, 'File change approval: /tmp');
    expect(approval.rawParams['threadId'], 'thr_1');
    expect(approval.rawParams['turnId'], 'turn_1');
    expect(approval.rawParams['startedAtMs'], now.millisecondsSinceEpoch);
    expect(approval.rawParams['grantRoot'], '/tmp');
    expect(approval.rawParams['reason'], 'SadCoder test approval request');
    expect(approval.rawParams['changes'], isA<List<Object?>>());
  });

  test(
    'test approval command uses fallback turn id without active turn',
    () async {
      final approval = buildTestFileChangeApproval(
        l10n: l10n,
        threadId: null,
        turnId: 'turn-1',
        now: now,
      );

      expect(approval.threadId, isNull);
      expect(approval.turnId, 'turn-1');
      expect(approval.rawParams.containsKey('threadId'), isFalse);
      expect(approval.rawParams['turnId'], 'turn-1');
    },
  );

  test(
    'test approval command rejects unsupported and unavailable inputs',
    () async {
      final controller = ApprovalStateController();
      addTearDown(controller.dispose);

      final unsupported = await queueTestApprovalFromCommand(
        l10n: l10n,
        approvalController: controller,
        threadId: 'thr_1',
        activeTurnId: 'turn_1',
        now: now,
        arguments: 'extra',
      );
      final unavailable = await queueTestApprovalFromCommand(
        l10n: l10n,
        approvalController: null,
        threadId: 'thr_1',
        activeTurnId: 'turn_1',
        now: now,
        arguments: '',
      );

      expect(unsupported, isNull);
      expect(unavailable, isNull);
      expect(controller.approvals, isEmpty);
    },
  );
}
