import '../threads/thread_summary.dart';

enum ThreadReviewDelivery {
  inline('inline'),
  detached('detached');

  const ThreadReviewDelivery(this.wireName);

  final String wireName;
}

enum ThreadReviewTargetKind { uncommittedChanges, baseBranch, commit, custom }

class ThreadReviewTarget {
  const ThreadReviewTarget.uncommittedChanges()
    : kind = ThreadReviewTargetKind.uncommittedChanges,
      branch = null,
      sha = null,
      title = null,
      instructions = null;

  const ThreadReviewTarget.baseBranch(this.branch)
    : kind = ThreadReviewTargetKind.baseBranch,
      sha = null,
      title = null,
      instructions = null;

  const ThreadReviewTarget.commit(this.sha, {this.title})
    : kind = ThreadReviewTargetKind.commit,
      branch = null,
      instructions = null;

  const ThreadReviewTarget.custom(this.instructions)
    : kind = ThreadReviewTargetKind.custom,
      branch = null,
      sha = null,
      title = null;

  final ThreadReviewTargetKind kind;
  final String? branch;
  final String? sha;
  final String? title;
  final String? instructions;

  Map<String, Object?> toJson() {
    return switch (kind) {
      ThreadReviewTargetKind.uncommittedChanges => {
        'type': 'uncommittedChanges',
      },
      ThreadReviewTargetKind.baseBranch => {
        'type': 'baseBranch',
        'branch': branch,
      },
      ThreadReviewTargetKind.commit => {
        'type': 'commit',
        'sha': sha,
        'title': title,
      },
      ThreadReviewTargetKind.custom => {
        'type': 'custom',
        'instructions': instructions,
      },
    };
  }
}

class ThreadReviewStartResult {
  const ThreadReviewStartResult({
    required this.turn,
    required this.reviewThreadId,
  });

  factory ThreadReviewStartResult.fromJson(Map<String, Object?> json) {
    final turn = TurnSummary.fromTurnResponse(json);
    final reviewThreadId = _stringValue(json['reviewThreadId']);
    if (turn.id.isEmpty || reviewThreadId == null) {
      throw const FormatException(
        'review/start response missing turn or reviewThreadId.',
      );
    }
    return ThreadReviewStartResult(turn: turn, reviewThreadId: reviewThreadId);
  }

  final TurnSummary turn;
  final String reviewThreadId;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
