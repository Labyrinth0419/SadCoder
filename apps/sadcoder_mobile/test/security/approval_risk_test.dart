import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/security/approval_risk.dart';

void main() {
  test('flags destructive command approvals', () {
    final approval = _commandApproval('rm -rf build');

    expect(isHighRiskApproval(approval), isTrue);
    expect(
      requiresApprovalSecondConfirmation(
        approval,
        CodexApprovalDecision.accept,
      ),
      isTrue,
    );
    expect(
      requiresApprovalSecondConfirmation(
        approval,
        CodexApprovalDecision.decline,
      ),
      isFalse,
    );
  });

  test('does not flag routine command approvals', () {
    expect(isHighRiskApproval(_commandApproval('cargo test')), isFalse);
  });

  test('flags large file change approvals by diff text or line count', () {
    expect(
      isLargeFileChangeApproval(
        _fileApproval({'diff': 'x' * largeApprovalDiffBytesThreshold}),
      ),
      isTrue,
    );
    expect(
      isLargeFileChangeApproval(
        _fileApproval({
          'summary': {'additions': 200, 'deletions': 150},
        }),
      ),
      isTrue,
    );
  });

  test('does not flag small file change approvals', () {
    expect(
      isLargeFileChangeApproval(
        _fileApproval({
          'summary': {'additions': 4, 'deletions': 2},
          'diff': '+small',
        }),
      ),
      isFalse,
    );
  });
}

PendingApproval _commandApproval(String command) {
  return PendingApproval(
    requestId: 'cmd-1',
    method: 'item/commandExecution/requestApproval',
    kind: PendingApprovalKind.commandExecution,
    rawParams: {'command': command},
    command: command,
  );
}

PendingApproval _fileApproval(Map<String, Object?> rawParams) {
  return PendingApproval(
    requestId: 'file-1',
    method: 'item/fileChange/requestApproval',
    kind: PendingApprovalKind.fileChange,
    rawParams: rawParams,
  );
}
