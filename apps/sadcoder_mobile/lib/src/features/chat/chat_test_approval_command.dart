import '../../approvals/approval_request_mapper.dart';
import '../../approvals/approval_state_controller.dart';
import '../../approvals/pending_approval.dart';
import '../../i18n/app_localizations.dart';

Future<String?> queueTestApprovalFromCommand({
  required AppLocalizations l10n,
  required ApprovalStateController? approvalController,
  required String? threadId,
  required String? activeTurnId,
  required DateTime now,
  required String arguments,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  if (approvalController == null) {
    return null;
  }

  approvalController.upsert(
    buildTestFileChangeApproval(
      l10n: l10n,
      threadId: threadId,
      turnId: activeTurnId ?? 'turn-1',
      now: now,
    ),
  );
  return l10n.slashCommandTestApprovalQueued;
}

PendingApproval buildTestFileChangeApproval({
  required AppLocalizations l10n,
  required String? threadId,
  required String turnId,
  required DateTime now,
}) {
  final reason = l10n.slashCommandTestApprovalReason;
  final startedAtMs = now.millisecondsSinceEpoch;
  final rawParams = <String, Object?>{
    'turnId': turnId,
    'startedAtMs': startedAtMs,
    'grantRoot': '/tmp',
    'reason': reason,
    'changes': [
      {'path': '/tmp/test.txt', 'kind': 'add', 'content': 'test'},
      {
        'path': '/tmp/test2.txt',
        'kind': 'update',
        'unifiedDiff': '+test\n-test2',
      },
    ],
  };
  if (threadId != null) {
    rawParams['threadId'] = threadId;
  }

  return PendingApproval(
    requestId: 'debug-test-approval-${now.microsecondsSinceEpoch}',
    method: fileChangeApprovalMethod,
    kind: PendingApprovalKind.fileChange,
    rawParams: rawParams,
    title: '${l10n.approvalKindFileChange}: /tmp',
    threadId: threadId,
    turnId: turnId,
    startedAtMs: startedAtMs,
    reason: reason,
    grantRoot: '/tmp',
  );
}
